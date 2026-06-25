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

// MARK: - Ohana App Icon Shape (matches SVG in design system)

private struct OhanaIconView: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.219, style: .continuous)
                .fill(Color(hex: "0C1640"))
                .frame(width: size, height: size)

            HeartbeatPath()
                .stroke(Color.goLime, style: StrokeStyle(lineWidth: size * 0.063,
                                                         lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.531, height: size * 0.25)

            Circle()
                .fill(Color.goLime)
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
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @AppStorage("ohana_onboarding_city") private var onboardingCity = ""
    @AppStorage("ohana_onboarding_notifications_intent") private var onboardingNotificationsIntent = true
    @AppStorage("ohana_onboarding_has_pets") private var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") private var onboardingHasChildren = false
    @AppStorage(PlantLockedPreviewPolicy.onboardingHasPlantsKey) private var onboardingHasPlants = false
    @AppStorage("ohana_onboarding_plant_experience") private var onboardingPlantExperience = PlantExperienceLevel.beginner.rawValue
    @AppStorage("ohana_onboarding_plant_scene") private var onboardingPlantScene = PlantCareScene.indoor.rawValue
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
    @State private var isSkippingProfile = false
    @State private var skipProfileError = ""
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
            if shouldReduceWork {
                iconPulse = false
            } else {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true } // ui-v4: allow gated onboarding icon pulse; smoothness: allow reduce-work gated onboarding pulse.
            }
            recoverInterruptedOnboardingIfNeeded()
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
            if !skipProfileError.isEmpty {
                Text(skipProfileError)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                } else if introPageIndex == introPageCount - 1 {
                    Button {
                        skipProfileSetup()
                    } label: {
                        Text(isSkippingProfile
                            ? localized(zh: "准备中", en: "Preparing", de: "Bereit")
                            : localized(zh: "跳过身份", en: "Skip identity", de: "Überspringen"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(OnboardingPalette.primaryText.opacity(0.72))
                            .frame(width: 118, height: 54)
                            .background(OnboardingPalette.mutedFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isFlippingToProfile || isSkippingProfile)
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
                    .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("onboarding-intro-primary-action")
                .disabled(isFlippingToProfile || isSkippingProfile)
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
                title: localized(zh: "游戏化成长", en: "Playful growth", de: "Spielerisches Wachstum"),
                subtitle: localized(zh: "照顾会获得椰子，推动生命之树和 Oasis 成长。", en: "Care earns coconuts and grows the Life Tree and Oasis.", de: "Pflege bringt Kokosnüsse und lässt Lebensbaum und Oase wachsen."),
                heroIcon: "tree.fill",
                tint: Color.goLime,
                badges: [
                    (icon: "bolt.fill", title: localized(zh: "椰子", en: "Coconuts", de: "Kokos")),
                    (icon: "arrow.up.forward.circle.fill", title: localized(zh: "等级", en: "Levels", de: "Level")),
                    (icon: "sparkles", title: localized(zh: "Oasis", en: "Oasis", de: "Oase"))
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
            onboardingPlantPreferencePage
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

    private var onboardingPlantPreferencePage: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "leaf.circle.fill") // a11y: allow decorative onboarding glyph; heading names the page.
                    .font(OhanaFont.adaptive(size: 64, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
                Text(localized(zh: "植物照护偏好", en: "Plant care preferences", de: "Pflanzenpflege"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                Text(localized(
                    zh: "这些偏好会影响植物安全提示和提醒文案；不授权定位也可以手动填写城市。",
                    en: "These preferences tune plant safety notes and reminders. You can type a city without location access.",
                    de: "Diese Angaben steuern Sicherheitshinweise und Erinnerungen. Du kannst die Stadt manuell eintragen."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(OnboardingPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                TextField(localized(zh: "城市/地区", en: "City or region", de: "Stadt oder Region"), text: $onboardingCity) // ui-v4: allow compact onboarding city input until shared onboarding input token lands.
                    .textFieldStyle(.plain)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(OnboardingPalette.mutedFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                Toggle(localized(zh: "愿意接收护理通知", en: "Allow care reminders", de: "Pflege-Erinnerungen erlauben"), isOn: $onboardingNotificationsIntent)
                    .tint(Color.goLime)
                Toggle(localized(zh: "家里有宠物", en: "Pets at home", de: "Tiere zu Hause"), isOn: $onboardingHasPets)
                    .tint(Color.goLime)
                Toggle(localized(zh: "家里有小孩", en: "Children at home", de: "Kinder zu Hause"), isOn: $onboardingHasChildren)
                    .tint(Color.goLime)
                Toggle(localized(zh: "家里有植物", en: "Plants at home", de: "Pflanzen zu Hause"), isOn: $onboardingHasPlants)
                    .tint(Color.goLime)

                Picker(localized(zh: "植物经验", en: "Plant experience", de: "Pflanzenerfahrung"), selection: $onboardingPlantExperience) {
                    Text(localized(zh: "新手", en: "Beginner", de: "Anfänger")).tag(PlantExperienceLevel.beginner.rawValue)
                    Text(localized(zh: "熟悉", en: "Comfortable", de: "Vertraut")).tag(PlantExperienceLevel.intermediate.rawValue)
                    Text(localized(zh: "进阶", en: "Experienced", de: "Erfahren")).tag(PlantExperienceLevel.experienced.rawValue)
                }
                .pickerStyle(.segmented)

                Picker(localized(zh: "主要场景", en: "Main plant area", de: "Pflanzenbereich"), selection: $onboardingPlantScene) {
                    Text(localized(zh: "室内", en: "Indoor", de: "Innen")).tag(PlantCareScene.indoor.rawValue)
                    Text(localized(zh: "阳台", en: "Balcony", de: "Balkon")).tag(PlantCareScene.balcony.rawValue)
                    Text(localized(zh: "花园", en: "Garden", de: "Garten")).tag(PlantCareScene.garden.rawValue)
                }
                .pickerStyle(.segmented)
            }
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(OnboardingPalette.primaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .fill(index == introPageIndex ? Color.goLime : OnboardingPalette.mutedFill)
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
        startProfileSetup()
    }

    private func startProfileSetup() {
        guard !isFlippingToProfile else { return }
        flipTask?.cancel()
        skipProfileError = ""
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

    private func skipProfileSetup() {
        guard !isReplay, !isSkippingProfile else { return }
        isSkippingProfile = true
        skipProfileError = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        var draft = MemberCreationDraft(kind: .human)
        draft.name = skippedProfileName()
        do {
            let result = try appServices.memberCreation.save(
                draft: draft,
                existingPets: [],
                existingHumans: [],
                context: modelContext,
                countryCode: appCountry
            )
            guard let human = result.human else {
                throw MemberCreationError.saveFailed("Skipped profile did not create a human.")
            }
            recordOnboardingHumanSaved(human)
            finishOnboarding(playsFeedback: false)
        } catch {
            isSkippingProfile = false
            skipProfileError = localized(
                zh: "暂时无法跳过，请先建立本人档案。",
                en: "Skip is unavailable right now. Create a profile first.",
                de: "Überspringen ist gerade nicht verfügbar. Erstelle zuerst ein Profil."
            )
            OhanaLog.warning(
                "Onboarding skip profile failed: \(error.localizedDescription)",
                category: "Onboarding"
            )
        }
    }

    private func skippedProfileName() -> String {
        localized(zh: "我", en: "Me", de: "Ich")
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

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}
