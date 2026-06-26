# DevQRH

DevQRH is a Flutter incident handbook app with a local Go RAG sidecar for
desktop builds. The Flutter app still works offline by itself; when
`rag_sidecar.exe` is present next to the Windows app binary, Flutter starts it
and uses loopback HTTP for retrieval and grounded RAG answers in the Agent tab.

## Project Layout

```text
DevQRH
├─ mobile/           # Flutter cross-platform app
├─ sidecar/rag/      # Go local RAG sidecar
└─ scripts/          # Build helpers
```

## Quick Start (One-Click Dev)

Build the Go sidecar, fetch Flutter deps, and launch the desktop app in one step:

```bat
scripts\run-dev.bat
```

```powershell
.\scripts\run-dev.ps1
```

Pass a device id to target another platform, e.g. `scripts\run-dev.bat chrome`.
The sidecar is built to `mobile\build\sidecar\rag_sidecar.exe`, where Flutter
auto-discovers it (no env var needed).

## Run Flutter

```bash
cd mobile
flutter pub get
flutter run
```

## Run Sidecar During Development

```bash
cd sidecar/rag
go run . --port=0
```

To point Flutter at a manually built sidecar, set:

```powershell
$env:DEVQRH_RAG_SIDECAR="C:\path\to\rag_sidecar.exe"
```

## Test

```bash
cd mobile
flutter test

cd ../sidecar/rag
go test ./...
```

## Windows Build With Sidecar

```powershell
.\scripts\build-windows-with-sidecar.ps1
```

The final app folder is:

```text
mobile\build\windows\x64\runner\Release\
```

Ship the whole `Release\` folder or wrap it in an installer. It contains the
Flutter app files plus `rag_sidecar.exe`.

The current RAG path is fully local: Flutter sends the active handbook package
to the sidecar once, the sidecar validates it and builds an in-memory index,
then later requests send only the query plus the returned content version. The
sidecar retrieves the best runbooks and returns an answer with citations. No
cloud LLM key is required for this local answer mode.

To enable an OpenAI-compatible LLM provider, configure these environment
variables before starting the app:

```powershell
$env:DEVQRH_LLM_API_KEY="..."
$env:DEVQRH_LLM_MODEL="..."
$env:DEVQRH_LLM_BASE_URL="https://api.openai.com/v1" # optional
```

If the provider is not configured or is unavailable, the sidecar falls back to
the deterministic local answer.

The built-in handbook package lives at
`mobile/assets/content/default_bundle.json`.

## k6 Sidecar Load Test

Start the sidecar on a fixed port, then run the reusable k6 script:

```powershell
cd sidecar/rag
go run . --port=18080

cd ../..
k6 run -e TARGET=http://127.0.0.1:18080 -e BUNDLE_MULTIPLIER=100 loadtest/devqrh-sidecar.k6.js
```

Use `QUERY_MODE=legacy` to compare the old request shape that sends the full
handbook package on every query.
