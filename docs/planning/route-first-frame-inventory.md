# Route First-Frame Inventory

Generated: 2026-06-17

Command:

```bash
scripts/report-route-first-frame-inventory.sh > docs/planning/route-first-frame-inventory.md
```

## Gate

```text
Route first-frame audit: passed (845 file(s)).
```

## Current Snapshot

| Metric | Count |
|---|---:|
| Ohana Swift files | 845 |
| Route/data container files scanned by this inventory | 64 |
| All `@Query` occurrences in `Ohana/` | 78 |
| All direct SwiftData `fetch` occurrences in `Ohana/` | 266 |
| Route/data `@Query` occurrences | 76 |
| Route/data ratchet baseline files | 45 |
| Route/data ratchet baseline `@Query` allowance | 76 |
| Route/data direct SwiftData `fetch` occurrences | 16 |
| Route/data deferred fetch markers | 16 |
| Route/data unmarked direct fetch occurrences | 0 |
| First-frame service fetch bypass patterns | 0 |

## Interpretation

- The active gate is strict: `scripts/audit-route-first-frame.sh --all` must pass.
- This file is an inventory snapshot; the debt allowance is explicit in `docs/governance/manifests/route-first-frame-baseline.json`.
- Existing route/data `@Query` subscriptions are ratcheted by file. New files default to zero, and any count above the baseline fails the audit.
- Route/data container fetches are acceptable only when they are deferred after the first frame and marked with `// route-first-frame: allow deferred-fetch`.
- First-frame service fetch bypasses, such as `rewards.currentHumanBalance(context:)` in render/snapshot builders, are zero-tolerance.
- Non-route `@Query` / `fetch` counts are shown for future maturity work; they are not a first-frame route blocker by themselves.

## Route/Data Files With `@Query`

| File | `@Query` count |
|---|---:|
| `Ohana/Features/Calendar/AddEventDataContainer.swift` | 2 |
| `Ohana/Features/CareLedger/CareLedgerAnalysisDataContainer.swift` | 3 |
| `Ohana/Features/DashboardRecords/IslandRetentionDashboardDataContainer.swift` | 1 |
| `Ohana/Features/DashboardRecords/IslandWeightDashboardDataContainer.swift` | 2 |
| `Ohana/Features/DashboardRecords/PetWeightDashboardDataContainer.swift` | 2 |
| `Ohana/Features/Documents/AddDocumentDataContainer.swift` | 1 |
| `Ohana/Features/Documents/ProtectionDocumentDataContainer.swift` | 1 |
| `Ohana/Features/Economy/CoconutBalanceTestDataContainer.swift` | 2 |
| `Ohana/Features/Economy/CoconutLogDataContainer.swift` | 2 |
| `Ohana/Features/Economy/PetBondVaultDataContainer.swift` | 1 |
| `Ohana/Features/Expenses/ExpenseHistoryDataContainer.swift` | 3 |
| `Ohana/Features/Expenses/HumanExpenseDetailDataContainer.swift` | 1 |
| `Ohana/Features/Expenses/IslandExpenseDashboardDataContainer.swift` | 3 |
| `Ohana/Features/FamilyReports/FamilyWeeklyReportDataContainer.swift` | 3 |
| `Ohana/Features/FamilyTasks/BountyBoardDataContainer.swift` | 2 |
| `Ohana/Features/FamilyTasks/FamilyActivityStripRouteContainer.swift` | 1 |
| `Ohana/Features/Gacha/GachaRouteContainer.swift` | 3 |
| `Ohana/Features/Health/CoHealthDashboardDataContainer.swift` | 1 |
| `Ohana/Features/Health/CoHealthDashboardFullDataContainer.swift` | 1 |
| `Ohana/Features/Health/IslandHealthDashboardDataContainer.swift` | 1 |
| `Ohana/Features/Health/PetHealthDetailDataContainer.swift` | 1 |
| `Ohana/Features/HumanHealth/HumanHealthReportDataContainer.swift` | 1 |
| `Ohana/Features/Hygiene/IslandHygieneDashboardDataContainer.swift` | 2 |
| `Ohana/Features/Hygiene/PetHygieneDetailDataContainer.swift` | 3 |
| `Ohana/Features/Medication/HumanMedicationDataContainer.swift` | 2 |
| `Ohana/Features/Medication/IslandMedicationDashboardDataContainer.swift` | 1 |
| `Ohana/Features/Medication/PetMedicationDataContainer.swift` | 1 |
| `Ohana/Features/Medication/PetMedicationDetailDataContainer.swift` | 1 |
| `Ohana/Features/Members/EditPetDataContainer.swift` | 2 |
| `Ohana/Features/Members/HumanBasicInfoDetailDataContainer.swift` | 2 |
| `Ohana/Features/Members/PetDetailSheetRouteContainer.swift` | 1 |
| `Ohana/Features/Moments/QuickMomentOverlayRouteContainer.swift` | 1 |
| `Ohana/Features/Moments/Views/PetMomentsHubRouteContainer.swift` | 1 |
| `Ohana/Features/Notifications/ReminderObservabilityDataContainer.swift` | 2 |
| `Ohana/Features/Oasis/OasisCritterCodexRouteContainer.swift` | 3 |
| `Ohana/Features/Onboarding/Day0PromiseDataContainer.swift` | 1 |
| `Ohana/Features/PetCare/IslandPottyDashboardDataContainer.swift` | 2 |
| `Ohana/Features/Plants/PlantDetailDataContainer.swift` | 1 |
| `Ohana/Features/Plants/PlantRouteContainer.swift` | 1 |
| `Ohana/Features/QuickCare/QuickCareExecutorPickerBarDataContainer.swift` | 1 |
| `Ohana/Features/Shop/InventoryDataContainer.swift` | 3 |
| `Ohana/Features/Walks/IslandExplorationDashboardDataContainer.swift` | 3 |
| `Ohana/Features/Walks/WalkRouteContainer.swift` | 1 |
| `Ohana/Features/Walks/WalkTrackingCardDataContainer.swift` | 2 |
| `Ohana/Features/Wishlist/HumanWishlistDataContainer.swift` | 1 |

## Route/Data Files With Deferred Fetch

| File | Fetch count | Deferred markers |
|---|---:|---:|
| `Ohana/Features/Achievements/AchievementWallDataContainer.swift` | 1 | 1 |
| `Ohana/Features/Calendar/CalendarRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/CrewRoster/CrewRosterRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/Economy/IslandWealthDashboardDataContainer.swift` | 1 | 1 |
| `Ohana/Features/Feeding/IslandFoodDashboardDataContainer.swift` | 1 | 1 |
| `Ohana/Features/FunctionMenu/FunctionMenuRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/Members/ExpandedHumanFeaturesDataContainer.swift` | 1 | 1 |
| `Ohana/Features/Members/HumanDetailSheetRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/Members/MemberCardCreationDataContainer.swift` | 1 | 1 |
| `Ohana/Features/Members/MemberProfileRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/QuickCare/QuickCareRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/Settings/SettingsRouteContainer.swift` | 1 | 1 |
| `Ohana/Features/Shop/CoconutShopRouteContainer.swift` | 1 | 1 |
