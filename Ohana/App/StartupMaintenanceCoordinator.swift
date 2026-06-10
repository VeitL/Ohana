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
import UIKit

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

            await runStep("care_ledger_backfill", delayMilliseconds: 45000) {
                await self.runCareLedgerBackfillIfNeeded(context: context)
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
        static let avatarAssetCompactionCompleted = "ohana_avatar_asset_compaction_v1_completed"
        static let careLedgerBackfillCompleted = "careLedgerBackfill_v1_completed"
    }
}

@MainActor
private enum InputLatencyWarmupService {
    private static var didWarmUp = false

    static func warmUpOnce() {
        guard !didWarmUp else { return }
        didWarmUp = true

        let startedAt = CFAbsoluteTimeGetCurrent()
        OhanaFeedback.prepareInteraction()
        warmUpTextInputSystem(startedAt: startedAt)
    }

    private static func warmUpTextInputSystem(startedAt: CFAbsoluteTime) {
        guard UIApplication.shared.applicationState == .active,
              currentFirstResponder() == nil,
              let scene = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene })
              .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            AppPerformanceMonitor.shared.record(
                "输入反馈预热",
                startedAt: startedAt,
                note: "text input skipped"
            )
            return
        }

        let textField = UITextField(frame: CGRect(x: -240, y: -240, width: 1, height: 1)) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
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

        guard textField.becomeFirstResponder() else {
            textField.removeFromSuperview()
            AppPerformanceMonitor.shared.record(
                "输入反馈预热",
                startedAt: startedAt,
                note: "first responder unavailable"
            )
            return
        }

        DispatchQueue.main.async {
            textField.resignFirstResponder()
            textField.removeFromSuperview()
            AppPerformanceMonitor.shared.record(
                "输入反馈预热",
                startedAt: startedAt,
                note: "text input warm"
            )
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
}

private final class InputWarmupResponderBox {
    weak var responder: UIResponder?
}

private extension UIResponder {
    @objc func ohanaCaptureInputWarmupFirstResponder(_ sender: Any) {
        (sender as? InputWarmupResponderBox)?.responder = self
    }
}
