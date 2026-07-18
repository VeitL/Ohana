# Local Build Storage Policy

Ohana uses three stable local build lanes. Do not create task-, TFU-, branch-,
or timestamp-named DerivedData directories.

| Lane | Simulator | DerivedData | Purpose |
|---|---|---|---|
| Tests | `iPhone 17 Tests` | `.build/DerivedData/tests` | Automated Unit, Integration, and UI tests |
| Dogfood | pinned UDID in `.build/dogfood-simulator.udid` | `.build/DerivedData/dogfood` | Long-lived human journeys and real local data |
| Release | generic iOS Simulator or signed device Archive | `.build/DerivedData/release` | Optimized compiler validation and Release Archive |

Unit and Integration fixtures still use isolated SwiftData containers. The
Simulator selected by the test runner is a disposable host, not a shared data
source.

## Simulator boundaries

- `scripts/test-simulator.sh` resolves only `iPhone 17 Tests`. It refuses the
  pinned Dogfood UDID, a generic destination, another named phone, and the old
  shared `OHANA_SIMULATOR_UDID` override.
- `scripts/prepare-test-simulator.sh` creates the dedicated test phone on the
  newest installed iOS runtime. It does not boot or erase Dogfood.
- Destructive setup uses `scripts/reset-test-simulator.sh --erase --confirm` or
  `--recreate --confirm`. Both commands re-check the target name and Dogfood
  pin immediately before mutation.
- `scripts/run-dogfood-simulator.sh` remains the only persistent Dogfood
  entrypoint. It overlays the app and never erases or uninstalls its data.

## Build and test behavior

- The default test action is `build-then-test`: `build-for-testing` runs once,
  then the selected tests run with `test-without-building`.
- Multi-shard UI runs build once and run every shard with
  `test-without-building` against the same fixed cache.
- Direct `OHANA_TEST_ACTION=test` is rejected because it hides the build/run
  boundary. Supported actions are `build-then-test`, `build-for-testing`, and
  `test-without-building`.
- A local build or test stops when free disk space is below 20 GiB. It warns
  when repo `.build` exceeds 25 GiB or aggregate Simulator `Library/Caches`
  exceeds 10 GiB.

## Reporting and cleanup

Run:

```sh
scripts/report-local-build-storage.sh
scripts/cleanup-local-build-storage.sh
```

Both commands are read-only by default. The cleanup command prints every
candidate, its size, the estimated reclaim, and a token derived from the exact
candidate list. Deletion requires a second invocation with that token. If the
list changes, the token is rejected.

The conservative automatic plan preserves:

- all three fixed DerivedData lanes;
- the newest legacy test cache as a temporary bridge until
  `.build/DerivedData/tests/Build/Products` exists;
- every Simulator device, including Dogfood and Tests;
- the newest child under `/private/tmp/OhanaArchives`;
- all Xcode DeviceSupport directories;
- arbitrary `/private/tmp/ohana-*` artifacts that may still be working files.

After the fixed tests lane has built products, old nested task caches inside
`.build/DerivedData/tests` become candidates too; the fixed lane itself remains.

Simulator cache deletion and DeviceSupport deletion are deliberately outside
the automatic script. Review them from the storage report first. Keep only the
DeviceSupport OS/build versions needed by physical devices that still connect;
removing any version requires a separate explicit approval.
