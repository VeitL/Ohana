# Local Xcode Test and Storage Policy

All local Xcode work uses one cache identity derived from the repository's
absolute Git common directory. Every linked worktree therefore shares:

```text
~/Library/Developer/Xcode/OhanaLocalBuild/Ohana-<common-git-dir-hash>/
├── DerivedData/{tests,dogfood,release}
├── TestResults/{staging,failed,success}
└── Locks/project.lock
```

The parent defaults to `~/Library/Developer/Xcode/OhanaLocalBuild`. A
machine-local, ignored `.build/xcode-cache-parent` file may contain one
absolute path (for example, a mounted external volume). If that configured
volume is absent, the scripts stop instead of silently filling the internal
disk. `OHANA_LOCAL_BUILD_CACHE_PARENT` remains the explicit process override.

Do not create task-, TFU-, branch-, timestamp-, or worktree-named DerivedData.
`.build/DerivedData` is legacy and may be removed through the reviewed cleanup
flow. The cache outside the source tree is reproducible; Dogfood's Simulator
data is not.

| Lane | Destination | Purpose |
|---|---|---|
| Tests | disposable `iPhone 17 Tests` | Unit, Integration, and UI tests |
| Dogfood | pinned `iPhone 17 Dogfood` | Release overlay for one long-lived synthetic user |
| Release | generic iOS Simulator or signed Archive destination | Optimized compiler and release validation |

## Mandatory local test entrypoint

Use `scripts/xcode-test.sh`. With no arguments it runs the small
`OhanaTests/AppWorkloadPolicyTests` smoke suite. It discovers and prints the
top-level Xcode container, resolved scheme, scheme test plan, explicit Tests
Simulator destination, shared cache, and result policy.

Broader work is explicit:

```sh
scripts/xcode-test.sh --only-testing OhanaTests/RelevantSuite
scripts/xcode-test.sh --unit
scripts/xcode-test.sh --ui
scripts/xcode-test.sh --full
scripts/xcode-test.sh --coverage --only-testing OhanaTests/RelevantSuite
scripts/xcode-test.sh --keep-success-result --only-testing OhanaTests/RelevantSuite
```

The default action builds test products once and then uses
`test-without-building`. `--build-for-testing` and `--without-building` expose
the two phases for sequential UI shards. Local defaults are:

- code coverage off;
- parallel testing off and one worker;
- retry, repetition, and run-until-failure off;
- only the requested selector, or the smoke suite when none is supplied.

Intentional repetitions require `OHANA_ALLOW_TEST_REPETITION=1`. Intentional
parallel workers require `OHANA_ALLOW_PARALLEL_TESTING=1`. Do not pass governed
coverage/parallel flags around the entrypoint.

## Serialization and result lifecycle

One atomic `mkdir` lock serializes tests, debug builds, Dogfood builds, and
release builds across all worktrees. An active owner causes an immediate
failure instead of an indefinite wait. A dead or malformed owner is removed
in place, so stale lock directories do not accumulate. Emergency concurrency
requires the conspicuous `OHANA_ALLOW_CONCURRENT_XCODE_TESTS=1` override and
accepts the shared-cache/disk risk.

Each Xcode action writes an xcresult into managed staging:

- successful results are deleted by default;
- `--keep-success-result` replaces one `success/latest.xcresult`;
- failures are moved to `failed/`;
- at most the newest three failures are retained;
- failures older than seven days are deleted;
- staging and Xcode-internal result bundles older than one day are pruned.

UI screenshot attachments use `.deleteOnSuccess`; failure evidence remains in
the retained failed xcresult. Nightly/shard wrappers do not create timestamp
result or log trees.

## Simulator and Dogfood boundaries

- Every automated entrypoint resolves only `iPhone 17 Tests` and rejects the
  pinned Dogfood UDID, name-only/generic destinations, and other phones.
