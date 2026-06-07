# DevQRH On-Call Local RAG PRD

Status: Draft confirmed for implementation planning
Date: 2026-06-08

## 1. Product Positioning

DevQRH will move from a generic handbook/RAG demo toward a local micro-RAG emergency quick-reference app for engineers during production incidents.

The first-class user job is:

> When an engineer is under incident pressure, they can search locally, find the most relevant runbook, see safe first actions, copy investigation commands or escalation summaries, and optionally ask a grounded local RAG brief without depending on a network service.

The product should feel like an on-call console, not a wiki, chat app, or document manager.

## 2. Target Users

- Backend engineers handling online service incidents.
- SRE/on-call engineers doing first-response triage.
- Team leads who need fast owner/escalation information.

V1 is optimized for backend service incidents, especially CPU, memory, database, latency, I/O, dependency, deployment, and capacity problems.

## 3. Core Principles

- Offline-first: core search, lookup, runbook rendering, and deterministic RAG answers must work without cloud access.
- Search-first: exact, fast retrieval is the primary workflow; RAG is a secondary briefing layer.
- Structured runbooks over generic documents: content must be authored as incident runbooks with explicit metadata and safety markings.
- Read-only app: V1 does not include an in-app editor.
- No command execution: DevQRH can display and copy commands, but must never execute operational commands.
- Safety visible by default: risky or destructive actions must be clearly separated from safe investigation steps.
- One active knowledge base: V1 ships and runs with one current handbook package at a time.

## 4. Non-Goals For V1

- No vector database.
- No multi-tenant/team knowledge-base switching.
- No incident timeline or full incident-management workflow.
- No chat, phone, Slack, or PagerDuty integration.
- No content signing in V1; package signature can be a later milestone.
- No automatic remediation or operational command execution.
- No mobile Android sidecar packaging until the Windows path is stable.

## 5. V1 User Workflows

### 5.1 Incident Search

The engineer enters a symptom, error text, system name, metric, or service keyword.

The app shows relevance-ranked runbooks with:

- Title.
- Severity hint.
- Affected systems.
- Owner/escalation hint.
- Safety/risk summary.
- Freshness status.
- Matched signals.

### 5.2 Runbook View

The engineer opens a runbook and sees:

- Impact and when-to-use guidance.
- Safe investigation checklist first.
- Caution steps separated from safe steps.
- Dangerous/destructive steps collapsed by default.
- Commands as copyable text only.
- Escalation information.
- Related runbooks.
- Last reviewed date and stale warning.

### 5.3 RAG Brief

The engineer can ask for a local answer. The response must be grounded in the active content package and follow a fixed incident-response format:

1. Likely cause.
2. Immediate safe checks.
3. Evidence to collect.
4. Risky actions, separated and clearly marked.
5. Escalation owner.
6. Citations to runbook IDs/titles.

If confidence is low, the answer should say that the local handbook has no strong match and show the best fallback runbooks instead of inventing guidance.

### 5.4 Incident Mode

Incident Mode is a lightweight focused state, not a full incident manager.

It should support:

- Pinning the currently used runbook.
- Keeping recent searches and recently opened runbooks local.
- Showing copyable investigation summary.
- Showing copyable escalation summary.
- Keeping the UI quiet and scan-friendly during high pressure.

## 6. Content Model

V1 should introduce a backward-compatible Runbook Schema v2. Existing v1 fields must continue to load.

Recommended source format: multi-file YAML for authors.

Recommended release format: a generated JSON bundle consumed by Flutter and the Go sidecar.

### 6.1 Package Manifest

Each released package should contain:

- `schemaVersion`: package schema version.
- `packageId`: stable package identifier.
- `name`: human-readable package name.
- `version`: semantic or date-based version.
- `team`: owning team or organization.
- `generatedAt`: build timestamp.
- `sourceRevision`: optional commit hash or source revision.
- `runbookCount`: number of included runbooks.
- `defaultLocale`: initial locale.
- `minAppVersion`: optional compatibility floor.

### 6.2 Runbook Fields

Required or strongly recommended fields:

- `id`: stable runbook ID.
- `title`: concise incident title.
- `summary`: one-paragraph operational summary.
- `severity`: `p1`, `p2`, or `p3`.
- `systems`: affected systems, services, components, or platforms.
- `tags`: searchable labels.
- `symptoms`: common observed signals.
- `signals`: metrics, logs, errors, alerts, or dashboard hints.
- `impact`: user or business impact.
- `owner`: responsible team/person text.
- `escalation`: escalation text, not an integration target.
- `lastReviewedAt`: review date.
- `reviewIntervalDays`: freshness threshold.
- `prerequisites`: required access, dashboards, permissions, or context.
- `safeSteps`: investigation steps safe to perform during first response.
- `cautionSteps`: steps needing judgment or additional verification.
- `dangerSteps`: destructive, irreversible, customer-impacting, or high-risk steps.
- `commands`: copyable commands/snippets, linked to step IDs where possible.
- `relatedRunbooks`: related runbook IDs.

### 6.3 Step Risk Model

Every operational step should have a risk level:

- `safe`: read-only or low-risk investigation.
- `caution`: may change load, trigger alerts, expose sensitive data, or require experienced judgment.
- `danger`: may restart services, mutate data, disable protection, drop traffic, or cause customer impact.

Danger steps must be visually separated and collapsed by default in UI.

### 6.4 Backward Compatibility

Existing runbooks with legacy fields should still load.

Migration rules:

- Missing `severity` defaults to `p3`.
- Missing `systems` defaults to empty list.
- Existing checklist steps default to `safe` unless explicitly marked otherwise.
- Existing `category` and `tags` remain searchable.
- Legacy bundle import should produce validation warnings, not fatal errors, unless required identity fields are missing.

