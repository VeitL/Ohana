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

// ui-v4: allow the Figma-authored fixed launch canvas color.
private let ohanaLaunchCanvasColor = Color(
    red: 12.0 / 255.0,
    green: 12.0 / 255.0,
    blue: 12.0 / 255.0
)

@main
struct OhanaApp: App {
    @UIApplicationDelegateAdaptor(OhanaCloudSharingAppDelegate.self) private var cloudSharingAppDelegate

    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @AppStorage(AppCountry.storageKey) private var appCountry: String = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem: String = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency: String = AppCurrency.fallbackCode

    init() {
        #if DEBUG
            if OhanaUITestLaunchOptions.disablesAnimations {
                UIView.setAnimationsEnabled(false)
            }
        #endif
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
    @State private var launchRevealTask: Task<Void, Never>?
    @State private var launchRevealProgress: CGFloat = 0
    @State private var isLaunchOverlayVisible = true
    @State private var commerce = CommerceEntitlementService()
    @State private var pendingExternalURL: URL?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let payload {
                appContent(for: payload)
                    .allowsHitTesting(!isLaunchOverlayVisible)
                    .accessibilityHidden(isLaunchOverlayVisible)
                    .zIndex(0)
            }

            if isLaunchOverlayVisible {
                GeometryReader { proxy in
                    OhanaBootstrapShell(
                        status: bootstrapStatus,
                        onRetry: retryBootstrap
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .mask {
                        OhanaLaunchCircularDismissMask(
                            progress: reduceMotion ? 0 : launchRevealProgress
                        )
                        .fill(.white, style: FillStyle(eoFill: true)) // ui-v4: allow alpha-only launch transition mask ink.
                        .blur(radius: reduceMotion ? 0 : 1.5)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .ignoresSafeArea()
                .opacity(reduceMotion ? 1 - launchRevealProgress : 1)
                .allowsHitTesting(payload == nil)
                .zIndex(1)
            }
        }
        .background(ohanaLaunchCanvasColor.ignoresSafeArea())
        .tint(Color.goPrimary)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            Task { @MainActor in
                await commerce.start()
            }
            startBootstrapIfNeeded()
            beginLaunchRevealIfReady()
        }
        .onChange(of: payload != nil) { _, isReady in
            guard isReady else { return }
            beginLaunchRevealIfReady()
        }
        .onOpenURL(perform: handleExternalURL)
        .onDisappear {
            bootstrapTask?.cancel()
            bootstrapTask = nil
            bootstrapWatchdogTask?.cancel()
            bootstrapWatchdogTask = nil
            launchRevealTask?.cancel()
            launchRevealTask = nil
        }
    }

    private func appContent(for payload: OhanaBootstrapPayload) -> some View {
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
                Task { @MainActor in
                    await payload.appServices.commerce.refreshEntitlements()
                    payload.appServices.systemSurfaces.scheduleRefresh(reason: "entitlementsRefreshed")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                payload.appServices.lifecycle.handle(.willTerminate)
            }
    }

    private func beginLaunchRevealIfReady() {
        guard payload != nil, isLaunchOverlayVisible, launchRevealTask == nil else { return }
        let duration = reduceMotion ? 0.14 : 0.48
        let animation: Animation = reduceMotion
            ? .easeOut(duration: duration)
            : .timingCurve(0.2, 0.78, 0.2, 1, duration: duration)

        launchRevealTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 16)
            guard !Task.isCancelled else { return }
            withAnimation(animation) {
                launchRevealProgress = 1
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isLaunchOverlayVisible = false
            launchRevealTask = nil
            OhanaStartupProbe.mark("bootstrap.reveal-complete")
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
            let openResult = await Self.openModelContainerOffMain()
            guard !Task.isCancelled else { return }
            var modelContainer: ModelContainer
            switch openResult {
            case let .success(openedContainer):
                modelContainer = openedContainer
            case .failure:
                OhanaStartupProbe.mark("bootstrap.container-failed-closed")
                bootstrapStatus = .storeUnavailable
                bootstrapWatchdogTask?.cancel()
                bootstrapWatchdogTask = nil
                bootstrapTask = nil
                return
            }
            OhanaStartupProbe.mark("bootstrap.container-ready")
            if resetPersistentStateForUITestsIfNeeded(modelContainer: modelContainer) {
                let reopenResult = await Self.openModelContainerOffMain()
                guard !Task.isCancelled else { return }
                switch reopenResult {
                case let .success(reopenedContainer):
                    modelContainer = reopenedContainer
                    OhanaStartupProbe.mark("ui-test-reset.container-reopened")
                case .failure:
                    OhanaStartupProbe.mark("ui-test-reset.container-reopen-failed")
                    bootstrapStatus = .storeUnavailable
                    bootstrapWatchdogTask?.cancel()
                    bootstrapWatchdogTask = nil
                    bootstrapTask = nil
                    return
                }
            }
            bootstrapStatus = .buildingServices
            let services = AppServices(modelContainer: modelContainer, commerce: commerce)
#if DEBUG
            seedHumanBaselineForUITestsIfNeeded(modelContainer: modelContainer, services: services)
            seedPlantBaselineForUITestsIfNeeded(modelContainer: modelContainer, services: services)
#endif
            OhanaStartupProbe.mark("bootstrap.services-ready")
            cloudSharingAppDelegate.configure(modelContainer: modelContainer, cloudSync: services.cloudSync)
            let initDurationMS = (CFAbsoluteTimeGetCurrent() - initStartedAt) * 1000
            let containerDurationMS = (CFAbsoluteTimeGetCurrent() - containerStartedAt) * 1000
            AppPerformanceMonitor.shared.record("SwiftData container ready", valueMS: containerDurationMS, note: "Deferred after first shell")
            AppPerformanceMonitor.shared.record("App init", valueMS: initDurationMS, note: "BGTask + deferred container")
            AppPerformanceMonitor.shared.record("进程到 App init 完成", startedAt: ohanaProcessStartTime)
            services.metricKit.start()
            if let pendingExternalURL {
                _ = services.systemSurfaceRoutes.submit(pendingExternalURL)
                self.pendingExternalURL = nil
            }
            payload = OhanaBootstrapPayload(modelContainer: modelContainer, appServices: services)
            OhanaStartupProbe.mark("bootstrap.payload-set")
            bootstrapWatchdogTask?.cancel()
            bootstrapWatchdogTask = nil
            bootstrapTask = nil
        }
    }

