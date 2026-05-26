# Feature Module Contract

Ohana is a multi-feature app. Every product area must behave like a bounded feature module even when it lives in the same Xcode target.

## Feature Definition

A feature is any user-facing product area with its own route, data reads, write commands, UI state, or recurring work. Examples: Feeding, Walking, Water, Poop, Reminders, Family Tasks, Rewards, Oasis, Inventory, Human Health, Reports, Settings.

Each feature must declare:

- Feature name and owner area.
- User entry points: tab, route, sheet, popup, widget, App Intent, notification, deep link.
- Public route values.
- Public service commands.
- Read models / snapshot builders.
- SwiftData models it owns.
- SwiftData models it may read.
- Runtime work it may start: timer, location, map, animation loop, background refresh.
- Privacy boundaries.
- Performance-sensitive paths.
- Test coverage expectations.

## Boundary Rule

Features may depend on shared foundations, design system, localization, runtime policy, and domain services. Features must not import each other's Views directly.

Allowed:

- Feature A emits a typed route.
- Feature A calls a shared domain service.
- Feature A reads a value snapshot produced by an approved read-model builder.
- Feature A uses shared UI components.

Not allowed:

- Feature A constructs Feature B's internal view directly.
- Feature A mutates Feature B's SwiftData models outside a domain service.
- Feature A starts Feature B's timers, animations, location, or refresh loops.
- Feature A observes broad global state just to update its own badge.
- Feature A reaches into another feature's private ViewModel.

## Suggested Soft Module Shape

Use this shape for large or growing features:

```text
Ohana/Features/<FeatureName>/
  <FeatureName>Routes.swift
  <FeatureName>RenderState.swift
  <FeatureName>SnapshotBuilder.swift
  <FeatureName>ServiceAdapter.swift
  Views/
  Components/
  Tests/
```

For smaller existing features, keep the current folder structure but follow the same logical boundary.

## Promotion Rule

Start as a soft module. Promote to a stricter module, package, or target only when one of these becomes true:

- The feature slows incremental builds.
- The feature has independent routes, services, and test fixtures.
- The feature is imported by unrelated product areas.
- The feature owns expensive startup, media, map, or background behavior.
- The feature needs a clear public API to stop cross-feature coupling.

