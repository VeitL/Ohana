//
//  OnboardingView.swift
//  Ohana
//
//  首次启动引导 — Go Focus setup
//

import SwiftData
import SwiftUI
import UIKit

private enum OnboardingPalette {
    static let backgroundTop = Color(hex: "06140F")
    static let backgroundBottom = Color(hex: "101827")
    static let primaryText = Color.goCardWhite.opacity(0.94)
    static let secondaryText = Color.goCardWhite.opacity(0.64)
    static let tertiaryText = Color.goCardWhite.opacity(0.42)
    static let panelFill = Color.goCardWhite.opacity(0.08)
    static let panelStroke = Color.goCardWhite.opacity(0.12)
    static let mutedFill = Color.goCardWhite.opacity(0.08)
    static let cardShadow = Color.arkInk.opacity(0.28)
    static let selectedText = Color.arkInk
}

private enum OnboardingPreferenceButtonTone {
    case primary
    case secondary
}

// MARK: - Ohana App Icon Shape (matches SVG in design system)

private struct OhanaIconView: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.219, style: .continuous)
                .fill(Color(hex: "0C1640"))
                .frame(width: size, height: size)

            HeartbeatPath()
                .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: size * 0.063,
                                                         lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.531, height: size * 0.25)

            Circle()
                .fill(Color.goPrimary)
                .frame(width: size * 0.094, height: size * 0.094)
        }
    }

    private struct HeartbeatPath: Shape {
        func path(in rect: CGRect) -> Path {
            // SVG path scaled to rect: M 60 140 C 60 96 108 96 128 128 C 148 160 196 160 196 116 C 196 88 168 80 148 108
            // Normalised to 0-1 within the 136×80 bounding box of the curve
            let w = rect.width, h = rect.height
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h * 0.75))
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control1: CGPoint(x: 0, y: h * 0.2),
                control2: CGPoint(x: w * 0.353, y: h * 0.2)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.225),
                control1: CGPoint(x: w * 0.647, y: h * 0.8),
                control2: CGPoint(x: w, y: h * 0.8)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.647, y: h * 0.7),
                control1: CGPoint(x: w, y: h * 0),
                control2: CGPoint(x: w * 0.794, y: h * 0)
            )
            return p
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @AppStorage("ohana_onboarding_has_pets") private var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") private var onboardingHasChildren = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    var isReplay: Bool = false
    var onReplayFinished: (() -> Void)?
    var onPrimaryHumanSaved: ((Human) -> Void)?
    var onHomeJoinHandoffPreflight: (() -> Void)?

    private enum FlowStep: Equatable {
        case intro
        case profile
    }

    @State private var step: FlowStep = .intro
    /// 每次进入「添加人类」步骤刷新，避免从欢迎页返回后残留半填状态
    @State private var humanWizardSessionId = UUID()

    @State private var iconPulse = false
    @State private var introPageIndex = 0
    @State private var introDragOffset: CGFloat = 0
    @State private var flipProgress: CGFloat = 0
    @State private var flipTask: Task<Void, Never>?
    @State private var isFlippingToProfile = false
    @State private var isProfilePrepared = false
    @State private var isHomeJoinHandoffPreflightActive = false
    @State private var isHomeJoinHandoffPresentationActive = false
    @State private var preferenceCoordinator = OnboardingPreferenceCoordinator()
    private let introPageCount = 4

    private var languageCode: String { AppLanguage.normalize(appLanguage) }
    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    private var flipAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : .easeInOut(duration: 0.42)
    }

    private var flipDurationMilliseconds: UInt64 { shouldReduceWork ? 120 : 420 }

    private var isCardFlipActive: Bool {
        isFlippingToProfile || isProfilePrepared
    }

    private var introSideOpacity: Double {
        guard isCardFlipActive else { return 1 }
        return flipProgress < 0.52 ? 1 : 0
    }

    private var profileSideOpacity: Double {
        guard isCardFlipActive else { return 1 }
        return flipProgress > 0.48 ? 1 : 0
    }

    private var introCardFlipAngle: Double {
        guard isCardFlipActive, !shouldReduceWork else { return 0 }
        return -180 * Double(flipProgress)
    }

    private var profileCardFlipProgress: CGFloat? {
        isCardFlipActive ? flipProgress : nil
    }

    private func localized(zh: String, en: String, de: String) -> String {
        AppLocalizedText(zh: zh, en: en, de: de).resolve(languageCode)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if !isHomeJoinHandoffPresentationActive {
                OhanaAppBackground()
                    .ignoresSafeArea()
            }

            content
        }
        .preferredColorScheme(isHomeJoinHandoffPreflightActive ? nil : .dark)
        .environment(\.colorScheme, .dark)
        .onAppear {
            preferenceCoordinator.syncLocationAuthorizationStatus(appServices.location.authorizationStatus)
            if shouldReduceWork {
                iconPulse = false
            } else {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true } // ui-v4: allow gated onboarding icon pulse; smoothness: allow reduce-work gated onboarding pulse.
            }
            recoverInterruptedOnboardingIfNeeded()
        }
        .task {
            await preferenceCoordinator.refreshNotificationStatus(appServices.userNotifications)
        }
        .onDisappear {
            flipTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if step == .intro || isFlippingToProfile {
                introFlow
                    .opacity(introSideOpacity)
                    .allowsHitTesting(step == .intro && !isFlippingToProfile)
                    .transition(.identity)
            }

            if step == .profile || isProfilePrepared {
                humanOnboardingWizard
                    .opacity(profileSideOpacity)
                    .allowsHitTesting(step == .profile && !isFlippingToProfile)
                    .transition(.identity)
            }
        }
    }

    /// 与「添加家人 → 家庭成员」相同的完整人类向导，完成后绑定为当前设备主人
    private var humanOnboardingWizard: some View {
        AddHumanWizardView(
            onComplete: {
                finishOnboarding(playsFeedback: false)
            },
            onCancel: {
                returnToIntro()
            },
            onHumanSaved: { human in
                recordOnboardingHumanSaved(human)
            },
            presentationStyle: .onboarding,
            onHomeJoinHandoffPreflight: beginHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: beginHomeJoinHandoffPresentation,
            onHomeJoinHandoffEnded: endHomeJoinHandoffPresentation
        )
        .id(humanWizardSessionId)
        .environment(\.colorScheme, .dark)
        .environment(\.memberCreationCardFlipProgress, profileCardFlipProgress)
        .preferredColorScheme(isHomeJoinHandoffPreflightActive ? nil : .dark)
    }

    // MARK: - Intro flow

    private var introFlow: some View {
        GeometryReader { proxy in
            let cardWidth = MemberCreationCardLayout.cardWidth(in: proxy.size.width)
            let cardHeight = MemberCreationCardLayout.cardHeight(
                in: proxy.size.height,
                includesTopChrome: false
            )
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                onboardingIntroCard(width: cardWidth)
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(introCardFlipAngle),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.78
                    )
                onboardingIntroActions(width: cardWidth)
                    .opacity(introSideOpacity)
                    .allowsHitTesting(!isCardFlipActive && step == .intro)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MemberCreationCardLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func onboardingIntroCard(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            onboardingIntroHeader
                .padding(.horizontal, 22)
                .padding(.top, 22)

            onboardingIntroPager
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            introPageDots
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
        }
        .frame(width: width)
        .background(OnboardingPalette.panelFill, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
        )
        .shadow(color: OnboardingPalette.cardShadow, radius: 24, y: 16) // ui-v4: allow onboarding fixed card lift
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
        .gesture(introSwipeGesture(pageWidth: width))
        .accessibilityElement(children: .contain)
    }

    private var onboardingIntroHeader: some View {
        HStack(spacing: 10) {
            OhanaIconView(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(zh: "欢迎来到 Ohana", en: "Welcome to Ohana", de: "Willkommen bei Ohana"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .lineLimit(1)
                Text(localized(zh: "左右滑动了解核心体验", en: "Swipe through the essentials", de: "Wische durch die Grundlagen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(OnboardingPalette.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
    }

    private var onboardingIntroPager: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            HStack(spacing: 0) {
                ForEach(0 ..< introPageCount, id: \.self) { index in
                    introPageContent(index)
                        .frame(width: pageWidth, height: proxy.size.height)
                }
            }
            .offset(x: -CGFloat(introPageIndex) * pageWidth + introDragOffset)
            .animation(GoMotion.page, value: introPageIndex)
        }
        .clipped()
    }

    private func onboardingIntroActions(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if isReplay {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onReplayFinished?()
                    } label: {
                        Text(localized(zh: "关闭", en: "Close", de: "Schliessen"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(OnboardingPalette.primaryText.opacity(0.72))
                            .frame(width: 104, height: 54)
                            .background(OnboardingPalette.mutedFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Button(action: advanceFromWelcome) {
                    HStack(spacing: 8) {
                        Text(introPageIndex < introPageCount - 1
                            ? localized(zh: "下一页", en: "Next", de: "Weiter")
                            : localized(zh: "建立本人档案", en: "Create profile", de: "Profil erstellen"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Image(systemName: introPageIndex < introPageCount - 1 ? "chevron.right" : "arrow.right")
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(OnboardingPalette.selectedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("onboarding-intro-primary-action")
                .disabled(isFlippingToProfile)
            }
        }
        .frame(width: width)
    }

    private func introSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isFlippingToProfile else { return }
                let translation = value.translation.width
                guard abs(translation) > abs(value.translation.height) else { return }
                let isPullingPastStart = introPageIndex == 0 && translation > 0
                let isPullingPastEnd = introPageIndex == introPageCount - 1 && translation < 0
                introDragOffset = (isPullingPastStart || isPullingPastEnd) ? translation * 0.32 : translation
            }
            .onEnded { value in
                guard !isFlippingToProfile else { return }
                let translation = value.translation.width
                let threshold = max(pageWidth * 0.18, 58)
                if translation < -threshold {
                    if introPageIndex < introPageCount - 1 {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(GoMotion.page) {
                            introPageIndex += 1
                            introDragOffset = 0
                        }
                    } else {
                        withAnimation(GoMotion.feedback) {
                            introDragOffset = 0
                        }
                        startProfileSetup()
                    }
                } else if translation > threshold, introPageIndex > 0 {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(GoMotion.page) {
                        introPageIndex -= 1
                        introDragOffset = 0
                    }
                } else {
                    withAnimation(GoMotion.feedback) {
                        introDragOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    private func introPageContent(_ index: Int) -> some View {
        switch index {
        case 1:
            introPage(
                title: localized(zh: "升级解锁更多", en: "Unlock as you grow", de: "Mehr freischalten"),
                subtitle: localized(zh: "照护获得椰子，升级后开启商店、植物管理和更多工具。", en: "Care earns coconuts. Level up to unlock the Shop, plant management, and more.", de: "Pflege bringt Kokosnüsse. Mit Leveln schaltest du Shop, Pflanzenverwaltung und mehr frei."),
                heroIcon: "tree.fill",
                tint: Color.goPrimary,
                badges: [
                    (icon: "cart.fill", title: localized(zh: "商店", en: "Shop", de: "Shop")),
                    (icon: "leaf.fill", title: localized(zh: "植物管理", en: "Plants", de: "Pflanzen")),
                    (icon: "sparkles", title: localized(zh: "更多功能", en: "More", de: "Mehr"))
                ]
            )
        case 2:
            introPage(
                title: localized(zh: "健康追踪", en: "Health tracking", de: "Gesundheit verfolgen"),
                subtitle: localized(zh: "体重、用药、提醒和趋势，帮你看清长期变化。", en: "Weight, medication, reminders, and trends show what changes over time.", de: "Gewicht, Medikamente, Erinnerungen und Trends zeigen Veränderungen."),
                heroIcon: "heart.text.square.fill",
                tint: Color.goTeal,
                badges: [
                    (icon: "scalemass.fill", title: localized(zh: "体重", en: "Weight", de: "Gewicht")),
                    (icon: "pills.fill", title: localized(zh: "用药", en: "Meds", de: "Medis")),
                    (icon: "chart.xyaxis.line", title: localized(zh: "趋势", en: "Trends", de: "Trends"))
                ]
            )
        case 3:
            onboardingPermissionPreferencePage
        default:
            introPage(
                title: localized(zh: "家中所有生命", en: "Every life at home", de: "Alles Leben zu Hause"),
                subtitle: localized(zh: "人类、宠物、植物和提醒，都放在同一个家里管理。", en: "Humans, pets, plants, and reminders live in one shared care home.", de: "Menschen, Tiere, Pflanzen und Erinnerungen bleiben in einem Pflegezuhause."),
                heroIcon: "house.fill",
                tint: Color.goBlue,
                badges: [
                    (icon: "person.fill", title: localized(zh: "人类", en: "Humans", de: "Menschen")),
                    (icon: "pawprint.fill", title: localized(zh: "宠物", en: "Pets", de: "Tiere")),
                    (icon: "leaf.fill", title: localized(zh: "植物", en: "Plants", de: "Pflanzen"))
                ]
            )
        }
    }

    private var onboardingPermissionPreferencePage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                onboardingLocationPreferenceCard
                onboardingNotificationPreferenceCard
                onboardingHouseholdPreferenceCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var onboardingLocationPreferenceCard: some View {
        onboardingPreferenceCard(
            icon: "location.fill.viewfinder",
            title: localized(zh: "位置", en: "Location", de: "Standort"),
            tint: Color.goBlue
        ) {
            VStack(spacing: 8) {
                if preferenceCoordinator.hasResolvedAutomaticLocation {
                    onboardingStatusRow(
                        icon: "checkmark.seal.fill",
                        title: localized(zh: "位置已开启", en: "Location allowed", de: "Standort erlaubt"),
                        detail: "\(preferenceCoordinator.countryDisplayName(languageCode: languageCode)) · \(preferenceCoordinator.cityDisplayName(languageCode: languageCode))",
                        tint: Color.goPrimary
                    )

                    HStack(spacing: 8) {
                        onboardingPreferenceActionButton(
                            title: localized(zh: "更新位置", en: "Update location", de: "Standort aktualisieren"),
                            icon: "location.fill",
                            tone: .secondary
                        ) {
                            Task {
                                await preferenceCoordinator.requestAutomaticLocation(locationProvider: appServices.location)
                            }
                        }

                        onboardingPreferenceActionButton(
                            title: localized(zh: "手动更改", en: "Edit manually", de: "Manuell ändern"),
                            icon: "pencil",
                            tone: .secondary
                        ) {
                            preferenceCoordinator.useManualLocation()
                        }
                    }
                } else if preferenceCoordinator.isResolvingLocation {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(Color.goPrimary)
                            Text(localized(zh: "定位中", en: "Allowing location", de: "Standort wird erlaubt"))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(OnboardingPalette.primaryText)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)

                        onboardingPreferenceActionButton(
                            title: localized(zh: "手动填写", en: "Enter manually", de: "Manuell"),
                            icon: "square.and.pencil",
                            tone: .secondary
                        ) {
                            preferenceCoordinator.useManualLocation()
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        onboardingPreferenceActionButton(
                            title: localized(zh: "允许位置", en: "Allow location", de: "Standort erlauben"),
                            icon: "location.fill",
                            tone: .primary
                        ) {
                            Task {
                                await preferenceCoordinator.requestAutomaticLocation(locationProvider: appServices.location)
                            }
                        }

                        onboardingPreferenceActionButton(
                            title: localized(zh: "手动填写", en: "Enter manually", de: "Manuell"),
                            icon: "square.and.pencil",
                            tone: .secondary
                        ) {
                            preferenceCoordinator.useManualLocation()
                        }
                    }
                }

                if preferenceCoordinator.locationError != nil {
                    onboardingInlineNotice(
                        icon: "exclamationmark.triangle.fill",
                        text: localized(
                            zh: "无法获取位置，请手动填写。",
                            en: "Couldn't get location. Enter it manually.",
                            de: "Standort nicht verfügbar. Bitte manuell eintragen."
                        ),
                        tint: Color.goOrange
                    )
                }

                if preferenceCoordinator.showsManualLocationFields {
                    onboardingManualLocationFields
                }

                if preferenceCoordinator.shouldShowLocationSettings {
                    onboardingPreferenceActionButton(
                        title: localized(zh: "打开系统设置", en: "Open Settings", de: "Einstellungen öffnen"),
                        icon: "gearshape.fill",
                        tone: .secondary,
                        action: openSystemSettings
                    )
                }
            }
        }
    }

    private var onboardingManualLocationFields: some View {
        VStack(spacing: 8) {
            onboardingPreferenceMenuRow(
                title: localized(zh: "国家/地区", en: "Country or region", de: "Land oder Region"),
                value: preferenceCoordinator.usesCustomCountry ? localized(zh: "自定义", en: "Custom", de: "Eigener Eintrag") : preferenceCoordinator.countryDisplayName(languageCode: languageCode),
                placeholder: localized(zh: "选择国家/地区", en: "Choose country", de: "Land wählen"),
                options: preferenceCoordinator.countryMenuOptions,
                action: { option in
                    preferenceCoordinator.selectCountry(option, languageCode: languageCode)
                }
            )

            if preferenceCoordinator.usesCustomCountry {
                OhanaTextField(
                    placeholder: localized(zh: "输入国家/地区", en: "Enter country or region", de: "Land eingeben"),
                    text: onboardingCountryBinding,
                    style: .compactCapsule
                )
                .accessibilityIdentifier("onboarding-custom-country-input")
            }

            if !preferenceCoordinator.usesCustomCountry {
                onboardingPreferenceMenuRow(
                    title: localized(zh: "城市", en: "City", de: "Stadt"),
                    value: preferenceCoordinator.usesCustomCity ? localized(zh: "自定义", en: "Custom", de: "Eigener Eintrag") : preferenceCoordinator.cityDisplayName(languageCode: languageCode),
                    placeholder: localized(zh: "选择城市", en: "Choose city", de: "Stadt wählen"),
                    options: preferenceCoordinator.cityMenuOptions,
                    action: { option in
                        preferenceCoordinator.selectCity(option, languageCode: languageCode)
                    }
                )
            }

            if preferenceCoordinator.usesCustomCity {
                OhanaTextField(
                    placeholder: localized(zh: "输入城市", en: "Enter city", de: "Stadt eingeben"),
                    text: onboardingCityBinding,
                    style: .compactCapsule
                )
                .accessibilityIdentifier("onboarding-custom-city-input")
            }
        }
    }

    private var onboardingNotificationPreferenceCard: some View {
        onboardingPreferenceCard(
            icon: "bell.badge.fill",
            title: localized(zh: "通知", en: "Notifications", de: "Mitteilungen"),
            tint: Color.goOrange
        ) {
            VStack(spacing: 8) {
                switch preferenceCoordinator.notificationPreferenceState {
                case .enabled:
                    onboardingStatusRow(
                        icon: "checkmark.seal.fill",
                        title: localized(zh: "通知已开启", en: "Notifications allowed", de: "Mitteilungen erlaubt"),
                        tint: Color.goPrimary
                    )
                case .requestable:
                    if preferenceCoordinator.isRequestingNotificationPermission {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(Color.goPrimary)
                            Text(localized(zh: "请求通知中", en: "Requesting notifications", de: "Mitteilungen werden angefragt"))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(OnboardingPalette.primaryText)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                    } else {
                        onboardingPreferenceActionButton(
                            title: localized(zh: "允许通知", en: "Allow notifications", de: "Mitteilungen erlauben"),
                            icon: "bell.fill",
                            tone: .primary
                        ) {
                            Task {
                                await preferenceCoordinator.requestNotificationPermission(appServices.userNotifications)
                            }
                        }
                    }
                case .settingsRequired:
                    OnboardingNotificationOffRow(
                        title: localized(zh: "通知关闭", en: "Notifications off", de: "Mitteilungen aus"),
                        isOn: notificationRetryBinding
                    )
                    onboardingPreferenceActionButton(
                        title: localized(zh: "打开系统设置", en: "Open Settings", de: "Einstellungen öffnen"),
                        icon: "gearshape.fill",
                        tone: .secondary,
                        action: openSystemSettings
                    )
                }
            }
        }
    }

    private var onboardingHouseholdPreferenceCard: some View {
        onboardingPreferenceCard(
            icon: "house.and.flag.fill",
            title: localized(zh: "家庭环境", en: "Home environment", de: "Zuhause"),
            tint: Color.goTeal
        ) {
            VStack(spacing: 6) {
                OnboardingPreferenceToggleRow(
                    icon: "pawprint.fill",
                    title: localized(zh: "家里有宠物", en: "Pets at home", de: "Tiere zu Hause"),
                    tint: Color.goOrange,
                    isOn: $onboardingHasPets
                )

                OnboardingPreferenceToggleRow(
                    icon: "figure.2.and.child.holdinghands",
                    title: localized(zh: "家里有小孩", en: "Children at home", de: "Kinder zu Hause"),
                    tint: Color.goBlue,
                    isOn: $onboardingHasChildren
                )
            }
        }
    }

    private func onboardingPreferenceCard(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(OnboardingPalette.primaryText)
                }
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(12)
        .background(OnboardingPalette.mutedFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func onboardingStatusRow(
        icon: String,
        title: String,
        detail: String? = nil,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func onboardingInlineNotice(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(tint)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(OnboardingPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func onboardingPreferenceActionButton(
        title: String,
        icon: String,
        tone: OnboardingPreferenceButtonTone,
        action: @escaping () -> Void
    ) -> some View {
        let isPrimary = tone == .primary
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isPrimary ? OnboardingPalette.selectedText : OnboardingPalette.primaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 10)
            .background(isPrimary ? Color.goPrimary : OnboardingPalette.mutedFill, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isPrimary ? Color.clear : OnboardingPalette.panelStroke, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
    }

    private func onboardingPreferenceMenuRow(
        title: String,
        value: String,
        placeholder: String,
        options: [OnboardingPlaceOption],
        action: @escaping (OnboardingPlaceOption) -> Void
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button(option.title(languageCode: languageCode)) {
                    action(option)
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                    Text(value.isEmpty ? placeholder : value)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(value.isEmpty ? OnboardingPalette.tertiaryText : OnboardingPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down") // a11y: allow decorative menu disclosure; Menu exposes label and value.
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(OnboardingPalette.mutedFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
            )
        }
        .accessibilityLabel(title)
        .accessibilityValue(value.isEmpty ? placeholder : value)
    }

    private var onboardingCountryBinding: Binding<String> {
        Binding(
            get: { preferenceCoordinator.country },
            set: { newValue in
                preferenceCoordinator.updateCustomCountry(newValue)
            }
        )
    }

    private var onboardingCityBinding: Binding<String> {
        Binding(
            get: { preferenceCoordinator.city },
            set: { newValue in
                preferenceCoordinator.updateCustomCity(newValue)
            }
        )
    }

    private var notificationRetryBinding: Binding<Bool> {
        Binding(
            get: { false },
            set: { newValue in
                guard newValue else { return }
                Task {
                    await preferenceCoordinator.requestNotificationPermission(appServices.userNotifications)
                }
            }
        )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func introPage(
        title: String,
        subtitle: String,
        heroIcon: String,
        tint: Color,
        badges: [(icon: String, title: String)]
    ) -> some View {
        VStack(spacing: 24) {
            onboardingHeroGlyphCluster(
                primaryIcon: heroIcon,
                tint: tint,
                badges: badges
            )
            .frame(height: 218)

            VStack(spacing: 10) {
                Text(title)
                    .font(OhanaFont.largeTitle(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)

            HStack(spacing: 8) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    onboardingBadgePill(
                        icon: badge.icon,
                        title: badge.title,
                        tint: tint
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func onboardingHeroGlyphCluster(
        primaryIcon: String,
        tint: Color,
        badges: [(icon: String, title: String)]
    ) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let centerSize = min(width * 0.36, 136)

            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: centerSize * 1.45, height: centerSize * 1.45)
                    .blur(radius: 1)
                    .scaleEffect(iconPulse && !shouldReduceWork ? 1.04 : 0.98)

                Circle()
                    .fill(tint)
                    .frame(width: centerSize, height: centerSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.goCardWhite.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.34), radius: 18, y: 10) // ui-v4: allow onboarding hero glyph depth

                Image(systemName: primaryIcon)
                    .font(OhanaFont.adaptive(size: 54, weight: .black))
                    .foregroundStyle(OnboardingPalette.selectedText)
                    .symbolRenderingMode(.monochrome)

                ForEach(Array(badges.enumerated()), id: \.offset) { index, badge in
                    onboardingFloatingGlyph(icon: badge.icon, tint: tint)
                        .offset(heroGlyphOffset(index: index, width: width, height: height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(GoMotion.hero, value: iconPulse)
        }
    }

    private func onboardingFloatingGlyph(icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(OhanaFont.adaptive(size: 19, weight: .black))
            .foregroundStyle(tint)
            .frame(width: 54, height: 54)
            .background(OnboardingPalette.mutedFill, in: Circle())
            .overlay(Circle().strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1))
    }

    private func heroGlyphOffset(index: Int, width: CGFloat, height: CGFloat) -> CGSize {
        switch index {
        case 0:
            CGSize(width: -width * 0.28, height: -height * 0.18)
        case 1:
            CGSize(width: width * 0.3, height: -height * 0.04)
        default:
            CGSize(width: -width * 0.06, height: height * 0.27)
        }
    }

    private func onboardingBadgePill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(OnboardingPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 8)
        .background(OnboardingPalette.mutedFill, in: Capsule())
        .overlay(Capsule().strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1))
    }

    private var introPageDots: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< introPageCount, id: \.self) { index in
                Capsule()
                    .fill(index == introPageIndex ? Color.goPrimary : OnboardingPalette.mutedFill)
                    .frame(width: index == introPageIndex ? 24 : 7, height: 7)
                    .animation(GoMotion.feedback, value: introPageIndex)
            }
        }
    }

    private func advanceFromWelcome() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard introPageIndex >= introPageCount - 1 else {
            withAnimation(GoMotion.page) {
                introPageIndex += 1
            }
            return
        }
        guard preferenceCoordinator.validateBeforeLeavingPreferencePage() else {
            return
        }
        startProfileSetup()
    }

    private func startProfileSetup() {
        guard !isFlippingToProfile else { return }
        flipTask?.cancel()
        humanWizardSessionId = UUID()
        flipProgress = 0
        isProfilePrepared = true
        isFlippingToProfile = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        flipTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 20 : 70) {
            withAnimation(flipAnimation) {
                flipProgress = 1
            }
            flipTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: flipDurationMilliseconds) {
                step = .profile
                isFlippingToProfile = false
                isProfilePrepared = false
                introDragOffset = 0
            }
        }
    }

    private func returnToIntro() {
        flipTask?.cancel()
        isProfilePrepared = true
        isFlippingToProfile = true
        flipTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 20 : 70) {
            withAnimation(flipAnimation) {
                flipProgress = 0
            }
            flipTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: flipDurationMilliseconds) {
                step = .intro
                isFlippingToProfile = false
                isProfilePrepared = false
                introDragOffset = 0
            }
        }
    }

    private func beginHomeJoinHandoffPreflight() {
        guard !isReplay else { return }
        guard !isHomeJoinHandoffPreflightActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeJoinHandoffPreflightActive = true
        }
        onHomeJoinHandoffPreflight?()
    }

    private func beginHomeJoinHandoffPresentation() {
        beginHomeJoinHandoffPreflight()
        guard !isHomeJoinHandoffPresentationActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeJoinHandoffPresentationActive = true
        }
    }

    private func endHomeJoinHandoffPresentation() {
        guard isHomeJoinHandoffPresentationActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeJoinHandoffPresentationActive = false
        }
    }

    private func recordOnboardingHumanSaved(_ human: Human) {
        guard !isReplay else { return }
        persistActiveHumanId(human.id.uuidString)
        OnboardingHomeJoinHandoffGate.markCompleted()
        onPrimaryHumanSaved?(human)
    }

    private func recoverInterruptedOnboardingIfNeeded() {
        guard !isReplay, !hasOnboarded else { return }
        if !currentActiveHumanId.isEmpty {
            OnboardingHomeJoinHandoffGate.markCompleted()
            finishOnboarding(playsFeedback: false)
            return
        }
        guard let recoveredHumanID = appServices.onboardingJourney.interruptedOnboardingPrimaryHumanID(
            context: modelContext
        ) else {
            return
        }
        persistActiveHumanId(recoveredHumanID)
        OnboardingHomeJoinHandoffGate.markCompleted()
        finishOnboarding(playsFeedback: false)
    }

    private func persistActiveHumanId(_ id: String) {
        currentActiveHumanId = id
    }

    private func finishOnboarding(playsFeedback: Bool = true) {
        if isReplay {
            if playsFeedback {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            onReplayFinished?()
            return
        }
        guard !hasOnboarded else { return }
        if playsFeedback {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        firstQuickCheckInCompleted = false
        showFirstSuccessCard = true
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hasOnboarded = true
        }
    }
}

private struct OnboardingPreferenceToggleRow: View {
    let icon: String
    let title: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct OnboardingNotificationOffRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill") // a11y: allow decorative notification-off glyph; row label names the state.
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color.goOrange)
                .frame(width: 44, height: 44)
                .background(Color.goOrange.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityIdentifier("onboarding-notification-off-row")
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}
