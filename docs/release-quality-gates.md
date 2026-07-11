# Release Quality Gates

Ohana changes must be safe to ship, diagnose, and recover.

## Test Portfolio Contract

- Business rules are owned by Unit/Integration tests; UI tests do not inspect
  persistence internals or stand in for ledger, migration, reward, or cache
  assertions.
- The normal change lane runs at most one high-value UI path for each affected
  module. Exhaustive UI shards are retained for nightly/RC regression.
- Closing a P0/P1 risk requires failure, recovery/retry, and repeat/idempotency
  evidence at the lowest trustworthy layer.
- Frequency follows risk; low-risk visual/copy changes do not start the full
  unit or UI portfolio.

## Change Risk Levels

Start with `scripts/dev-check-changed.sh` for changed files. Escalate only when
the changed surface needs broader proof. A build is evidence for compiler
surface, not for behavior, smoothness, privacy, persistence, leaks, or product
acceptance.

### Low Risk

Pure copy, small visual spacing, localized string, non-interactive token mirror.

Required:

- `git diff --check`.
- `scripts/dev-check-changed.sh`.
- Relevant UI audit if UI changed.
- No app build unless the local gate recommends it, the user asks for it, or the
  change touches Swift compiler surface.

### Medium Risk

New screen, new route, new popup, new SwiftData read model, new animation, new App Intent.

Required:

- `scripts/dev-check-changed.sh`.
- Build or targeted simulator test when the change touches compiler surface,
  routing, runtime policy, generated assets, project settings, or behavior.
- UI audit if visible.
- Runtime audit if timers, animation loops, maps, location, or background work are touched.
- Targeted simulator path.
- Relevant unit test for service/read model behavior.

### High Risk

SwiftData schema migration, persistence writes, privacy, deletion/memorial mode, reminders/tasks/rewards synchronization, background location, startup path, cross-feature service, or any feature used from multiple entry points.

Required:

- Build.
- Targeted unit tests with in-memory SwiftData.
- Runtime audit.
- Manual simulator flow.
- Recovery path.
- Privacy review.
- Performance note if launch, route transition, scrolling, or tap path changes.
- Feature flag, kill switch, or graceful fallback where feasible.

## Validation Evidence Matrix

| Change class | Minimum evidence | Do not claim |
|---|---|---|
| Docs-only or governance prose | `git diff --check`; relevant shell/JSON/Markdown audit when touched | App behavior, build health, or CI coverage |
| Audit/script rule | Bad fixture caught, good fixture allowed, plus the audit command itself | Whole-repo enforcement unless the audit ran on whole scope |
| Pure UI | `scripts/audit-ui-v4.sh --changed` or path-specific audit; screenshot/manual proof if visual acceptance matters | Runtime smoothness or route behavior without a real path |
| Simulator UI bug | Exact simulator, starting UI snapshot/screenshot, driven steps, final screenshot/log, rerun of the same path | Fixed UI if the route was unreachable or only coordinates worked |
| App Intents/system surfaces | Build, route-handoff test, entity/action summary, privacy/deleted/memorial/missing-data checks | That all Shortcuts/Siri/Spotlight surfaces work from an app-only test |
| Performance/smoothness | Code-first smell review; one focused Instruments/ETTrace capture when runtime evidence is needed | "Feels fast" or conclusions from mixed/unsymbolicated traces |
| Leak/memory growth | Same-flow before/after memgraph, app-owned leaked type counts, ownership path or retaining edge | Leak fixed because total memory is smaller |
| Persistence/schema | In-memory migration/compatibility tests, recovery path, backup/export impact, targeted simulator test when user-visible | Data safety from a build-only pass |

## Efficient Test Lanes

Use the smallest lane that can prove the changed behavior. Do not start the
full UI suite as a default response to a local code edit.

| Lane | Command | Use when |
|---|---|---|
| Changed-file preflight | `scripts/dev-check-changed.sh` | Every local change; it dispatches syntax and applicable repository audits without starting Xcode by default. |
| Targeted unit/integration | `scripts/test-simulator.sh -only-testing:OhanaTests/<RelevantTests>` | One service, command, read model, persistence boundary, or regression test changed. |
| Full unit suite | `scripts/test-unit.sh` or `scripts/module-exit-gate.sh --unit` | Broad module handoff or phase boundary; it does not pull in the UI target. |
| Release UI smoke | `scripts/test-ui-release-smoke.sh smoke` | First-release onboarding and first-pet path changed. |
| Domain UI shard | `scripts/test-ui-shard.sh <shard>` | One user-facing domain changed; use `--list` to see the available shards. |
| Full UI regression | `scripts/test-ui-nightly.sh` | Nightly, release candidate, or an explicitly requested whole-app UI pass. It builds once, then runs sequential shards with one xcresult per shard. |
| Real-device acceptance | `docs/release-true-device-test-plan.md` | Permissions, HealthKit, background delivery, location, energy, iCloud, biometrics, camera, keyboard, and device-only behavior. |

## Frequency Matrix

| Trigger | Required lane | UI allowance |
|---|---|---|
| Copy, color, spacing, radius, non-interactive token | Changed-file preflight and relevant static UI/accessibility audit | None unless visual acceptance itself is requested |
| One business rule, command, service, read model, or persistence behavior | Targeted Unit/Integration selector plus build when compiler/startup/persistence risk requires it | One high-value path only when navigation or visible integration changed |
| P0/P1 repair | Targeted failure + recovery/retry + repeat/idempotency tests, relevant audits, and build | One high-value recovery/user path; UI must not assert database internals |
| Broad module handoff | Full unit lane plus module-relevant audits | One module path, not every button |
| Nightly | Full unit as scheduled plus sequential UI shards | Complete shard manifest |
| RC / release candidate | Whole-repo audits, full unit, sequential full UI, and applicable real-device plan | Complete release paths and device-owned behavior |

`scripts/module-exit-gate.sh` defaults to the fast changed/static lane. Repeat
`--test <target/test>` for targeted Unit/Integration selectors and, only when
needed, one UI selector. Use `--unit` for the full unit lane and `--full` for
whole-repository audits plus full unit tests. The complete UI suite remains
`scripts/test-ui-nightly.sh`.

UI shards intentionally run sequentially with parallel testing disabled. The UI
tests launch, reset, seed, and sometimes preserve state in the same simulator;
parallel runners would compete for the app process and persistence container.
`scripts/audit-ui-test-shards.sh` requires every source UI test to appear in
exactly one shard so a newly added test cannot silently disappear from the full
regression lane.

## Rollback and Recovery

High-risk features must answer:

- What happens if the write fails?
- What happens if the app is killed mid-write?
- What happens if migration fails?
- What happens if the feature route opens with missing data?
- What user data could be lost?
- Can the feature be hidden or disabled without breaking app launch?
- Are diagnostics privacy-safe?

## Release Report Template

```text
Change:
Risk level:
Affected flows:
Affected data:
Affected permissions:
Affected background work:
Validation commands:
Simulator/device:
Screenshots/recording:
Trace/memgraph artifacts:
Known limitations:
Rollback/fallback:
```
