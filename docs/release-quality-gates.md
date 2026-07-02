# Release Quality Gates

Ohana changes must be safe to ship, diagnose, and recover.

## Change Risk Levels

Start with `scripts/dev-check-changed.sh` for changed files. Escalate only when
the changed surface needs broader proof. A build is evidence for compiler
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
- Targeted unit tests with in-memory SwiftData.
- Runtime audit.
- Manual simulator flow.
- Recovery path.
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
| Persistence/schema | In-memory migration/compatibility tests, recovery path, backup/export impact, targeted simulator test when user-visible | Data safety from a build-only pass |

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
Trace/memgraph artifacts:
Known limitations:
Rollback/fallback:
```