- When creating that disposable phone, `prepare-test-simulator.sh` selects the
  newest available iOS runtime and a compatible iPhone type. Explicit
  compatibility passes may set `OHANA_TEST_RUNTIME_VERSION` or
  `OHANA_TEST_DEVICE_TYPE_NAME`; the selected Xcode must also expose that
  runtime as a scheme destination. Dogfood's pinned runtime/device are
  unchanged.
- Each test reinstall can leave the previous Ohana build in the Tests device's
  `containermanagerd/Dead` cache. The unified entrypoint prints a project-owned
  candidate plan and removes only entries whose container metadata and app
  Bundle ID both identify Ohana. It preserves the active app, app data, every
  unverified cache, and every other Simulator.
- Normally, Simulator system assets are allowed to converge. If a completed
  test leaves free space below the configured disk gate, the unified entrypoint
  additionally prints and applies the Tests-only transient plan for unfinished
  downloads and Ohana host profraw trees. The installed app, app data, and
  installed system assets remain untouched.
- Destructive test setup may use `scripts/reset-test-simulator.sh --erase
  --confirm` or `--recreate --confirm`; both re-check the exact disposable
  target immediately before mutation.
- `scripts/run-dogfood-simulator.sh` remains the only persistent Dogfood
  entrypoint. It never erases, uninstalls, seeds, resets, or runs XCTest.
- Cleaning `DerivedData/dogfood` removes only a reproducible build cache. It
  never authorizes deleting the Dogfood Simulator, app container, SwiftData
  store, UDID pin, identity seal, initialization state, or evidence.

## Disk gate, audit, and cleanup

Every local build/test stops before Xcode starts when free space is below
20 GiB. A deliberate local override may set `OHANA_MINIMUM_FREE_GIB`; lowering
it accepts the resulting Xcode failure/corruption risk. The runner reports
pre/post free space, DerivedData size, managed result size, and deltas. The
read-only audit is:

```sh
scripts/xcode-storage-audit.sh
```

It reports shared and legacy DerivedData, worktree results, global Xcode
DerivedData, CoreSimulator devices/caches/runtimes, DeviceSupport, temporary
diagnostic exports, active test processes, unavailable/cloned devices,
numbered `.git` conflict copies, and deleted-but-open CoreSimulator logs.

A large long-lived `CoreSimulator.log` is especially dangerous: a failure
diagnostic export can copy that log in full, multiplying one hidden leak into
several GiB. The audit reports this state; it never kills the service or deletes
another project's diagnostic export.

Cleanup always starts with a candidate list, sizes, exact snapshot token, and
`REPORT ONLY`. Apply revalidates ownership, boundaries, mount crossings, open
files, active Xcode locks/processes, and the snapshot before a same-parent
quarantine rename and deletion:

```sh
# Expired /private/tmp/ohana-*, legacy worktree caches, and proven-passing
# legacy top-level xcresults.
scripts/cleanup-local-build-storage.sh --scope safe

# Managed and legacy test results, including retained failures.
scripts/cleanup-local-build-storage.sh --scope results

# Dead replacement copies of Ohana.app in the shutdown iPhone 17 Tests only.
scripts/cleanup-local-build-storage.sh --scope test-app-cache

# Explicit low-space relief for unfinished MobileAsset downloads in the
# shutdown Tests device and Ohana-only host profraw temp trees. The runner also
# applies it after a test falls below the disk gate; assets may download again.
scripts/cleanup-local-build-storage.sh --scope test-transient-cache

# Rebuildable Tests compiler/module/index caches and standalone dSYMs; preserve
# executable products and xctestrun for xcode-test.sh --without-building.
scripts/cleanup-local-build-storage.sh --scope test-intermediates

# Active shared DerivedData only; Simulator data is still excluded.
scripts/cleanup-local-build-storage.sh --scope derived-data

# Combine all scopes.
scripts/cleanup-local-build-storage.sh --scope all
```

After reviewing every path, repeat the printed command with `--apply <token>`.
No cleanup scope includes `.git`, Archives, Xcode DeviceSupport, installed
Simulator runtimes, healthy Simulator devices, another project's temporary
files, or any Dogfood data. Those require separate evidence and authorization.
