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
                    .fill(OnboardingPalette.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
                    )
                    .shadow(color: OnboardingPalette.cardShadow, radius: 18, y: 10) // ui-v4: allow onboarding hero stage lift

                Capsule()
                    .fill(Color.arkInk.opacity(0.24))
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
                        colors: [Color.goCardWhite.opacity(0.14), coat.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: coat.opacity(0.28), radius: 18, y: 10) // ui-v4: allow onboarding companion depth

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
        .foregroundStyle(OnboardingPalette.selectedText)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.goLime.opacity(0.92), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.arkInk.opacity(0.12), lineWidth: 1))
    }
}

private struct OnboardingAvatarShowcase: View {
    var isActive: Bool
    var focusMode: Bool = false

    private var dogAvatar: UIImage? {
        onboardingImageData(filename: "dog_shiba_inu_girl_red.png", directory: PetAvatarAssetCatalog.assetDirectory)
    }

    private var catAvatar: UIImage? {
        onboardingImageData(filename: "cat_ragdoll_girl_seal_bicolor.png", directory: PetAvatarAssetCatalog.assetDirectory)
    }

    private var humanAvatar: UIImage? {
        onboardingImageData(filename: "human_female_young_adult.png", directory: HumanAvatarAssetCatalog.assetDirectory)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let mainHeight = min(proxy.size.height * 0.9, focusMode ? 218 : 200)
            let sideHeight = mainHeight * 0.78

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(OnboardingPalette.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
                    )
                    .shadow(color: OnboardingPalette.cardShadow, radius: 18, y: 10) // ui-v4: allow onboarding avatar stage lift

                Capsule()
                    .fill(Color.arkInk.opacity(0.26))
                    .frame(width: width * 0.72, height: 24)
                    .blur(radius: 10)
                    .offset(y: -16)

                avatarFigure(
                    image: humanAvatar,
                    fallback: {
                        HumanSilhouetteView(gender: "女", accent: Color.goTeal.opacity(0.82))
                    },
                    height: sideHeight
                )
                .offset(x: focusMode ? -96 : -108, y: isActive ? -34 : -24)
                .rotationEffect(.degrees(-5))
                .zIndex(0)

                avatarFigure(
                    image: dogAvatar,
                    fallback: {
                        PetSilhouetteView(
                            species: "狗",
                            coatColor: Color(hex: "D9944A"),
                            eyeColor: Color(hex: "4A2C17"),
                            isAnimationEnabled: false
                        )
                    },
                    height: mainHeight
                )
                .offset(x: focusMode ? -12 : -22, y: isActive ? -18 : -8)
                .rotationEffect(.degrees(focusMode ? -2 : -4))
                .zIndex(2)

                avatarFigure(
                    image: catAvatar,
                    fallback: {
                        PetSilhouetteView(
                            species: "猫",
                            coatColor: Color(hex: "F1E5D0"),
                            eyeColor: Color(hex: "3A6EA5"),
                            isAnimationEnabled: false
                        )
                    },
                    height: sideHeight
                )
                .offset(x: focusMode ? 98 : 110, y: isActive ? -50 : -40)
                .rotationEffect(.degrees(6))
                .zIndex(1)

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

    private func onboardingImageData(filename: String, directory: String) -> UIImage? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func avatarFigure<Fallback: View>(
        image: UIImage?,
        @ViewBuilder fallback: () -> Fallback,
        height: CGFloat
    ) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            } else {
                fallback()
                    .frame(width: height * 0.72, height: height)
            }
        }
        .shadow(color: Color.arkInk.opacity(0.34), radius: 18, x: 0, y: 12) // ui-v4: allow onboarding avatar grounding
    }

    private func stageBadge(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(label)
                .font(OhanaFont.caption2(.black))
        }
        .foregroundStyle(OnboardingPalette.selectedText)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.goLime.opacity(0.92), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.arkInk.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.fallbackCode
    @AppStorage(AppCountry.storageKey) private var appCountry: String = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem: String = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency: String = AppCurrency.fallbackCode
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isReplay: Bool = false
    var onReplayFinished: (() -> Void)?

    private enum FlowStep: Int, Equatable {
        case region = 0
        case intro = 1
        case profile = 2
        case firstPet = 3
    }

    @State private var step: FlowStep = .region
    /// 每次进入「添加人类」步骤刷新，避免从欢迎页返回后残留半填状态
    @State private var humanWizardSessionId = UUID()
    @State private var petWizardSessionId = UUID()

    @State private var iconPulse = false
    @State private var introPageIndex = 0
    private let introPageCount = 3

    private var languageCode: String { AppLanguage.normalize(appLanguage) }
    private var selectedCountry: AppCountry.Option { AppCountry.option(for: appCountry) }
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
                colors: [OnboardingPalette.backgroundTop, OnboardingPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .onAppear {
            if shouldReduceWork {
                iconPulse = false
            } else {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true } // ui-v4: allow gated onboarding icon pulse
            }
            if !isReplay && !currentActiveHumanId.isEmpty && !hasOnboarded {
                step = .firstPet
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .region:
            regionLanguageFlow
                .transition(.opacity.combined(with: .move(edge: .leading)))
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
            ForEach(0 ..< FlowStep.firstPet.rawValue + 1, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? Color.goLime : OnboardingPalette.mutedFill)
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
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Region and language

    private var regionLanguageFlow: some View {
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

                    Spacer(minLength: 26)

                    VStack(spacing: 12) {
                        Text(AppLocalizedText(
                            zh: "先选择语言，再选择国家/地区",
                            en: "Choose language, then region",
                            de: "Sprache wählen, dann Region"
                        ).resolve(languageCode))
                        .font(OhanaFont.largeTitle(.black))
                        .foregroundStyle(OnboardingPalette.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                        Text(AppLocalizedText(
                            zh: "语言决定界面文字；国家/地区会预设货币和计量单位，之后都可以调整。",
                            en: "Language controls the app text. Region presets currency and units, both editable later.",
                            de: "Die Sprache steuert den App-Text. Die Region setzt Währung und Einheiten."
                        ).resolve(languageCode))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppLocalizedText(zh: "语言", en: "Language", de: "Sprache").resolve(languageCode))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(OnboardingPalette.tertiaryText)
                            .textCase(.uppercase)

                        HStack(spacing: 10) {
                            ForEach(AppLanguage.supported) { language in
                                languageChoiceButton(language)
                            }
                        }

                        Text(AppLocalizedText(zh: "国家/地区", en: "Country/Region", de: "Land/Region").resolve(languageCode))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(OnboardingPalette.tertiaryText)
                            .textCase(.uppercase)
                            .padding(.top, 6)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                            ForEach(AppCountry.supported) { country in
                                regionChoiceButton(country)
                            }
                        }
                    }
                    .padding(18)
                    .background(OnboardingPalette.panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 28)

                    Spacer(minLength: 22)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(GoMotion.page) { step = .intro }
                    } label: {
                        HStack(spacing: 8) {
                            Text(AppLocalizedText(zh: "继续", en: "Continue", de: "Weiter").resolve(languageCode))
                                .font(OhanaFont.title3(.black))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .black))
                        }
                        .foregroundStyle(OnboardingPalette.selectedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.goLime, in: Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 42)
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    private func regionChoiceButton(_ country: AppCountry.Option) -> some View {
        let isSelected = country.code == selectedCountry.code
        return Button {
            applyCountryDefaults(country)
        } label: {
            HStack(spacing: 8) {
                Text(country.flag)
                    .font(.system(size: 20))
                Text(country.displayName.resolve(languageCode))
                    .font(OhanaFont.subheadline(isSelected ? .black : .bold))
                    .foregroundStyle(isSelected ? OnboardingPalette.selectedText : OnboardingPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(OnboardingPalette.selectedText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? Color.goLime : OnboardingPalette.mutedFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func languageChoiceButton(_ language: AppLanguage.Option) -> some View {
        let isSelected = AppLanguage.normalize(appLanguage) == language.code
        return Button {
            appLanguage = language.code
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(language.displayName)
                .font(OhanaFont.subheadline(isSelected ? .black : .bold))
                .foregroundStyle(isSelected ? OnboardingPalette.selectedText : OnboardingPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.goLime : OnboardingPalette.mutedFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func applyCountryDefaults(_ country: AppCountry.Option) {
        appCountry = country.code
        appMeasurementSystem = AppMeasurementSystem.normalize(country.defaultMeasurementSystemCode)
        appCurrency = AppCurrency.normalize(country.defaultCurrencyCode)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

                    TabView(selection: $introPageIndex) {
                        ForEach(0..<introPageCount, id: \.self) { index in
                            introPageContent(index)
                                .tag(index)
                                .padding(.horizontal, 20)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: min(max(proxy.size.height * 0.64, 430), 560))

                    introPageDots
                        .padding(.top, 4)

                    Spacer(minLength: 18)

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
                title: localized(zh: "2.5D 档案，一眼认出", en: "2.5D profiles, easy to spot", de: "2.5D-Profile, sofort erkennbar"),
                subtitle: localized(zh: "第一位人类和第一只宠物默认获得 2.5D 头像，卡片和首页会保持同一种视觉语言。", en: "The first human and pet get 2.5D avatars by default, matching cards and Home.", de: "Die ersten Profile erhalten standardmäßig 2.5D-Avatare."),
                focusMode: true,
                rows: [
                    (icon: "person.crop.circle.fill", title: localized(zh: "人类头像", en: "Human avatar", de: "Menschen-Avatar"), subtitle: localized(zh: "先自动生成", en: "Auto generated", de: "Automatisch"), tint: Color.goTeal, filled: false),
                    (icon: "pawprint.fill", title: localized(zh: "宠物头像", en: "Pet avatar", de: "Tier-Avatar"), subtitle: localized(zh: "按外貌更新", en: "Matches appearance", de: "Nach Aussehen"), tint: Color(hex: "F59E0B"), filled: false),
                    (icon: "photo.on.rectangle", title: localized(zh: "也可替换", en: "Replace anytime", de: "Ersetzbar"), subtitle: localized(zh: "拍照或相册", en: "Camera or photos", de: "Kamera/Fotos"), tint: Color.goLime, filled: true)
                ]
            )
        case 2:
            introPage(
                title: localized(zh: "今天该做什么，自动排好", en: "Today’s care, sorted", de: "Heute sortiert"),
                subtitle: localized(zh: "Today Focus 会把体重、喂食、用药和提醒放到最该看的地方。", en: "Today Focus brings weight, feeding, medication, and reminders forward.", de: "Today Focus zeigt Gewicht, Futter, Medikamente und Erinnerungen."),
                focusMode: true,
                rows: [
                    (icon: "checklist.checked", title: localized(zh: "今日焦点", en: "Today Focus", de: "Today Focus"), subtitle: localized(zh: "先看最重要", en: "Important first", de: "Wichtiges zuerst"), tint: Color.goBlue, filled: false),
                    (icon: "scalemass.fill", title: localized(zh: "人类体重", en: "Human weight", de: "Menschengewicht"), subtitle: localized(zh: "添加人类后出现", en: "Appears after adding", de: "Nach dem Hinzufügen"), tint: Color.goTeal, filled: false),
                    (icon: "bolt.fill", title: localized(zh: "打卡反馈", en: "Check-in feedback", de: "Check-in Feedback"), subtitle: localized(zh: "椰子奖励", en: "Coconut reward", de: "Kokosnuss"), tint: Color.goLime, filled: true)
                ]
            )
        default:
            introPage(
                title: localized(
                    zh: "照顾，一眼看懂",
                    en: "Care at a glance",
                    de: "Pflege auf einen Blick"
                ),
                subtitle: localized(
                    zh: "给家人、宠物和日常记录一个清爽首页。",
                    en: "One calm home for family, pets, and daily logs.",
                    de: "Ein ruhiger Ort für Familie, Tiere und tägliche Einträge."
                ),
                focusMode: false,
                rows: [
                    (icon: "person.2.fill", title: localized(zh: "添加家人", en: "Add people", de: "Menschen"), subtitle: localized(zh: "谁在照顾", en: "Who helps", de: "Wer hilft"), tint: Color.goBlue, filled: false),
                    (icon: "pawprint.fill", title: localized(zh: "添加宠物", en: "Add pets", de: "Tiere"), subtitle: localized(zh: "生成快捷照护", en: "Quick care ready", de: "Schnelle Pflege"), tint: Color(hex: "F59E0B"), filled: false),
                    (icon: "bolt.heart.fill", title: localized(zh: "完成第一次打卡", en: "First check-in", de: "Erster Check-in"), subtitle: localized(zh: "马上得到反馈", en: "Instant feedback", de: "Sofort Feedback"), tint: Color.goLime, filled: true)
                ]
            )
        }
    }

    private func introPage(
        title: String,
        subtitle: String,
        focusMode: Bool,
        rows: [(icon: String, title: String, subtitle: String, tint: Color, filled: Bool)]
    ) -> some View {
        VStack(spacing: 16) {
            OnboardingAvatarShowcase(isActive: iconPulse && !shouldReduceWork, focusMode: focusMode)
                .frame(height: 230)

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

            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    onboardingStepRow(
                        icon: row.icon,
                        title: row.title,
                        subtitle: row.subtitle,
                        tint: row.tint,
                        usesFilledTint: row.filled
                    )
                }
            }
            .padding(.horizontal, 4)
        }
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
                        : localized(zh: "开始设置", en: "Start setup", de: "Einrichten"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(OnboardingPalette.selectedText)
                    Image(systemName: introPageIndex < introPageCount - 1 ? "chevron.right" : "arrow.right")
                        .font(.system(size: 14, weight: .black))
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
                .foregroundStyle(usesFilledTint ? OnboardingPalette.selectedText : tint)
                .frame(width: 34, height: 34)
                .background(usesFilledTint ? tint : tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(OnboardingPalette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(subtitle)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(OnboardingPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(OnboardingPalette.panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
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

                    OnboardingAvatarShowcase(isActive: iconPulse && !shouldReduceWork, focusMode: true)
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
                        .foregroundStyle(OnboardingPalette.primaryText)
                        .multilineTextAlignment(.center)
                        Text(localized(
                            zh: "添加后，首页马上出现快捷照护入口。",
                            en: "Quick care actions appear on Home right away.",
                            de: "Schnelle Pflege erscheint direkt auf der Startseite."
                        ))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(OnboardingPalette.secondaryText)
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
                                .foregroundStyle(OnboardingPalette.selectedText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Color.goLime, in: Capsule())
                        }

                        Button(localized(zh: "先进入首页", en: "Enter Home First", de: "Erst zur Startseite")) {
                            finishOnboarding()
                        }
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(OnboardingPalette.secondaryText)
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
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .presentationDetents([.large]) // ui-v4: allow first-pet creation wizard
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
                .foregroundStyle(OnboardingPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(OnboardingPalette.panelFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
        )
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

    private func finishOnboarding() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
