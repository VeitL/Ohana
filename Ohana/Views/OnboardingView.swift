//
//  OnboardingView.swift
//  Ohana
//
//  首次启动引导 — Go Focus setup
//

import SwiftData
import SwiftUI

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

private struct OnboardingCompanionStage: View {
    var isActive: Bool
    var focusMode: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let mainSize = min(width * (focusMode ? 0.46 : 0.42), 150)
            let sideSize = min(width * 0.3, 112)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(hex: "FFFFFF").opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.arkInk.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "0C1640").opacity(0.08), radius: 18, y: 10)

                Capsule()
                    .fill(Color(hex: "0C1640").opacity(0.08))
                    .frame(width: width * 0.66, height: 22)
                    .blur(radius: 10)
                    .offset(y: -18)

                petBubble(
                    species: "狗",
                    coat: Color(hex: "D9944A"),
                    eye: Color(hex: "4A2C17"),
                    size: mainSize,
                    rotation: focusMode ? -2 : -5
                )
                .offset(x: focusMode ? -34 : -46, y: isActive ? -20 : -12)
                .zIndex(2)

                petBubble(
                    species: "猫",
                    coat: Color(hex: "F1E5D0"),
                    eye: Color(hex: "3A6EA5"),
                    size: sideSize,
                    rotation: focusMode ? 5 : 8
                )
                .offset(x: focusMode ? 62 : 72, y: isActive ? -42 : -34)
                .zIndex(1)

                if !focusMode {
                    petBubble(
                        species: "兔子",
                        coat: Color(hex: "F7D9E5"),
                        eye: Color(hex: "9B3A60"),
                        size: sideSize * 0.82,
                        rotation: -8
                    )
                    .offset(x: -118, y: isActive ? -60 : -50)
                    .zIndex(0)
                }

                HStack(spacing: 8) {
                    stageBadge(icon: "fork.knife", label: focusMode ? "40g" : "+1")
                    stageBadge(icon: "bell.fill", label: "09:00")
                    stageBadge(icon: "bolt.fill", label: "+🥥")
                }
                .offset(y: -18)
                .zIndex(3)
            }
            .animation(GoMotion.hero, value: isActive)
        }
    }

    private func petBubble(
        species: String,
        coat: Color,
        eye: Color,
        size: CGFloat,
        rotation: Double
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFFFFF"), coat.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: coat.opacity(0.28), radius: 18, y: 10)

            PetSilhouetteView(
                species: species,
                coatColor: coat,
                eyeColor: eye,
                isAnimationEnabled: false
            )
            .padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
    }

    private func stageBadge(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(label)
                .font(OhanaFont.caption2(.black))
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.goLime.opacity(0.92), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.arkInk.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.fallbackCode
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isReplay: Bool = false
    var onReplayFinished: (() -> Void)?

    private enum FlowStep: Int, Equatable {
        case intro = 0
        case profile = 1
        case firstPet = 2
    }

    @State private var step: FlowStep = .intro
    /// 每次进入「添加人类」步骤刷新，避免从欢迎页返回后残留半填状态
    @State private var humanWizardSessionId = UUID()
    @State private var petWizardSessionId = UUID()

    @State private var iconPulse = false

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
            LinearGradient(
                colors: [Color(hex: "F7F9EF"), Color(hex: "EAF0FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .onAppear {
            if shouldReduceWork {
                iconPulse = false
            } else {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true }
            }
            if !isReplay && !currentActiveHumanId.isEmpty && !hasOnboarded {
                step = .firstPet
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
        case .firstPet:
            petChoiceFlow
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 3, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? Color.goLime : Color.arkInk.opacity(0.12))
                    .frame(width: i == step.rawValue ? 28 : nil, height: 4)
                    .animation(GoMotion.feedback, value: step)
            }
        }
    }

    /// 与「添加家人 → 家庭成员」相同的完整人类向导，完成后绑定为当前设备主人
    private var humanOnboardingWizard: some View {
        NavigationStack {
            ZStack {
                GoIslandWizardBackdrop()
                AddHumanWizardView(
                    onComplete: {
                        withAnimation(GoMotion.page) {
                            step = .firstPet
                        }
                    },
                    onHumanSaved: { human in
                        currentActiveHumanId = human.id.uuidString
                    }
                )
                .id(humanWizardSessionId)
            }
            .navigationTitle(localized(zh: "家庭成员", en: "Family Member", de: "Familienmitglied"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(GoMotion.page) { step = .intro }
                    } label: {
                        Text(localized(zh: "返回", en: "Back", de: "Zuruck"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }
                }
            }
        }
    }

    // MARK: - Intro flow

    private var introFlow: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        OhanaIconView(size: 38)
                        Spacer()
                        progressBar
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)

                    Spacer(minLength: 14)

                    OnboardingCompanionStage(isActive: iconPulse && !shouldReduceWork)
                        .frame(height: min(260, proxy.size.height * 0.32))
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        Text(localized(
                            zh: "照顾，一眼看懂",
                            en: "Care at a glance",
                            de: "Pflege auf einen Blick"
                        ))
                        .font(OhanaFont.largeTitle(.black))
                        .foregroundStyle(Color.arkInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                        Text(localized(
                            zh: "给家人、宠物和日常记录一个清爽首页。",
                            en: "One calm home for family, pets, and daily logs.",
                            de: "Ein ruhiger Ort für Familie, Tiere und tägliche Einträge."
                        ))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(Color.arkInk.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        onboardingStepRow(
                            icon: "person.2.fill",
                            title: localized(zh: "添加家人", en: "Add people", de: "Menschen"),
                            subtitle: localized(zh: "谁在照顾", en: "Who helps", de: "Wer hilft"),
                            tint: Color.goBlue
                        )
                        onboardingStepRow(
                            icon: "pawprint.fill",
                            title: localized(zh: "添加宠物", en: "Add pets", de: "Tiere"),
                            subtitle: localized(zh: "生成快捷照护", en: "Quick care ready", de: "Schnelle Pflege"),
                            tint: Color(hex: "F59E0B")
                        )
                        onboardingStepRow(
                            icon: "bolt.heart.fill",
                            title: localized(zh: "完成第一次打卡", en: "First check-in", de: "Erster Check-in"),
                            subtitle: localized(zh: "马上得到反馈", en: "Instant feedback", de: "Sofort Feedback"),
                            tint: Color.goLime,
                            usesFilledTint: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                    Spacer(minLength: 18)

                    ctaArea
                        .padding(.horizontal, 24)
                        .padding(.bottom, 42)
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    // MARK: - CTA area

    private var ctaArea: some View {
        VStack(spacing: 12) {
            Button(action: advanceFromWelcome) {
                HStack(spacing: 8) {
                    Text(localized(zh: "开始设置", en: "Start setup", de: "Einrichten"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.arkInk)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.arkInk)
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
                .foregroundStyle(Color.arkInk.opacity(0.58))
            } else {
                Text(localized(
                    zh: "本地优先 · 无需账号",
                    en: "Local-first · No account",
                    de: "Lokal zuerst · Kein Konto"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.arkInk.opacity(0.36))
                .multilineTextAlignment(.center)
            }
        }
    }

    private func onboardingStepRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        usesFilledTint: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(usesFilledTint ? Color.arkInk : tint)
                .frame(width: 34, height: 34)
                .background(usesFilledTint ? tint : tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.arkInk)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(subtitle)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.arkInk.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "FFFFFF").opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.arkInk.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Optional first pet

    private var petChoiceFlow: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        OhanaIconView(size: 38)
                        Spacer()
                        progressBar
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)

                    Spacer(minLength: 20)

                    OnboardingCompanionStage(isActive: iconPulse && !shouldReduceWork, focusMode: true)
                        .frame(height: 250)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    VStack(spacing: 12) {
                        Text(localized(
                            zh: "添加第一个宠物？",
                            en: "Add your first pet?",
                            de: "Erstes Tier hinzufugen?"
                        ))
                        .font(OhanaFont.largeTitle(.black))
                        .foregroundStyle(Color.arkInk)
                        .multilineTextAlignment(.center)
                        Text(localized(
                            zh: "添加后，首页马上出现快捷照护入口。",
                            en: "Quick care actions appear on Home right away.",
                            de: "Schnelle Pflege erscheint direkt auf der Startseite."
                        ))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(Color.arkInk.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    }
                    .padding(.horizontal, 34)

                    VStack(spacing: 10) {
                        onboardingMiniTip(
                            icon: "bolt.fill",
                            text: localized(zh: "物种专属快捷操作", en: "Species-aware actions", de: "Aktionen nach Tierart")
                        )
                        onboardingMiniTip(
                            icon: "calendar",
                            text: localized(zh: "生日、疫苗之后再补", en: "Add dates later", de: "Termine spater erganzen")
                        )
                        onboardingMiniTip(
                            icon: "sparkles",
                            text: localized(zh: "首次打卡有椰子反馈", en: "First log earns feedback", de: "Erster Eintrag gibt Feedback")
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                    Spacer(minLength: 20)

                    VStack(spacing: 12) {
                        Button {
                            petWizardSessionId = UUID()
                            step = .firstPet
                            showPetWizard = true
                        } label: {
                            Label(localized(zh: "添加第一个宠物", en: "Add First Pet", de: "Erstes Tier"), systemImage: "pawprint.fill")
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Color.goLime, in: Capsule())
                        }

                        Button(localized(zh: "先进入首页", en: "Enter Home First", de: "Erst zur Startseite")) {
                            finishOnboarding()
                        }
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(Color.arkInk.opacity(0.58))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 42)
                }
                .frame(minHeight: proxy.size.height)
            }
            .sheet(isPresented: $showPetWizard) {
                NavigationStack {
                    ZStack {
                        GoIslandWizardBackdrop()
                        AddPetWizardView {
                            showPetWizard = false
                            finishOnboarding()
                        }
                        .id(petWizardSessionId)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(localized(zh: "稍后", en: "Later", de: "Spater")) {
                                showPetWizard = false
                            }
                            .font(OhanaFont.headline(.semibold))
                            .foregroundStyle(Color.goLime)
                        }
                    }
                }
                .presentationDetents([.large])
                .interactiveDismissDisabled(false)
            }
        }
    }

    @State private var showPetWizard = false

    private func onboardingMiniTip(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.goBlue)
                .frame(width: 24)
            Text(text)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.arkInk.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(hex: "FFFFFF").opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.arkInk.opacity(0.06), lineWidth: 1)
        )
    }

    private func advanceFromWelcome() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        startProfileSetup()
    }

    private func startProfileSetup() {
        humanWizardSessionId = UUID()
        withAnimation(GoMotion.page) { step = .profile }
    }

    private func finishOnboarding() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isReplay {
            onReplayFinished?()
            return
        }
        firstQuickCheckInCompleted = false
        showFirstSuccessCard = true
        withAnimation(.easeInOut(duration: 0.28)) {
            hasOnboarded = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}
