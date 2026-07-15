# Ohana

Ohana is a local-first iOS care app for pets, people, and plants. The first
release is a single-device Solo experience built with SwiftUI, SwiftData, Swift
Charts, HealthKit, Core Location, UserNotifications, and optional restricted
iCloud Drive backup. The current product has no Ohana account, developer-hosted
backend, or login requirement.

## Start Here

- Product behavior: [`docs/specs/product-foundation.md`](docs/specs/product-foundation.md)
- Engineering and agent rules: [`AGENTS.md`](AGENTS.md)
- Documentation map: [`docs/README.md`](docs/README.md)
- Current release and validation status: [`docs/testing-progress.md`](docs/testing-progress.md)
- Open work: [`docs/task-follow-ups.md`](docs/task-follow-ups.md)
- Manual and physical-device acceptance: [`docs/release-true-device-test-plan.md`](docs/release-true-device-test-plan.md)
- Deferred account/backend extension: [`docs/planning/account-backend-extension.md`](docs/planning/account-backend-extension.md)

Do not use planning, reference, archive, design-export, or dated audit documents
as current status sources. Their role and precedence are listed in
`docs/README.md`.

## Current Product Shape

- A clean install creates one local Human from a name, then lets the user create
  the first Pet immediately or defer it to Task Center.
- Home holds family and member cards. Task Center is the single list/calendar
  surface for Event, Reminder, local FamilyTask, and small system-journey items.
- The first active Pet makes the one-time island starter gift claimable. Oasis
  stays hidden until the user explicitly claims that gift; later starter-plan
  rewards are separate, optional, and member-owned.
- The first release remains local-only Solo. Local Human profiles are content
  records, not authenticated accounts or remote collaborators.

## Local Commands

```bash
open Ohana.xcodeproj
scripts/dev-check-changed.sh
scripts/module-exit-gate.sh --test OhanaTests/RelevantTests
scripts/release-hardening-check.sh --static-only
scripts/build-debug-fast.sh
scripts/build-release-fast.sh
scripts/test-simulator.sh
scripts/run-dogfood-simulator.sh --status
scripts/archive-release-local.sh
```

Automated Unit, Integration, and UI validation uses only the disposable
`iPhone 17 Tests` simulator and `.build/DerivedData/tests`. Persistent manual
journeys use the pinned `iPhone 17` Dogfood simulator through
`scripts/run-dogfood-simulator.sh`; that lane overlays builds and preserves the
installed app and data. `build-release-fast.sh` uses a generic iOS Simulator
destination, keeps `-O`, and reuses `.build/DerivedData/release` for optimized
compiler checks.
`archive-release-local.sh` is the slower signed WMO lane for RC/signing gates;
it writes outside the File Provider-managed repository and never uploads.
`dev-check-changed.sh` is read-only unless `--fix-format` and explicit targets
are supplied;
`module-exit-gate.sh` owns feature proof; `release-hardening-check.sh` owns the
full static/unit release lane and accepts `--with-ui` for RC UI regression.
Commit, push, remote CI, signing, entitlement changes, and App Store actions
require an explicit user request.

## Repository Layout

- `Ohana/`: production app code.
- `OhanaTests/`: Swift Testing and unit/integration coverage.
- `OhanaUITests/`: XCTest UI coverage.
- `Resources/`: packaged non-catalog resources.
- `docs/`: current policy, status, specifications, planning, evidence, and archives.
- `scripts/`: local and CI validation helpers.
- `ui规范.selection.json`: machine-readable UI token source of truth.

The latest SwiftData schema and supported languages must be read from current
source rather than copied from historical documentation:

- `Ohana/Models/SharedModelContainer.swift`
- `Ohana/Shared/LocalizationSettings.swift`
