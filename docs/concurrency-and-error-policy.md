# Concurrency, Error Handling & Logging Policy

This codebase uses `@MainActor`, `@ModelActor`, `Sendable`, and (sparingly)
`@unchecked Sendable`. Without a written model these get applied ad hoc and cause
data races or main-thread stalls. This document defines the rules.

## Concurrency Model

- **UI and SwiftData live model objects are MainActor.** Views, view models,
  live `Pet/Human/Plant/...` objects from the main context, and anything driving
  `body` run on `@MainActor`.
- **Heavy/bulk persistence work uses a background `@ModelActor`.** One-time
  maintenance, full-table fetches, export, and aggregation that can operate on
  value types should run on a dedicated background SwiftData context (e.g.,
  `CareLedgerBackfillActor`, `DataBackupActor`). They must return only `Sendable`
  values (e.g., `Data`, value-type snapshots), never live `ModelContext` or
  `@Model` instances, across isolation boundaries.
- **`ModelContext` is not `Sendable`.** Never pass a `ModelContext` across an
  isolation boundary. Pass the `Sendable` `ModelContainer` and create/own the
  context inside the actor.
- **`Sendable` first, `@unchecked Sendable` rarely.** Prefer value types and real
  `Sendable` conformance. `@unchecked Sendable` is allowed only for types whose
  thread-safety is enforced by other means (single-writer, lock, or
  isolation-agnostic pure logic) and must carry a comment explaining why it is
  safe. New `nonisolated(unsafe)` globals need the same justification.
- **Off-main work is opt-in and cancellable.** Background tasks must be
  route-scoped or maintenance-scoped and cancellable; do not spawn detached work
  that outlives its owner. Repeating/runtime work still goes through
  `AppWorkloadPolicy` (see `docs/app-architecture-governance.md`).
- **Swift 6 direction.** New code should compile clean under strict concurrency
  checking. Do not silence data-race warnings with `@unchecked`/`nonisolated`
  without justification; fix the isolation instead.

## Error Handling

- **Model the failure.** Throw typed errors (`LocalizedError` where user-facing)
  from services; do not return silent `nil` for real failures that the user needs
  to know about.
- **Surface user-facing failures.** A failed business write (save, import,
  schedule) must produce Chinese and English source copy through `L10n`, use the
  registered-language fallback chain, and provide a safe recovery path rather
  than a silent no-op. See the recovery questions in
  `docs/release-quality-gates.md`.
- **`try?` is for genuinely optional reads.** Do not use `try?` to swallow errors
  on writes or on data the user expects to persist.
- **No `fatalError`/force-unwrap on user data paths.** Force unwrap and
  `fatalError` are only acceptable for true programmer invariants, never for
  optional model data, parsing, or I/O.
- **Recovery over crash without identity forks.** Persistence/migration/startup
  failures may retry a different opening strategy only against the same primary
  store identity. If that store remains unavailable, stop before mounting any
  writable app surface and show the retry/support recovery shell; never create
  an automatic secondary disk or memory store.

## Logging

- **Use `OSLog`/`Logger`, not `print`.** `print()` is not acceptable in shipping
  code (the SwiftLint custom rule flags it). Use subsystem `HT.Ohana` and a
  meaningful category (e.g., `MemberCreationPerformance` uses signposts already).
- **Privacy-safe by default.** Never log pet/human names, private notes, PIN,
  health values, precise routes, or raw user text. Use `.private` redaction for
  anything potentially identifying; keep diagnostics aligned with
  `docs/performance-and-observability.md`.
- **Levels.** `debug` for development detail, `info` for lifecycle/flow,
  `error`/`fault` for real failures worth investigating in production.

## Validation

- New types, changed public APIs, SwiftData, actors, or isolation changes use the
  targeted-tests + `scripts/build-debug-fast.sh` path (AGENTS.md classification).
- Add an in-memory SwiftData test when a background actor writes business facts
  (e.g., `CareLedgerBackfillActorTests`).
