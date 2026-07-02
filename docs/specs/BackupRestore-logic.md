# Backup And Restore Logic

> Status: first-release data-safety rulebook. It consolidates manual export,
> encrypted export, automatic backup, restore, reset cleanup, and acceptance
> evidence. `docs/specs/AutomaticBackup-logic.md` remains the detailed automatic
> backup sub-rulebook.

## Purpose

Ohana is local-first, so data safety depends on export, automatic backup, and a
restore path that users can understand. Backup and restore must protect user
data without implying CloudKit sync, online collaboration, or multi-device merge
semantics.

## Scope

In scope:

- Manual JSON export.
- Optional encrypted manual export and encrypted import.
- Default-on automatic backup to the user's iCloud Drive ubiquity container.
- Restore from a backup file into a local store.
- Reset/delete-all cleanup of Ohana-managed automatic backup files.
- Tests proving backup-to-wipe-to-restore.

Out of scope:

- CloudKit sync, CKShare, shared database routing, or multi-device conflict
  resolution.
- Password-protecting automatic backups for launch. Automatic backups are
  plaintext JSON files in the user's iCloud Drive container.
- Recoverable user-visible recycle-bin state; the current product model uses
  irreversible deletion after confirmation.

## Invariants

BR-001. Manual export and automatic backup use the same `OhanaBackup` projection
owned by `DataBackupManager` / `DataBackupActor`. A model added to one backup
path must be considered for the other path.

BR-002. Export must omit local-only secrets such as human PIN hash/salt or data
that can recover a PIN.

BR-003. Manual encrypted export uses the current backup encryption envelope and
must reject weak, missing, mismatched, or wrong passwords with localized errors.
Legacy encrypted envelopes may remain readable only through explicit
compatibility code and tests.

BR-004. Restore acceptance for launch is backup -> wipe/reset to an empty local
store -> restore -> verify completeness. Merge import into a non-empty store is
best-effort unless a later rulebook explicitly defines conflict semantics.

BR-005. Restore must rebuild or rehydrate the derived state needed for launch
surfaces: people, pets, plants, care logs, reminders/events, care ledger,
coconut accounts/ledger entries, Oasis/economy state, inventory, and app-state
preferences that are part of the `OhanaBackup` projection.

BR-006. Automatic backup follows `docs/specs/AutomaticBackup-logic.md`: default
on, daily due semantics, one run at a time, visible status, iCloud Drive file
boundary, and failure visibility.

BR-007. Reset/delete-all disables automatic backup and attempts to remove
Ohana-managed automatic backup files. Manual files the user explicitly exported
or shared are not touched.

BR-008. Backup, restore, and automatic-backup diagnostics are privacy-safe. Do
not log names, health values, precise routes, raw notes, PIN fields, or backup
passwords.

## Validation

Required launch evidence:

- Manual export/import round trip for active household data.
- Encrypted export/import success plus wrong-password, missing-password, and
  weak-password failures.
- PIN omission test.
- Automatic backup default-on, toggle-off no-op, success metadata, failure
  visibility, concurrent trigger suppression, and cleanup behavior.
- Backup-to-wipe-to-restore acceptance covering at least one human, one pet,
  care facts, reminders/events, wallet/ledger state, and app preferences.
- Backup coverage tests for any newly added SwiftData model or backup DTO field.

Do not close a backup/restore item with only a successful build. Data safety
requires projection, import, error, and wipe-restore evidence.
