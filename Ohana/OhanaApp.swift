//
//  OhanaApp.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import Foundation

let ohanaProcessStartTime = CFAbsoluteTimeGetCurrent()

@main
struct OhanaApp: App {
    let container: ModelContainer
    private static let bgTaskID = "com.guanchen.li.Ark.reminderRefill"
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @AppStorage("appLanguage") private var appLanguage: String = "zh"
    @AppStorage(AppCountry.storageKey) private var appCountry: String = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem: String = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency: String = AppCurrency.fallbackCode

    init() {
        let initStartedAt = CFAbsoluteTimeGetCurrent()
        AppCountry.ensureInitialized()
        self.container = SharedModelContainer.make()
        OhanaApp.registerBGTasks()
        let initDurationMS = (CFAbsoluteTimeGetCurrent() - initStartedAt) * 1_000
        Task { @MainActor in
            AppPerformanceMonitor.shared.record("App init", valueMS: initDurationMS, note: "ModelContainer + BGTask")
            AppPerformanceMonitor.shared.record("进程到 App init 完成", startedAt: ohanaProcessStartTime)
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
                .tint(Color.goPrimary)
                .preferredColorScheme(preferredScheme)
                .environment(\.locale, AppLanguage.swiftUIPreferredLocale)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onChange(of: appCountry) { _, _ in }
                .onChange(of: appCurrency) { _, _ in }
                .onChange(of: appMeasurementSystem) { _, _ in }
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

        // 与 `OhanaApp` 主容器共用单例，避免再 new 一个 ModelContainer 争用 SQLite
        Task { @MainActor in
            let modelContext = ModelContext(SharedModelContainer.make())
            let reminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
            await ReminderSchedulingService.refillMissingPendingNotifications(reminders: reminders, context: modelContext)
            ReminderSchedulingService.compensate(reminders: reminders, context: modelContext)
            try? modelContext.save()
            task.setTaskCompleted(success: true)
        }
    }
}
