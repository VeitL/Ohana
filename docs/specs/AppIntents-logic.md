# App Intents And System Surfaces Logic

> Status: active system-surface rulebook. Ohana currently ships a read-only
> Today Care Widget and a walk Live Activity / Dynamic Island. App Intents,
> Shortcuts, Siri, Spotlight, and controls remain unimplemented.

## Purpose

Ohana system surfaces must expose small, useful user actions. They are not a
second navigation tree and not a shortcut around product privacy, memorial,
deletion, or first-release local-only boundaries.

## Scope

In scope:

- App Intents.
- App Entities and fixed AppEnums used by system surfaces.
- App Shortcuts, Siri phrases, Spotlight actions/entities, widgets, controls,
  and notification actions that reuse intent-style parameters.
- Runtime handoff from a system surface into the main scene.

Out of scope:

- Mirroring every tab, settings page, dashboard, or debug/lab view.
- Exposing private health, PIN, backup password, deleted, trashed, memorial-only,
  or locked data through system suggestions.
- Cloud collaboration or shared household entry points before the product
  foundation allows online multi-user behavior.

## Current Shipped Surfaces

- The Personal Today Care Widget reads one versioned App Group snapshot with at
  most three items. It uses generic care labels instead of free-form household
  titles, omits health/medication details, expires stale Personal content, and
  opens either the typed Task Center route or Settings. It never writes a care
  fact inline.
- The Free and Personal walk Live Activity carries a stable session and pet ID,
  pet display name, phase, elapsed time, distance, and potty count. It opens the
  typed active-walk route and exposes no completion, reward, or persistence
  action. Missing, deleted, deceased, or ineligible pets are rejected by the
  normal walk route container.
- Neither surface reads live SwiftData models in the extension. The app owns
  projection and domain invariants; WidgetKit and ActivityKit receive only
  bounded value data.

## Invariants

AI-001. Start with actions, not screens. A first pass may expose only 1-3
high-value actions that make sense outside the app UI.

AI-002. Good first candidates are quick pet-care logging, opening a specific pet
or human profile, viewing today's care focus, and creating or jumping to
reminders. Each candidate must be backed by existing app/domain logic.

AI-003. `AppEntity` surfaces are narrower than SwiftData models. They carry
stable identifiers, display representation, and only the fields needed for
routing or disambiguation.

AI-004. Every app-opening intent translates into a typed route value first. The
route host presents the destination. Feature-specific global side channels,
prebuilt destination views, and raw SwiftData object graphs are forbidden.

AI-005. Every inline action writes through the same command/service boundary the
app UI uses. App Intents must not directly edit balances, reminders, tasks,
privacy flags, SwiftData relationships, or reward side effects.

AI-006. Privacy, deleted, memorial, missing-data, and local-account boundaries
apply exactly as they do in the app. A system surface may show a safe placeholder
or open a recovery route, but it must not leak hidden values.

AI-007. Shortcut phrases and display strings are user-facing copy and follow the
registered-language fallback chain. Chinese and English are mandatory at
authoring time.

AI-008. Widgets, controls, notification actions, and App Intents should reuse one
structured action/entity layer where practical. Do not create one-off parameter
models for each surface unless the behavior genuinely differs.

## Validation

For any App Intents/system-surface change, report:

- Actions exposed and why they are useful outside the app.
- Entity/AppEnum types and the fields exposed.
- Whether each action completes inline or opens the app.
- The exact typed route or command handoff.
- Build result for the target containing the intents.
- Targeted route/command test for the handoff.
- Privacy/deleted/memorial/missing-data behavior.

Do not claim Siri, Shortcuts, Spotlight, widget, or control coverage from an
app-only build. Each shipped surface needs its own manual or automated evidence.
