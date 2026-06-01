# DevQRH RAG Sidecar

Local loopback service used by the Flutter desktop app.

The current implementation provides retrieval endpoints with the same response
shape as the Flutter offline matcher:

- `GET /health`
- `GET /metrics`
- `POST /content/sync`
- `POST /lookup`
- `POST /agent/navigate`
- `POST /rag/answer`

Call `/content/sync` with the active handbook package first. It validates the
package, builds an in-memory retrieval index, and returns a `contentVersion`.
Subsequent `/lookup`, `/agent/navigate`, and `/rag/answer` calls should send
only `query` plus `contentVersion`.

The query endpoints still accept the older `{ query, bootstrap }` shape as a
compatibility fallback, but that path is slower because it has to decode and
index the package for that request.

`/rag/answer` performs local retrieval over the synced handbook package and
returns a grounded answer plus citations. This endpoint is deterministic and
does not require a cloud LLM key.

Set the following environment variables to enable an OpenAI-compatible chat
completion provider:

```powershell
$env:DEVQRH_LLM_API_KEY="..."
$env:DEVQRH_LLM_MODEL="..."
$env:DEVQRH_LLM_BASE_URL="https://api.openai.com/v1" # optional
$env:DEVQRH_LLM_TEMPERATURE="0.2" # optional
$env:DEVQRH_LLM_TIMEOUT_SECONDS="20" # optional
```

If the provider call fails, the endpoint returns the deterministic local answer
with `mode: "local_fallback"`.

Optional LLM protection:

```powershell
$env:DEVQRH_LLM_MAX_CONCURRENCY="2"
```

The sidecar also applies an internal circuit breaker after repeated provider
failures and falls back to the local answer while the circuit is open.

Run locally:

```bash
go run . --port=0
```

The process prints a JSON readiness line to stdout:

```json
{"event":"ready","port":12345}
```

Flutter starts this executable on desktop when it is present next to the app
binary, then falls back to the in-app matcher if the sidecar is missing.

Run a local k6 smoke/stress test after starting the sidecar on a fixed port:

```powershell
go run . --port=18080
cd ..\..
k6 run -e TARGET=http://127.0.0.1:18080 -e BUNDLE_MULTIPLIER=100 loadtest/devqrh-sidecar.k6.js
```
