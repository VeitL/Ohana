# Dead Code Archive - 2026-06-11

This folder preserves source that was identified as unused or unreachable in the
current app route graph.

The archive lives under `docs/archive/`, outside the Xcode
file-system-synchronized groups for `Ohana`, `OhanaTests`, and `OhanaUITests`.
Files here are historical reference only and do not participate in the app build.

## Layout

- `Ohana/`: whole Swift files moved out of the active app tree.
- `mixed-file-snapshots/`: snapshots of active files before unused declarations
  were removed from those files.

## Notes

- The current app home entry is `ContentView -> VerticalSolidHomeDataContainer ->
  VerticalSolidHomeView`; old Overview/expanded quick-action code was archived.
- Mixed active files were kept in place only for declarations that still have
  current call sites.