    private func handleExternalURL(_ url: URL) {
        guard OhanaExternalRoute.parse(url) != nil else { return }
        if let payload {
            _ = payload.appServices.systemSurfaceRoutes.submit(url)
        } else {
            pendingExternalURL = url
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

    private static func openModelContainerOffMain() async -> Result<ModelContainer, SharedModelContainerOpenFailure> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                OhanaStartupProbe.mark("bootstrap.container-start")
                #if DEBUG
                    if consumeUITestStoreOpenFailureIfRequested() {
                        continuation.resume(returning: .failure(SharedModelContainerOpenFailure(
                            attemptedStoreKinds: SharedModelContainerOpenPolicy.orderedAttempts
                        )))
                        return
                    }
                #endif
                do {
                    let modelContainer = try SharedModelContainer.make()
                    continuation.resume(returning: .success(modelContainer))
                } catch let failure as SharedModelContainerOpenFailure {
                    continuation.resume(returning: .failure(failure))
                } catch {
                    continuation.resume(returning: .failure(SharedModelContainerOpenFailure(
                        attemptedStoreKinds: SharedModelContainerOpenPolicy.orderedAttempts
                    )))
                }
            }
        }
    }

    #if DEBUG
        private static let uiTestStoreOpenFaultLock = NSLock()
        private static var didConsumeUITestStoreOpenFailure = false

        private static func consumeUITestStoreOpenFailureIfRequested() -> Bool {
            guard OhanaUITestLaunchOptions.requestsSingleStoreOpenFailure else { return false }
            uiTestStoreOpenFaultLock.lock()
            defer { uiTestStoreOpenFaultLock.unlock() }
            guard !didConsumeUITestStoreOpenFailure else { return false }
            didConsumeUITestStoreOpenFailure = true
            return true
        }
    #endif

    private func resetPersistentStateForUITestsIfNeeded(modelContainer: ModelContainer) -> Bool {
        #if DEBUG
            guard OhanaUITestLaunchOptions.resetsPersistentState else { return false }
            do {
                try StaticAppResetter(
                    questManager: QuestManager(),
                    automaticBackups: AutomaticBackupService()
                ).resetForUITests(context: modelContainer.mainContext)
                SharedModelContainer.invalidateCachedContainer(modelContainer)
                OhanaStartupProbe.mark("ui-test-reset.complete")
                return true
            } catch {
                OhanaStartupProbe.mark("ui-test-reset.failed")
                OhanaLog.error("UI test persistent reset failed: \(error.localizedDescription)", category: "Startup")
                return false
            }
        #else
            return false
        #endif
    }

