//
//  StartupMaintenanceCoordinator.swift
//  Ohana
//
//  First-render handoff and cancellable startup maintenance queue.
//

import Combine
import Foundation
import SwiftData
import SwiftUI
#if os(iOS)
    import UIKit
#endif

@MainActor
final class StartupMaintenanceCoordinator: ObservableObject {
    private let defaults: UserDefaults
    private var maintenanceTask: Task<Void, Never>?
    private var didStart = false
    private var resumeFromMaintenanceStep: String?

    private static let maintenanceStepNames: Set<String> = [
        "input_warmup",
        "shop_purchase_recovery",
        "companion_lifecycle_compatibility",
        "auto_feeder_materialization",
        "reminder_refill",
        "media_attachment_presence_backfill",
        "member_theme_normalization",
        "plant_care_orphan_maintenance",
        "care_ledger_backfill",
        "shared_care_note_cleanup",
        "shop_purchase_defaults_migration",
        "avatar_asset_compaction"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func startAfterFirstRender(context: ModelContext, services: AppServices) {
        guard !didStart else { return }
        didStart = true
        let persistedCursor = defaults.string(forKey: Keys.maintenanceCursor)
        if let persistedCursor, Self.maintenanceStepNames.contains(persistedCursor) {
            resumeFromMaintenanceStep = persistedCursor
        } else if persistedCursor != nil {
            clearMaintenanceCursor(ifMatching: persistedCursor ?? "")
        }

        maintenanceTask = Task { @MainActor in
            AppPerformanceMonitor.shared.record(
                "launch_shell_ready",
                startedAt: ohanaProcessStartTime,
                note: "RootView appeared"
            )

            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else {
                recordCancelled("first_render")
                return
            }
            AppPerformanceMonitor.shared.record(
                "first_render",
                startedAt: ohanaProcessStartTime,
                note: "startup maintenance deferred"
            )

            await runMaintenanceSequence(context: context, services: services)
            maintenanceTask = nil
        }
    }

    private func runMaintenanceSequence(context: ModelContext, services: AppServices) async {
        guard await runStep("input_warmup", delayMilliseconds: 700, operation: {
                InputLatencyWarmupService.warmUpOnce()
            }) else {
                return
            }

            guard await runStep("shop_purchase_recovery", delayMilliseconds: 120, operation: {
                let results = ShopPurchaseRecoveryService.settleRecoverable(
                    context: context,
                    services: services
                )
                guard !results.isEmpty else { return }
                AppPerformanceMonitor.shared.record(
                    "startup_shop_purchase_recovery",
                    valueMS: 0,
                    note: "settled=\(results.count)"
                )
            }) else {
                return
            }

            guard await runStep("companion_lifecycle_compatibility", delayMilliseconds: 120, operation: {
                do {
                    let result = try OasisCompanionLifecycleCompatibilityService.reconcile(
                        context: context
                    )
                    guard result.repairedCount > 0 || result.hasMoreWork else { return }
                    AppPerformanceMonitor.shared.record(
                        "startup_companion_lifecycle_compatibility",
                        valueMS: 0,
                        note: "inspected=\(result.inspectedCount), repaired=\(result.repairedCount), more=\(result.hasMoreWork)"
                    )
                } catch {
                    OhanaLog.error(
                        "Companion lifecycle compatibility failed: \(error.localizedDescription)",
                        category: "StartupMaintenance"
                    )
                }
            }) else {
                return
            }

            guard await runStep("auto_feeder_materialization", delayMilliseconds: 2500, operation: {
                await self.materializeAutoFeederLogsIfNeeded(context: context)
            }) else {
                return
            }

            guard await runStep("reminder_refill", delayMilliseconds: 16000, operation: {
                FamilyWeeklyReportService().scheduleWeeklyReminder()
                guard self.shouldRunReminderMaintenance else { return }
                let result = await self.runReminderMaintenanceIfNeeded(context: context)
                if result.completed {
                    self.defaults.set(Date().timeIntervalSince1970, forKey: Keys.reminderMaintenanceLastRunAt)
                }
            }) else {
                return
            }

            guard await runStep("media_attachment_presence_backfill", delayMilliseconds: 2500, requiresExpensiveBudget: true, operation: {
                await self.backfillMediaAttachmentPresenceIfNeeded(context: context)
            }) else {
                return
            }

            guard await runStep("member_theme_normalization", delayMilliseconds: 5000, requiresExpensiveBudget: true, operation: {
                await self.normalizeMemberThemeColorsIfNeeded(context: context)
            }) else {
                return
            }

            guard await runStep("plant_care_orphan_maintenance", delayMilliseconds: 30000, requiresExpensiveBudget: true, operation: {
                guard self.shouldRunPlantCareOrphanMaintenance else { return }
                let result = await PlantCareOrphanMaintenanceService.runOffMainScan(context: context, defaults: self.defaults)
                if result.didPersist {
                    self.defaults.set(Date().timeIntervalSince1970, forKey: Keys.plantCareOrphanMaintenanceLastRunAt)
                }
                guard result.removedEventCount > 0 || result.cleanedPreferencePlantCount > 0 else { return }
                AppPerformanceMonitor.shared.record(
                    "startup_plant_care_orphan_maintenance",
                    valueMS: 0,
                    note: "\(result.removedEventCount) events, \(result.removedReminderCount) reminders, \(result.cleanedPreferencePlantCount) pref scopes"
                )
            }) else {
                return
            }

            guard await runStep("care_ledger_backfill", delayMilliseconds: 45000, requiresExpensiveBudget: true, operation: {
                await self.runCareLedgerBackfillIfNeeded(context: context)
            }) else {
                return
            }

            guard await runStep("shared_care_note_cleanup", delayMilliseconds: 5000, requiresExpensiveBudget: true, operation: {
                await self.cleanLegacySharedCareNotesIfNeeded(context: context)
            }) else {
                return
            }

            guard await runStep("shop_purchase_defaults_migration", delayMilliseconds: 5000, requiresExpensiveBudget: true, operation: {
                await self.migrateLegacyShopPurchasesIfNeeded(context: context)
            }) else {
                return
            }

            guard await runStep("avatar_asset_compaction", delayMilliseconds: 90000, requiresExpensiveBudget: true, operation: {
                await self.compactAvatarAssetsIfNeeded(context: context)
            }) else {
                return
            }
    }

    func cancel() {
        maintenanceTask?.cancel()
        maintenanceTask = nil
    }

    private func runStep(
        _ name: String,
        delayMilliseconds: UInt64,
        requiresExpensiveBudget: Bool = false,
        operation: @escaping @MainActor () async -> Void
    ) async -> Bool {
        if let resumeFromMaintenanceStep,
           resumeFromMaintenanceStep != name {
            return true
        }
        if resumeFromMaintenanceStep == name {
            resumeFromMaintenanceStep = nil
        }
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
        guard !Task.isCancelled else {
            recordMaintenanceCursor(name)
            recordCancelled(name)
            return false
        }

        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_\(name)",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity,
              !requiresExpensiveBudget || budget.allowsExpensiveWork
        else {
            recordMaintenanceCursor(name)
            AppPerformanceMonitor.shared.record(
                "startup_maintenance_deferred",
                valueMS: 0,
                note: "\(name), low-cost continuation on next eligible launch"
            )
            return false
        }

        let startedAt = CFAbsoluteTimeGetCurrent()
        AppPerformanceMonitor.shared.record(
            "startup_maintenance_started",
            valueMS: 0,
            note: name
        )
        await operation()

        guard !Task.isCancelled else {
            recordMaintenanceCursor(name)
            recordCancelled(name)
            return false
        }
        clearMaintenanceCursor(ifMatching: name)
        AppPerformanceMonitor.shared.record(
            "startup_maintenance_completed",
            startedAt: startedAt,
            note: name
        )
        return true
    }

    private var shouldRunReminderMaintenance: Bool {
        let twelveHours: TimeInterval = 12 * 60 * 60
        let lastRun = defaults.double(forKey: Keys.reminderMaintenanceLastRunAt)
        return Date().timeIntervalSince1970 - lastRun >= twelveHours
    }

    private var shouldRunPlantCareOrphanMaintenance: Bool {
        let oneDay: TimeInterval = 24 * 60 * 60
        let lastRun = defaults.double(forKey: Keys.plantCareOrphanMaintenanceLastRunAt)
        return Date().timeIntervalSince1970 - lastRun >= oneDay
    }

    private func runReminderMaintenanceIfNeeded(context: ModelContext) async -> ReminderMaintenanceRunResult {
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_reminder_refill",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity else {
            return ReminderMaintenanceRunResult(pendingCount: 0, completed: false, hasMoreWork: true)
        }
        do {
            let plan = try await ReminderMaintenanceService.makeBackgroundPlan(
                context: context,
                budget: budget,
                futureOffset: ReminderMaintenanceCursorStore.futureOffset(defaults: defaults)
            )
            guard !Task.isCancelled else {
                return ReminderMaintenanceRunResult(
                    pendingCount: plan.reminderModelIDs.count,
                    completed: false,
                    hasMoreWork: plan.hasMoreWork
                )
            }
            let result = await ReminderMaintenanceService.run(plan: plan, context: context)
            ReminderMaintenanceCursorStore.record(result, plan: plan, defaults: defaults)
            return result
        } catch is CancellationError {
            return ReminderMaintenanceRunResult(pendingCount: 0, completed: false, hasMoreWork: true)
        } catch {
            #if DEBUG
                OhanaLog.error("Startup reminder maintenance plan failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
            return ReminderMaintenanceRunResult(pendingCount: 0, completed: false, hasMoreWork: true)
        }
    }

    private func runCareLedgerBackfillIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: Keys.careLedgerBackfillCompleted) else { return }
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_care_ledger_backfill",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity, budget.allowsExpensiveWork else { return }
        do {
            let actor = CareLedgerBackfillActor(modelContainer: context.container)
            let result = try await actor.runBatch(
                cursor: CareLedgerBackfillCursorStore.cursor(defaults: defaults),
                maximumSourceRecordCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds)
            )
            guard !Task.isCancelled else { return }
            if result.didComplete {
                defaults.set(true, forKey: Keys.careLedgerBackfillCompleted)
                CareLedgerBackfillCursorStore.clear(defaults: defaults)
            } else {
                CareLedgerBackfillCursorStore.store(result.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_care_ledger_backfill_continuation",
                    valueMS: 0,
                    note: "processed=\(result.processedSourceRecordCount), source=\(result.nextCursor.sourceIndex), offset=\(result.nextCursor.sourceOffset)"
                )
            }
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("CareLedger backfill failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func materializeAutoFeederLogsIfNeeded(context: ModelContext) async {
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_auto_feeder_materialization",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity else { return }

        let actor = StartupAutoFeederMaintenanceActor(modelContainer: context.container)
        do {
            let result = try await actor.runBatch(
                cursor: StartupAutoFeederCursorStore.cursor(defaults: defaults),
                maximumPetCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds),
                now: Date(),
                calendar: .current
            )
            guard !Task.isCancelled else { return }
            if result.didComplete {
                StartupAutoFeederCursorStore.clear(defaults: defaults)
            } else {
                StartupAutoFeederCursorStore.store(result.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_auto_feeder_materialization_continuation",
                    valueMS: 0,
                    note: "pets=\(result.processedPetCount), offset=\(result.nextCursor.petOffset)"
                )
            }
            guard result.insertedLogCount > 0 else { return }
            AppPerformanceMonitor.shared.record(
                "startup_auto_feeder_materialized",
                valueMS: 0,
                note: "\(result.insertedLogCount) logs"
            )
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("Startup auto-feeder materialization failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func normalizeMemberThemeColorsIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: Keys.memberThemeColorNormalizationCompleted) else { return }
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_member_theme_normalization",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity, budget.allowsExpensiveWork else { return }

        let actor = MemberThemeColorMaintenanceActor(modelContainer: context.container)
        do {
            let result = try await actor.runBatch(
                cursor: MemberThemeColorNormalizationCursorStore.cursor(defaults: defaults),
                maximumRecordCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds)
            )
            guard !Task.isCancelled else { return }
            if result.didComplete {
                defaults.set(true, forKey: Keys.memberThemeColorNormalizationCompleted)
                MemberThemeColorNormalizationCursorStore.clear(defaults: defaults)
            } else {
                MemberThemeColorNormalizationCursorStore.store(result.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_member_theme_normalization_continuation",
                    valueMS: 0,
                    note: "scanned=\(result.scannedRecordCount), source=\(result.nextCursor.source.rawValue), offset=\(result.nextCursor.offset)"
                )
            }
            guard result.normalizedRecordCount > 0 else { return }
            AppPerformanceMonitor.shared.record(
                "startup_member_theme_normalization",
                valueMS: 0,
                note: "\(result.normalizedRecordCount) members"
            )
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("Member theme normalization failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func backfillMediaAttachmentPresenceIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: Keys.mediaAttachmentPresenceBackfillCompleted) else { return }
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_media_attachment_presence_backfill",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity, budget.allowsExpensiveWork else { return }
        let actor = MediaAttachmentPresenceBackfillActor(modelContainer: context.container)
        do {
            let batch = try await actor.runBatch(
                cursor: MediaAttachmentPresenceBackfillCursorStore.cursor(defaults: defaults),
                maximumRecordCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds)
            )
            guard !Task.isCancelled else { return }
            if batch.didComplete {
                defaults.set(true, forKey: Keys.mediaAttachmentPresenceBackfillCompleted)
                MediaAttachmentPresenceBackfillCursorStore.clear(defaults: defaults)
            } else {
                MediaAttachmentPresenceBackfillCursorStore.store(batch.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_media_attachment_presence_backfill_continuation",
                    valueMS: 0,
                    note: "scanned=\(batch.scannedRecordCount), source=\(batch.nextCursor.source.rawValue), \(batch.backfillResult.performanceNote)"
                )
            }
            AppPerformanceMonitor.shared.record(
                "startup_media_attachment_presence_backfill",
                valueMS: 0,
                note: batch.backfillResult.performanceNote
            )
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("Media attachment presence backfill failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func cleanLegacySharedCareNotesIfNeeded(context: ModelContext) async {
        guard defaults.integer(forKey: SharedCareLegacyNoteMaintenanceService.completedVersionKey) < SharedCareLegacyNoteMaintenanceService.currentVersion else {
            return
        }
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_shared_care_note_cleanup",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity, budget.allowsExpensiveWork else { return }

        let actor = SharedCareLegacyNoteMaintenanceActor(modelContainer: context.container)
        do {
            let result = try await actor.runBatch(
                cursor: SharedCareLegacyNoteCleanupCursorStore.cursor(defaults: defaults),
                maximumRecordCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds),
                cleanedAt: Date()
            )
            guard !Task.isCancelled else { return }
            if result.didComplete {
                defaults.set(SharedCareLegacyNoteMaintenanceService.currentVersion, forKey: SharedCareLegacyNoteMaintenanceService.completedVersionKey)
                SharedCareLegacyNoteCleanupCursorStore.clear(defaults: defaults)
            } else {
                SharedCareLegacyNoteCleanupCursorStore.store(result.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_shared_care_note_cleanup_continuation",
                    valueMS: 0,
                    note: "scanned=\(result.scannedRecordCount), source=\(result.nextCursor.source.rawValue), offset=\(result.nextCursor.offset)"
                )
            }
            AppPerformanceMonitor.shared.record(
                "startup_shared_care_note_cleanup",
                valueMS: 0,
                note: "\(result.cleanedRecordCount) cleaned, \(result.skippedOrphanCount) skipped"
            )
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("Shared-care legacy cleanup failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func migrateLegacyShopPurchasesIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: ShopPurchaseRecordStore.legacyMigrationDefaultsKey) else { return }
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_shop_purchase_defaults_migration",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity, budget.allowsExpensiveWork else { return }

        let itemIDs = ShopPurchaseRecordStore
            .legacyPurchasedItemIDs(raw: defaults.string(forKey: ShopPurchaseRecordStore.legacyDefaultsKey) ?? "")
            .filter { itemID in
                guard let item = ShopCatalog.item(id: itemID) else { return false }
                return !item.isConsumable && item.id != AppIconCatalog.defaultItemId
            }
        let actor = StartupShopPurchaseMigrationActor(modelContainer: context.container)
        do {
            let result = try await actor.runBatch(
                eligibleItemIDs: itemIDs,
                cursor: StartupShopPurchaseMigrationCursorStore.cursor(defaults: defaults),
                maximumItemCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds),
                now: Date()
            )
            guard !Task.isCancelled else { return }
            if result.didComplete {
                defaults.set(true, forKey: ShopPurchaseRecordStore.legacyMigrationDefaultsKey)
                StartupShopPurchaseMigrationCursorStore.clear(defaults: defaults)
            } else {
                StartupShopPurchaseMigrationCursorStore.store(result.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_shop_purchase_defaults_migration_continuation",
                    valueMS: 0,
                    note: "processed=\(result.processedItemCount), offset=\(result.nextCursor.itemOffset)"
                )
            }
            AppPerformanceMonitor.shared.record(
                "startup_shop_purchase_defaults_migration",
                valueMS: 0,
                note: "\(result.insertedRecordCount) records"
            )
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("Shop purchase defaults migration failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func compactAvatarAssetsIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: Keys.avatarAssetCompactionCompleted) else { return }
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "startup_avatar_asset_compaction",
            requestedItemCount: 64
        )
        guard budget.hasWorkCapacity, budget.allowsExpensiveWork else { return }
        let actor = AvatarAssetMaintenanceActor(modelContainer: context.container)
        do {
            let result = try await actor.runBatch(
                cursor: AvatarAssetCompactionCursorStore.cursor(defaults: defaults),
                maximumRecordCount: budget.maximumItemCount,
                deadline: Date().addingTimeInterval(budget.maximumWallClockSeconds)
            )
            guard !Task.isCancelled else { return }
            if result.didComplete {
                defaults.set(true, forKey: Keys.avatarAssetCompactionCompleted)
                AvatarAssetCompactionCursorStore.clear(defaults: defaults)
            } else {
                AvatarAssetCompactionCursorStore.store(result.nextCursor, defaults: defaults)
                AppPerformanceMonitor.shared.record(
                    "startup_avatar_asset_compaction_continuation",
                    valueMS: 0,
                    note: "scanned=\(result.scannedRecordCount), compacted=\(result.compactedRecordCount), source=\(result.nextCursor.source.rawValue), offset=\(result.nextCursor.offset)"
                )
            }
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
                OhanaLog.error("Avatar asset compaction failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func recordCancelled(_ name: String) {
        AppPerformanceMonitor.shared.record(
            "startup_maintenance_cancelled",
            valueMS: 0,
            note: name
        )
    }

    /// One durable cursor tells the next eligible launch which deferred
    /// maintenance step still needs a bounded retry. Individual services retain
    /// their own completion markers; this cursor never stores model data.
    private func recordMaintenanceCursor(_ name: String) {
        defaults.set(name, forKey: Keys.maintenanceCursor)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.maintenanceCursorUpdatedAt)
    }

    private func clearMaintenanceCursor(ifMatching name: String) {
        guard defaults.string(forKey: Keys.maintenanceCursor) == name else { return }
        defaults.removeObject(forKey: Keys.maintenanceCursor)
        defaults.removeObject(forKey: Keys.maintenanceCursorUpdatedAt)
    }

    private enum Keys {
        static let reminderMaintenanceLastRunAt = "ohana_startup_maintenance_last_run_at"
        static let plantCareOrphanMaintenanceLastRunAt = "ohana_plant_care_orphan_maintenance_last_run_at"
        static let avatarAssetCompactionCompleted = "ohana_avatar_asset_compaction_v1_completed"
        static let careLedgerBackfillCompleted = "careLedgerBackfill_v2_completed"
        static let mediaAttachmentPresenceBackfillCompleted = "ohana_media_attachment_presence_backfill_v1_completed"
        static let memberThemeColorNormalizationCompleted = "ohana_member_theme_color_normalization_v1_completed"
        static let maintenanceCursor = "ohana_startup_maintenance_cursor"
        static let maintenanceCursorUpdatedAt = "ohana_startup_maintenance_cursor_updated_at"
    }
}

private enum CareLedgerBackfillCursorStore {
    private static let key = "ohana_care_ledger_backfill_cursor_v3"

    static func cursor(defaults: UserDefaults) -> CareLedgerBackfillCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(CareLedgerBackfillCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: CareLedgerBackfillCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

private enum AvatarAssetCompactionCursorStore {
    private static let key = "ohana_avatar_asset_compaction_cursor_v2"

    static func cursor(defaults: UserDefaults) -> AvatarAssetCompactionCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(AvatarAssetCompactionCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: AvatarAssetCompactionCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

private enum MediaAttachmentPresenceBackfillCursorStore {
    private static let key = "ohana_media_attachment_presence_backfill_cursor_v2"

    static func cursor(defaults: UserDefaults) -> MediaAttachmentPresenceBackfillCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(MediaAttachmentPresenceBackfillCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: MediaAttachmentPresenceBackfillCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

private enum MemberThemeColorNormalizationCursorStore {
    private static let key = "ohana_member_theme_color_normalization_cursor_v1"

    static func cursor(defaults: UserDefaults) -> MemberThemeColorNormalizationCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(MemberThemeColorNormalizationCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: MemberThemeColorNormalizationCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

private enum StartupAutoFeederCursorStore {
    private static let key = "ohana_startup_auto_feeder_cursor_v1"

    static func cursor(defaults: UserDefaults) -> StartupAutoFeederCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(StartupAutoFeederCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: StartupAutoFeederCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

private enum SharedCareLegacyNoteCleanupCursorStore {
    private static let key = "ohana_shared_care_legacy_note_cleanup_cursor_v1"

    static func cursor(defaults: UserDefaults) -> SharedCareLegacyNoteCleanupCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(SharedCareLegacyNoteCleanupCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: SharedCareLegacyNoteCleanupCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

private enum StartupShopPurchaseMigrationCursorStore {
    private static let key = "ohana_startup_shop_purchase_migration_cursor_v1"

    static func cursor(defaults: UserDefaults) -> StartupShopPurchaseMigrationCursor {
        guard let data = defaults.data(forKey: key),
              let cursor = try? JSONDecoder().decode(StartupShopPurchaseMigrationCursor.self, from: data)
        else {
            return .initial
        }
        return cursor
    }

    static func store(_ cursor: StartupShopPurchaseMigrationCursor, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

@MainActor
private enum InputLatencyWarmupService {
    private static var didWarmUp = false

    static func warmUpOnce() {
        guard !didWarmUp else { return }
        didWarmUp = true

        let startedAt = CFAbsoluteTimeGetCurrent()
        #if targetEnvironment(simulator)
            AppPerformanceMonitor.shared.record(
                "输入反馈预热",
                startedAt: startedAt,
                note: "simulator skipped"
            )
        #else
            OhanaFeedback.prepareInteraction()
            warmUpTextInputSystem(startedAt: startedAt)
        #endif
    }

    #if os(iOS)
        private static func warmUpTextInputSystem(startedAt: CFAbsoluteTime) {
            guard UIApplication.shared.applicationState == .active,
                  currentFirstResponder() == nil,
                  let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive }),
                  let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            else {
                recordWarmup(startedAt: startedAt, note: "text input skipped")
                return
            }

            let textField = UITextField(frame: CGRect(x: -240, y: -240, width: 1, height: 1)) // ui-v4: allow offscreen startup text-input warmup field; never user-visible or interactive.
            textField.alpha = 0.01
            textField.tintColor = .clear
            textField.textColor = .clear
            textField.backgroundColor = .clear
            textField.keyboardType = .default
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.smartDashesType = .no
            textField.smartQuotesType = .no
            textField.isAccessibilityElement = false
            textField.accessibilityElementsHidden = true
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
            window.addSubview(textField)

            var didBecomeFirstResponder = false
            UIView.performWithoutAnimation {
                didBecomeFirstResponder = textField.becomeFirstResponder()
            }
            guard didBecomeFirstResponder else {
                textField.removeFromSuperview()
                recordWarmup(startedAt: startedAt, note: "first responder unavailable")
                return
            }

            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    textField.resignFirstResponder()
                    textField.removeFromSuperview()
                }
                recordWarmup(startedAt: startedAt, note: "text input warm")
            }
        }

        private static func currentFirstResponder() -> UIResponder? {
            let box = InputWarmupResponderBox()
            UIApplication.shared.sendAction(
                #selector(UIResponder.ohanaCaptureInputWarmupFirstResponder(_:)),
                to: nil,
                from: box,
                for: nil
            )
            return box.responder
        }
    #else
        private static func warmUpTextInputSystem(startedAt: CFAbsoluteTime) {
            AppPerformanceMonitor.shared.record(
                "输入反馈预热",
                startedAt: startedAt,
                note: "text input unavailable"
            )
        }
    #endif

    private static func recordWarmup(startedAt: CFAbsoluteTime, note: String) {
        AppPerformanceMonitor.shared.record(
            "输入反馈预热",
            startedAt: startedAt,
            note: note
        )
    }
}

#if os(iOS)
    private final class InputWarmupResponderBox {
        weak var responder: UIResponder?
    }

    private extension UIResponder {
        @objc func ohanaCaptureInputWarmupFirstResponder(_ sender: Any) {
            (sender as? InputWarmupResponderBox)?.responder = self
        }
    }
#endif
