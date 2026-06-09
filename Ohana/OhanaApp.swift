//
//  OhanaApp.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation
import Combine
import UIKit

let ohanaProcessStartTime = CFAbsoluteTimeGetCurrent()

@main
struct OhanaApp: App {
    private let modelContainer: ModelContainer
    private let appServices: AppServices
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @AppStorage(AppCountry.storageKey) private var appCountry: String = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem: String = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency: String = AppCurrency.fallbackCode

    init() {
        let initStartedAt = CFAbsoluteTimeGetCurrent()
        AppCountry.ensureInitialized()
        BackgroundTaskCoordinator.registerTasks()
        _ = NotificationManager.shared
        let containerStartedAt = CFAbsoluteTimeGetCurrent()
        modelContainer = SharedModelContainer.make()
        appServices = AppServices()
        let initDurationMS = (CFAbsoluteTimeGetCurrent() - initStartedAt) * 1_000
        let containerDurationMS = (CFAbsoluteTimeGetCurrent() - containerStartedAt) * 1_000
        Task { @MainActor in
            AppPerformanceMonitor.shared.record("SwiftData container ready", valueMS: containerDurationMS, note: "Eager before RootView")
            AppPerformanceMonitor.shared.record("App init", valueMS: initDurationMS, note: "BGTask + eager container")
            AppPerformanceMonitor.shared.record("进程到 App init 完成", startedAt: ohanaProcessStartTime)
            MetricKitObserver.shared.start()
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
                .modelContainer(modelContainer)
                .environment(appServices)
            .tint(Color.goPrimary)
            .preferredColorScheme(preferredScheme)
            .environment(\.locale, AppLanguage.swiftUIPreferredLocale)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: appCountry) { _, _ in }
            .onChange(of: appCurrency) { _, _ in }
            .onChange(of: appMeasurementSystem) { _, _ in }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                AppLifecycleCoordinator.shared.handle(.didEnterBackground)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                AppLifecycleCoordinator.shared.handle(.willResignActive)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                AppLifecycleCoordinator.shared.handle(.didBecomeActive)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                AppLifecycleCoordinator.shared.handle(.willTerminate)
            }
        }
    }
}
