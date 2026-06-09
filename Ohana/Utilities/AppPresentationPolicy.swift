//
//  AppPresentationPolicy.swift
//  Ohana
//
//  Global route presentation and content-mount policy. Mature app navigation
//  should mutate the route first, show a light shell, then mount heavy content
//  after the visual handoff.
//

import SwiftUI

enum AppPresentationSurface: Equatable {
    case navigationPush
    case sheetPage
    case compactSheet
    case fullScreen
    case inlineOverlay
}

enum AppPresentationLoading: Equatable {
    case immediate
    case shellFirst(delayMS: UInt64)

    var mountsImmediately: Bool {
        if case .immediate = self { return true }
        return false
    }

    var delayMS: UInt64 {
        switch self {
        case .immediate:
            return 0
        case let .shellFirst(delayMS):
            return delayMS
        }
    }
}

struct AppPresentationPolicy {
    let surface: AppPresentationSurface
    let loading: AppPresentationLoading
    let instrumentationName: String
    let detents: Set<PresentationDetent>
    let cornerRadius: CGFloat
    let contentInteraction: PresentationContentInteraction

    init(
        surface: AppPresentationSurface,
        loading: AppPresentationLoading,
        instrumentationName: String,
        detents: Set<PresentationDetent> = [.large],
        cornerRadius: CGFloat = 36,
        contentInteraction: PresentationContentInteraction = .scrolls
    ) {
        self.surface = surface
        self.loading = loading
        self.instrumentationName = instrumentationName
        self.detents = detents
        self.cornerRadius = cornerRadius
        self.contentInteraction = contentInteraction
    }
}

enum AppPresentationPolicyProvider {
    static func policy(for route: AppRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .navigationPush,
            loading: .shellFirst(delayMS: 48),
            instrumentationName: route.presentationName
        )
    }

    static func policy(for route: AppSheetRoute) -> AppPresentationPolicy {
        switch route {
        case .accountSwitcher, .requiredAccountSwitch:
            return AppPresentationPolicy(
                surface: .compactSheet,
                loading: .shellFirst(delayMS: 64),
                instrumentationName: route.presentationName,
                detents: [.medium, .large],
                cornerRadius: 32
            )
        default:
            return AppPresentationPolicy(
                surface: .sheetPage,
                loading: .shellFirst(delayMS: 80),
                instrumentationName: route.presentationName,
                detents: [.large],
                cornerRadius: 36
            )
        }
    }

    static func policy(for route: AppFullScreenRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .fullScreen,
            loading: .shellFirst(delayMS: 64),
            instrumentationName: route.presentationName
        )
    }

    static func policy(for route: AppOverlayRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .inlineOverlay,
            loading: .shellFirst(delayMS: 64),
            instrumentationName: route.presentationName
        )
    }
}

struct AppDeferredRouteContent<Content: View>: View {
    let routeID: String
    let policy: AppPresentationPolicy
    @ViewBuilder let content: () -> Content

    @State private var isMounted = false
    @State private var mountTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if policy.loading.mountsImmediately || isMounted {
                content()
                    .transition(.opacity)
            } else {
                AppRouteLoadingShell(policy: policy)
                    .transition(.opacity)
            }
        }
        .animation(GoMotion.quick, value: isMounted)
        .onAppear(perform: scheduleMount)
        .onChange(of: routeID) { _, _ in
            resetAndScheduleMount()
        }
        .onDisappear {
            mountTask?.cancel()
            mountTask = nil
        }
    }

    private func resetAndScheduleMount() {
        mountTask?.cancel()
        mountTask = nil
        isMounted = policy.loading.mountsImmediately
        scheduleMount()
    }

    private func scheduleMount() {
        recordPresentationSample("route_shell_ready")
        guard !policy.loading.mountsImmediately else {
            isMounted = true
            recordPresentationSample("route_content_mounted")
            return
        }
        guard mountTask == nil else { return }
        mountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: policy.loading.delayMS) {
            isMounted = true
            mountTask = nil
            recordPresentationSample("route_content_mounted")
        }
    }

    private func recordPresentationSample(_ name: String) {
        let note = policy.instrumentationName
        Task { @MainActor in
            await Task.yield()
            AppPerformanceMonitor.shared.record(name, valueMS: 0, note: note)
        }
    }
}

