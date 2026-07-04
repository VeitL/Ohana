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
            0
        case let .shellFirst(delayMS):
            delayMS
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
            AppPresentationPolicy(
                surface: .compactSheet,
                loading: .shellFirst(delayMS: 64),
                instrumentationName: route.presentationName,
                detents: [.medium, .large],
                cornerRadius: OhanaRadius.sheetCompact
            )
        case .streakDetail:
            AppPresentationPolicy(
                surface: .sheetPage,
                loading: .immediate,
                instrumentationName: route.presentationName,
                detents: [.large],
                cornerRadius: OhanaRadius.sheetPage
            )
        default:
            AppPresentationPolicy(
                surface: .sheetPage,
                loading: .shellFirst(delayMS: 80),
                instrumentationName: route.presentationName,
                detents: [.large],
                cornerRadius: OhanaRadius.sheetPage
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
            loading: .immediate,
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
                RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                    .fill(Color.ohanaGlassStroke.opacity(0.18))
                    .frame(width: 82, height: 8)

                VStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
                        .fill(Color.ohanaCardSurface.opacity(0.82))
                        .frame(width: 186, height: 12)
                    RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
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
            "petProfile"
        case .humanProfile:
            "humanProfile"
        case .plantProfile:
            "plantProfile"
        }
    }
}

private extension AppSheetRoute {
    var presentationName: String {
        switch self {
        case .accountSwitcher:
            "accountSwitcher"
        case .addEntity:
            "addEntity"
        case .calendar:
            "calendar"
        case .coconutLog:
            "coconutLog"
        case .coconutShop:
            "coconutShop"
        case .crewRoster:
            "crewRoster"
        case .functionMenu:
            "functionMenu"
        case .petAllFeatures:
            "petAllFeatures"
        case .petBasicInfo:
            "petBasicInfo"
        case .petFood:
            "petFood"
        case .petWeightQuick:
            "petWeightQuick"
        case .petWeight:
            "petWeight"
        case .petExpenseQuick:
            "petExpenseQuick"
        case .petExpense:
            "petExpense"
        case .petFeed:
            "petFeed"
        case .petWater:
            "petWater"
        case .petPotty:
            "petPotty"
        case .petLitter:
            "petLitter"
        case .petPlay:
            "petPlay"
        case .petHygiene:
            "petHygiene"
        case .petWalkSummary:
            "petWalkSummary"
        case .petHealth:
            "petHealth"
        case .petMedication:
            "petMedication"
        case .petMomentHistory:
            "petMomentHistory"
        case .petDocuments:
            "petDocuments"
        case .petAchievements:
            "petAchievements"
        case .petRetention:
            "petRetention"
        case .petBondVault:
            "petBondVault"
        case .humanAllFeatures:
            "humanAllFeatures"
        case .humanBasicInfo:
            "humanBasicInfo"
        case .humanMedicationQuick:
            "humanMedicationQuick"
        case .humanMedication:
            "humanMedication"
        case .humanWeightQuick:
            "humanWeightQuick"
        case .humanWeight:
            "humanWeight"
        case .humanWorkoutQuick:
            "humanWorkoutQuick"
        case .humanWorkout:
            "humanWorkout"
        case .humanWorkoutDashboard:
            "humanWorkoutDashboard"
        case .humanMetrics:
            "humanMetrics"
        case .humanReport:
            "humanReport"
        case .humanExpenseQuick:
            "humanExpenseQuick"
        case .humanExpense:
            "humanExpense"
        case .humanWishlist:
            "humanWishlist"
        case .humanNoteQuick:
            "humanNoteQuick"
        case .humanNote:
            "humanNote"
        case .requiredAccountSwitch:
            "requiredAccountSwitch"
        case .settings:
            "settings"
        case .streakDetail:
            "streakDetail"
        }
    }
}

private extension AppFullScreenRoute {
    var presentationName: String {
        switch self {
        case .oasisReward:
            "oasisReward"
        case .requiredHumanProfile:
            "requiredHumanProfile"
        case .walk:
            "walk"
        }
    }
}

private extension AppOverlayRoute {
    var presentationName: String {
        switch self {
        case .quickMoment:
            "quickMoment"
        case .petWeightQuick:
            "petWeightQuick"
        case .petExpenseQuick:
            "petExpenseQuick"
        case .humanMedicationQuick:
            "humanMedicationQuick"
        case .humanWeightQuick:
            "humanWeightQuick"
        case .humanWorkoutQuick:
            "humanWorkoutQuick"
        case .humanExpenseQuick:
            "humanExpenseQuick"
        case .humanNoteQuick:
            "humanNoteQuick"
        }
    }
}
