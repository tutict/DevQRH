# 应手 RAG Sidecar

Local loopback service used by the Flutter desktop app for offline-first study material retrieval, grounded learning Q&A, card generation assistance, and review scheduling.

Primary learning endpoints:

- `GET /health`
- `GET /metrics`
- `POST /content/sync`
- `POST /lookup`
- `POST /rag/answer`
- `POST /cards/generate`
- `POST /review/schedule`

Call `/content/sync` with the active learning package first:

```json
{ "bundle": { "manifest": {}, "matchingConfig": {}, "materials": [], "decks": [], "cards": [] } }
```

The sidecar validates the `LearningBundle`, builds an in-memory retrieval index over `materials`, and returns a `contentVersion`. Subsequent `/lookup`, `/rag/answer`, and `/cards/generate` calls should send `contentVersion`; they may also send an inline `bundle` for one-shot fallback.

`/lookup` returns ranked study materials with the same JSON shape as the Flutter offline matcher. `/rag/answer` returns a deterministic local answer with citations; it does not require a model key and must stay grounded in retrieved material.

`/cards/generate` is intentionally gated on model configuration. If `DEVQRH_LLM_API_KEY` is missing, it returns HTTP 503 with a clear error so Flutter can disable AI card generation without affecting search or review. The current build emits deterministic card candidates behind that gate; provider-backed generation can be added without changing the Flutter contract.

`/review/schedule` accepts a `ReviewState`, one of `again`, `hard`, `good`, or `easy`, and returns the updated spaced-repetition state.

OpenAI-compatible provider settings:

```powershell
$env:DEVQRH_LLM_API_KEY="..."
$env:DEVQRH_LLM_MODEL="..."
$env:DEVQRH_LLM_BASE_URL="https://api.openai.com/v1" # optional
$env:DEVQRH_LLM_TEMPERATURE="0.2" # optional
$env:DEVQRH_LLM_TIMEOUT_SECONDS="20" # optional
$env:DEVQRH_LLM_MAX_CONCURRENCY="2" # optional
```

The older runbook `{ bootstrap }` sync and `/agent/navigate` path remain for compatibility while the Flutter client moves to `features/knowledge` and `LearningBundle`.

Run locally:

```bash
go run . --port=0
```

The process prints a JSON readiness line to stdout:

```json
{"event":"ready","port":12345}
```

Flutter starts this executable on desktop when it is present next to the app binary, then falls back to the in-app matcher if the sidecar is missing.

Run a local k6 smoke/stress test after starting the sidecar on a fixed port:

```powershell
go run . --port=18080
cd ..\..
k6 run -e TARGET=http://127.0.0.1:18080 -e BUNDLE_MULTIPLIER=100 loadtest/devqrh-sidecar.k6.js
```
