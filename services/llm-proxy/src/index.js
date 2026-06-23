import { hashPassword } from './auth/passwords.js';
import { loadConfig } from './config.js';
import { createApp } from './http.js';
import { createLogger } from './logger.js';
import { SqliteStore } from './store.js';

// Load a local .env (gitignored) into process.env if present, so secrets like
// the LLM API key live in a file instead of the command line. No-op when the
// file is missing — the ambient environment still wins.
try {
  process.loadEnvFile();
} catch {
  // No .env file; rely on the ambient environment.
}

const config = loadConfig();
const logger = createLogger(config.logLevel);

validateProductionConfig(config, logger);

const store = new SqliteStore(config.dataFile);
await seedBootstrapAdmin(store, config, logger);
await store.deleteExpiredSessions();

const app = await createApp({ config, store, logger });
const server = app.server;

server.listen(config.port, config.host, () => {
  logger.info('listening', {
    host: config.host,
    port: config.port,
    provider: config.llmProvider,
    env: config.nodeEnv,
    require_device_token: config.requireDeviceToken,
  });
});

let shuttingDown = false;
async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info('shutdown_start', { signal });
  server.close();
  try {
    await app.queue.onIdle();
  } catch {
    // best effort
  }
  try {
    store.close();
  } catch {
    // best effort
  }
  logger.info('shutdown_complete', {});
  process.exit(0);
}
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => shutdown(signal));
}

function validateProductionConfig(cfg, log) {
  if (cfg.nodeEnv !== 'production') return;
  const problems = [];
  if (cfg.llmProvider === 'openai-compatible' && !cfg.llmApiKey) {
    problems.push('LLM_API_KEY is required for the openai-compatible provider');
  }
  if (cfg.internalToken === 'change-me') {
    problems.push('INTERNAL_TOKEN is still the example default');
  }
  if (cfg.corsAllowedOrigins.includes('*')) {
    log.warn('cors_wildcard_in_production', {
      hint: 'set CORS_ALLOWED_ORIGINS to explicit origins',
    });
  }
  if (!cfg.requireDeviceToken) {
    log.warn('device_token_not_enforced', {
      hint: 'set REQUIRE_DEVICE_TOKEN=true so installation_id cannot be impersonated',
    });
  }
  if (problems.length > 0) {
    log.error('invalid_production_config', { problems });
    process.exit(1);
  }
}

async function seedBootstrapAdmin(s, cfg, log) {
  if ((await s.countAdmins()) > 0) return;
  if (!cfg.adminBootstrapUsername || !cfg.adminBootstrapPassword) {
    if (cfg.nodeEnv === 'production') {
      log.error('no_admin_in_production', {
        hint: 'set ADMIN_USERNAME and ADMIN_PASSWORD to seed the first operator account',
      });
      process.exit(1);
    }
    log.warn('no_admin_configured', {
      hint: 'set ADMIN_USERNAME and ADMIN_PASSWORD to seed the first operator account',
    });
    return;
  }
  if (cfg.adminBootstrapPassword.length < 8) {
    log.error('admin_password_too_short', { hint: 'ADMIN_PASSWORD must be >= 8 chars' });
    return;
  }
  await s.createAdmin({
    username: cfg.adminBootstrapUsername,
    passwordHash: hashPassword(cfg.adminBootstrapPassword),
    role: 'owner',
  });
  log.info('admin_seeded', { username: cfg.adminBootstrapUsername, role: 'owner' });
}