struct AppRouteLoadingShell: View {
    let policy: AppPresentationPolicy

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.ohanaGlassStroke.opacity(0.18))
                    .frame(width: 82, height: 8)

                VStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.ohanaCardSurface.opacity(0.82))
                        .frame(width: 186, height: 12)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.ohanaCardSurface.opacity(0.58))
                        .frame(width: 132, height: 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(loadingLabel)
        }
        .allowsHitTesting(false)
    }

    private var loadingLabel: Text {
        Text(L10n(AppLanguage.code).tr(
            zh: "正在打开",
            en: "Opening",
            de: "Wird geöffnet"
        ))
    }
}

extension View {
    func appDeferredRouteContent(
        routeID: String,
        policy: AppPresentationPolicy
    ) -> some View {
        AppDeferredRouteContent(routeID: routeID, policy: policy) {
            self
        }
    }

    func appRouteSheetPresentation(for route: AppSheetRoute) -> some View {
        appPresentationSheet(AppPresentationPolicyProvider.policy(for: route))
    }

    func appPresentationSheet(_ policy: AppPresentationPolicy) -> some View {
        self
            .presentationDetents(policy.detents)
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(policy.cornerRadius)
            .presentationBackground(Color.clear)
            .presentationContentInteraction(policy.contentInteraction)
    }
}

private extension AppRoute {
    var presentationName: String {
        switch self {
        case .petProfile:
            return "petProfile"
        case .humanProfile:
            return "humanProfile"
        case .plantProfile:
            return "plantProfile"
        }
    }
}

private extension AppSheetRoute {
    var presentationName: String {
        switch self {
        case .accountSwitcher:
            return "accountSwitcher"
        case .addEntity:
            return "addEntity"
        case .calendar:
            return "calendar"
        case .coconutShop:
            return "coconutShop"
        case .functionMenu:
            return "functionMenu"
        case .petAllFeatures:
            return "petAllFeatures"
        case .petBasicInfo:
            return "petBasicInfo"
        case .petFood:
            return "petFood"
        case .petWeight:
            return "petWeight"
        case .petExpense:
            return "petExpense"
        case .petFeed:
            return "petFeed"
        case .petWater:
            return "petWater"
        case .petPotty:
            return "petPotty"
        case .petLitter:
            return "petLitter"
        case .petPlay:
            return "petPlay"
        case .petHygiene:
            return "petHygiene"
        case .petWalkSummary:
            return "petWalkSummary"
        case .petHealth:
            return "petHealth"
        case .petMedication:
            return "petMedication"
        case .petMomentHistory:
            return "petMomentHistory"
        case .petDocuments:
            return "petDocuments"
        case .petAchievements:
            return "petAchievements"
        case .petRetention:
            return "petRetention"
        case .petBondVault:
            return "petBondVault"
        case .humanAllFeatures:
            return "humanAllFeatures"
        case .humanBasicInfo:
            return "humanBasicInfo"
        case .humanMedication:
            return "humanMedication"
        case .humanWeight:
            return "humanWeight"
        case .humanWorkout:
            return "humanWorkout"
        case .humanWorkoutDashboard:
            return "humanWorkoutDashboard"
        case .humanMetrics:
            return "humanMetrics"
        case .humanReport:
            return "humanReport"
        case .humanExpense:
            return "humanExpense"
        case .humanWishlist:
            return "humanWishlist"
        case .humanNote:
            return "humanNote"
        case .requiredAccountSwitch:
            return "requiredAccountSwitch"
        case .streakDetail:
            return "streakDetail"
        }
    }
}

private extension AppFullScreenRoute {
    var presentationName: String {
        switch self {
        case .oasisReward:
            return "oasisReward"
        case .requiredHumanProfile:
            return "requiredHumanProfile"
        case .walk:
            return "walk"
        }
    }
}

private extension AppOverlayRoute {
    var presentationName: String {
        switch self {
        case .coconutLog:
            return "coconutLog"
        case .crewRoster:
            return "crewRoster"
        case .quickMoment:
            return "quickMoment"
        case .settings:
            return "settings"
        }
    }
}
