# Release Quality Gates

Ohana changes must be safe to ship, diagnose, and recover.

## Change Risk Levels

### Low Risk

Pure copy, small visual spacing, localized string, non-interactive token mirror.

Required:

- Build.
- Relevant UI audit if UI changed.

### Medium Risk

New screen, new route, new popup, new SwiftData read model, new animation, new App Intent.

Required:

- Build.
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
Known limitations:
Rollback/fallback:
```

