# Ohana

Ohana is a local-first iOS care app for pets, people, and plants. The first
release is a single-device Solo experience built with SwiftUI, SwiftData, Swift
Charts, HealthKit, Core Location, UserNotifications, and optional restricted
iCloud Drive backup.

## Start Here

- Product behavior: [`docs/specs/product-foundation.md`](docs/specs/product-foundation.md)
- Engineering and agent rules: [`AGENTS.md`](AGENTS.md)
- Documentation map: [`docs/README.md`](docs/README.md)
- Current release and validation status: [`docs/testing-progress.md`](docs/testing-progress.md)
- Open work: [`docs/task-follow-ups.md`](docs/task-follow-ups.md)
- Manual and physical-device acceptance: [`docs/release-true-device-test-plan.md`](docs/release-true-device-test-plan.md)

Do not use planning, reference, archive, design-export, or dated audit documents
as current status sources. Their role and precedence are listed in
`docs/README.md`.

## Local Commands

```bash
open Ohana.xcodeproj
scripts/dev-check-changed.sh
scripts/build-debug-fast.sh
scripts/test-simulator.sh
```

Local command-line validation uses the `iPhone 17` simulator by name with the
`iphonesimulator` SDK. Commit, push, remote CI, signing, entitlement changes,
and App Store actions require an explicit user request.

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
