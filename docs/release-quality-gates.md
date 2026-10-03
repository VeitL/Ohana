# Release Quality Gates

Ohana changes must be safe to ship, diagnose, and recover.

Owner: repository validation workflow under `AGENTS.md`.
Status: active policy. Last reviewed: 2026-10-02 against the current validation
entrypoints; this date does not certify app or release acceptance.

## Gate Severity And Ownership

- Correctness boundaries with a zero baseline—data safety, privacy, migration,
  rewards/ledger writes, and architecture ownership—remain full-repository hard
  failures.
- Heuristic proxies with accepted history—file length, raw source-resource size,
  and formatting—must not make an unrelated PR responsible for old debt. PR and
  push checks use warning bands or the merge-base diff; explicit release/debt
  scans may still report the whole repository.
- File length starts review at 1200 lines and hard-fails a new file above 1400
  lines. Declaration-level complexity remains the authoritative blocker because
  it measures behavior more directly than total lines.
- Resource source bytes use a warning target, hard ceiling, and allowed growth
  from the base revision. The compiled `Assets.car` and Release archive are the
  authority for shipped size; raw `.xcassets` size is only an early signal.
- Known CodeSign-risk metadata such as FinderInfo, ResourceFork, and quarantine
  remains a hard failure. Benign or unclassified source xattrs are advisory
  until the signed Release archive provides the authoritative result.
- A temporary baseline or waiver must be reviewed and bounded. Updating a
  baseline is not evidence that the underlying issue was fixed.
- A test-host crash is a defect, not a permanent CI topology. During diagnosis,
  isolate the smallest crashing selector so the rest of the portfolio remains
  observable; after the root cause is fixed, restore one complete unit run and
  remove the extra simulator launches.
- Wall-clock performance checks use a review target plus a hard regression
  ceiling. Crossing the target is diagnostic evidence; only a clearly bounded
  runaway (currently 2x the target for dense snapshots) blocks unrelated work.

## Test Portfolio Contract

- Business rules are owned by Unit/Integration tests; UI tests do not inspect
  persistence internals or stand in for ledger, migration, reward, or cache
  assertions.
- Test readback errors must throw or record a failed issue. Never substitute
  an empty array, nil, or a sentinel for a failed fetch when asserting deletion,
  absence, counts, or rollback. Use isolated stores/defaults where injectable;
  otherwise restore every modified shared preference and in-memory projection
  on all exits. Source-text checks prove architectural constraints, not runtime
  behavior, and must follow accepted product changes rather than obsolete UI.
- The normal change lane runs at most one high-value UI path for each affected
  module. Exhaustive UI shards are retained for nightly/RC regression.
- Closing a P0/P1 risk requires failure, recovery/retry, and repeat/idempotency
  evidence at the lowest trustworthy layer.
- Frequency follows risk; low-risk visual/copy changes do not start the full
  unit or UI portfolio.

## Change Risk Levels

Start with the read-only `scripts/dev-check-changed.sh` for changed files.
Formatting changes require `--fix-format` plus explicit targets. Escalate only when the
changed surface needs broader proof. A build is evidence for compiler
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
- Targeted in-memory Unit/Integration proof for the affected invariant.
- A temporary on-disk old-store or durability fixture when migration,
  relaunch, atomicity, or filesystem persistence is part of the risk.
- Runtime audit.
- A disposable Simulator journey for destructive, empty-state, permission
  setup, restore, or other state-mutating acceptance.
- One guarded normal-UI Dogfood journey when the stabilized change can affect
  persisted facts or accumulated existing-user behavior; never use Dogfood for
  destructive/reset/empty-state flows.
- Failure, recovery/retry, and repeat/idempotency proof.
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
| Persistence/schema | In-memory invariant/compatibility tests; temporary on-disk old-store fixtures for affected migration or durability paths; recovery and backup/export impact; targeted simulator test when user-visible | Durability or existing-store safety from an in-memory or build-only pass |
| Simulator/system simulation | Exact runtime and OS, deterministic setup, driven journey, and final UI/log evidence | Physical-device delivery, permission prompts, energy, biometrics, camera, iCloud, or background execution |
| Signed release Archive | Final Archive inspection for signing, entitlements, embedded manifests/frameworks, and an Archive-generated Xcode Privacy Report | Runtime behavior on a device or App Store processing success |
| Physical device | Named hardware/OS and the relevant normal-product journey from the release artifact | Coverage of untested hardware, OS versions, accounts, regions, or external distribution |
| External platform | Platform receipt from the actual boundary, such as CI, App Store Connect processing, TestFlight installation, or review metadata | Evidence for any external boundary that was not actually exercised |

## Efficient Test Lanes

Use the smallest lane that can prove the changed behavior. Do not start the
full UI suite as a default response to a local code edit.

