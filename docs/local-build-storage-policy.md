# Local Build Storage Policy

Ohana uses three stable local build lanes. Do not create task-, TFU-, branch-,
or timestamp-named DerivedData directories.

| Lane | Simulator | DerivedData | Purpose |
|---|---|---|---|
| Tests | `iPhone 17 Tests` | `.build/DerivedData/tests` | Automated Unit, Integration, and UI tests |
| Dogfood | pinned `iPhone 17 Dogfood` UDID in `.build/dogfood-simulator.udid` | `.build/DerivedData/dogfood` | One long-lived synthetic user governed by `docs/dogfood-testing.md` |
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
  entrypoint. It overlays Release, refuses missing-data replacement and
  test/reset/seed arguments, requires the ready user's sealed store identity,
  and never erases or uninstalls its data.

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
- When that free-space gate blocks, it also prints the largest tracked local
  roots (fixed/legacy DerivedData, individual Ohana temporary artifacts,
  Archives, Simulator caches, and DeviceSupport) so the report points to the
  source that is actually growing rather than only the repo cache.

## Reporting and cleanup

Run:

```sh
scripts/report-local-build-storage.sh
scripts/cleanup-local-build-storage.sh
```

Both commands are read-only by default. The cleanup command prints every
candidate, its size, the estimated reclaim, and a token derived from the exact
candidate snapshot. The snapshot includes each path, recursive newest modified
time, and a deterministic recursive metadata manifest (relative path, type,
device, inode, owner, mode, link count, byte/block size, modified time, and
change time). Deletion requires a second invocation with that token. If the
candidate list or sampled metadata changes, the token is rejected. Apply moves
each unchanged candidate to a same-parent quarantine name, verifies the tree
and open-file state again, then deletes without crossing filesystem boundaries.

The conservative automatic plan preserves:

- all three fixed DerivedData lanes;
- the newest legacy test cache as a temporary bridge until
  `.build/DerivedData/tests/Build/Products` exists;
- every Simulator device, including Dogfood and Tests;
- the complete `/private/tmp/OhanaArchives` tree;
- all Xcode DeviceSupport directories;
- `/private/tmp/ohana-*` artifacts whose recursive newest modified time is less
  than 24 hours old, have an open file, cannot be inspected, are symlinks, are
  owned by another user, or fall outside the exact direct-child boundary.
- any candidate that is a mount point, contains a nested mount, or whose mount
  and activity boundaries cannot be inspected.

Direct `/private/tmp/ohana-*` artifacts become conservative candidates only
after their newest content is at least 24 hours old and an open-file check is
clean. The apply phase repeats boundary, age, ownership, and open-file checks
before quarantine and again after the atomic rename. `xcodebuild` and the three
lane locks also stop the entire apply. A stale apply token is an error even when
no candidates remain.

Production report/cleanup commands require the physical repository root,
`/private/tmp`, a TTL from 24 hours through one year, and the current clock.
Test overrides require explicit fixture mode plus a physical fixture root that
contains both the resolved fake repo and resolved fake tmp root. Symlink escapes
are rejected. This prevents an inherited fixture variable from silently
widening the production delete scope.

The report also detects two read-only growth sources that cleanup never touches:

- numbered Finder/conflict copies under `.git/objects` and `.git/index*`, with
  their count and total allocated size;
- default Xcode `~/Library/Developer/Xcode/DerivedData`, including the count and
  size of `Ohana-*` caches that may belong to Xcode UI builds or old checkouts.

Simulator reporting shows both the full device footprint and its
`Library/Caches` subset. `.git`, default Xcode DerivedData, every Simulator,
DeviceSupport, and Archives require separate review and authorization; this
cleanup script never deletes them.

The fixed tests, Dogfood, and release lanes are protected as complete trees;
standard children such as `tests/Logs/Build` are never reclassified as legacy
candidates.

Simulator cache deletion and DeviceSupport deletion are deliberately outside
the automatic script. Review them from the storage report first. Keep only the
DeviceSupport OS/build versions needed by physical devices that still connect;
removing any version requires a separate explicit approval.
