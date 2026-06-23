import { resolve } from 'node:path';

const DEFAULT_BLOCKLIST = [
  'BLOCK_ME',
  '自杀',
  '杀人',
  '诈骗',
];

function parseInteger(env, name, fallback, { min = 0 } = {}) {
  const raw = env[name];
  if (raw == null || raw === '') return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < min) {
    throw new Error(`${name} must be an integer >= ${min}`);
  }
  return parsed;
}

function parseList(raw, fallback) {
  const source = raw == null || raw.trim() === '' ? fallback.join(',') : raw;
  return source
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export function loadConfig(env = process.env) {
  const dataFile = env.DATA_FILE ?? resolve('data/llm-proxy.db');
  const llmProvider = env.LLM_PROVIDER ?? 'stub';

  return {
    host: env.HOST ?? '0.0.0.0',
    port: parseInteger(env, 'PORT', 8787, { min: 1 }),
    dataFile,
    nodeEnv: env.NODE_ENV ?? 'development',
    logLevel: env.LOG_LEVEL ?? 'info',
    // CORS allowlist for browser callers. '*' is fine for the native app (which
    // is not subject to CORS) and local dev; set explicit origins in production.
    corsAllowedOrigins: parseList(env.CORS_ALLOWED_ORIGINS, ['*']),
    internalToken: env.INTERNAL_TOKEN ?? '',
    // First-operator bootstrap: an owner admin is seeded on startup when set and
    // no admin exists yet.
    adminBootstrapUsername: env.ADMIN_USERNAME ?? '',
    adminBootstrapPassword: env.ADMIN_PASSWORD ?? '',
    sessionTtlHours: parseInteger(env, 'SESSION_TTL_HOURS', 168, { min: 1 }),
    // When true, device endpoints require a valid X-Device-Token issued at
    // registration (defends against installation_id impersonation). Default off
    // for smooth migration of already-deployed clients.
    requireDeviceToken: (env.REQUIRE_DEVICE_TOKEN ?? 'false').trim().toLowerCase() === 'true',
    // Only trust X-Forwarded-For (for per-IP rate limiting) when the service runs
    // behind a known reverse proxy. Default false so a direct client cannot spoof
    // the header to bypass IP rate limits.
    trustProxy: (env.TRUST_PROXY ?? 'false').trim().toLowerCase() === 'true',
    llmProvider,
    llmEndpoint: env.LLM_ENDPOINT ?? 'https://api.openai.com/v1/chat/completions',
    llmApiKey: env.LLM_API_KEY ?? '',
    llmModel: env.LLM_MODEL ?? 'gpt-4o-mini',
    llmTimeoutMs: parseInteger(env, 'LLM_TIMEOUT_MS', 20000, { min: 1000 }),
    requestBodyLimitBytes: parseInteger(env, 'REQUEST_BODY_LIMIT_BYTES', 64 * 1024, {
      min: 1024,
    }),
    workerConcurrency: parseInteger(env, 'WORKER_CONCURRENCY', 2, { min: 1 }),
    jobTimeoutMs: parseInteger(env, 'JOB_TIMEOUT_MS', 30000, { min: 1000 }),
    installationRateLimitPerMinute: parseInteger(
      env,
      'INSTALLATION_RATE_LIMIT_PER_MINUTE',
      8,
      { min: 1 },
    ),
    ipRateLimitPerMinute: parseInteger(env, 'IP_RATE_LIMIT_PER_MINUTE', 30, {
      min: 1,
    }),
    dailyJobLimit: parseInteger(env, 'DAILY_JOB_LIMIT', 500, { min: 1 }),
    dailyBudgetCents: parseInteger(env, 'DAILY_BUDGET_CENTS', 500, { min: 1 }),
    estimatedJobCostCents: parseInteger(env, 'ESTIMATED_JOB_COST_CENTS', 2, {
      min: 0,
    }),
    maxTextLength: parseInteger(env, 'MAX_TEXT_LENGTH', 2000, { min: 1 }),
    maxComments: parseInteger(env, 'MAX_COMMENTS', 5, { min: 1 }),
    maxCommentLength: parseInteger(env, 'MAX_COMMENT_LENGTH', 160, { min: 1 }),
    maxFriends: parseInteger(env, 'MAX_FRIENDS', 12, { min: 1 }),
    // Staggered delivery pacing: each comment gets a delay_seconds so the client
    // reveals them gradually (real-person feel) instead of dumping them at once.
    // delay[i] = firstDelay + i*gap, capped at maxDelay. All tunable via env.
    commentFirstDelaySeconds: parseInteger(env, 'COMMENT_FIRST_DELAY_SECONDS', 4, { min: 0 }),
    commentDelayGapSeconds: parseInteger(env, 'COMMENT_DELAY_GAP_SECONDS', 18, { min: 0 }),
    commentMaxDelaySeconds: parseInteger(env, 'COMMENT_MAX_DELAY_SECONDS', 600, { min: 1 }),
    safetyBlocklist: parseList(env.SAFETY_BLOCKLIST, DEFAULT_BLOCKLIST),
  };
}
