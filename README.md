# GenkiSNS

GenkiSNS is a private virtual SNS app. The real user publishes notes locally; AI friends generate likes and comments.

## Repository Layout

```text
apps/
  mobile/          Flutter iOS / Android app
services/
  llm-proxy/       V1.6 backend for review and server-side LLM calls
docs/              Product, design, and architecture docs
```

## Mobile App

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

The mobile app stores V1 notes and interactions in local SQLite. It always
generates local template interactions first. When `GENKI_API_BASE` is configured,
it can upgrade those interactions through the V1.6 backend.

## Backend

```bash
cd services/llm-proxy
npm test
npm start
```

`services/llm-proxy` handles installation review state, safety checks, queued LLM
jobs, provider API keys on the server, rate limits, budget guards, and
fallback-friendly errors. The app must not call OpenAI, Claude, Gemini, or other
LLM providers directly in this hosted-backend path.

Local development can use `LLM_PROVIDER=stub` without a model key. For a real
provider, configure `LLM_PROVIDER=openai-compatible`, `LLM_API_KEY`,
`LLM_ENDPOINT`, and `LLM_MODEL` in `services/llm-proxy/.env`, then run the app
with:

```bash
flutter run --dart-define=GENKI_API_BASE=http://<backend-ip>:8787
```
