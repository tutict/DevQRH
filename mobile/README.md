# DevQRH Mobile

Standalone Flutter handbook app with an optional local Go RAG sidecar on
desktop.

## Current mode

- No remote backend required
- Desktop builds can use `rag_sidecar.exe` for local retrieval and RAG answers
- Built-in handbook bundle ships with the app
- Users can import a local handbook package from Settings
- Imported content replaces the current local handbook cache
- Users can restore the built-in handbook at any time

## Handbook package format

Import a JSON file with this shape:

```json
{
  "manifest": {
    "schemaVersion": 2,
    "packageId": "devqrh.default.oncall",
    "name": "DevQRH Default On-Call Runbooks",
    "version": "20260415",
    "checklistCount": 4,
    "runbookCount": 4,
    "generatedAt": 1776124800000,
    "team": "platform",
    "defaultLocale": "en-US"
  },
  "matchingConfig": {
    "partialMinLength": 3,
    "synonymGroups": [["slow", "latency"]],
    "weights": {
      "exactQueryId": 1.0,
      "exactIdToken": 1.0,
      "exactTitleToken": 0.95,
      "exactKeywordToken": 0.9,
      "exactSymptomToken": 0.78,
      "exactContextToken": 0.6,
      "synonymKeyword": 0.72,
      "synonymPrimary": 0.62,
      "synonymAny": 0.5,
      "partialKeyword": 0.48,
      "partialPrimary": 0.4,
      "partialAny": 0.28,
      "tokenAverage": 0.88,
      "keywordCoverage": 0.12,
      "exactTitleBoost": 0.12,
      "partialTitleBoost": 0.07,
      "partialIdBoost": 0.07,
      "phraseBoost": 0.04
    }
  },
  "checklists": [
    {
      "id": "cpu_100",
      "title": "CPU 100%",
      "summary": "Use this runbook when a service or host is CPU saturated.",
      "severity": "p2",
      "systems": ["linux", "jvm", "backend-service"],
      "tags": ["cpu", "saturation"],
      "keywords": ["cpu"],
      "symptoms": ["high CPU"],
      "signals": ["CPU usage above 90%"],
      "owner": "backend platform",
      "escalation": "Escalate to the owning service team if errors rise.",
      "lastReviewedAt": "2026-04-15",
      "reviewIntervalDays": 180,
      "safeSteps": [{"step": 1, "action": "top", "risk": "safe"}],
      "cautionSteps": [],
      "dangerSteps": [],
      "commands": [
        {
          "id": "cpu-top",
          "title": "Top processes",
          "command": "top",
          "step": 1,
          "risk": "safe"
        }
      ],
      "immediateActions": [{"step": 1, "action": "top", "risk": "safe"}],
      "decisionTree": [{"condition": "high GC", "action": "analyze dump"}],
      "rootCause": ["bad code"],
      "longTermFix": ["optimize hot path"],
      "relatedRunbooks": []
    }
  ]
}
```

`schemaVersion: 2` packages can include on-call metadata such as severity,
systems, owner/escalation, review freshness, risk-grouped steps, and copyable
commands. Older packages with only `immediateActions` still import; missing
operational metadata is treated as a validation warning rather than a fatal
error.

The built-in reference package lives at `assets/content/default_bundle.json`.

## Build

Windows release:

```bash
flutter build windows
```

Windows release with the local Go sidecar:

```powershell
..\scripts\build-windows-with-sidecar.ps1
```

Output:

```text
build/windows/x64/runner/Release/
```

Ship the whole `Release/` folder, not only `DevQRH.exe`. With the sidecar build,
that folder also contains `rag_sidecar.exe`.

When `rag_sidecar.exe` is present, the Agent tab shows a local RAG answer with
source citations before the recommended runbook. If the sidecar is missing, the
app falls back to the built-in Flutter matcher.

Optional LLM mode is configured through the sidecar environment:

```powershell
$env:DEVQRH_LLM_API_KEY="..."
$env:DEVQRH_LLM_MODEL="..."
$env:DEVQRH_LLM_BASE_URL="https://api.openai.com/v1" # optional
```

Android release:

```bash
flutter build apk
```

This machine currently cannot build Android because the Android SDK is not installed.

## App identity

- App name: `DevQRH`
- Android package: `com.devqrh.app`
- Windows binary: `DevQRH.exe`
