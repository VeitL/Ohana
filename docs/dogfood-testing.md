# Dogfood Real-User Testing

Status: active repository policy  
Owner: `AGENTS.md` validation rules and `scripts/run-dogfood-simulator.sh`  
Last verified: 2026-07-16 against the current worktree

Dogfood is one persistent synthetic user, not another automated test target. It
exists to reveal upgrade, accumulated-data, recurring-plan, performance, and
day-to-day usability problems that clean fixtures cannot reproduce. Product
behavior still comes from [`specs/product-foundation.md`](specs/product-foundation.md),
and destructive coverage remains on `iPhone 17 Tests`.

The machine-readable profile and readiness thresholds live in
[`governance/manifests/dogfood-user-profile.json`](governance/manifests/dogfood-user-profile.json).
Do not copy or casually fork them into another persona.

## Fixed Environment

- Simulator: exactly `iPhone 17 Dogfood`, pinned by UDID in the ignored local
  file `.build/dogfood-simulator.udid`.
- Build: unsigned Simulator `Release`, overlaid from the fixed
  `.build/DerivedData/dogfood` lane.
- App identity: `com.guanchen.li.Ohana`.
- Data: one long-lived logical app data set and SwiftData store. CoreSimulator
  may remount it under a new data-container UUID during an overlay; the launcher
  fingerprints durable files before and after instead of treating that path as
  identity. New builds never erase, uninstall, reset, reseed, or replace the
  virtual phone.
- Scope: local-first Free / Personal Solo behavior. Simulator evidence does not
  prove notification delivery, background execution, energy, permissions,
  HealthKit, iCloud, Storefront, signing, or hardware behavior.

The synthetic household starts as one local operator with Human profile
`Lin Cheng`, English app language, German region, EUR, metric units, and Berlin
time. The first Pet is `Mochi`, a Labrador Retriever. These are invented identities;
never enter real names, contact details, medical facts, photos, credentials, or
other private data into this environment.

## Initialization And Readiness

Initialization is a one-time, explicit operation:

```bash
scripts/run-dogfood-simulator.sh --initialize
```

Initialization is transactional. The ignored
`.build/dogfood-initialization.pending` marker is created only after a true
empty-state preflight. If install or launch fails, rerunning the same explicit
command may resume only that exact Simulator while no sealed identity exists.
Without a store it retries install/launch; if launch actually created
`default.store` before failing, the resume path quick-checks it and relaunches
the installed App without reinstalling.
Read-only `--status` also follows the pending UDID. A successful launch writes
the pin and clears the marker; a ready interrupted store may instead be finalized
by `--seal-user`.

Complete the normal product UI without XCTest launch arguments or seeders:

1. Create Human `Lin Cheng`.
2. Create Pet `Mochi` as a Labrador Retriever.
3. Explicitly claim the 50-coconut starter gift, finish its ceremony, and open
   the now-visible Oasis tab once.
4. Confirm at least two ordinary recurring plans created by the normal product
   journey. Adjust future plans only through the UI as a real user would.
5. Complete at least one real care action and confirm it appears in history and
   the coconut ledger.

Then run:

```bash
scripts/run-dogfood-simulator.sh --require-ready
scripts/run-dogfood-simulator.sh --seal-user
```

`--seal-user` is the one-time handoff from initialization to longitudinal use.
It writes only a SHA-256 hash of SwiftData's store UUID to the ignored local
`.build/dogfood-store.identity`; it does not write App data or expose the raw
store UUID. Normal overlays refuse an unsealed or mismatched identity.

Readiness is based on anonymous counts and product preferences: onboarding,
active-Human selection, claimed starter gift with pending state cleared, at
least one active Human and Pet, two plans, one care record, one ledger entry,
one persisted starter-gift ledger entry, and one temporally linked canonical
care event plus care-sourced wallet reward. Product-level Oasis access and its
cleared first-visit prompt are also required. Only active Pet schedules with a live
recurrence rule count as plans. `OasisUnlock` rows are later Life Tree rewards,
so they are reported as longitudinal facts rather than Day-0 gates. The reporter
opens SQLite read-only and never prints
names, identifiers, notes, health content, or attachment paths.
It also rejects detached data containers left behind by an uninstalled App and
any preferences namespace carrying `*Tests*.plist` contamination.

