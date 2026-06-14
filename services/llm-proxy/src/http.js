import { randomUUID } from 'node:crypto';
import { createServer as createHttpServer } from 'node:http';

import { createLlmProvider } from './llmProvider.js';
import { JobQueue } from './queue.js';
import { SlidingWindowRateLimiter } from './rateLimit.js';
import { buildInteractionRequest } from './request.js';
import { reviewContent, reviewInstallation } from './review.js';
import { makeInstallation } from './store.js';

export async function createApp({ config, store, provider = createLlmProvider(config) }) {
  await store.load();
  await store.markStaleJobsFailed();
  const queue = new JobQueue({ store, provider, config });
  const rateLimiter = new SlidingWindowRateLimiter();

  async function handler(req, res) {
    try {
      const url = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`);
      const route = `${req.method} ${url.pathname}`;

      if (req.method === 'OPTIONS') {
        return sendJson(res, 204, null);
      }
      if (route === 'GET /healthz') {
        return sendJson(res, 200, { ok: true });
      }
      // NOTE: each handler is awaited so a thrown error rejects inside this
      // try/catch instead of escaping as an unhandled rejection.
      if (route === 'POST /v1/installations') {
        return await handleRegisterInstallation({ req, res, config, store });
      }
      if (route === 'GET /v1/installations/me') {
        return await handleGetInstallation({ req, res, store });
      }
      if (route === 'POST /v1/interactions/jobs') {
        return await handleCreateJob({ req, res, config, store, queue, rateLimiter });
      }
      if (req.method === 'GET' && url.pathname.startsWith('/v1/interactions/jobs/')) {
        const jobId = decodeURIComponent(url.pathname.split('/').at(-1));
        return await handleGetJob({ req, res, store, jobId });
      }
      if (req.method === 'POST' && url.pathname.startsWith('/internal/installations/')) {
        const parts = url.pathname.split('/');
        const installationId = decodeURIComponent(parts[3] ?? '');
        const action = parts[4] ?? '';
        if (action === 'status') {
          return await handleSetInstallationStatus({ req, res, config, store, installationId });
        }
      }

      return sendJson(res, 404, { error: 'not_found' });
    } catch (error) {
      const statusCode = error.statusCode ?? 500;
      return sendJson(res, statusCode, {
        error: statusCode >= 500 ? 'internal_error' : 'bad_request',
        detail: error.message,
        fallback_required: statusCode >= 500,
      });
    }
  }

  return {
    handler,
    server: createHttpServer(handler),
    queue,
    store,
  };
}

async function handleRegisterInstallation({ req, res, config, store }) {
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
  return sendJson(res, 200, installationResponse(installation));
}

async function handleGetInstallation({ req, res, store }) {
  const installation = await requireInstallation(req, store);
  return sendJson(res, 200, installationResponse(installation));
}

async function handleCreateJob({ req, res, config, store, queue, rateLimiter }) {
  const installation = await requireInstallation(req, store);
  const installationReview = reviewInstallation(installation);
  if (!installationReview.ok) {
    return sendFallback(res, installationReview.reason);
  }

  // A malformed body / oversized request / missing field on the job route must
  // still be fallback-friendly so the app keeps its local template interactions.
  let request;
  try {
    const body = await readJson(req, config.requestBodyLimitBytes);
    request = buildInteractionRequest(body, { maxFriends: config.maxFriends });
  } catch (error) {
    return sendFallback(res, error.message || 'invalid_request');
  }
  const contentReview = reviewContent({ payload: request, config });
  if (!contentReview.ok) {
    return sendFallback(res, contentReview.reason);
  }

  const ip = clientIp(req, config);
  const installationLimit = rateLimiter.check({
    key: `installation:${installation.installation_id}`,
    limit: config.installationRateLimitPerMinute,
  });
  if (!installationLimit.ok) {
    return sendJson(res, 429, {
      error: 'rate_limited',
      detail: 'installation_rate_limited',
      retry_after_seconds: installationLimit.retryAfterSeconds,
      fallback_required: true,
    });
  }
  const ipLimit = rateLimiter.check({
    key: `ip:${ip}`,
    limit: config.ipRateLimitPerMinute,
  });
  if (!ipLimit.ok) {
    return sendJson(res, 429, {
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
  if (!created.ok) {
    return sendFallback(res, created.reason);
  }
  queue.enqueue(job);
  return sendJson(res, 202, {
    job_id: job.job_id,
    status: job.status,
    estimated_wait_seconds: 2,
    fallback_required: false,
  });
}

async function handleGetJob({ req, res, store, jobId }) {
  const installation = await requireInstallation(req, store);
  const job = await store.getJob(jobId);
  if (!job || job.installation_id !== installation.installation_id) {
    return sendJson(res, 404, { error: 'job_not_found' });
  }
  return sendJson(res, 200, jobResponse(job));
}

async function handleSetInstallationStatus({ req, res, config, store, installationId }) {
  if (!config.internalToken || req.headers['x-internal-token'] !== config.internalToken) {
    return sendJson(res, 401, { error: 'unauthorized' });
  }
  const body = await readJson(req);
  const status = body.status;
  if (!['allowed', 'limited', 'blocked'].includes(status)) {
    return sendJson(res, 400, { error: 'bad_request', detail: 'invalid_status' });
  }
  const installation = await store.setInstallationStatus({
    installationId,
    status,
    reason: typeof body.reason === 'string' ? body.reason : '',
    source: typeof body.source === 'string' ? body.source : 'internal_api',
  });
  return sendJson(res, 200, installationResponse(installation));
}

async function requireInstallation(req, store) {
  const installationId = normalizeInstallationId(req.headers['x-installation-id']);
  if (!installationId) {
    const error = new Error('X-Installation-Id header is required');
    error.statusCode = 401;
    throw error;
  }
  const installation = await store.getInstallation(installationId);
  if (!installation) {
    return store.upsertInstallation(
      makeInstallation({ installationId, platform: 'unknown' }),
    );
  }
  return installation;
}

async function readJson(req, limitBytes = 64 * 1024) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limitBytes) {
      const error = new Error('request_body_too_large');
      error.statusCode = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    const error = new Error('invalid_json');
    error.statusCode = 400;
    throw error;
  }
}

function sendFallback(res, reason) {
  return sendJson(res, 200, {
    status: 'failed',
    reason,
    fallback_required: true,
  });
}

function sendJson(res, statusCode, body) {
  const payload = body == null ? '' : JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,X-Installation-Id,X-Internal-Token',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function installationResponse(installation) {
  return {
    installation_id: installation.installation_id,
    status: installation.status,
    status_reason: installation.status_reason,
    backend_available: true,
    updated_at: installation.updated_at,
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
  // X-Forwarded-For is client-controlled and can be spoofed to bypass the per-IP
  // rate limit, so only honor it when explicitly running behind a trusted proxy.
  if (config?.trustProxy) {
    const forwarded = req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim()) {
      return forwarded.split(',')[0].trim();
    }
  }
  return req.socket.remoteAddress ?? 'unknown';
}
