# Reliability SLOs and Performance Targets

`docs/performance-and-observability.md` intentionally says its budgets are "not
fake guarantees." This document adds the missing piece mature apps have: explicit
numeric targets plus how they are measured. These are objectives to drive
decisions and alerting, not contractual promises.

## Reliability Objectives

| Metric | Target | Source |
|---|---|---|
| Crash-free sessions | ≥ 99.5% | MetricKit `MXCrashDiagnostic` + App Store Connect |
| Crash-free users | ≥ 99.8% | App Store Connect |
| App hang rate (foreground) | ≤ 0.5% of foreground time | MetricKit `MXHangDiagnostic` / `applicationHangTime` |
| Scroll hitch rate (key lists) | ≤ 5 ms/s hitch | Instruments / `MXAnimationMetric` |
| Disk-write exceptions | ~0 sustained | MetricKit `MXDiskWriteExceptionDiagnostic` |

## Performance Targets (p90 unless noted)

| Flow | Target |
|---|---|
| Cold launch to first meaningful frame | ≤ 1500 ms p90; no regression without review |
| Warm launch | ≤ 500 ms p90; no feature-wide recompute |
| Tap to first visible feedback | same interaction turn (local state) |
| Route transition to destination shell | ≤ 1 frame before heavy aggregation |
| Memory after 30 min mixed session | no unbounded growth; stable working set |

## Measurement

- **In-app:** `MetricKitObserver` already aggregates launch time, hang time,
  memory peak, and crash/hang/CPU/disk diagnostics into `AppPerformanceMonitor`
  (Settings → 性能诊断面板). Use it as the primary local signal.
- **Stores:** App Store Connect Metrics (crashes, hangs, launch, battery) is the
  production source of truth once shipped.
- **Signposts:** Emit the `flow_*` signposts from
  `docs/performance-and-observability.md` for critical flows.

## When an SLO Is Breached

1. Triage with MetricKit diagnostics first (privacy-safe; no names/notes/PIN).
2. Reproduce on the smallest supported iPhone and at the OS floor.
3. If a recent release caused the regression, prefer rollback / kill switch
   (see `docs/release-quality-gates.md`) over a risky hotfix.
4. Add a regression test or signpost so the same breach is caught earlier next
   time.

## Release Gate

A medium/high-risk change touching launch, route transitions, scrolling, or the
tap path must include a performance note (before/after or reasoned argument) per
`docs/release-quality-gates.md`. "Feels fast" is not acceptable evidence.
