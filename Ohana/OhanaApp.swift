//
//  OhanaApp.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct OhanaApp: App {
    let container: ModelContainer
    private static let bgTaskID = "com.guanchen.li.Ark.reminderRefill"
    @AppStorage("appThemePreference") private var appThemePreference: String = "system"

    init() {
        self.container = SharedModelContainer.make()
        OhanaApp.registerBGTasks()
        // TODO: 测试完毕后移除
        UserDefaults.standard.set(10000, forKey: "coconutCount")
        // 强制同步到 QuestManager（解决初始化顺序问题）
        DispatchQueue.main.async {
            QuestManager.shared.coconutCount = 10000
            QuestManager.shared.flushToDefaults()
        }
    }
    
    private var preferredScheme: ColorScheme? {
        switch appThemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil  // system
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tint(Color.arkCoral)
                .preferredColorScheme(preferredScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    OhanaApp.scheduleReminderRefill()
                }
        }
    }

    // MARK: - BGTask Registration
    private static func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            handleReminderRefill(task: refreshTask)
        }
    }

    static func scheduleReminderRefill() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6) // 6 小时后
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleReminderRefill(task: BGAppRefreshTask) {
        scheduleReminderRefill() // 立即再排队下次

        let modelContext = ModelContext(SharedModelContainer.make())
        let reminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
        NotificationManager.shared.refillWindowIfNeeded(allReminders: reminders)
        NotificationManager.shared.compensate(reminders: reminders)
        try? modelContext.save()
        task.setTaskCompleted(success: true)
    }
}
