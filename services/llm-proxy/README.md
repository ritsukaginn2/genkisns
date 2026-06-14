# GenkiSNS LLM Proxy

Runnable V1.6 backend service for installation review, content review, queue-first
LLM generation, rate limits, and budget guards.

## Responsibility

- Manage anonymous installation identity.
- Store installation review state: `allowed`, `limited`, `blocked`.
- Review text content before it enters LLM generation.
- Enqueue interaction generation jobs and process them with bounded worker concurrency.
- Call the configured LLM provider from workers with server-side API keys.
- Validate structured JSON job results before returning them to the app.
- Enforce per-installation rate limits, per-IP rate limits, daily job limits, and
  estimated daily budget limits.
- Return fallback-friendly responses so the app can keep local template comments.

The backend is not the source of truth for V1 notes. The Flutter app continues to store notes, media references, likes, comments, and local replies in local SQLite.

## Endpoints

```text
GET  /healthz
POST /v1/installations
GET  /v1/installations/me
POST /v1/interactions/jobs
GET  /v1/interactions/jobs/:job_id
POST /internal/installations/:installation_id/status
```

The Flutter app must call this service instead of calling OpenAI, Claude, Gemini, or any other hosted LLM provider directly.

## Local Environment

Copy `.env.example` to `.env`, then run:

```sh
npm test
npm start
```

`LLM_PROVIDER=stub` keeps local development runnable without a model key. Use
`LLM_PROVIDER=openai-compatible` with `LLM_API_KEY`, `LLM_ENDPOINT`, and
`LLM_MODEL` when connecting a hosted provider.

Example real-provider settings:

```sh
LLM_PROVIDER=openai-compatible
LLM_ENDPOINT=https://api.openai.com/v1/chat/completions
LLM_API_KEY=<server-side-api-key>
LLM_MODEL=gpt-4o-mini
```

For a physical phone, start the service on the Mac LAN interface and run the
Flutter app with an IP-based backend URL:

```sh
flutter run --dart-define=GENKI_API_BASE=http://<mac-lan-ip>:8787
```

## Internal Review Operation

Set `INTERNAL_TOKEN` in `.env`, then update an installation review state with
the protected internal endpoint:

```sh
curl -X POST http://127.0.0.1:8787/internal/installations/<installation_id>/status \
  -H 'Content-Type: application/json' \
  -H 'X-Internal-Token: <internal-token>' \
  -d '{"status":"blocked","reason":"manual review","source":"operator"}'
```

Allowed `status` values are `allowed`, `limited`, and `blocked`. `limited` and
`blocked` return fallback-friendly job responses so the app keeps its local
template comments.

## Verification

```sh
npm test
```

The test suite covers installation registration, allowed / limited / blocked
review states, content review, queue-first generation, invalid LLM results,
per-installation limits, per-IP limits, and daily budget guards.

The backend does not store GenkiSNS notes or media files. The mobile app remains
the source of truth for local posts, likes, comments, replies, and media refs.
