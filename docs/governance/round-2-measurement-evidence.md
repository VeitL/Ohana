# Round 2 Measurement Evidence

> Date: 2026-06-08
>
> Scope: add stable, privacy-safe measurement probes for critical flows. This is evidence plumbing, not a claim that every flow is already optimized.

## Added Probe Contract

`AppFlowPerformance` centralizes stable flow names and phase names in `Ohana/Utilities/AppRuntimePolicy.swift`.

Probe notes must use low-sensitivity fields only, such as `flow`, `phase`, `action`, `count`, `source`, `from`, `to`, `prepared`, `bytes`, or `errorType`. Do not include pet names, human names, notes, PIN values, health values, precise route text, or raw user text.

## Critical Flow Coverage

| Flow | Stable Probe Prefix | Evidence Added |
|---|---|---|
| Home card expand/collapse | `flow.home.card_expand`, `flow.home.card_collapse` | tap accepted, state submitted, first frame, animation complete |
| Home tab switch | `flow.home.tab_switch` | flow start, first frame, outgoing page unmounted |
| Quick care command | `flow.quick_care.command` | flow start, queried data ready, write success, noop |
| Calendar open | `flow.calendar.open` | shell ready, first frame, initial timeline data ready |
| Calendar mode/filter | `flow.calendar.mode_switch`, `flow.calendar.filter` | flow start, first visual frame |
| Calendar add-event sheet | `flow.calendar.add_event_sheet` | shell ready, content mounted, route dismiss |
| Oasis home tab open | `flow.oasis.open` | preview-to-live shell ready, content mounted, first live frame |
| Backup export | `flow.backup.export` | export start, background data ready, protected write success, write failure |

## Machine Enforcement

`docs/governance/manifests/performance-slo.json` now declares `probeNames` for every performance flow. `scripts/audit-governance-manifests.sh` verifies that each probe name exists in Swift source, so manifest evidence cannot drift into fiction.

## Validation Run

Completed on 2026-06-08:

- `scripts/release-hardening-check.sh --skip-build`: passed. This includes runtime guardrails, release data safety, localization coverage, governance manifest audit, resource integrity/xattr/privacy manifest checks, UI V4 changed-files audit, accessibility changed-files audit, smoothness changed-files audit, and git-size reporting.
- `DERIVED_DATA_PATH=/tmp/OhanaDD-fullscore-round2 scripts/build-debug-fast.sh`: passed on `platform=iOS Simulator,name=iPhone 17` with `-sdk iphonesimulator`.
- Existing actor-isolation warnings remain in background backup/backfill helpers; they are tracked as follow-up runtime/concurrency debt rather than evidence failures for this instrumentation round.

## Remaining Round 2 Gaps

- Probe output is visible through `AppPerformanceMonitor`; simulator-driven path validation still needs to exercise the flows and capture samples.
- Existing ad-hoc/Chinese performance sample names remain for history. New probes use stable ASCII names.
- Round 3 must use the evidence to fix the highest-impact smoothness risks rather than only adding more instrumentation.
