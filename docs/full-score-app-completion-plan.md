# Full-Score App Completion Plan

> Goal: make Ohana excellent in performance, energy, smoothness, privacy, resource discipline, and release confidence through measurable, repeatable gates.
>
> Rule precedence remains `AGENTS.md` -> `ui规范.selection.json` -> governance docs -> current source. This file is the execution roadmap, not a competing rule source.

## Definition of Full Score

Ohana is "full score" only when the following are true:

- High-frequency interactions give visible feedback in the same interaction turn.
- Startup reaches the shell without feature-wide scans, image decoding, timers, map warmup, or dashboard aggregation.
- Hidden/off-tab/covered surfaces are unmounted or inert.
- SwiftData writes go through domain services; render paths consume snapshots/read models.
- Runtime loops, maps, timers, particles, and location are visible, intentional, and governed by `AppWorkloadPolicy`.
- Key flows have MetricKit, `AppPerformanceMonitor`, signpost, test, or simulator evidence.
- Resource size, xattrs, privacy manifest, backup safety, localization, and CI gates block regressions.
- Remaining legacy debt is tracked with owner, risk, and next verification action.

## Rounds

### Round 0 - Governance Foundation

Status: complete.

- Remove parallel editor rule folders.
- Make `AGENTS.md` and docs structure current.
- Add governance manifests for feature, cache, performance SLO, and privacy ownership.
- Add resource/xattr pre-sign audit.
- Mark historical docs as reference/stale.

Acceptance: `scripts/release-hardening-check.sh --skip-build`, governance manifest audit, resource integrity audit, localization audit, and runtime audit pass.

### Round 1 - Full-App Risk Inventory

Status: complete.

- Produce a performance, energy, and smoothness audit report.
- Identify P0/P1/P2 risks by evidence, not intuition.
- Add a lightweight smoothness-risk audit for new changed SwiftUI code.
- Expand the completion matrix with target flow, owner, evidence, and next action.

Acceptance: Round 1 report exists, new audit script passes on changed files, and the next repair round is selected by impact.

### Round 2 - Measurement Evidence

Status: complete for initial critical-flow probe coverage; simulator evidence capture remains part of Round 6.

- Add privacy-safe flow probes for home card expansion, tab switching, quick care command, sheet entry/exit, calendar open, Oasis enter, and backup export.
- Normalize metric names to ASCII stable identifiers.
- Make performance SLO manifest require evidence fields for critical flows.
- Add tests where measurement can be asserted without simulator timing.

Acceptance: each critical flow has a measurement source and a documented pass/fail evidence path. Current evidence is in `docs/governance/round-2-measurement-evidence.md`.

### Round 3 - Interaction Smoothness Repairs

Status: complete for this hardening pass; Oasis host/live data sub-pass and
home read-model determinism are documented in
`docs/governance/round-3-interaction-smoothness-evidence.md` and
`docs/governance/final-verification-matrix.md`.

- Repair the highest-traffic P0 paths first: home card expansion, tab switch, inline overlay/sheet entry, quick care command, Today Focus, calendar agenda.
- Move broad queries and image decode out of reusable/high-frequency surfaces.
- Keep first-frame work to local visual state, frozen snapshots, or route values.

Acceptance: strict smoothness matrix is compliant for repaired flows, changed
smoothness audit passes, and fixed-simulator tests are green.

### Round 4 - Runtime and Energy Repairs

Status: complete for this hardening pass; runtime/energy ownership gate and
first ambient-loop repair are documented in
`docs/governance/round-4-runtime-energy-evidence.md`.

- Audit every timer, `TimelineView`, `repeatForever`, Canvas/particle loop, map, and location path.
- Ensure visibility gating, Low Power Mode, Reduce Motion, background pause, and active-walk exceptions are explicit.
- Remove or downgrade ambient loops that compete with high-frequency interactions.

Acceptance: runtime guardrails stay full-repo strict, and remaining exceptions
have policy gates plus evidence.

### Round 5 - Resource, Privacy, and Release Hardening

Status: complete for this hardening pass; release/resource ownership manifest
and manifest-driven resource budget audit are documented in
`docs/governance/round-5-resource-privacy-release-evidence.md`.

- Reduce or justify resource/bundle size.
- Add signed-build or archive-equivalent resource validation when feasible.
- Close privacy/export/delete/backup evidence gaps.
- Promote changed-file UI/accessibility/smoothness ratchets into the full-scope
  baseline ratchet, then shrink the baseline to zero before switching to direct
  `--all` strict gates.

Acceptance: release hardening passes, resource budgets are intentional, and App
Store-sensitive flows have explicit evidence.

Status: complete for the gate upgrade; see
`docs/governance/full-scope-ratchet-policy.md` and
`docs/governance/manifests/full-scope-audit-baseline.json`.

### Round 6 - Final Verification Matrix

Status: complete; see `docs/governance/final-verification-matrix.md`.

- Run fixed iPhone 17 simulator build/test.
- Validate key paths on simulator with screenshots/logs where UI behavior matters.
- Complete the final matrix: startup, home, tab, sheet, quick care, calendar, Oasis, backup, privacy, resource, localization, accessibility.
- Mark the goal complete only when no required work remains.

Acceptance: final report lists every gate run, residual future refinements, and
no blocking P0/P1 maturity gaps. The exact fixed-simulator test command passed
on `platform=iOS Simulator,name=iPhone 17` with `-sdk iphonesimulator`:

`xcodebuild test -project Ohana.xcodeproj -scheme Ohana -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/OhanaDD-fullscore-round7-final -disableAutomaticPackageResolution -skipPackagePluginValidation`

Result bundle:
`/tmp/OhanaDD-fullscore-round7-final/Logs/Test/Test-Ohana-2026.06.08_16-52-17-+0200.xcresult`
