# OnlineFeatureGate Logic

## Purpose

`OnlineFeatureGate` is the single first-release decision point for online
collaboration. The launch version of Ohana is single-device, single-owner, and
free; therefore every online surface is closed by default. Future paid
multi-device sync and multi-owner collaboration must evolve by replacing the
inside of this gate with the entitlement service, not by adding scattered
product checks.

## Launch Semantics

- The launch gate is always closed.
- A closed gate means no reachable FamilyTasks collaboration surface, no cloud
  sync settings surface, and no CKShare acceptance path.
- A closed gate must block work before CloudKit share acceptance, before cloud
  sync enablement, and before any shared database scope switch.
- The gate does not remove local single-owner data, local backups, care logs,
  reminders, or the local family weekly report.
- Domain models and dormant future services may remain in code for migration
  continuity, but user-reachable entry points must be hidden or blocked through
  `OnlineFeatureGate`.

## Collected Surfaces

### FamilyTasks And Collaboration

- `Ohana/Features/Home/Views/FocusHomeHeaderView.swift`: header copy and action
  must not expose "family collaboration" while the gate is closed.
- `Ohana/Features/Home/Views/VerticalSolidHomeView.swift`: header `onCrew`
  remains a members roster action only.
- `Ohana/Features/Home/Views/VerticalSolidHomeView+TodayFocus.swift`: Today
  Focus family task taps must not open collaboration mode while the gate is
  closed.
- `Ohana/Features/Home/Views/FocusHomeAuxiliaryViews.swift`: assigned family
  task snapshots must receive an empty source while the gate is closed.
- `Ohana/Features/Home/HomeReadModelStore.swift`: home snapshots must not fetch
  `FamilyCollaborationTask` for launch when the gate is closed.
- `Ohana/Features/Home/VerticalSolidHomeSnapshotBuilder.swift`: family task
  inputs remain supported for the future, but launch callers pass no online
  tasks.
- `Ohana/Features/CrewRoster/CrewRosterRouteContainer.swift`: collaboration
  data queries are mounted only when the gate is open.
- `Ohana/Features/CrewRoster/Views/CrewRosterOverlay.swift`: collaboration mode,
  task dashboard, collaboration FAB, and bounty/task drawers are hidden while
  closed; members roster remains available.
- `Ohana/Features/FamilyTasks/Views/BountyBoardView.swift` and
  `Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView*.swift`:
  these views are future surfaces and must be unreachable through launch
  navigation.
- `Ohana/Features/Onboarding/Day0PromiseDataContainer.swift` and
  `Ohana/Features/Onboarding/Views/Day0PromiseSheet.swift`: the legacy day-zero
  promise bounty surface remains dormant and must have no launch entry point.

### Settings Cloud Sync

- `Ohana/Features/Settings/Views/SettingsView.swift`: the household sync section
  is not rendered while the gate is closed.
- `Ohana/Features/Settings/Views/SettingsView+CloudSync.swift`: invite, bind,
  retry, save, and stop-sharing handlers must also guard with the gate so stale
  UI state cannot enable sync.

### CKShare Invite And Accept

- `Ohana/App/OhanaCloudSharingAppDelegate.swift`: incoming CKShare acceptance is
  blocked before `CloudSyncHouseholdShareService.acceptShare`, before accepted
  share state writes, before `cloudSync.setEnabled(true)`, and before remote
  sync start/send/fetch.
- `Ohana/Domain/Services/CloudSyncShareRuntime.swift`: share helpers stay as the
  future implementation detail. Launch acceptance is blocked at the app-delegate
  handoff.
- Remote notification registration and iCloud account observation may remain
  inert in launch builds because `CloudSyncEngineRuntime` defaults to disabled;
  no user-reachable enable path may bypass the gate.

## Blocked UX

When a user opens another person's CKShare link in the launch build, Ohana
must show a visible, respectful notice:

- Title: "联机协作即将推出"
- Message: "这个版本不会加入共享家庭，您的本机数据保持不变。"

The app must not crash, silently ignore the link, accept the share, enable sync,
or mutate the local store as a shared household.

## FamilyReports Split

The local family weekly report remains in launch because it is a single-device
care recap. The bounty board and collaboration leaderboard are hidden with the
online gate. The weekly report may keep care-ledger contribution ranking, but
copy must describe local care contribution rather than online collaboration or
bounty participation.

If the weekly report becomes tightly coupled to bounty/collaboration state in a
future refactor, hide the coupled part behind `OnlineFeatureGate` first. If that
is too costly, stop and escalate under product constitution section 7 before
shipping.

## Entitlement Evolution

`OnlineFeatureGate` is the launch placeholder for D9's future entitlement
service. The only entitlement dimension is whether online collaboration is
unlocked. When paid sync/collaboration ships, callers should keep asking the
same gate and the gate can delegate to subscription, lifetime purchase, or
family-plan state internally.

No call site may decide online availability from CloudKit account state,
UserDefaults sync flags, number of humans, build configuration, subscription
strings, or product identifiers directly.
