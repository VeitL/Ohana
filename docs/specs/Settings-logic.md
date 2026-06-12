# Settings Module Logic

Updated: 2026-06-12

## Product Contract

Settings is a release-facing control surface. First-launch/release users must only see controls that either work immediately or intentionally route to a real system setting. Developer-only diagnostics, visual labs, balance mutation tools, and experimental playgrounds are not release UI.

## Release Gates

- Developer tools are Debug-only. Release builds must not expose design labs, performance diagnostics, privacy test panels, collaboration playgrounds, or coconut balance mutation tools.
- Empty action rows are not allowed in release UI. Privacy policy/contact entries stay hidden or tracked until final URLs or contact channels exist.
- Notification category switches are real controls. If a Settings switch disables a category, reminder scheduling must skip local notification registration for that category while keeping the in-app reminder fact intact.
- Notification preference decisions live in one shared policy path, not in Settings views. Settings only reads/writes user preference; `NotificationDeliveryPolicy` makes the scheduling decision.
- User-facing Settings copy must go through `L10n.tr` / `AppLocalizedText` or existing localization helpers. Chinese and English authoring text are required; other registered languages use the fallback chain unless explicit translations are provided.

## Notification Preference Groups

The Settings UI exposes human-scale groups rather than internal notification categories:

- Medication: medication reminders.
- Feeding: feeding and food-stock reminders.
- Hygiene: hygiene/grooming reminders.
- Check-in: calendar-style check-in/ambient reminders.

When a group is off:

- the `Reminder` and `Event` remain in SwiftData;
- the app does not register a local notification;
- scheduling ledger records a user-disabled skip result;
- the reminder status remains pending unless another domain service changes it.

## Out Of Scope

- No CloudKit enablement, remote push, subscription, account, or entitlement work.
- No startup-path work beyond reading lightweight `UserDefaults` preferences during reminder scheduling.
- No schema changes owned by Settings.

