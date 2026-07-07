//
//  OhanaApp.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Combine
import Foundation
import SwiftData
import SwiftUI
import UIKit

let ohanaProcessStartTime = CFAbsoluteTimeGetCurrent()

@main
struct OhanaApp: App {
    @UIApplicationDelegateAdaptor(OhanaCloudSharingAppDelegate.self) private var cloudSharingAppDelegate

    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @AppStorage(AppCountry.storageKey) private var appCountry: String = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem: String = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency: String = AppCurrency.fallbackCode

    init() {
        AppCountry.ensureInitialized()
        BackgroundTaskCoordinator.registerTasks()
    }

    private var preferredScheme: ColorScheme? {
        switch appThemePreference {
        case "light": .light
        case "dark": .dark
        default: nil // system
        }
    }

    var body: some Scene {
        WindowGroup {
            OhanaBootstrapRootView(
                cloudSharingAppDelegate: cloudSharingAppDelegate,
                preferredScheme: preferredScheme,
                appLanguage: appLanguage
            )
            .onChange(of: appCountry) { _, _ in }
            .onChange(of: appCurrency) { _, _ in }
            .onChange(of: appMeasurementSystem) { _, _ in }
        }
    }
}

private struct OhanaBootstrapPayload {
    let modelContainer: ModelContainer
    let appServices: AppServices
}

private struct OhanaBootstrapRootView: View {
    let cloudSharingAppDelegate: OhanaCloudSharingAppDelegate
    let preferredScheme: ColorScheme?
    let appLanguage: String

    @State private var payload: OhanaBootstrapPayload?
    @State private var bootstrapStatus: OhanaBootstrapStatus = .preparing
    @State private var bootstrapTask: Task<Void, Never>?
    @State private var bootstrapWatchdogTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let payload {
                RootView(appLanguage: appLanguage)
                    .modelContainer(payload.modelContainer)
                    .environment(payload.appServices)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        payload.appServices.lifecycle.handle(.didEnterBackground)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        payload.appServices.lifecycle.handle(.willResignActive)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        payload.appServices.lifecycle.handle(.didBecomeActive)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                        payload.appServices.lifecycle.handle(.willTerminate)
                    }
            } else {
                OhanaBootstrapShell(
                    status: bootstrapStatus,
                    onRetry: retryBootstrap
                )
            }
        }
        .tint(Color.goPrimary)
        .preferredColorScheme(preferredScheme)
        .onAppear(perform: startBootstrapIfNeeded)
        .onDisappear {
            bootstrapTask?.cancel()
            bootstrapTask = nil
            bootstrapWatchdogTask?.cancel()
            bootstrapWatchdogTask = nil
        }
    }

    private func startBootstrapIfNeeded() {
        guard payload == nil, bootstrapTask == nil else { return }
        let initStartedAt = CFAbsoluteTimeGetCurrent()
        bootstrapStatus = .preparing
        OhanaStartupProbe.mark("bootstrap.appear")
        scheduleBootstrapWatchdog()
        bootstrapTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 96)
            guard !Task.isCancelled else { return }
            OhanaStartupProbe.mark("bootstrap.first-frame-yield-complete")
            let containerStartedAt = CFAbsoluteTimeGetCurrent()
            bootstrapStatus = .openingStore
            let modelContainer = await Self.openModelContainerOffMain()
            OhanaStartupProbe.mark("bootstrap.container-ready")
            resetPersistentStateForUITestsIfNeeded(modelContainer: modelContainer)
            bootstrapStatus = .buildingServices
            let services = AppServices(modelContainer: modelContainer)
            OhanaStartupProbe.mark("bootstrap.services-ready")
            cloudSharingAppDelegate.configure(modelContainer: modelContainer, cloudSync: services.cloudSync)
            let initDurationMS = (CFAbsoluteTimeGetCurrent() - initStartedAt) * 1000
            let containerDurationMS = (CFAbsoluteTimeGetCurrent() - containerStartedAt) * 1000
            AppPerformanceMonitor.shared.record("SwiftData container ready", valueMS: containerDurationMS, note: "Deferred after first shell")
            AppPerformanceMonitor.shared.record("App init", valueMS: initDurationMS, note: "BGTask + deferred container")
            AppPerformanceMonitor.shared.record("进程到 App init 完成", startedAt: ohanaProcessStartTime)
            services.metricKit.start()
            payload = OhanaBootstrapPayload(modelContainer: modelContainer, appServices: services)
            OhanaStartupProbe.mark("bootstrap.payload-set")
            bootstrapWatchdogTask?.cancel()
            bootstrapWatchdogTask = nil
            bootstrapTask = nil
        }
    }

    private func retryBootstrap() {
        guard payload == nil else { return }
        bootstrapTask?.cancel()
        bootstrapTask = nil
        bootstrapWatchdogTask?.cancel()
        bootstrapWatchdogTask = nil
        OhanaStartupProbe.mark("bootstrap.retry")
        startBootstrapIfNeeded()
    }

    private func scheduleBootstrapWatchdog() {
        bootstrapWatchdogTask?.cancel()
        bootstrapWatchdogTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard payload == nil, !Task.isCancelled else { return }
            OhanaStartupProbe.mark("bootstrap.slow")
            bootstrapStatus = .slowOpeningStore
        }
    }

    private static func openModelContainerOffMain() async -> ModelContainer {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                OhanaStartupProbe.mark("bootstrap.container-start")
                let modelContainer = SharedModelContainer.make()
                continuation.resume(returning: modelContainer)
            }
        }
    }

    private func resetPersistentStateForUITestsIfNeeded(modelContainer: ModelContainer) {
        #if DEBUG
            guard OhanaUITestLaunchOptions.resetsPersistentState else { return }
            do {
                try StaticAppResetter(questManager: QuestManager()).resetForUITests(context: modelContainer.mainContext)
                OhanaStartupProbe.mark("ui-test-reset.complete")
            } catch {
                OhanaStartupProbe.mark("ui-test-reset.failed")
                OhanaLog.error("UI test persistent reset failed: \(error.localizedDescription)", category: "Startup")
            }
        #endif
    }
}

