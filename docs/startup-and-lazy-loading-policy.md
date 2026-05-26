# Startup and Lazy Loading Policy

Keep app startup skinny. A mature app should make the shell responsive first, then activate feature work from typed, visible, or explicitly targeted entry points.

## Startup Allowlist

App launch may perform:

- App shell initialization.
- Root route host initialization.
- SwiftData container setup and lightweight migration checks.
- Localization and theme token loading.
- `AppWorkloadPolicy` setup.
- Required permission state reads.
- Crash-safe recovery checks.

App launch must not perform:

- Full dashboard recomputation.
- Broad SwiftData scans for every feature.
- Feature route tree construction for all destinations.
- Image/avatar decoding for screens not visible.
- Map, location, timer, or animation loop startup.
- Reward, reminder, task, inventory, or report synchronization unless recovering an interrupted critical transaction.
- Network calls required only by non-visible pages.
- Widget refresh fan-out caused by ordinary app open.

## Lazy Activation

A feature activates only when one of these occurs:

- The user navigates to its route.
- The feature's tab or dashboard card becomes visible.
- A route-scoped `.task(id:)` starts for that feature.
- A widget, App Intent, notification, or deep link targets that feature.
- A scheduled background task explicitly belongs to that feature.

## Route Destination Rule

Route values may be registered at launch, but heavy destination construction must be lazy. A route value carries stable identifiers and lightweight parameters only.

## Startup Regression Review

Any change touching app launch must report:

- Cold launch before/after.
- Warm launch before/after.
- Main-thread blocking work observed or ruled out.
- SwiftData queries performed during launch.
- Image decoding performed during launch.
- Timers or repeating work started during launch.

