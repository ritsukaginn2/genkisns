import { loadConfig } from './config.js';
import { createApp } from './http.js';
import { JsonFileStore } from './store.js';

const config = loadConfig();
const store = new JsonFileStore(config.dataFile);
const app = await createApp({ config, store });

app.server.listen(config.port, config.host, () => {
  // eslint-disable-next-line no-console
  console.log(`GenkiSNS LLM proxy listening on http://${config.host}:${config.port}`);
});