## Development And Test Routing

Dogfood is not reserved for release candidates. Once a relevant change is
stable and its narrow automated or disposable-environment proof passes, use the
pinned synthetic user as the default second-stage acceptance environment. Its
job is to answer the question clean fixtures cannot: does the final Release
artifact still behave correctly with accumulated, real-journey data?
This is standing authorization for safe journeys through the guarded launcher;
future tasks do not need to ask again. It does not authorize erase, reset,
uninstall, direct data mutation, or any other destructive expansion.

| Change | Dogfood expectation |
|---|---|
| SwiftData schema, migration, persistence, backup-compatible encoding | Prove destructive/migration cases on isolated or disposable data first, then overlay Dogfood once and verify the existing household opens and reads back correctly. |
| Care commands, plans, reminders, tasks, wallet/economy, projections | Run targeted tests first, then exercise one safe relevant normal-UI action and confirm its history, balance, schedule, or projection exactly once. |
| Route restoration, stateful navigation, long lists, accumulated-data performance | Use Dogfood for the final flow/readback because its existing state is the test asset; capture only final evidence. |
| Small visual-only edit or isolated logic with no runtime/persistence effect | Dogfood is not required unless the user explicitly requests the rendered flow or existing content materially affects it. |
| Onboarding, reset, restore, deletion, empty state, permission mutation | Never use Dogfood; use `iPhone 17 Tests` or isolated stores. |
| Notification delivery, background execution, energy, HealthKit, StoreKit account state, hardware behavior | Dogfood may provide a UI smoke check, but physical-device evidence owns the gate. |

For a relevant development task:

1. Stabilize the code and pass the narrowest relevant Unit/Integration or
   disposable-Simulator proof.
2. Run `scripts/run-dogfood-simulator.sh --require-ready` as the read-only
   baseline.
3. Run `scripts/run-dogfood-simulator.sh` once to build and overlay the final
   Release artifact. Use `--no-build` only when that exact final artifact is
   already present and verified; never use it to reuse a stale build.
4. Through normal UI, inspect the affected existing-data path and perform at
   most the smallest safe representative action needed for evidence.
5. Re-run `--require-ready`. Record `overlay pass` only after the relevant UI
   readback succeeds; the check-in consumes the fresh launcher receipt.

Do not create noise by overlaying after every edit or repeating an unchanged
passing journey. Limit normal use to one overlay per stabilized change batch
unless it fails or the user requests another run. Every relevant task handoff
must report either the Dogfood
command and observed result, or a concrete skip reason with the unverified
existing-data risk. A Dogfood pass complements targeted tests; it never replaces
them.

### Explicit detached-App recovery

If a guarded overlay loses the installed App while leaving one metadata-owned
data container behind, stop and inspect with `--status`. Do not call `simctl
install` directly. After explicit user authorization, and only when status shows
one detached container with `sealed/match`, reuse the exact validated Release
artifact through:

```bash
scripts/run-dogfood-simulator.sh --repair-detached --no-build
```

This exceptional path verifies the sealed store identity, SQLite safety and a
durable-data fingerprint before installation. It then requires CoreSimulator to
expose exactly one authoritative container, repeats the identity, safety and
fingerprint checks, and launches before writing an overlay receipt. It never
erases, uninstalls, resets, seeds, or edits the detached data. A mismatch stops
the repair without destructive rollback; preserve that state for diagnosis.
After a successful repair, repeat `--require-ready`, inspect the relevant normal
UI path, and only then record `overlay pass`.

## Longitudinal Journeys

Daily, for five to ten minutes:

- cold-launch once and inspect Home and Task Center before recording anything;
- record two to four plausible care facts, rotating Home, Quick Care, and Task
  Center entry points rather than producing perfectly regular fixture data;
- complete or defer a due item and verify one user action creates one fact, one
  reward result, and the expected reminder transition;
- occasionally terminate and relaunch, checking that history, wallet, plans,
  and the selected Human remain intact;
