import { randomUUID } from 'node:crypto';
import { createServer as createHttpServer } from 'node:http';

import {
  ADMIN_ROLES,
  authenticateAdmin,
  isValidRole,
  loginAdmin,
  publicAdmin,
  roleAtLeast,
} from './auth/adminAuth.js';
import { hashPassword } from './auth/passwords.js';
import { generateToken, hashToken, safeEqualHex } from './auth/tokens.js';
import { createLlmProvider } from './llmProvider.js';
import { createLogger } from './logger.js';
import { JobQueue } from './queue.js';
import { SlidingWindowRateLimiter } from './rateLimit.js';
import { buildInteractionRequest } from './request.js';
import { reviewContent, reviewInstallation } from './review.js';
import { makeInstallation } from './store.js';

export async function createApp({
  config,
  store,
  provider = createLlmProvider(config),
  logger = createLogger(config.logLevel),
}) {
  await store.load();
  await store.markStaleJobsFailed();
  const queue = new JobQueue({ store, provider, config });
  const rateLimiter = new SlidingWindowRateLimiter();

  function send(res, statusCode, body) {
    const payload = body == null ? '' : JSON.stringify(body);
    res.writeHead(statusCode, {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': Buffer.byteLength(payload),
    });
    res.end(payload);
  }

  async function handler(req, res) {
    const startedAt = Date.now();
    const url = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`);
    const route = `${req.method} ${url.pathname}`;
    applyCorsHeaders(req, res, config);
    res.on('finish', () => {
      logger.info('request', {
        method: req.method,
        path: url.pathname,
        status: res.statusCode,
        ms: Date.now() - startedAt,
        ip: clientIp(req, config),
      });
    });

    try {
      if (req.method === 'OPTIONS') return send(res, 204, null);
      if (route === 'GET /healthz') return send(res, 200, { ok: true });
      if (route === 'GET /readyz') return handleReady({ res, store, config, send });

      // Device (end-user) API.
      if (route === 'POST /v1/installations') {
        return await handleRegisterInstallation({ req, res, config, store, send });
      }
      if (route === 'GET /v1/installations/me') {
        return await handleGetInstallation({ req, res, config, store, send });
      }
      if (route === 'POST /v1/interactions/jobs') {
        return await handleCreateJob({ req, res, config, store, queue, rateLimiter, send });
      }
      if (req.method === 'GET' && url.pathname.startsWith('/v1/interactions/jobs/')) {
        const jobId = decodeURIComponent(url.pathname.split('/').at(-1));
        return await handleGetJob({ req, res, config, store, jobId, send });
      }

      // Admin (operator) API.
      if (url.pathname === '/admin/login' && req.method === 'POST') {
        return await handleAdminLogin({ req, res, config, store, send });
      }
      if (url.pathname.startsWith('/admin/')) {
        return await handleAdminRoute({ req, res, url, config, store, send });
      }

      // Legacy internal moderation endpoint (kept for backward compatibility).
      if (req.method === 'POST' && url.pathname.startsWith('/internal/installations/')) {
        const parts = url.pathname.split('/');
        const installationId = decodeURIComponent(parts[3] ?? '');
        if ((parts[4] ?? '') === 'status') {
          return await handleSetInstallationStatus({ req, res, config, store, installationId, send });
        }
      }

      return send(res, 404, { error: 'not_found' });
    } catch (error) {
      const statusCode = error.statusCode ?? 500;
      if (statusCode >= 500) logger.error('handler_error', { route, error: error.message });
      return send(res, statusCode, {
        error: error.code ?? (statusCode >= 500 ? 'internal_error' : 'bad_request'),
        // Never echo raw internal error messages to clients on 5xx.
        detail: statusCode >= 500 ? 'internal_error' : error.message,
        fallback_required: statusCode >= 500,
      });
    }
  }

  return {
    handler,
    server: createHttpServer(handler),
    queue,
    store,
    logger,
  };
}

// --- Device endpoints ---

async function handleRegisterInstallation({ req, res, config, store, send }) {
  const body = await readJson(req, config.requestBodyLimitBytes);
  const installationId = normalizeInstallationId(body.installation_id) ?? makeInstallationId();
  const installation = await store.upsertInstallation(
    makeInstallation({
      installationId,
      platform: typeof body.platform === 'string' ? body.platform : 'unknown',
      appVersion: typeof body.app_version === 'string' ? body.app_version : '',
      deviceModel: typeof body.device_model === 'string' ? body.device_model : '',
    }),
  );

  let deviceToken;
  if (!installation.device_token_hash) {
    // New (or legacy tokenless) device: issue a secret, returned exactly once.
    deviceToken = generateToken();
    await store.setDeviceTokenHash(installationId, hashToken(deviceToken));
  } else if (!deviceTokenMatches(req, installation) && config.requireDeviceToken) {
    // A token exists; an unauthenticated refresh must not be able to claim it.
    throw httpError(401, 'device_token_required', 'valid X-Device-Token required');
  }

  return send(res, 200, installationResponse(installation, deviceToken));
}

async function handleGetInstallation({ req, res, config, store, send }) {
  const installation = await requireInstallation(req, store, config);
  return send(res, 200, installationResponse(installation));
}

async function handleCreateJob({ req, res, config, store, queue, rateLimiter, send }) {
  const installation = await requireInstallation(req, store, config);
  const installationReview = reviewInstallation(installation);
  if (!installationReview.ok) return sendFallback(send, res, installationReview.reason);

  let request;
  try {
    const body = await readJson(req, config.requestBodyLimitBytes);
    request = buildInteractionRequest(body, { maxFriends: config.maxFriends });
  } catch (error) {
    return sendFallback(send, res, error.message || 'invalid_request');
  }
  const contentReview = reviewContent({ payload: request, config });
  if (!contentReview.ok) return sendFallback(send, res, contentReview.reason);

  const ip = clientIp(req, config);
  const installationLimit = rateLimiter.check({
    key: `installation:${installation.installation_id}`,
    limit: config.installationRateLimitPerMinute,
  });
  if (!installationLimit.ok) {
    return send(res, 429, {
      error: 'rate_limited',
      detail: 'installation_rate_limited',
      retry_after_seconds: installationLimit.retryAfterSeconds,
      fallback_required: true,
    });
  }
  const ipLimit = rateLimiter.check({ key: `ip:${ip}`, limit: config.ipRateLimitPerMinute });
  if (!ipLimit.ok) {
    return send(res, 429, {
      error: 'rate_limited',
      detail: 'ip_rate_limited',
      retry_after_seconds: ipLimit.retryAfterSeconds,
      fallback_required: true,
    });
  }

  const now = new Date().toISOString();
  const job = {
    job_id: makeJobId(),
    installation_id: installation.installation_id,
    post_id: request.post_id,
    status: 'queued',
    request,
    fallback_required: false,
    created_at: now,
    updated_at: now,
  };
  const created = await store.createJobIfBudgetAvailable(job, config);
  if (!created.ok) return sendFallback(send, res, created.reason);
  queue.enqueue(job);
  return send(res, 202, {
    job_id: job.job_id,
    status: job.status,
    estimated_wait_seconds: 2,
    fallback_required: false,
  });
}

async function handleGetJob({ req, res, config, store, jobId, send }) {
  const installation = await requireInstallation(req, store, config);
  const job = await store.getJob(jobId);
  if (!job || job.installation_id !== installation.installation_id) {
    return send(res, 404, { error: 'job_not_found' });
  }
  return send(res, 200, jobResponse(job));
}

// --- Admin endpoints ---

async function handleAdminLogin({ req, res, config, store, send }) {
  const body = await readJson(req, config.requestBodyLimitBytes);
  const result = await loginAdmin({
    store,
    config,
    username: typeof body.username === 'string' ? body.username : '',
    password: typeof body.password === 'string' ? body.password : '',
  });
  if (!result) throw httpError(401, 'invalid_credentials', 'invalid username or password');
  return send(res, 200, {
    token: result.token,
    role: result.admin.role,
    expires_at: result.expiresAt,
  });
}

async function handleAdminRoute({ req, res, url, config, store, send }) {
  const segments = url.pathname.split('/').filter(Boolean); // ['admin', ...]
  const sub = segments.slice(1);
  const method = req.method;

  if (sub[0] === 'logout' && method === 'POST') {
    const token = bearerToken(req);
    if (token) await store.deleteSession(hashToken(token));
    return send(res, 204, null);
  }
  if (sub[0] === 'me' && method === 'GET') {
    const admin = await requireAdmin({ req, store, minRole: 'viewer' });
    return send(res, 200, publicAdmin(admin));
  }
  if (sub[0] === 'stats' && method === 'GET') {
    await requireAdmin({ req, store, minRole: 'viewer' });
    return send(res, 200, await store.getStats());
  }
  if (sub[0] === 'usage' && method === 'GET') {
    await requireAdmin({ req, store, minRole: 'viewer' });
    return send(res, 200, await store.getUsage());
  }
  if (sub[0] === 'installations' && sub.length === 1 && method === 'GET') {
    await requireAdmin({ req, store, minRole: 'viewer' });
    const status = url.searchParams.get('status') || undefined;
    if (status && !['allowed', 'limited', 'blocked'].includes(status)) {
      throw httpError(400, 'bad_request', 'invalid status filter');
    }
    const limit = queryInt(url, 'limit', 50, 200);
    const offset = queryInt(url, 'offset', 0, 1_000_000);
    const [items, total] = await Promise.all([
      store.listInstallations({ status, limit, offset }),
      store.countInstallations({ status }),
    ]);
    return send(res, 200, { items, total, limit, offset });
  }
  if (sub[0] === 'installations' && sub.length === 2 && method === 'GET') {
    await requireAdmin({ req, store, minRole: 'viewer' });
    const id = decodeURIComponent(sub[1]);
    const installation = await store.getInstallation(id);
    if (!installation) throw httpError(404, 'not_found', 'installation not found');
    const [audit, jobs] = await Promise.all([
      store.getInstallationAudit(id),
      store.listJobs({ installationId: id, limit: 20 }),
    ]);
    return send(res, 200, {
      installation: installationDetail(installation),
      audit,
      recent_jobs: jobs,
    });
  }
  if (sub[0] === 'installations' && sub.length === 3 && sub[2] === 'status' && method === 'POST') {
    const admin = await requireAdmin({ req, store, minRole: 'admin' });
    const id = decodeURIComponent(sub[1]);
    const body = await readJson(req, config.requestBodyLimitBytes);
    if (!['allowed', 'limited', 'blocked'].includes(body.status)) {
      throw httpError(400, 'bad_request', 'invalid_status');
    }
    const installation = await store.setInstallationStatus({
      installationId: id,
      status: body.status,
      reason: typeof body.reason === 'string' ? body.reason : '',
      source: `admin:${admin.username}`,
    });
    return send(res, 200, installationResponse(installation));
  }
  if (sub[0] === 'jobs' && method === 'GET') {
    await requireAdmin({ req, store, minRole: 'viewer' });
    const installationId = url.searchParams.get('installation_id') || undefined;
    const status = url.searchParams.get('status') || undefined;
    const items = await store.listJobs({
      installationId,
      status,
      limit: queryInt(url, 'limit', 50, 200),
      offset: queryInt(url, 'offset', 0, 1_000_000),
    });
    return send(res, 200, { items });
  }
  if (sub[0] === 'admins' && sub.length === 1 && method === 'GET') {
    await requireAdmin({ req, store, minRole: 'owner' });
    return send(res, 200, { items: await store.listAdmins() });
  }
  if (sub[0] === 'admins' && sub.length === 1 && method === 'POST') {
    await requireAdmin({ req, store, minRole: 'owner' });
    const body = await readJson(req, config.requestBodyLimitBytes);
    return await createAdminAccount({ res, store, body, send });
  }
  if (sub[0] === 'admins' && sub.length === 3 && sub[2] === 'disable' && method === 'POST') {
    const admin = await requireAdmin({ req, store, minRole: 'owner' });
    const targetId = parsePositiveInt(sub[1]);
    if (targetId === null) throw httpError(400, 'bad_request', 'invalid admin id');
    return await setAdminDisabled({ res, store, admin, targetId, disabled: true, send });
  }
  if (sub[0] === 'admins' && sub.length === 3 && sub[2] === 'enable' && method === 'POST') {
    await requireAdmin({ req, store, minRole: 'owner' });
    const targetId = parsePositiveInt(sub[1]);
    if (targetId === null) throw httpError(400, 'bad_request', 'invalid admin id');
    const updated = await store.setAdminDisabled(targetId, false);
    if (!updated) throw httpError(404, 'not_found', 'admin not found');
    return send(res, 200, publicAdmin(updated));
  }

  return send(res, 404, { error: 'not_found' });
}

async function createAdminAccount({ res, store, body, send }) {
  const username = typeof body.username === 'string' ? body.username.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const role = typeof body.role === 'string' ? body.role : 'admin';
  if (!/^[A-Za-z0-9_.-]{3,40}$/.test(username)) {
    throw httpError(400, 'bad_request', 'username must be 3-40 chars [A-Za-z0-9_.-]');
  }
  if (password.length < 8) throw httpError(400, 'bad_request', 'password must be >= 8 chars');
  if (!isValidRole(role)) throw httpError(400, 'bad_request', `role must be one of ${ADMIN_ROLES.join(', ')}`);
  if (await store.getAdminByUsername(username)) {
    throw httpError(409, 'conflict', 'username already exists');
  }
  const admin = await store.createAdmin({ username, passwordHash: hashPassword(password), role });
  return send(res, 201, publicAdmin(admin));
}

async function setAdminDisabled({ res, store, admin, targetId, disabled, send }) {
  if (targetId === admin.id) throw httpError(400, 'bad_request', 'cannot disable yourself');
  const target = await store.getAdminById(targetId);
  if (!target) throw httpError(404, 'not_found', 'admin not found');
  const updated = await store.setAdminDisabled(targetId, disabled);
  if (disabled) await store.deleteSessionsForAdmin(targetId);
  return send(res, 200, publicAdmin(updated));
}

async function handleSetInstallationStatus({ req, res, config, store, installationId, send }) {
  const provided = req.headers['x-internal-token'];
  const authorized =
    Boolean(config.internalToken) &&
    typeof provided === 'string' &&
    safeEqualHex(hashToken(provided), hashToken(config.internalToken));
  if (!authorized) return send(res, 401, { error: 'unauthorized' });
  const body = await readJson(req, config.requestBodyLimitBytes);
  if (!['allowed', 'limited', 'blocked'].includes(body.status)) {
    return send(res, 400, { error: 'bad_request', detail: 'invalid_status' });
  }
  const installation = await store.setInstallationStatus({
    installationId,
    status: body.status,
    reason: typeof body.reason === 'string' ? body.reason : '',
    source: typeof body.source === 'string' ? body.source : 'internal_api',
  });
  return send(res, 200, installationResponse(installation));
}

function handleReady({ res, store, config, send }) {
  const providerReady = config.llmProvider === 'stub' || Boolean(config.llmApiKey);
  let dbReady = true;
  try {
    store.db.prepare('SELECT 1').get();
  } catch {
    dbReady = false;
  }
  const ready = providerReady && dbReady;
  return send(res, ready ? 200 : 503, {
    ok: ready,
    db: dbReady,
    provider: providerReady ? 'ready' : 'missing_api_key',
  });
}

// --- Auth helpers ---

async function requireAdmin({ req, store, minRole }) {
  const auth = await authenticateAdmin({ store, token: bearerToken(req) });
  if (!auth) throw httpError(401, 'unauthorized', 'admin authentication required');
  if (!roleAtLeast(auth.admin.role, minRole)) {
    throw httpError(403, 'forbidden', `requires role >= ${minRole}`);
  }
  return auth.admin;
}

async function requireInstallation(req, store, config) {
  const installationId = normalizeInstallationId(req.headers['x-installation-id']);
  if (!installationId) throw httpError(401, 'unauthorized', 'X-Installation-Id header is required');
  // Do NOT auto-provision here: registration is the only path that creates an
  // installation. This prevents id squatting / table inflation by unauthenticated
  // callers and avoids treating an arbitrary id as a valid identity.
  const installation = await store.getInstallation(installationId);
  if (!installation) throw httpError(401, 'unauthorized', 'unknown installation; register first');
  // When device-token enforcement is on, require a valid token unconditionally
  // (a tokenless/legacy installation must re-register to obtain one).
  if (config.requireDeviceToken) {
    if (!installation.device_token_hash || !deviceTokenMatches(req, installation)) {
      throw httpError(401, 'unauthorized', 'valid X-Device-Token required');
    }
  }
  return installation;
}

function deviceTokenMatches(req, installation) {
  const provided = req.headers['x-device-token'];
  if (typeof provided !== 'string' || !provided.trim()) return false;
  return safeEqualHex(hashToken(provided.trim()), installation.device_token_hash);
}

function bearerToken(req) {
  const header = req.headers['authorization'];
  if (typeof header === 'string' && header.startsWith('Bearer ')) {
    return header.slice('Bearer '.length).trim();
  }
  return null;
}

// --- Shared helpers ---

async function readJson(req, limitBytes = 64 * 1024) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limitBytes) throw httpError(413, 'payload_too_large', 'request_body_too_large');
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw httpError(400, 'bad_request', 'invalid_json');
  }
}

function sendFallback(send, res, reason) {
  return send(res, 200, { status: 'failed', reason, fallback_required: true });
}

function applyCorsHeaders(req, res, config) {
  const allowed = config.corsAllowedOrigins;
  const origin = req.headers['origin'];
  let allowOrigin = null;
  if (allowed.includes('*')) allowOrigin = '*';
  else if (typeof origin === 'string' && allowed.includes(origin)) allowOrigin = origin;
  if (!allowOrigin) return; // origin not allowed -> emit no CORS headers
  res.setHeader('Access-Control-Allow-Origin', allowOrigin);
  if (allowOrigin !== '*') res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type,X-Installation-Id,X-Device-Token,X-Internal-Token,Authorization',
  );
}

function parsePositiveInt(value) {
  const n = Number.parseInt(value, 10);
  return Number.isInteger(n) && n > 0 && String(n) === String(value) ? n : null;
}

function httpError(statusCode, code, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  return error;
}

function queryInt(url, name, fallback, max) {
  const raw = url.searchParams.get(name);
  if (raw == null || raw === '') return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 0) return fallback;
  return Math.min(parsed, max);
}

function installationResponse(installation, deviceToken) {
  const body = {
    installation_id: installation.installation_id,
    status: installation.status,
    status_reason: installation.status_reason,
    backend_available: true,
    updated_at: installation.updated_at,
  };
  if (deviceToken) body.device_token = deviceToken;
  return body;
}

function installationDetail(installation) {
  return {
    installation_id: installation.installation_id,
    platform: installation.platform,
    app_version: installation.app_version,
    device_model: installation.device_model,
    status: installation.status,
    status_reason: installation.status_reason,
    has_device_token: Boolean(installation.device_token_hash),
    created_at: installation.created_at,
    updated_at: installation.updated_at,
    last_seen_at: installation.last_seen_at,
  };
}

function jobResponse(job) {
  return {
    job_id: job.job_id,
    status: job.status,
    result: job.result ?? null,
    reason: job.reason ?? null,
    fallback_required: Boolean(job.fallback_required),
  };
}

function makeInstallationId() {
  return randomUUID().replaceAll('-', '');
}

function makeJobId() {
  return `job_${randomUUID().replaceAll('-', '')}`;
}

function normalizeInstallationId(value) {
  if (Array.isArray(value)) return normalizeInstallationId(value[0]);
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return /^[A-Za-z0-9_-]{12,80}$/.test(trimmed) ? trimmed : null;
}

function clientIp(req, config) {
  if (config?.trustProxy) {
    const forwarded = req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim()) {
      return forwarded.split(',')[0].trim();
    }
  }
  return req.socket.remoteAddress ?? 'unknown';
}
