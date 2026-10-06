# OS Support Matrix

Status: Active release policy

Owner: Product owner

Last reviewed: 2026-07-15

## Approved First-Release Policy

- Distribution target: iPhone app only.
- Minimum OS: iOS 26.2.
- Native iPad app: not included in the first release.
- Native watchOS app, complication, and WatchConnectivity data client: not
  included in the first release.
- A paired Apple Watch may receive and act on system notifications forwarded
  from iPhone. That is a physical-device compatibility check, not a claim that
  Ohana ships a native Apple Watch app.
- App Store storefront selection remains part of the signed-release and App
  Store Connect checklist owned by `TFU-20260709-001`; it does not change the
  device-family policy.

This is an intentional narrow-launch decision. It keeps the current iOS 26-era
API surface and avoids combining RC hardening with an older-OS compatibility
migration or unverified iPad/watchOS product work.

Apple's current compatibility list includes iPhone SE (2nd generation) and
iPhone 11 through the current iPhone generation:
<https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-26-iphe3fa5df43/26>.

## Enforced Repository Configuration

- Every `Ohana`, `OhanaTests`, and `OhanaUITests` build configuration uses
  `TARGETED_DEVICE_FAMILY = 1`.
- Every explicit iOS deployment setting remains `26.2`.
- App build configurations do not generate iPad-specific orientation keys.
- The project contains no watchOS target.
- `docs/governance/manifests/release-device-matrix.json` is the machine-readable
  policy, and `scripts/audit-governance-manifests.sh` rejects configuration
  drift.

## Release Acceptance Matrix

| Lane | Required evidence |
| --- | --- |
| Automated tests | Unit, Integration, and UI tests use only the disposable `iPhone 17 Tests` device and the worktree-shared external `tests` cache lane. |
| Persistent Dogfood | Non-destructive long-lived journeys use the pinned `iPhone 17 Dogfood` Release synthetic user through `scripts/run-dogfood-simulator.sh` and preserve its durable app data across container remounts. |
| Release compiler lane | Optimized compiler validation uses a generic iOS Simulator destination and the shared external `release` cache lane; signed-device proof still requires an Archive. |
| Hardware floor | Signed Release smoke on iPhone SE (2nd generation), or the smallest supported iPhone actually used for launch, running iOS 26.2 or later. |
| Current hardware | Signed Release smoke on a current iPhone and current supported iOS. |
| Archive / App Store Connect | The shipped app reports iPhone-only device family, requires no iPad screenshots, exposes no watchOS app, and records the selected storefronts. |
| Paired Apple Watch | Notification forwarding and Complete / Skip / Snooze actions are checked once; no native Watch support is advertised. |

Simulator evidence cannot close the hardware-floor, signed Archive, App Store
Connect, notification-delivery, energy, or physical accessibility rows. Those
remain in `TFU-20260709-001` and the true-device release plan.

## Automated OS and Toolchain Validation

Passing on one OS runtime or Xcode release does not establish compatibility
with another. Keep the OS runtime and Xcode toolchain explicit in every test
receipt, and vary one of them at a time when diagnosing a failure.

| Trigger | Required automated coverage |
| --- | --- |
| Pull request | Full Unit/Integration suite on the minimum supported iOS runtime and the latest supported stable iOS runtime; critical UI smoke paths on both runtimes. |
| Nightly | Complete UI shard manifest on the latest supported stable iOS runtime. Keep the governed per-simulator shard execution serial. |
| Release candidate | Full Unit/Integration and complete UI shard manifest on both the minimum supported runtime (iOS 26.2) and latest supported stable runtime. Run each matrix leg on an isolated disposable `iPhone 17 Tests` Simulator. |
| Next-major iOS beta | Use the matching Xcode beta and OS runtime. Run critical UI smoke paths on each beta; run the complete suite before adopting the OS as a supported release target. |
| Xcode upgrade | Before changing the stable CI toolchain, run the same commit and runtime with both the old and new Xcode versions so toolchain changes are not confused with OS changes. |

Every matrix leg must use the same source commit, device profile, seed, locale,
and permission fixture unless the test explicitly varies that input. Receipts
must record the exact Xcode build, simulator runtime, device, selectors, and
result counts. Preserve the first failing result; a later retry is diagnostic
evidence and never replaces a failed matrix leg. If a runner cannot provide
the required runtime or Xcode version, mark that leg **Blocked** rather than
substituting a different environment or claiming compatibility. Keep UI shards
serial on each Simulator; separate OS matrix legs may use separate CI runners
only when each runner owns its own disposable test Simulator and managed cache.
The matrix policy itself is not test evidence: a leg remains **Blocked** until
CI or an approved device run publishes a receipt for that exact OS/toolchain
combination.

## Deferred Platform Migrations

Each of the following requires its own product decision, code audit, fallback
plan, target, and test matrix:

1. Lowering the deployment target below iOS 26.2.
2. Shipping a native iPad experience.
3. Shipping a dependent or independent watchOS app.
4. Adding Watch complications, WatchConnectivity persistence, HealthKit workout
   sessions, or background location on Apple Watch.

Do not change deployment target or device family as incidental work.
