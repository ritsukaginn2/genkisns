const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const SECRET_KEY = /(token|password|secret|authorization|api[_-]?key)/i;

function redact(fields) {
  if (!fields || typeof fields !== 'object') return fields;
  const out = {};
  for (const [key, value] of Object.entries(fields)) {
    out[key] = SECRET_KEY.test(key) ? '[redacted]' : value;
  }
  return out;
}

/**
 * Minimal structured (JSON-per-line) logger with level filtering and redaction
 * of obviously-sensitive field names. Errors/warnings go to stderr, the rest to
 * stdout, so log shippers can route by stream.
 */
export function createLogger(level = 'info') {
  const min = LEVELS[level] ?? LEVELS.info;
  function emit(lvl, msg, fields) {
    if (LEVELS[lvl] < min) return;
    const line = JSON.stringify({
      ts: new Date().toISOString(),
      level: lvl,
      msg,
      ...redact(fields),
    });
    if (lvl === 'error' || lvl === 'warn') process.stderr.write(`${line}\n`);
    else process.stdout.write(`${line}\n`);
  }
  return {
    debug: (msg, fields) => emit('debug', msg, fields),
    info: (msg, fields) => emit('info', msg, fields),
    warn: (msg, fields) => emit('warn', msg, fields),
    error: (msg, fields) => emit('error', msg, fields),
  };
}