#if DEBUG
    private func seedHumanBaselineForUITestsIfNeeded(modelContainer: ModelContainer, services: AppServices) {
        UITestHumanBaselineSeeder.seedIfRequested(modelContainer: modelContainer, services: services)
    }

    private func seedPlantBaselineForUITestsIfNeeded(modelContainer: ModelContainer, services: AppServices) {
        UITestPlantBaselineSeeder.seedIfRequested(modelContainer: modelContainer, services: services)
    }
#endif
}

private enum OhanaBootstrapStatus: Equatable {
    case preparing
    case openingStore
    case buildingServices
    case slowOpeningStore
    case storeUnavailable
}

private struct OhanaBootstrapShell: View {
    let status: OhanaBootstrapStatus
    let onRetry: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    var body: some View {
        if case .storeUnavailable = status {
            recoveryContent
        } else {
            OhanaLaunchLoadingView(
                accessibilityLabel: statusMessage,
                showsSlowRecovery: status == .slowOpeningStore,
                retryTitle: l.tr(zh: "重试启动", en: "Retry startup", de: "Start erneut versuchen"),
                onRetry: onRetry
            )
        }
    }

    private var recoveryContent: some View {
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
                Image(systemName: "externaldrive.badge.exclamationmark") // a11y: allow decorative icon; adjacent status text names the failure
                    .font(OhanaFont.title(.bold))
                    .foregroundStyle(Color.white.opacity(0.9)) // ui-v4: allow bootstrap shell ink on dark gradient
                    .accessibilityHidden(true)
                Text(statusMessage)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.white.opacity(0.68)) // ui-v4: allow bootstrap shell ink on dark gradient
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: onRetry) {
                    Text(l.tr(zh: "重试启动", en: "Retry startup", de: "Start erneut versuchen"))
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.25))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.88), in: Capsule()) // ui-v4: allow bootstrap retry pill on dark gradient
                }
                .accessibilityIdentifier("bootstrap-retry-button")
                Link(destination: OhanaPublicLinks.support) {
                    Text(l.tr(zh: "联系支持", en: "Contact support", de: "Support kontaktieren"))
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(Color.white.opacity(0.9)) // ui-v4: allow bootstrap shell ink on dark gradient
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                }
                .accessibilityIdentifier("bootstrap-support-action")
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
        case .storeUnavailable:
            l.tr(
                zh: "无法打开本地数据。为避免创建第二套数据库，Ohana 已停在不可写恢复界面。请释放设备空间后重试；现有数据不会被删除。",
                en: "Ohana could not open local data. To avoid creating a second database, the app has stopped at a read-only recovery screen. Free device storage and retry; existing data has not been deleted.",
                de: "Ohana konnte die lokalen Daten nicht öffnen. Um keine zweite Datenbank anzulegen, bleibt die App in einer nicht beschreibbaren Wiederherstellungsansicht. Gib Speicher frei und versuche es erneut; vorhandene Daten wurden nicht gelöscht."
            )
        }
    }

    private var l: L10n {
        L10n(appLanguage)
    }
}

private struct OhanaLaunchLoadingView: View {
    let accessibilityLabel: String
    let showsSlowRecovery: Bool
    let retryTitle: String
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var accumulatedMotionTime: TimeInterval = 0
    @State private var motionResumedAt = Date()

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunRepeatingAnimation(isVisible: true)
    }

    var body: some View {
        ZStack {
            ohanaLaunchCanvasColor
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !canAnimate)) { context in
                    let sample = motionSample(at: context.date)

                    ZStack {
                        OhanaLaunchGlow(
                            scale: sample.glowScale,
                            opacity: sample.glowOpacity
                        )

                        OhanaLaunchMark(
                            leftEyeScale: sample.leftEyeScale,
                            rightEyeScale: sample.rightEyeScale
                        )
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .accessibilityHidden(true)
                }
            }
            .allowsHitTesting(false)

            if showsSlowRecovery {
                VStack {
                    Spacer()
                    Button(retryTitle, action: onRetry)
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("bootstrap-retry-button")
                        .padding(.bottom, 48)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
        .onChange(of: canAnimate) { wasAnimating, isAnimating in
            let now = Date()
            if wasAnimating {
                accumulatedMotionTime += max(0, now.timeIntervalSince(motionResumedAt))
            }
            if isAnimating {
                motionResumedAt = now
            }
        }
    }

    private func motionSample(at date: Date) -> OhanaLaunchMotionSample {
        guard canAnimate else { return .reducedMotion }
        let elapsed = accumulatedMotionTime + max(0, date.timeIntervalSince(motionResumedAt))
        return OhanaLaunchMotionSample(elapsed: elapsed)
    }
}