#if DEBUG
    private enum OhanaUITestLaunchOptions {
        static var resetsPersistentState: Bool {
            let arguments = ProcessInfo.processInfo.arguments
            return arguments.contains("-OHANA_UI_TESTS")
                && arguments.contains("-OHANA_RESET_PERSISTENT_STATE")
        }
    }
#endif

private enum OhanaBootstrapStatus {
    case preparing
    case openingStore
    case buildingServices
    case slowOpeningStore
}

private struct OhanaBootstrapShell: View {
    let status: OhanaBootstrapStatus
    let onRetry: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppBackgroundStyle.goIsland.gradientColors(for: .dark),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Ohana")
                    .font(OhanaFont.largeTitle(.heavy))
                    .foregroundStyle(Color.white.opacity(0.96)) // ui-v4: allow bootstrap shell ink on dark gradient
                ProgressView()
                    .tint(Color.white.opacity(0.86)) // ui-v4: allow bootstrap shell ink on dark gradient
                    .scaleEffect(0.86)
                    .accessibilityLabel(l.tr(zh: "正在准备 Ohana", en: "Preparing Ohana", de: "Ohana wird vorbereitet"))
                Text(statusMessage)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.white.opacity(0.68)) // ui-v4: allow bootstrap shell ink on dark gradient
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if case .slowOpeningStore = status {
                    Button(action: onRetry) {
                        Text(l.tr(zh: "重试启动", en: "Retry startup", de: "Start erneut versuchen"))
                            .font(OhanaFont.footnote(.black))
                            .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.25))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.88), in: Capsule()) // ui-v4: allow bootstrap retry pill on dark gradient
                    }
                }
            }
        }
    }

    private var statusMessage: String {
        switch status {
        case .preparing:
            l.tr(zh: "正在准备启动", en: "Preparing startup", de: "Start wird vorbereitet")
        case .openingStore:
            l.tr(zh: "正在打开本地数据", en: "Opening local data", de: "Lokale Daten werden geöffnet")
        case .buildingServices:
            l.tr(zh: "正在准备服务", en: "Preparing services", de: "Dienste werden vorbereitet")
        case .slowOpeningStore:
            l.tr(
                zh: "本地数据打开较慢，Ohana 仍在继续准备。",
                en: "Local data is taking longer to open. Ohana is still preparing.",
                de: "Lokale Daten brauchen länger. Ohana bereitet sich weiter vor."
            )
        }
    }

    private var l: L10n {
        L10n(appLanguage)
    }
}

private enum OhanaStartupProbe {
    nonisolated static func mark(_ event: String) {
        #if DEBUG
            let filename = "ohana-startup-probe.log"
            let line = "\(Date().timeIntervalSince1970) \(event)\n"
            guard let data = line.data(using: .utf8),
                  let directory = FileManager.default.urls(
                      for: .applicationSupportDirectory,
                      in: .userDomainMask
                  ).first else {
                return
            }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: url)
                }
                OhanaLog.info("[StartupProbe] \(event)", category: "Startup", privacy: .publicText)
            } catch {
                OhanaLog.warning(
                    "[StartupProbe] write failed: \(error.localizedDescription)",
                    category: "Startup",
                    privacy: .publicText
                )
            }
        #endif
    }
}
