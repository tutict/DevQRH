# DevQRH RAG Sidecar

Local loopback service used by the Flutter desktop app.

The current implementation provides retrieval endpoints with the same response
shape as the Flutter offline matcher:

- `GET /health`
- `POST /lookup`
- `POST /agent/navigate`
- `POST /rag/answer`

`/rag/answer` performs local retrieval over the supplied handbook package and
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