private struct OhanaLaunchMotionSample {
    private static let blinkDuration: TimeInterval = 3.8
    private static let rightEyeDelay: TimeInterval = 0.08
    private static let firstBlinkLead = blinkDuration * 0.88
    private static let glowDuration: TimeInterval = 2.6

    let leftEyeScale: CGFloat
    let rightEyeScale: CGFloat
    let glowScale: CGFloat
    let glowOpacity: CGFloat

    static let reducedMotion = OhanaLaunchMotionSample(
        leftEyeScale: 1,
        rightEyeScale: 1,
        glowScale: 1,
        glowOpacity: 0.13
    )

    init(elapsed: TimeInterval) {
        leftEyeScale = Self.eyeScale(
            phase: Self.phase(
                elapsed + Self.firstBlinkLead,
                duration: Self.blinkDuration
            )
        )
        rightEyeScale = Self.eyeScale(
            phase: Self.phase(
                elapsed + Self.firstBlinkLead - Self.rightEyeDelay,
                duration: Self.blinkDuration
            )
        )

        let glowPhase = Self.phase(elapsed, duration: Self.glowDuration)
        let glowLinearProgress = glowPhase <= 0.5
            ? glowPhase * 2
            : (1 - glowPhase) * 2
        let glowProgress = Self.smoothstep(glowLinearProgress)
        glowScale = 1 + 0.16 * glowProgress
        glowOpacity = 0.13 + 0.11 * glowProgress
    }

    private init(
        leftEyeScale: CGFloat,
        rightEyeScale: CGFloat,
        glowScale: CGFloat,
        glowOpacity: CGFloat
    ) {
        self.leftEyeScale = leftEyeScale
        self.rightEyeScale = rightEyeScale
        self.glowScale = glowScale
        self.glowOpacity = glowOpacity
    }

    private static func phase(_ elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
        let wrapped = elapsed.truncatingRemainder(dividingBy: duration)
        let positive = wrapped >= 0 ? wrapped : wrapped + duration
        return CGFloat(positive / duration)
    }

    private static func eyeScale(phase: CGFloat) -> CGFloat {
        if phase < 0.88 || phase >= 1 {
            return 1
        }
        if phase <= 0.93 {
            let progress = smoothstep((phase - 0.88) / 0.05)
            return 1 - 0.94 * progress
        }
        let progress = smoothstep((phase - 0.93) / 0.07)
        return 0.06 + 0.94 * progress
    }

    private static func smoothstep(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

private struct OhanaLaunchGlow: View {
    let scale: CGFloat
    let opacity: CGFloat

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(0.7), location: 0), // ui-v4: allow the Figma-authored launch glow.
                .init(color: .clear, location: 0.7),
                .init(color: .clear, location: 1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 144
        )
        .frame(width: 288, height: 288)
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

private struct OhanaLaunchMark: View {
    let leftEyeScale: CGFloat
    let rightEyeScale: CGFloat

    var body: some View {
        ZStack {
            launchLayer(named: "LaunchMarkMouth")

            launchLayer(named: "LaunchMarkEyeLeft")
                .scaleEffect(
                    x: 1,
                    y: leftEyeScale,
                    anchor: UnitPoint(x: 0.364, y: 0.328)
                )

            launchLayer(named: "LaunchMarkEyeRight")
                .scaleEffect(
                    x: 1,
                    y: rightEyeScale,
                    anchor: UnitPoint(x: 0.633, y: 0.362)
                )
        }
        .frame(width: 180, height: 180)
        .shadow(color: .black.opacity(0.42), radius: 20, x: 0, y: 18) // ui-v4: allow the Figma launch mark's intentional soft shadow.
    }

    private func launchLayer(named name: String) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .frame(width: 180, height: 180)
    }
}

private struct OhanaLaunchCircularDismissMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        let maximumRadius = hypot(rect.width, rect.height) * 0.52
        let radius = maximumRadius * clampedProgress
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        return path
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
