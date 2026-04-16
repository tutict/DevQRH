# DevQRH Mobile

Standalone Flutter handbook app.

## Current mode

- No backend required
- Built-in handbook bundle ships with the app
- Users can import a local handbook package from Settings
- Imported content replaces the current local handbook cache
- Users can restore the built-in handbook at any time

## Handbook package format

Import a JSON file with this shape:

```json
{
  "manifest": {
    "version": "20260415",
    "checklistCount": 4,
    "generatedAt": 1776124800000
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
      "keywords": ["cpu"],
      "symptoms": ["high CPU"],
      "immediateActions": [{"step": 1, "action": "top"}],
      "decisionTree": [{"condition": "high GC", "action": "analyze dump"}],
      "rootCause": ["bad code"],
      "longTermFix": ["optimize hot path"]
    }
  ]
}
```

The built-in reference package lives at `assets/content/default_bundle.json`.

## Build

Windows release:

```bash
flutter build windows
```

Output:

```text
build/windows/x64/runner/Release/
```

Ship the whole `Release/` folder, not only `DevQRH.exe`.

Android release:

```bash
flutter build apk
```

This machine currently cannot build Android because the Android SDK is not installed.

## App identity

- App name: `DevQRH`
- Android package: `com.devqrh.app`
- Windows binary: `DevQRH.exe`