| Lane | Command | Use when |
|---|---|---|
| Changed-file preflight | `scripts/dev-check-changed.sh` | Every local change; read-only by default, it dispatches syntax, format lint, and applicable repository audits without starting Xcode. |
| Feature/module gate | `scripts/module-exit-gate.sh --test OhanaTests/<RelevantTests>` | Changed checks plus targeted Unit/Integration proof and, only when necessary, one high-value UI selector. |
| Release static gate | `scripts/release-hardening-check.sh --static-only` | Fixture self-tests and the complete strict static audit set without CoreSimulator. |
| Release unit gate | `scripts/release-hardening-check.sh` | Full static release gate plus the complete unit suite; use `--with-ui` only for RC full UI regression. |
| Fast optimized Release build | `scripts/build-release-fast.sh` | Repeated optimized compiler/artifact checks. It keeps `-O`, uses incremental compilation, and does not prove runtime behavior, signing, or App Store readiness. |
| Targeted unit/integration | `scripts/xcode-test.sh --only-testing OhanaTests/<RelevantTests>` | One service, command, read model, persistence boundary, or regression test changed. |
| Full unit suite | `scripts/test-unit.sh` or `scripts/module-exit-gate.sh --unit` | Broad module handoff or phase boundary; it does not pull in the UI target. |
| Release UI smoke | `scripts/test-ui-release-smoke.sh smoke` | First-release onboarding and first-pet path changed. |
| Domain UI shard | `scripts/test-ui-shard.sh <shard>` | One user-facing domain changed; use `--list` to see the available shards. |
| Full UI regression | `scripts/test-ui-nightly.sh --continue-after-failure` | Nightly, release candidate, or an explicitly requested whole-app UI pass. Collect every shard once through the governed sequential build-then-test lifecycle and fixed incremental cache. Any failed shard keeps the campaign failed after collection; passing results are deleted and failure retention remains bounded. |
| Signed WMO Archive | `scripts/archive-release-local.sh` | RC/signing/device-matrix gates only. It keeps whole-module optimization, writes outside the File Provider-managed repository, verifies code signing/xattrs, and does not upload. |
| Real-device acceptance | `docs/release-true-device-test-plan.md` | Permissions, HealthKit, background delivery, location, energy, iCloud, biometrics, camera, keyboard, and device-only behavior. |

## Frequency Matrix

| Trigger | Required lane | UI allowance |
|---|---|---|
| Copy, color, spacing, radius, non-interactive token | Changed-file preflight and relevant static UI/accessibility audit | None unless visual acceptance itself is requested |
| One business rule, command, service, read model, or persistence behavior | Targeted Unit/Integration selector plus build when compiler/startup/persistence risk requires it | One high-value path only when navigation or visible integration changed |
| P0/P1 repair | Targeted failure + recovery/retry + repeat/idempotency tests, relevant audits, and build | One high-value recovery/user path; UI must not assert database internals |
| Broad module handoff | Full unit lane plus module-relevant audits | One module path, not every button |
| Nightly | Full unit as scheduled plus full UI collection | Complete shard manifest |
| RC / release candidate | Whole-repo audits, full unit, full UI collection, and applicable real-device plan | Complete release paths and device-owned behavior |

`scripts/module-exit-gate.sh` defaults to the fast changed/static lane. Repeat
`--test <target/test>` for targeted Unit/Integration selectors and, only when
needed, one UI selector. Use `--unit` for the full unit lane and `--full` for
the canonical release static baseline plus full unit tests. It does not rerun
the changed audits after `dev-check-changed.sh`. The complete UI suite remains
`scripts/test-ui-nightly.sh --continue-after-failure`, or
`scripts/release-hardening-check.sh --with-ui`
for an explicit RC lane.

Local UI shards run sequentially with parallel testing disabled. Each
shard owns one normal governed build-then-test lifecycle; the fixed cache keeps
those builds incremental without sharing a stale build-for-testing artifact
across shard boundaries. The UI tests launch, reset, seed, and sometimes
preserve state in the same simulator, so parallel runners would compete for the
app process and persistence container. Hosted CI shards may run concurrently
only on separate hosts with independent simulators. A fresh hosted simulator
and a reused local simulator do not establish equivalent permission or data
preconditions merely because the source revision matches.
`scripts/audit-ui-test-shards.sh` requires every source UI test to appear in
exactly one shard so a newly added test cannot silently disappear from the full
regression lane.

## UI Automation Evidence Contract

### Comparable Preconditions

- Record the source revision and any uncommitted patch, toolchain/SDK, actual
  simulator runtime, build configuration, device, seed/store lifecycle,
  language/time zone, animation settings, and diagnostic flags. Record
  notification and location authorization separately, or mark them unknown.
  Resetting app data is not evidence that system permissions were reset.
- Each independent case must establish its own declared starting conditions.
  If one case intentionally preserves state, name that dependency. After a
  failure, capture the screen and accessibility state before containment, and
  verify that a leftover system overlay cannot obstruct the next case.
- Handle an expected permission request through the real system UI, once, with
  a handler scoped to Ohana's specific alert and intended choice; verify the
  alert has closed. Do not add a blanket Allow handler, direct permission/store
  writes, or a business bypass. Keep Simulator reset and storage operations
  within the existing `AGENTS.md` safeguards.
