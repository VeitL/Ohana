# Dependency Governance

Ohana is currently first-party and dependency-light. Keep it that way on purpose;
every third-party dependency is long-term surface area for security, supply chain,
binary size, build time, and maintenance.

## Default Answer Is No

Prefer the platform (SwiftUI, SwiftData, Swift Charts, Foundation, OSLog,
MetricKit) and existing shared utilities before adding a dependency. Most needs
(networking glue, small helpers, formatting) should be solved in-repo.

## Adding a Dependency Requires Justification

Before adding a Swift Package, record (in the PR description or a short note):

- Problem it solves and why the platform/in-repo option is insufficient.
- Maintenance health: active maintenance, release cadence, open-issue health.
- License: must be permissive and compatible (MIT/Apache-2.0/BSD). No
  copyleft/unknown licenses without explicit approval.
- Security/supply-chain: reputable source, reasonable transitive dependency tree.
- Cost: binary size impact and build-time impact.
- Exit plan: how hard is it to remove later.

## Versioning Rules

- Pin with exact or tight ranges; commit `Package.resolved`.
- No `branch`/`revision` dependencies for shipping code.
- Update deliberately (review changelogs), not automatically.
- CI builds with `-disableAutomaticPackageResolution` where possible; resolution
  is an intentional step, not a silent build-time fetch.

## Allowed Tooling vs Shipping Code

Developer tooling that does not ship in the app binary (SwiftLint, SwiftFormat,
xcbeautify, snapshot-testing in test targets) has a lower bar than runtime
dependencies, but still follows the license rule and is installed via a pinned
mechanism (Homebrew in CI, documented versions).

## Forbidden Without Explicit Approval

- Analytics/tracking SDKs (conflicts with the local-first privacy posture).
- Ad SDKs.
- Crash SDKs that exfiltrate PII (MetricKit is the privacy-safe default).
- Anything pulling Google Fonts, web assets, or non-V4 design systems into the
  app (see the UI source-of-truth rules in `AGENTS.md`).
