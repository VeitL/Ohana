//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = UserDefaults.standard.bool(forKey: "ohana_db_fallback_active")
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if hasOnboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            // 任务二：App 启动时补充 14 天内的通知窗口
            Task { @MainActor in
                let allReminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
                await ReminderSchedulingService.refillMissingPendingNotifications(reminders: allReminders, context: modelContext)
                ReminderSchedulingService.compensate(reminders: allReminders, context: modelContext)
                if !UserDefaults.standard.bool(forKey: "careLedgerBackfill_v1_completed") {
                    do {
                        try CareLedgerBackfillService.backfill(context: modelContext)
                        UserDefaults.standard.set(true, forKey: "careLedgerBackfill_v1_completed")
                    } catch {
                        #if DEBUG
                        print("⚠️ CareLedger backfill failed: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OhanaReminderAction"))) { notification in
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
            ReminderCompletionService.complete(reminder, by: currentActiveHumanId, context: modelContext)
        case "SKIP":
            ReminderCompletionService.skip(reminder, by: currentActiveHumanId, context: modelContext)
        case "SNOOZE":
            ReminderCompletionService.snoozeOneDay(reminder, by: currentActiveHumanId, context: modelContext)
        default:
            return
        }
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

#Preview {
    RootView()
        .modelContainer(SharedModelContainer.make())
}
