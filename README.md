# DevQRH

Developer Quick Reference Handbook.

Fast lookup for incident checklists.

## Principles

- Clarity over intelligence
- Speed over completeness
- Action path over explanation

## Run

Build:

```bash
mvn test
mvn package
```

CLI:

```bash
java -jar target/devqrh.jar ask "CPU 100%"
java -jar target/devqrh.jar ask "service is slow"
java -jar target/devqrh.jar agent "service is slow"
```

Windows shortcut:

```powershell
.\devqrh.cmd ask "CPU 100%"
```

Server:

```bash
java -jar target/devqrh.jar serve
```

Cross-platform app:

```bash
cd mobile
flutter pub get
flutter run --dart-define=DEVQRH_API_BASE_URL=http://localhost:8080
```

Reload without restart:

```bash
curl -X POST http://localhost:8080/api/admin/reload
```

Auto reload:

- Works on Windows, macOS, Linux
- Watches `data/*.yaml`
- Watches `src/main/resources/matcher/matching-config.yaml`
- Enabled by default in `serve` mode
- Uses Java `WatchService`, no extra native dependency

## API

- `GET /api/lookup?q=CPU%20100`
- `GET /api/agent/navigate?q=service%20is%20slow`
- `GET /api/checklists/cpu_100`
- `GET /api/mobile/manifest`
- `GET /api/mobile/bootstrap`
- `POST /api/admin/reload`

## Matching Config

- Synonyms and weights: `src/main/resources/matcher/matching-config.yaml`
- Tune synonyms in `synonym_groups`
- Tune ranking in `weights`
- No Java change needed for normal relevance tuning
- Running server prefers local files when they exist:
  - checklists: `data/*.yaml`
  - matcher config: `src/main/resources/matcher/matching-config.yaml`
- Auto reload config:
  - `devqrh.auto-reload.enabled`
  - `devqrh.auto-reload.debounce-ms`

## Mobile

- Stack: Flutter
- Targets: Android / iOS / Web / Windows / macOS / Linux
- App root: `mobile/`
- Default API:
  - Android emulator: `http://10.0.2.2:8080`
  - Others: `http://localhost:8080`
- Override API:
  - `--dart-define=DEVQRH_API_BASE_URL=http://<host>:8080`
- Backend CORS is enabled for `/api/**` and configurable via `devqrh.cors.allowed-origin-patterns`
- App sync flow:
  - app boot loads cached content first
  - UI renders cached checklist content before remote sync finishes
  - fetch `/api/mobile/manifest`
  - compare local version
  - fetch `/api/mobile/bootstrap` when changed
  - bootstrap includes checklist content and matching config
  - search falls back to cached checklist data when offline

## Data Format

```yaml
id: cpu_100
title: CPU 100%
keywords:
  - cpu
  - load
symptoms:
  - high CPU
immediate_actions:
  - step: 1
    action: "top"
decision_tree:
  - condition: "high GC"
    action: "analyze heap dump"
root_cause:
  - bad code
long_term_fix:
  - optimize code
```
