# Ops Daemon (Phase 1)

Local-only control surface for safe Docker Compose operations.

## Endpoints
- `GET /health`
- `POST /compose/up` `{ "serviceGroup": "core" | "apps" | "paperless" | "all" }`
- `POST /compose/restart` `{ "service": "paperless" }`
- `POST /env/write` `{ "service": "paperless", "key": "PAPERLESS_OCR_LANGUAGE", "value": "..." }`

## Safety
- Allowlisted groups/services only.
- Allowlisted env file keys only.
- No arbitrary command execution.
- Paperless env updates write to `.env` and re-render `dev/paperless/docker-compose.env`.
