//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage("ohana_startup_maintenance_last_run_at") private var startupMaintenanceLastRunAt: Double = 0
    @AppStorage("ohana_avatar_asset_compaction_v1_completed") private var avatarAssetCompactionCompleted = false
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = UserDefaults.standard.bool(forKey: "ohana_db_fallback_active")
    @State private var didQueueStartupMaintenance = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if hasOnboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .toggleStyle(OhanaPillToggleStyle())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            queueStartupMaintenance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReminderAction)) { notification in
            handleReminderAction(notification.userInfo)
        }
        .alert("数据异常", isPresented: $showDBFallbackAlert) {
            Button("我知道了", role: .cancel) {
                UserDefaults.standard.removeObject(forKey: "ohana_db_fallback_active")
            }
        } message: {
            Text("数据库加载失败，当前为临时模式。本次会话的数据不会被保存。请尝试重启 App，如问题持续请联系开发者。")
        }
    }

    private func handleReminderAction(_ userInfo: [AnyHashable: Any]?) {
        guard let action = userInfo?["action"] as? String,
              let reminder = reminder(from: userInfo) else { return }

        switch action {
        case "COMPLETE":
            completeReminder(reminder)
        case "SKIP":
            ReminderCompletionService.skip(reminder, by: currentActiveHumanId, context: modelContext)
        case "SNOOZE":
            ReminderCompletionService.snoozeOneDay(reminder, by: currentActiveHumanId, context: modelContext)
        default:
            return
        }
    }

    private func completeReminder(_ reminder: Reminder) {
        if let event = reminder.event,
           event.feedRuleKindRaw == FeedRuleKind.manualReminder.rawValue,
           let pet = pet(for: event) {
            _ = CareEventService.completePlannedFeed(
                pet: pet,
                reminder: reminder,
                context: modelContext,
                executorId: currentActiveHumanId.isEmpty ? nil : currentActiveHumanId
            )
            return
        }
        ReminderCompletionService.complete(reminder, by: currentActiveHumanId, context: modelContext)
    }

    private func pet(for event: Event) -> Pet? {
        guard let id = UUID(uuidString: event.relatedEntityId) else { return nil }
        let descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func queueStartupMaintenance() {
        guard !didQueueStartupMaintenance else { return }
        didQueueStartupMaintenance = true

        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 700)
            guard !Task.isCancelled else { return }
            InputLatencyWarmupService.warmUpOnce()

            try? await Task.sleep(nanoseconds: 16_000_000_000)
            guard !Task.isCancelled else { return }
            MemberThemeColorMaintenanceService.normalizeReservedColors(context: modelContext)
            FamilyWeeklyReportService.shared.scheduleWeeklyReminder()
            materializeAutoFeederLogsIfNeeded()

            try? await Task.sleep(nanoseconds: 25_000_000_000)
            guard !Task.isCancelled else { return }
            if shouldRunStartupReminderMaintenance() {
                let allReminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
                await ReminderSchedulingService.refillMissingPendingNotifications(reminders: allReminders, context: modelContext)
                ReminderSchedulingService.compensate(reminders: allReminders, context: modelContext)
                startupMaintenanceLastRunAt = Date().timeIntervalSince1970
            }

            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard !Task.isCancelled else { return }
            runCareLedgerBackfillIfNeeded()

            try? await Task.sleep(nanoseconds: 90_000_000_000)
            guard !Task.isCancelled else { return }
            await compactAvatarAssetsIfNeeded()
        }
    }

    private func shouldRunStartupReminderMaintenance() -> Bool {
        let twelveHours: TimeInterval = 12 * 60 * 60
        return Date().timeIntervalSince1970 - startupMaintenanceLastRunAt >= twelveHours
    }

    private func runCareLedgerBackfillIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "careLedgerBackfill_v1_completed") else { return }
        do {
            try CareLedgerBackfillService.backfill(context: modelContext)
            UserDefaults.standard.set(true, forKey: "careLedgerBackfill_v1_completed")
        } catch {
            #if DEBUG
            print("⚠️ CareLedger backfill failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func materializeAutoFeederLogsIfNeeded() {
        let events = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
        guard events.contains(where: { $0.relatedEntityType == FeedRuleMetadata.autoFeederEntityType }) else { return }
        let pets = (try? modelContext.fetch(FetchDescriptor<Pet>())) ?? []
        var inserted = 0
        for pet in pets {
            inserted += FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: events, context: modelContext)
        }
        #if DEBUG
        if inserted > 0 {
            print("✅ Auto feeder materialized \(inserted) due feed log(s)")
        }
        #endif
    }

    private func compactAvatarAssetsIfNeeded() async {
        guard !avatarAssetCompactionCompleted else { return }
        await AvatarAssetMaintenanceService.compactStoredAvatars(context: modelContext)
        avatarAssetCompactionCompleted = true
    }

    private func reminder(from userInfo: [AnyHashable: Any]?) -> Reminder? {
        let reminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
        if let reminderId = userInfo?["reminderId"] as? String,
           let reminder = reminders.first(where: { $0.id.uuidString == reminderId }) {
            return reminder
        }
        if let notificationId = userInfo?["notificationId"] as? String,
           let reminder = reminders.first(where: { $0.notificationId == notificationId }) {
            return reminder
        }
        if let createdAt = userInfo?["reminderCreatedAt"] as? TimeInterval {
            return reminders.first {
                abs($0.createdAt.timeIntervalSince1970 - createdAt) < 0.001
            }
        }
        return nil
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
            AppPerformanceMonitor.shared.record("输入反馈预热", startedAt: startedAt, note: "text input skipped")
            return
        }

        let textField = UITextField(frame: CGRect(x: -240, y: -240, width: 1, height: 1))
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
            AppPerformanceMonitor.shared.record("输入反馈预热", startedAt: startedAt, note: "first responder unavailable")
            return
        }

        DispatchQueue.main.async {
            textField.resignFirstResponder()
            textField.removeFromSuperview()
            AppPerformanceMonitor.shared.record("输入反馈预热", startedAt: startedAt, note: "text input warm")
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

#Preview {
    RootView()
        .modelContainer(SharedModelContainer.make())
}
