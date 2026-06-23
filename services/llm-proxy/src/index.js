import { loadConfig } from './config.js';
import { createApp } from './http.js';
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
const store = new SqliteStore(config.dataFile);
const app = await createApp({ config, store });

app.server.listen(config.port, config.host, () => {
  // eslint-disable-next-line no-console
  console.log(`GenkiSNS LLM proxy listening on http://${config.host}:${config.port}`);
});
