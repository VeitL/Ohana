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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func startAfterFirstRender(context: ModelContext) {
        guard !didStart else { return }
        didStart = true

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

            await runStep("input_warmup", delayMilliseconds: 700) {
                InputLatencyWarmupService.warmUpOnce()
            }

            await runStep("media_attachment_presence_backfill", delayMilliseconds: 2500) {
                self.backfillMediaAttachmentPresenceIfNeeded(context: context)
            }

            await runStep("member_theme_and_auto_feeder", delayMilliseconds: 16000) {
                MemberThemeColorMaintenanceService.normalizeReservedColors(context: context)
                FamilyWeeklyReportService().scheduleWeeklyReminder()
                self.materializeAutoFeederLogsIfNeeded(context: context)
            }

            await runStep("reminder_refill", delayMilliseconds: 25000) {
                guard self.shouldRunReminderMaintenance else { return }
                let result = await ReminderMaintenanceService.runPendingReminderMaintenance(context: context)
                if result.completed {
                    self.defaults.set(Date().timeIntervalSince1970, forKey: Keys.reminderMaintenanceLastRunAt)
                }
            }

            await runStep("plant_care_orphan_maintenance", delayMilliseconds: 30000) {
                guard self.shouldRunPlantCareOrphanMaintenance else { return }
                let result = PlantCareOrphanMaintenanceService.run(context: context, defaults: self.defaults)
                if result.didPersist {
                    self.defaults.set(Date().timeIntervalSince1970, forKey: Keys.plantCareOrphanMaintenanceLastRunAt)
                }
                guard result.removedEventCount > 0 || result.cleanedPreferencePlantCount > 0 else { return }
                AppPerformanceMonitor.shared.record(
                    "startup_plant_care_orphan_maintenance",
                    valueMS: 0,
                    note: "\(result.removedEventCount) events, \(result.removedReminderCount) reminders, \(result.cleanedPreferencePlantCount) pref scopes"
                )
            }

            await runStep("care_ledger_backfill", delayMilliseconds: 45000) {
                await self.runCareLedgerBackfillIfNeeded(context: context)
            }

            await runStep("shared_care_note_cleanup", delayMilliseconds: 5000) {
                self.cleanLegacySharedCareNotesIfNeeded(context: context)
            }

            await runStep("shop_purchase_defaults_migration", delayMilliseconds: 5000) {
                self.migrateLegacyShopPurchasesIfNeeded(context: context)
            }

            await runStep("avatar_asset_compaction", delayMilliseconds: 90000) {
                await self.compactAvatarAssetsIfNeeded(context: context)
            }

            maintenanceTask = nil
        }
    }

    func cancel() {
        maintenanceTask?.cancel()
        maintenanceTask = nil
    }

    private func runStep(
        _ name: String,
        delayMilliseconds: UInt64,
        operation: @escaping @MainActor () async -> Void
    ) async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
        guard !Task.isCancelled else {
            recordCancelled(name)
            return
        }

        let startedAt = CFAbsoluteTimeGetCurrent()
        AppPerformanceMonitor.shared.record(
            "startup_maintenance_started",
            valueMS: 0,
            note: name
        )
        await operation()

        guard !Task.isCancelled else {
            recordCancelled(name)
            return
        }
        AppPerformanceMonitor.shared.record(
            "startup_maintenance_completed",
            startedAt: startedAt,
            note: name
        )
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

    private func runCareLedgerBackfillIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: Keys.careLedgerBackfillCompleted) else { return }
        do {
            // Run the unbounded full-table backfill on a background SwiftData
            // context so it never blocks the main thread.
            let actor = CareLedgerBackfillActor(modelContainer: context.container)
            try await actor.run()
            defaults.set(true, forKey: Keys.careLedgerBackfillCompleted)
        } catch {
            #if DEBUG
                OhanaLog.error("CareLedger backfill failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func materializeAutoFeederLogsIfNeeded(context: ModelContext) {
        let inserted = StartupFeedAutoLogMaintenanceService.materializeDueAutoFeederLogs(context: context)
        if inserted > 0 {
            AppPerformanceMonitor.shared.record(
                "startup_auto_feeder_materialized",
                valueMS: 0,
                note: "\(inserted) logs"
            )
        }
    }

    private func backfillMediaAttachmentPresenceIfNeeded(context: ModelContext) {
        guard !defaults.bool(forKey: Keys.mediaAttachmentPresenceBackfillCompleted) else { return }
        let result = MediaAttachmentPresenceBackfillService.run(context: context)
        defaults.set(true, forKey: Keys.mediaAttachmentPresenceBackfillCompleted)
        AppPerformanceMonitor.shared.record(
            "startup_media_attachment_presence_backfill",
            valueMS: 0,
            note: result.performanceNote
        )
    }

    private func cleanLegacySharedCareNotesIfNeeded(context: ModelContext) {
        let result = SharedCareLegacyNoteMaintenanceService.runIfNeeded(
            context: context,
            defaults: defaults
        )
        guard result.didRun else { return }
        AppPerformanceMonitor.shared.record(
            "startup_shared_care_note_cleanup",
            valueMS: 0,
            note: "\(result.cleanup.cleanedCount) cleaned, \(result.cleanup.skippedOrphanCount) skipped"
        )
    }

    private func migrateLegacyShopPurchasesIfNeeded(context: ModelContext) {
        do {
            let inserted = try ShopPurchaseRecordStore.migrateLegacyDefaultsIfNeeded(
                context: context,
                defaults: defaults
            )
            AppPerformanceMonitor.shared.record(
                "startup_shop_purchase_defaults_migration",
                valueMS: 0,
                note: "\(inserted) records"
            )
        } catch {
            context.rollback()
            #if DEBUG
                OhanaLog.error("Shop purchase defaults migration failed: \(error.localizedDescription)", category: "StartupMaintenance")
            #endif
        }
    }

    private func compactAvatarAssetsIfNeeded(context: ModelContext) async {
        guard !defaults.bool(forKey: Keys.avatarAssetCompactionCompleted) else { return }
        await AvatarAssetMaintenanceService.compactStoredAvatars(context: context)
        defaults.set(true, forKey: Keys.avatarAssetCompactionCompleted)
    }

    private func recordCancelled(_ name: String) {
        AppPerformanceMonitor.shared.record(
            "startup_maintenance_cancelled",
            valueMS: 0,
            note: name
        )
    }

    private enum Keys {
        static let reminderMaintenanceLastRunAt = "ohana_startup_maintenance_last_run_at"
        static let plantCareOrphanMaintenanceLastRunAt = "ohana_plant_care_orphan_maintenance_last_run_at"
        static let avatarAssetCompactionCompleted = "ohana_avatar_asset_compaction_v1_completed"
        static let careLedgerBackfillCompleted = "careLedgerBackfill_v1_completed"
        static let mediaAttachmentPresenceBackfillCompleted = "ohana_media_attachment_presence_backfill_v1_completed"
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
