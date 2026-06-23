# GenkiSNS Backend — User Management & LLM Proxy

A production-ready, secure backend for GenkiSNS. It owns **device-user identity &
moderation**, an **operator (admin) management system**, and a hardened
**LLM-forwarding proxy** (content review, rate/budget limits, queue, result
validation). It is **not** the source of truth for notes/media — the mobile app
keeps those in local SQLite. The backend stores only identity, moderation,
jobs, usage, and operator accounts.

Runs on **Node ≥ 22** with **zero external npm dependencies** (uses `node:sqlite`,
`node:http`, `node:crypto`).

## Responsibilities

- Anonymous **device users** (`installation_id` + an issued `device_token`
  secret) with moderation state: `allowed` / `limited` / `blocked`, plus an
  audit trail.
- **Operator accounts** (`username` + scrypt password) with role-based sessions
  (`viewer` < `admin` < `owner`) and a management API.
- **Content safety review** of text/nickname/bio/persona before any LLM call.
- **LLM forwarding** from server-side keys only (stub or OpenAI-compatible, e.g.
  DeepSeek), via a bounded-concurrency queue with structured-result validation
  and staggered `delay_seconds` for real-person-paced delivery.
- **Abuse protection**: per-installation + per-IP rate limits, daily job and
  estimated-budget caps; all over-limit / rejected paths are fallback-friendly.

## Architecture

```
src/
  index.js        bootstrap: config validation, admin seeding, graceful shutdown
  config.js       env-driven config
  db.js           node:sqlite connection + versioned migrations
  store.js        SqliteStore — all persistence (DAO)
  http.js         routing, CORS, request logging, device + admin handlers
  logger.js       JSON logging with secret redaction
  auth/
    passwords.js  scrypt hash/verify
    tokens.js     opaque token gen + sha256 storage + constant-time compare
    adminAuth.js  login, session validation, role checks
  cli/createAdmin.js   operator CLI to create/reset an admin
  llmProvider.js  stub + openai-compatible providers
  queue.js        bounded-concurrency job worker + delay assignment
  rateLimit.js    sliding-window limiter
  request.js      request normalization (caps friends, etc.)
  resultValidation.js   LLM JSON validation
  review.js       installation + content review
```

Data is a single SQLite file (`DATA_FILE`); schema is applied via `user_version`
migrations at startup.

## Endpoints

### Ops
```
GET  /healthz     liveness
GET  /readyz      readiness (db + provider configured)
```

### Device (end-user) API
```
POST /v1/installations              register/refresh; issues device_token once
GET  /v1/installations/me           moderation status
POST /v1/interactions/jobs          submit an AI-interaction job
GET  /v1/interactions/jobs/:job_id  poll job result
```
Headers: `X-Installation-Id` (required on the last three). When
`REQUIRE_DEVICE_TOKEN=true`, also `X-Device-Token` (the value returned by
`POST /v1/installations`).

### Admin (operator) API — `Authorization: Bearer <session-token>`
```
POST /admin/login                          {username,password} -> {token,role,expires_at}
POST /admin/logout
GET  /admin/me
GET  /admin/stats                          (viewer+)
GET  /admin/usage                          (viewer+)
GET  /admin/installations[?status&limit&offset]   (viewer+)
GET  /admin/installations/:id              (viewer+)  detail + audit + recent jobs
POST /admin/installations/:id/status       (admin+)   {status,reason}
GET  /admin/jobs[?installation_id&status]  (viewer+)
GET  /admin/admins                         (owner)
POST /admin/admins                         (owner)    {username,password,role}
POST /admin/admins/:id/disable             (owner)
POST /admin/admins/:id/enable              (owner)
```

## Configuration

Copy `.env.example` to `.env` (gitignored; auto-loaded at startup). Key vars:

| Var | Default | Notes |
|-----|---------|-------|
| `NODE_ENV` | development | `production` fails fast on unsafe config |
| `LOG_LEVEL` | info | debug/info/warn/error |
| `DATA_FILE` | ./data/llm-proxy.db | SQLite file |
| `LLM_PROVIDER` | stub | `stub` or `openai-compatible` |
| `LLM_ENDPOINT` / `LLM_API_KEY` / `LLM_MODEL` | — | server-side provider creds |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | — | seeds first `owner` if no admin exists |
| `SESSION_TTL_HOURS` | 168 | admin session lifetime |
| `REQUIRE_DEVICE_TOKEN` | false | enforce per-device token on device API |
| `CORS_ALLOWED_ORIGINS` | * | comma-separated; set explicit origins in prod |
| `TRUST_PROXY` | false | honor `X-Forwarded-For` only behind a trusted proxy |
| `INSTALLATION_RATE_LIMIT_PER_MINUTE` | 8 | |
| `IP_RATE_LIMIT_PER_MINUTE` | 30 | |
| `DAILY_JOB_LIMIT` / `DAILY_BUDGET_CENTS` / `ESTIMATED_JOB_COST_CENTS` | 500/500/2 | |
| `MAX_TEXT_LENGTH` / `MAX_COMMENTS` / `MAX_COMMENT_LENGTH` / `MAX_FRIENDS` | 2000/5/160/12 | |
| `COMMENT_FIRST_DELAY_SECONDS` / `COMMENT_DELAY_GAP_SECONDS` / `COMMENT_MAX_DELAY_SECONDS` | 4/18/600 | staggered delivery pacing |
| `INTERNAL_TOKEN` | change-me | legacy `/internal` moderation; prefer admin API |

## Running

Local (stub provider, no key):
```sh
cp .env.example .env
npm test
npm start
```

Real model (e.g. DeepSeek) in `.env`:
```sh
LLM_PROVIDER=openai-compatible
LLM_ENDPOINT=https://api.deepseek.com/v1/chat/completions
LLM_API_KEY=<server-side-key>
LLM_MODEL=deepseek-chat
```

Seed an operator (either env on first boot, or CLI any time):
```sh
ADMIN_USERNAME=root ADMIN_PASSWORD=<strong-pass> npm start   # first owner
npm run create-admin -- root '<strong-pass>' owner            # CLI create/reset
```

Docker:
```sh
docker build -t genki-llm-proxy .
docker run -p 8787:8787 -v genki_data:/data --env-file .env genki-llm-proxy
```

Physical phone in dev (LAN IP, which is DHCP and can change):
```sh
flutter run --dart-define=GENKI_API_BASE=http://<mac-lan-ip>:8787
```

## Production checklist

- `NODE_ENV=production`, a real `LLM_API_KEY`, and a rotated `INTERNAL_TOKEN`
  (or remove reliance on `/internal`).
- Seed an `owner` admin; create least-privilege `viewer`/`admin` accounts.
- Terminate TLS at a reverse proxy and set `TRUST_PROXY=true` + explicit
  `CORS_ALLOWED_ORIGINS`.
- Consider `REQUIRE_DEVICE_TOKEN=true` once clients send `X-Device-Token`.
- Back up the SQLite `DATA_FILE`.

## Security model

- LLM provider keys never reach the app — server-side only.
- Admin passwords: scrypt; session tokens are random and stored only as SHA-256;
  all secret comparisons are constant-time; login timing is uniform.
- Device tokens defend against `installation_id` impersonation.
- Request body size limits, friends-array cap, content review before LLM, and
  per-installation/IP/daily limits bound abuse and cost.

## Tests

```sh
npm test
```
Covers installation registration, moderation states, content review, queue-first
generation, result validation, rate/budget limits, staggered delays, device-token
enforcement, admin auth, role enforcement, and operator management.