## 7. Validation Model

The content build/import path should return a validation report with two levels.

Errors block import:

- Duplicate runbook IDs.
- Missing runbook ID or title.
- Invalid schema version.
- Invalid step risk level.
- Broken required structure that prevents search or rendering.

Warnings allow import but surface quality issues:

- Missing owner or escalation.
- Missing severity.
- Missing systems.
- Missing last review date.
- Stale review date.
- No safe investigation steps.
- Danger steps without caution text.
- Commands not linked to steps.
- Very short or vague summaries.

The app should expose warnings in a package/library health view so maintainers can improve content quality.

## 8. Retrieval And RAG Behavior

The current Go sidecar remains the Windows local RAG runtime.

Required behavior:

- Flutter syncs the active content package once.
- Sidecar validates the package and returns a content version.
- Query calls send `query + contentVersion`, not the full package.
- Retrieval ranks by symptom, signals, systems, title, tags, and summary.
- Safety metadata should influence presentation, not hide relevant matches.
- Low-confidence retrieval must produce an explicit no-strong-match response.
- RAG answers must cite runbooks.
- Cloud/OpenAI-compatible LLM use stays optional; local deterministic answers remain the fallback.

Search ranking priorities:

1. Exact system/service/error matches.
2. Symptom and signal matches.
3. Title and tag matches.
4. Summary/body matches.
5. Related runbook expansion.

## 9. UI Direction

Rename generic knowledge-base language toward on-call usage.

Suggested navigation:

- `Incident Search`: primary search surface.
- `Runbooks`: browse all runbooks.
- `RAG Brief`: grounded answer view.
- `Pinned`: pinned emergency references.
- `Library`: package and validation health.

Visual priorities:

- Dense, scan-friendly layout.
- Safety status visible without opening deep panels.
- No marketing hero or decorative layout.
- Commands shown in copyable blocks.
- Dangerous actions collapsed and clearly marked.
- Stale content warning visible near runbook metadata.

## 10. Local Data And Privacy

V1 local state may include:

- Recent searches.
- Recently opened runbooks.
- Pinned runbooks.
- Last active package version.

V1 should not store:

- Full incident timelines.
- Sensitive customer data.
- Automatically captured command output.
- External chat or escalation records.

## 11. Content Scope

V1 target content size:

- 30-50 high-quality backend on-call runbooks.

Initial priority set:

- CPU saturation.
- Memory leak / OOM.
- MySQL slow queries.
- Database connection pool exhaustion.
- Redis latency or memory pressure.
- HTTP 5xx spike.
- Latency p95/p99 regression.
- Deployment rollback.
- Disk full.
- I/O bottleneck.
- Dependency timeout.
- Queue backlog.
- Thread pool exhaustion.
- Kubernetes pod crashloop.
- DNS or service discovery failure.

## 12. Implementation Roadmap

### Milestone 1: PRD And Terminology

Deliverables:

- This PRD.
- Confirmed V1 scope and non-goals.
- Stable naming for on-call concepts.

Acceptance:

- Future implementation tasks can reference this document.

### Milestone 2: Schema v2 And Content Builder

Deliverables:

- YAML source schema.
- JSON bundle schema v2.
- Validation report with errors/warnings.
- Backward-compatible loader for existing bundle.

Acceptance:

- Existing bundle still loads.
- Invalid content produces clear validation errors.
- Missing quality metadata produces warnings.

### Milestone 3: Sidecar Retrieval Upgrade

Deliverables:

- Sidecar understands schema v2 fields.
- Search weights systems, symptoms, signals, severity, and safety metadata.
- RAG brief uses fixed incident-response format.
- No-strong-match behavior remains explicit.

Acceptance:

- Existing k6 load test still passes.
- Query payload stays versioned and small.
- RAG answer cites runbooks and separates risky actions.

### Milestone 4: Flutter On-Call UI

Deliverables:

- Navigation rename.
- Incident Search result cards.
- Runbook detail page with risk-grouped steps.
- Copyable investigation/escalation summary.
- Pinned and recent local state.
- Library health view for validation warnings.

Acceptance:

- Engineer can search, open, copy safe checks, copy escalation summary, and ask for RAG brief while offline.

### Milestone 5: Seed Runbook Expansion

Deliverables:

- 30-50 runbooks in YAML source.
- Generated default JSON bundle.
- Review metadata for every runbook.

Acceptance:

- No schema errors.
- Warnings are either resolved or intentionally documented.
- Core backend incident categories are represented.

### Milestone 6: Windows Packaging Verification

Deliverables:

- Windows build includes Flutter app and Go sidecar.
- Local sidecar startup/health path verified.
- Offline runbook search verified.
- Optional cloud LLM fallback behavior verified.

Acceptance:

- A Windows user can launch one packaged app folder and use local RAG without installing a server separately.

## 13. Success Criteria

V1 is successful when:

- An engineer can find the right runbook in under a few seconds.
- The first visible actions are safe investigation steps.
- Dangerous actions are never presented as ordinary checklist items.
- The app remains useful with no network.
- The active package can be validated before use.
- RAG answers are grounded, cited, and honest about low confidence.
- Windows packaging keeps Flutter and Go sidecar as one application distribution.

## 14. Post-V1 Options

- Android packaging strategy.
- Content package signature verification.
- Team/package switching.
- Vector index for larger content collections.
- Local embedding model.
- External incident-tool integrations.
- In-app authoring/review workflow.
- Role-based content visibility.

## 15. Open Questions

- What exact YAML file layout should authors use: one file per runbook or grouped by system?
- Should severity be authored manually only, or inferred from impact text during content build?
- What is the minimum app versioning policy for future package compatibility?
- Which 30-50 seed runbooks should be written first, and who owns review freshness?
