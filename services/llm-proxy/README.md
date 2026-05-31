# GenkiSNS LLM Proxy

V1.6 backend service for paid quota and secure LLM-powered AI interactions.

## Responsibility

- Manage anonymous installation identity.
- Validate entitlement and remaining quota.
- Enqueue interaction generation jobs.
- Call the configured LLM provider from workers with server-side API keys.
- Return structured JSON job results to the app.
- Keep request logs, rate limits, budget circuit breakers, and fallback-friendly errors.

## Planned Endpoint

```text
POST /v1/installations
GET  /v1/entitlements
POST /v1/purchases/verify
POST /v1/interactions/jobs
GET  /v1/interactions/jobs/:job_id
```

The Flutter app must call this service instead of calling OpenAI, Claude, Gemini, or any other provider directly.

## Local Environment

Copy `.env.example` to `.env` when implementation starts.
