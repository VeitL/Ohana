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
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isReplay: Bool = false
    var onReplayFinished: (() -> Void)?

    private enum FlowStep: Equatable {
        case intro
        case profile
    }

    @State private var step: FlowStep = .intro
    /// 每次进入「添加人类」步骤刷新，避免从欢迎页返回后残留半填状态
    @State private var humanWizardSessionId = UUID()

    @State private var iconPulse = false
    @State private var introPageIndex = 0
    private let introPageCount = 3

    private var languageCode: String { AppLanguage.normalize(appLanguage) }
    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    private func localized(zh: String, en: String, de: String) -> String {
        AppLocalizedText(zh: zh, en: en, de: de).resolve(languageCode)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            content
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .onAppear {
            if shouldReduceWork {
                iconPulse = false
            } else {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true } // ui-v4: allow gated onboarding icon pulse; smoothness: allow reduce-work gated onboarding pulse.
            }
            if !isReplay && !currentActiveHumanId.isEmpty && !hasOnboarded {
                finishOnboarding(playsFeedback: false)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro:
            introFlow
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .profile:
            humanOnboardingWizard
                .transition(.opacity)
        }
    }

    /// 与「添加家人 → 家庭成员」相同的完整人类向导，完成后绑定为当前设备主人
    private var humanOnboardingWizard: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()
                AddHumanWizardView(
                    onComplete: {
                        finishOnboarding()
                    },
                    onHumanSaved: { human in
                        currentActiveHumanId = human.id.uuidString
                    }
                )
                .id(humanWizardSessionId)
            }
            .navigationTitle(localized(zh: "本人档案", en: "Your Profile", de: "Dein Profil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(GoMotion.page) { step = .intro }
                    } label: {
                        Image(systemName: "chevron.left") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel(localized(zh: "返回", en: "Back", de: "Zurück"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Intro flow

    private var introFlow: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        OhanaIconView(size: 38)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)

                    Spacer(minLength: 18)

                    TabView(selection: $introPageIndex) {
                        ForEach(0..<introPageCount, id: \.self) { index in
                            introPageContent(index)
                                .tag(index)
                                .padding(.horizontal, 20)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: min(max(proxy.size.height * 0.68, 440), 590))

                    introPageDots
                        .padding(.top, 12)

                    Spacer(minLength: 20)

                    ctaArea
                        .padding(.horizontal, 24)
                        .padding(.bottom, 42)
                }
                .frame(minHeight: proxy.size.height)
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
        default:
            introPage(
                title: localized(zh: "家庭成员管理", en: "Family care", de: "Familienpflege"),
                subtitle: localized(zh: "人类、宠物、植物，都放在同一个家里管理。", en: "Humans, pets, and plants live in one shared care home.", de: "Menschen, Tiere und Pflanzen bleiben in einem Pflegezuhause."),
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
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 420)
        .background(OnboardingPalette.panelFill, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
        )
        .shadow(color: OnboardingPalette.cardShadow, radius: 20, y: 12) // ui-v4: allow onboarding primary card lift
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
            return CGSize(width: -width * 0.28, height: -height * 0.18)
        case 1:
            return CGSize(width: width * 0.3, height: -height * 0.04)
        default:
            return CGSize(width: -width * 0.06, height: height * 0.27)
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
            ForEach(0..<introPageCount, id: \.self) { index in
                Capsule()
                    .fill(index == introPageIndex ? Color.goLime : OnboardingPalette.mutedFill)
                    .frame(width: index == introPageIndex ? 24 : 7, height: 7)
                    .animation(GoMotion.feedback, value: introPageIndex)
            }
        }
    }

    // MARK: - CTA area

    private var ctaArea: some View {
        VStack(spacing: 12) {
            Button(action: advanceFromWelcome) {
                HStack(spacing: 8) {
                    Text(introPageIndex < introPageCount - 1
                         ? localized(zh: "下一页", en: "Next", de: "Weiter")
                        : localized(zh: "建立本人档案", en: "Create profile", de: "Profil erstellen"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(OnboardingPalette.selectedText)
                    Image(systemName: introPageIndex < introPageCount - 1 ? "chevron.right" : "arrow.right")
                        .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(OnboardingPalette.selectedText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.goLime, in: Capsule())
            }

            if isReplay {
                Button(localized(zh: "关闭", en: "Close", de: "Schliessen")) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onReplayFinished?()
                }
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(OnboardingPalette.secondaryText)
            } else {
                Text(localized(
                    zh: "本地优先 · 无需账号",
                    en: "Local-first · No account",
                    de: "Lokal zuerst · Kein Konto"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(OnboardingPalette.tertiaryText)
                .multilineTextAlignment(.center)
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
        humanWizardSessionId = UUID()
        withAnimation(GoMotion.page) { step = .profile }
    }

    private func finishOnboarding(playsFeedback: Bool = true) {
        if playsFeedback {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if isReplay {
            onReplayFinished?()
            return
        }
        firstQuickCheckInCompleted = false
        showFirstSuccessCard = true
        withAnimation(GoMotion.page) {
            hasOnboarded = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}