- stop on duplicate facts, ghost reminders, unexplained balance changes,
  migration recovery UI, or data disappearance. Preserve evidence before any
  attempted repair.

Weekly:

- overlay the latest already-validated build and compare the launcher's pre/post
  durable-data fingerprint plus readiness;
- add one weight, expense, hygiene, or health fact and one synthetic image or
  Moment; inspect Calendar, weekly report, wallet ledger, and Oasis;
- backdate one normal care fact through the UI to exercise record date versus
  reward operation date;
- inspect backup status. Simulator iCloud failure must be understandable, but
  it cannot close the true-device backup gate;
- after week two, naturally add the second Human profile `An` to exercise local
  attribution and assignment. It is a cared-for profile, not a remote operator.

Day-7 targets are at least 15 care facts across five natural dates, one weight,
one expense, one Moment, one cold-start readback, and one successful overlay.

Monthly:

- inspect 30-day trends and long lists, edit or disable an old plan, then create
  one replacement plan;
- complete a manual restricted export without opening or copying private
  content into the repository;
- include a realistic two- or three-day gap followed by normal backfill;
- allow Plant `Pothos` only after the product naturally reaches Lv.4; never seed
  the growth level;
- keep this persona on Free for at least 30 days. Personal may be entered once
  through a natural purchase test later, but refund, downgrade, revocation, and
  repeated entitlement switching stay on disposable or physical environments.

Day-30 targets are at least 30 care facts across 14 dates, about four weight
records, two expenses, three Moments, real completed/late/edited plan history,
consistent wallet and trend projections, one export, and multiple successful
overlay upgrades.

## Non-Negotiable Safety Rules

Never target pinned Dogfood with:

- XCTest, `xcodebuild test`, UI-test seeders, `-OHANA_UI_TESTS`,
  `-OHANA_RESET_PERSISTENT_STATE`, or any `-OHANA_UI_TEST*` argument;
- Simulator erase/delete/recreate, app uninstall, App Reset, direct SQLite or
  UserDefaults mutation, or Debug coconut/growth tools;
- destructive onboarding, migration, backup-restore, deletion, permissions, or
  empty-store scenarios;
- permanent member deletion, artificial memorialization of the active Pet, or
  repeated fake Free / Personal state changes merely to cover branches.

If Dogfood data is missing or corrupt, the normal launcher must stop rather
than silently create a replacement user. Diagnose read-only first and move any
destructive reproduction to `iPhone 17 Tests`. A new Dogfood identity requires
an explicit user decision; do not repair the pin, reset the device, or invoke
`--initialize` as an automatic recovery action.

## Commands And Evidence

```bash
# Read-only device, app, store, build, and anonymized user status
scripts/run-dogfood-simulator.sh --status

# Require the Day-0 real-user baseline without booting or changing anything
scripts/run-dogfood-simulator.sh --require-ready

# One-time: pin the ready synthetic user's hashed SwiftData identity
scripts/run-dogfood-simulator.sh --seal-user

# Require the anonymous Day-7 or Day-30 longitudinal data targets
scripts/run-dogfood-simulator.sh --require-longitudinal
scripts/run-dogfood-simulator.sh --require-day30

# Build Release, overlay, validate container continuity, and launch
scripts/run-dogfood-simulator.sh

# Record a privacy-minimized result under ignored .build/dogfood-evidence
scripts/record-dogfood-checkin.sh daily pass --note "Normal care and relaunch passed"
scripts/record-dogfood-checkin.sh --list
```

Passing check-ins are evidence-gated: bootstrap/daily require Day-0, weekly
requires Day-7, and monthly requires Day-30. Overlay and upgrade additionally
consume one fresh launcher receipt after successful SQLite, identity,
fingerprint, install, launch, and Day-0 readback checks; a failed later attempt
invalidates an older unconsumed receipt, and upgrade also requires the App
version or build to change.

Capture only final screenshots or concise issue evidence. Do not commit the
local pin, data container, raw database, exports, attachments, or personal
content. Dated results may update `docs/testing-progress.md` only after a real
journey was performed; a script status check alone is not product evidence.
