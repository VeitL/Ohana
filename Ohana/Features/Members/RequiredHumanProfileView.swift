import SwiftUI
import UIKit

private enum RequiredHumanIntroPalette {
    static let primaryText = Color.goCardWhite.opacity(0.94)
    static let secondaryText = Color.goCardWhite.opacity(0.64)
    static let tertiaryText = Color.goCardWhite.opacity(0.42)
    static let panelFill = Color.goCardWhite.opacity(0.08)
    static let panelStroke = Color.goCardWhite.opacity(0.12)
    static let mutedFill = Color.goCardWhite.opacity(0.08)
    static let cardShadow = Color.arkInk.opacity(0.28)
    static let selectedText = Color.arkInk
}

struct RequiredHumanProfileView: View {
    let onHumanSaved: (Human) -> Void

    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isCreatingProfile = false
    @State private var savedHuman: Human?
    @State private var introPageIndex = 0
    @State private var introDragOffset: CGFloat = 0
    @State private var flipProgress: CGFloat = 0
    @State private var flipTask: Task<Void, Never>?
    @State private var isFlippingToProfile = false
    @State private var isProfilePrepared = false

    private let introPageCount = 3

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

    var body: some View {
        NavigationStack {
            ZStack {
                GoIslandWizardBackdrop()

                if !isCreatingProfile || isFlippingToProfile {
                    introFlow
                        .opacity(introSideOpacity)
                        .allowsHitTesting(!isCreatingProfile && !isFlippingToProfile)
                        .transition(.identity)
                }

                if isCreatingProfile || isProfilePrepared {
                    profileWizard
                        .opacity(profileSideOpacity)
                        .allowsHitTesting(isCreatingProfile && !isFlippingToProfile)
                        .transition(.identity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onDisappear {
            flipTask?.cancel()
        }
    }

    private var profileWizard: some View {
        AddHumanWizardView(
            onComplete: {
                if let savedHuman {
                    onHumanSaved(savedHuman)
                }
            },
            onCancel: {
                returnToIntro()
            },
            onHumanSaved: { human in
                savedHuman = human
            },
            presentationStyle: .onboarding
        )
        .environment(\.memberCreationCardFlipProgress, profileCardFlipProgress)
    }

    private var introFlow: some View {
        GeometryReader { proxy in
            let cardWidth = MemberCreationCardLayout.cardWidth(in: proxy.size.width)
            let cardHeight = MemberCreationCardLayout.cardHeight(
                in: proxy.size.height,
                includesTopChrome: false
            )
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                introCard(width: cardWidth)
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(introCardFlipAngle),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.78
                    )
                introActions(width: cardWidth)
                    .opacity(introSideOpacity)
                    .allowsHitTesting(!isCardFlipActive && !isCreatingProfile)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MemberCreationCardLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func introCard(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            introHeader
                .padding(.horizontal, 22)
                .padding(.top, 22)

            introPager
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            introPageDots
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
        }
        .frame(width: width)
        .background(RequiredHumanIntroPalette.panelFill, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                .strokeBorder(RequiredHumanIntroPalette.panelStroke, lineWidth: 1)
        )
        .shadow(color: RequiredHumanIntroPalette.cardShadow, radius: 24, y: 16) // ui-v4: allow required human onboarding card lift
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
        .gesture(introSwipeGesture(pageWidth: width))
        .accessibilityElement(children: .contain)
    }

    private var introHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                    .fill(Color(hex: "0C1640"))
                    .frame(width: 38, height: 38)
                Image(systemName: "heart.text.square.fill")
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localized(
                    zh: "欢迎来到 Ohana",
                    en: "Welcome to Ohana",
                    de: "Willkommen bei Ohana"
                ))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(RequiredHumanIntroPalette.primaryText)
                .lineLimit(1)

                Text(localized(
                    zh: "左右滑动了解核心体验",
                    en: "Swipe through the essentials",
                    de: "Wische durch die Grundlagen"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(RequiredHumanIntroPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
    }

    private var introPager: some View {
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

    private func introActions(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Button(action: advanceFromIntro) {
                HStack(spacing: 8) {
                    Text(introPageIndex < introPageCount - 1
                        ? localized(zh: "下一页", en: "Next", de: "Weiter")
                        : localized(zh: "建立本人档案", en: "Create profile", de: "Profil erstellen"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Image(systemName: introPageIndex < introPageCount - 1 ? "chevron.right" : "arrow.right")
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .accessibilityHidden(true)
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(RequiredHumanIntroPalette.selectedText)
                .frame(width: width, height: 54)
                .background(Color.goLime, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isFlippingToProfile)
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
                subtitle: localized(
                    zh: "照顾会获得椰子，推动生命之树和 Oasis 成长。",
                    en: "Care earns coconuts and grows the Life Tree and Oasis.",
                    de: "Pflege bringt Kokosnüsse und lässt Lebensbaum und Oase wachsen."
                ),
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
                subtitle: localized(
                    zh: "体重、用药、提醒和趋势，帮你看清长期变化。",
                    en: "Weight, medication, reminders, and trends show what changes over time.",
                    de: "Gewicht, Medikamente, Erinnerungen und Trends zeigen Veränderungen."
                ),
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
                subtitle: localized(
                    zh: "人类、宠物、植物，都放在同一个家里管理。",
                    en: "Humans, pets, and plants live in one shared care home.",
                    de: "Menschen, Tiere und Pflanzen bleiben in einem Pflegezuhause."
                ),
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
            heroGlyphCluster(primaryIcon: heroIcon, tint: tint, badges: badges)
                .frame(height: 218)

            VStack(spacing: 10) {
                Text(title)
                    .font(OhanaFont.largeTitle(.black))
                    .foregroundStyle(RequiredHumanIntroPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(RequiredHumanIntroPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)

            HStack(spacing: 8) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    badgePill(icon: badge.icon, title: badge.title, tint: tint)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func heroGlyphCluster(
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

                Circle()
                    .fill(tint)
                    .frame(width: centerSize, height: centerSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.goCardWhite.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.34), radius: 18, y: 10) // ui-v4: allow required human hero glyph depth

                Image(systemName: primaryIcon)
                    .font(OhanaFont.adaptive(size: 54, weight: .black))
                    .foregroundStyle(RequiredHumanIntroPalette.selectedText)
                    .symbolRenderingMode(.monochrome)
                    .accessibilityHidden(true)

                ForEach(Array(badges.enumerated()), id: \.offset) { index, badge in
                    floatingGlyph(icon: badge.icon, tint: tint)
                        .offset(heroGlyphOffset(index: index, width: width, height: height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func floatingGlyph(icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(OhanaFont.adaptive(size: 19, weight: .black))
            .foregroundStyle(tint)
            .frame(width: 54, height: 54)
            .background(RequiredHumanIntroPalette.mutedFill, in: Circle())
            .overlay(Circle().strokeBorder(RequiredHumanIntroPalette.panelStroke, lineWidth: 1))
            .accessibilityHidden(true)
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

    private func badgePill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(RequiredHumanIntroPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 8)
        .background(RequiredHumanIntroPalette.mutedFill, in: Capsule())
        .overlay(Capsule().strokeBorder(RequiredHumanIntroPalette.panelStroke, lineWidth: 1))
    }

    private var introPageDots: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< introPageCount, id: \.self) { index in
                Capsule()
                    .fill(index == introPageIndex ? Color.goLime : RequiredHumanIntroPalette.mutedFill)
                    .frame(width: index == introPageIndex ? 24 : 7, height: 7)
                    .animation(GoMotion.feedback, value: introPageIndex)
            }
        }
    }

    private func advanceFromIntro() {
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
        flipProgress = 0
        isProfilePrepared = true
        isFlippingToProfile = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        flipTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 20 : 70) {
            withAnimation(flipAnimation) {
                flipProgress = 1
            }
            flipTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: flipDurationMilliseconds) {
                isCreatingProfile = true
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
                isCreatingProfile = false
                isFlippingToProfile = false
                isProfilePrepared = false
                introDragOffset = 0
            }
        }
    }

    private func localized(zh: String, en: String, de: String) -> String {
        AppLocalizedText(zh: zh, en: en, de: de).resolve(languageCode)
    }
}