- Diagnose on the failing CI toolchain first. A different OS is valuable
  compatibility evidence, but does not isolate a cause. Controlled comparisons
  change one declared variable at a time.

### Behavioral Assertions And Interaction

- Derive expected behavior from `docs/specs/product-foundation.md` and the
  accepted flow. Preserve save, reward, deletion, cancellation, and relevant
  cold-launch readback assertions through normal UI. Unit/Integration tests
  own persistent invariants as described in the Test Portfolio Contract.
- Assert the user's resulting state or destination. Do not require an obsolete
  intermediate menu or a source-code layout when the accepted flow reaches the
  correct result directly. Replace a stale implementation assertion with
  behavioral evidence; do not restore old UI solely to satisfy it or delete a
  business assertion to make a run pass.
- Use semantic operations for ordinary native controls. Keep a coordinate path
  only as an explicit, documented exception supported by evidence. Scope
  queries and scrolling to the current page/container; observe related
  properties consistently and observe again after scrolling, keyboard changes,
  or navigation. Do not add fixed sleeps or repeat clicks to hide a failure.
- Wait for an observable state transition, not elapsed time. A short success
  toast alone is not persistence proof, and a permission dialog may obscure it.
  Keep transient feedback verification separate from stable saved-state
  readback, and state which requirement each assertion proves.
- A successful process exit is not execution evidence. The governed test
  entrypoint checks the result bundle for executed cases; a successful UI run
  must contain every requested selector, with no skipped, synthetic, repeated,
  or unexpected cases. Enumeration is preparation only and never a test pass.

### Failure Classification And Complete Collection

The raw runner result and the diagnosed cause are separate facts. Every failed
case must identify its actual failing step, the last successful step, whether
the named business action was reached, and supporting activities plus a screen
or accessibility capture. Include explicit diagnostic attachments even when
the result exporter does not mark them as automatic failure attachments.

| Cause | Evidence required before assigning it |
|---|---|
| Product behavior | Valid starting conditions and input reached the business action, but the specified result or invariant failed. |
| Test interaction or assertion | The driver selected the wrong target, assumed an obsolete route, or evaluated the wrong observation; the captured UI and accepted behavior explain the mismatch. |
| Setup or environment | A permission overlay, runner initialization, or other preparation failure prevented the business step; identify the step that was never reached. |
| Undetermined | Evidence does not distinguish the causes. Preserve the uncertainty and collect the missing observation before changing product code. |

- Stop the current journey when its prerequisite fails; continuing downstream
  would manufacture more errors. Continue the other independent cases and all
  shards once. Collection never turns failure into success. If a storage,
  runtime, or safety preflight prevents continuation, report the remaining
  selectors as not run, not passed.
- Report planned, executed, passed, failed, skipped, and not-run counts against
  the complete shard manifest. Group cases with a shared cause for diagnosis,
  while retaining every raw failure and distinguishing blocked preparation
  from a reached business assertion. Keep static, Unit, UI, and device results
  separate; neither diagnostic selectors nor manual checks fill missing UI
  coverage or overwrite a historical failure.

### Repair And Acceptance Sequence

1. Read existing receipts, activities, and final screens before another run.
   Establish the protected worktree baseline and classify the actual step;
   a test name alone cannot identify the broken feature.
2. After an evidence-based change stabilizes, run the relevant changed-file
   static/accessibility checks and Unit/Integration proof before long UI work.
   Catch stale assertions and static gate failures here, rather than spending a
   full CI campaign discovering them.
3. Use the shortest real journey for the unresolved cause with comparable
   preconditions. Mark it diagnostic. If it passes while the longer journey
   fails, inspect preceding state and isolation before changing click APIs or
   timeouts. A zero-execution runner failure is neither a business failure nor
   a pass; an environment repair may justify one documented verification while
   preserving the original result.
4. Verify the relevant failure set after the repair. Each retained change must
   explain the original failing step, why the change addresses it, and the
   business result proved. Do not rerun unchanged code simply to clear a failure.
5. Freeze the final revision and configuration for complete acceptance. Check
   for a matching active or completed full CI run before dispatching; dispatch
   once per revision under the task's authorization. Collect the full manifest
   on every required toolchain/runtime, with the required gates passing. Do not
   combine revisions or targeted runs into a full-pass claim. Change grouping
   only after evidence of session degradation, retaining total coverage.

Manual acceptance remains valid for the named steps, artifact, and OS tested.
An automation preparation failure does not invalidate that observation. Ask
for one short manual comparison only when it resolves an uncertain product
fact; do not repeatedly ask for an unchanged flow already accepted. Manual
evidence cannot certify a different OS or replace a separately required
automated gate. Permissions, delivery, background behavior, and other
hardware-owned acceptance still follow the real-device plan.

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
UI source/toolchain/runtime and starting permissions/data:
UI planned/executed/passed/failed/skipped/not-run:
UI failures: actual step, business action reached, cause, evidence:
Simulator/system simulation:
Signed Archive:
Physical device:
External platform:
Screenshots/recording:
Trace/memgraph artifacts:
Known limitations:
Rollback/fallback:
```
