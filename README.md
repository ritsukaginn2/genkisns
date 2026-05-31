# GenkiSNS

GenkiSNS is a private virtual SNS app. The real user publishes notes locally; AI friends generate likes and comments.

## Repository Layout

```text
apps/
  mobile/          Flutter iOS / Android app
services/
  llm-proxy/       V1.6 cloud LLM proxy backend
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

The mobile app stores V1 notes and interactions in local SQLite. V1 uses local template interactions; real LLM provider keys must not be stored in the app.

## LLM Proxy

The V1.6 backend service lives in `services/llm-proxy`. It will handle quota, paid entitlement, queued LLM jobs, and provider API keys on the server.
