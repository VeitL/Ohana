import SwiftUI

struct OhanaGrowthOnboardingOverlay: View {
    let appLanguage: String
    let treeLevel: Int
    let onFinish: () -> Void
    let onSkip: () -> Void

    @State private var stepIndex = 0

    private var steps: [OnboardingStep] {
        [
            OnboardingStep(
                icon: "person.2.fill",
                titleZh: "先建立你的小家",
                titleEn: "Start with your family",
                titleDe: "Beginne mit deiner Familie",
                detailZh: "添加家人和宠物后，首页会变成你的日常照护面板。",
                detailEn: "Add family members and pets, then Home becomes your daily care board.",
                detailDe: "Füge Familie und Tiere hinzu, dann wird Home zur Pflegezentrale."
            ),
            OnboardingStep(
                icon: "checkmark.circle.fill",
                titleZh: "先记录最重要的事",
                titleEn: "Log the essentials first",
                titleDe: "Erfasse zuerst das Wichtigste",
                detailZh: "喂食、喝水、便便和日历是最早解锁的核心功能。",
                detailEn: "Food, water, potty, and the calendar are the first core tools.",
                detailDe: "Futter, Wasser, Toilette und Kalender sind zuerst da."
            ),
            OnboardingStep(
                icon: "tree.fill",
                titleZh: "让生命之树带路",
                titleEn: "Let the Life Tree guide you",
                titleDe: "Der Lebensbaum führt dich",
                detailZh: "照护越稳定，树等级越高，健康、家庭、Oasis 和奖励会逐步打开。",
                detailEn: "Consistent care grows the tree and gradually opens health, family, Oasis, and rewards.",
                detailDe: "Stetige Pflege lässt den Baum wachsen und öffnet Gesundheit, Familie, Oasis und Belohnungen."
            )
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.ohanaPrimaryText.opacity(0.34)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onSkip)

                onboardingPanel(safeBottom: proxy.safeAreaInsets.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .allowsHitTesting(true)
        }
    }

    private func onboardingPanel(safeBottom: CGFloat) -> some View {
        let step = steps[stepIndex]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: step.icon)
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title(language: appLanguage))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(localized(zh: "生命之树 Lv.\(treeLevel)", en: "Life Tree Lv.\(treeLevel)", de: "Lebensbaum Lv.\(treeLevel)"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                }

                Spacer()

                Button(action: onSkip) {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Text(step.detail(language: appLanguage))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == stepIndex ? Color.goPrimary : Color.ohanaControlFill)
                        .frame(width: index == stepIndex ? 22 : 8, height: 8)
                        .animation(GoMotion.feedback, value: stepIndex)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    onSkip()
                } label: {
                    Text(localized(zh: "稍后", en: "Later", de: "Später"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    if stepIndex >= steps.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(GoMotion.feedback) {
                            stepIndex += 1
                        }
                    }
                } label: {
                    Text(stepIndex >= steps.count - 1
                        ? localized(zh: "开始", en: "Start", de: "Start")
                        : localized(zh: "下一步", en: "Next", de: "Weiter"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(18)
        .padding(.bottom, max(8, safeBottom + 6))
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .padding(.horizontal, 6)
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }
}

struct GrowthUnlockFlowTestView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var simulatedLevel = 1
    @State private var simulatedProgress = 0.48
    @State private var showsGuide = false
    @State private var showsStarterCeremony = false
    @State private var unlockToastStatus: GrowthUnlockStatus?
    @State private var unlockToastDismissTask: Task<Void, Never>?
    @State private var growthPulseStatus: GrowthLoopPulseStatus?
    @State private var growthPulseDismissTask: Task<Void, Never>?
    @State private var openedRecommendationStep: GrowthUnlockStep?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        GrowthUnlockProgressCard(
                            currentLevel: simulatedLevel,
                            progressToNextLevel: simulatedProgressToNextLevel,
                            appLanguage: appLanguage
                        )
                        GrowthDailyLoopStrip(
                            currentLevel: simulatedLevel,
                            progressToNextLevel: simulatedProgressToNextLevel,
                            pendingFocusCount: simulatedPendingFocusCount,
                            hasAnyMember: true,
                            appLanguage: appLanguage,
                            onPrimaryAction: simulateDailyCompletion
                        )
                        levelControl
                        onboardingPreview
                        recommendationPreview
                        roadmap
                        featureMatrix
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }

                if let unlockToastStatus {
                    GrowthUnlockToastView(
                        status: unlockToastStatus,
                        appLanguage: appLanguage,
                        onDismiss: dismissUnlockToast,
                        onOpen: {
                            presentRecommendedEntry(for: unlockToastStatus.step)
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(16)
                }

                if let growthPulseStatus {
                    GrowthLoopPulseToastView(
                        status: growthPulseStatus,
                        appLanguage: appLanguage
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(15)
                }

                if showsGuide {
                    OhanaGrowthOnboardingOverlay(
                        appLanguage: appLanguage,
                        treeLevel: simulatedLevel,
                        onFinish: { withAnimation(GoMotion.feedback) { showsGuide = false } },
                        onSkip: { withAnimation(GoMotion.feedback) { showsGuide = false } }
                    )
                    .zIndex(20)
                }

                if showsStarterCeremony {
                    StarterGiftCeremonyOverlay(
                        appLanguage: appLanguage,
                        amount: StarterGiftPolicy.giftAmount,
                        onFinish: { withAnimation(GoMotion.feedback) { showsStarterCeremony = false } }
                    )
                    .zIndex(21)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .onDisappear {
            unlockToastDismissTask?.cancel()
            growthPulseDismissTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "tree.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaCardSurface, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(zh: "成长解锁流程测试", en: "Growth unlock flow test", de: "Wachstums-Test"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(localized(zh: "模拟新手引导、功能锁和树等级节奏", en: "Preview onboarding, feature locks, and tree pacing", de: "Onboarding, Sperren und Baumstufen testen"))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var levelControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localized(zh: "模拟等级", en: "Simulated level", de: "Simulierte Stufe"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("Lv.\(simulatedLevel)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.goPrimary, in: Capsule())
            }

            Stepper(value: $simulatedLevel, in: 0 ... 10) {
                Text(currentStage.title(language: appLanguage))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color(hex: currentStage.tintHex))
            }
            .tint(Color.goPrimary)

            HStack(spacing: 10) {
                Button(action: simulateUpgrade) {
                    Label(
                        localized(zh: "模拟升级", en: "Level up", de: "Stufe hoch"),
                        systemImage: "arrow.up.circle.fill"
                    )
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(simulatedLevel >= 10)
                .opacity(simulatedLevel >= 10 ? 0.55 : 1)

                Button(action: resetSimulation) {
                    Label(
                        localized(zh: "重置", en: "Reset", de: "Zurück"),
                        systemImage: "arrow.counterclockwise"
                    )
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var onboardingPreview: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(GoMotion.feedback) {
                    showsGuide = true
                }
            } label: {
                previewActionRow(
                    icon: "play.circle.fill",
                    title: localized(zh: "播放首次使用引导", en: "Play first-run guide", de: "Ersteinführung starten"),
                    detail: localized(zh: "不写入真实完成状态", en: "Does not change real completion state", de: "Ändert keinen echten Status")
                )
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                withAnimation(GoMotion.feedback) {
                    simulatedLevel = 0
                    showsStarterCeremony = true
                }
            } label: {
                previewActionRow(
                    icon: "gift.fill",
                    title: localized(zh: "播放新人礼包 Lv0", en: "Play starter gift Lv0", de: "Startergeschenk Lv0"),
                    detail: localized(zh: "+50🥥，去 Oasis 注入后升 Lv1", en: "+50🥥, inject in Oasis to reach Lv1", de: "+50🥥, in Oasis für Lv1 einspeisen")
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func previewActionRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                Text(detail)
                    .font(OhanaFont.caption2(.semibold))
            }
            Spacer()
            Image(systemName: "chevron.right").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    @ViewBuilder
    private var recommendationPreview: some View {
        if let openedRecommendationStep {
            HStack(spacing: 10) {
                Image(systemName: "arrowshape.turn.up.right.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color(hex: openedRecommendationStep.tintHex))
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(zh: "推荐入口已命中", en: "Recommended entry selected", de: "Empfohlener Einstieg gewählt"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(GrowthUnlockPolicy.primaryDestinationTitle(for: openedRecommendationStep, language: appLanguage))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color(hex: openedRecommendationStep.tintHex))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text("Lv.\(openedRecommendationStep.requiredLevel)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.goPrimary, in: Capsule())
            }
            .frame(minHeight: 64)
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
    }

    private var roadmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "完整解锁路线", en: "Full unlock path", de: "Kompletter Pfad"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            ForEach(GrowthUnlockPolicy.stages) { step in
                GrowthUnlockStageRow(step: step, currentLevel: simulatedLevel, appLanguage: appLanguage)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var featureMatrix: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "功能入口状态", en: "Feature entry states", de: "Funktionsstatus"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(previewDestinations, id: \.title) { item in
                    let availability = AppFeatureRouteGuard.availability(for: item.destination, currentLevel: simulatedLevel)
                    featureCell(title: item.title, icon: item.icon, availability: availability)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func featureCell(title: String, icon: String, availability: AppFeatureAvailability) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: featureIcon(defaultIcon: icon, availability: availability))
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(featureTint(availability))
                Spacer()
                Text(featureBadgeText(availability))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(featureBadgeForeground(availability))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(featureBadgeBackground(availability), in: Capsule())
            }

            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)

            Text(featureStageText(availability))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var currentStage: GrowthUnlockStep {
        GrowthUnlockPolicy.stages
            .last(where: { simulatedLevel >= $0.requiredLevel }) ?? GrowthUnlockPolicy.stages[0]
    }

    private var simulatedProgressToNextLevel: Double {
        simulatedLevel >= 10 ? 1 : simulatedProgress
    }

    private var simulatedPendingFocusCount: Int {
        max(0, 4 - simulatedLevel / 2)
    }

    private var previewDestinations: [(title: String, icon: String, destination: FMDest)] {
        var destinations: [(title: String, icon: String, destination: FMDest)] = [
            ("每日照护", "sun.max.fill", .featureGroup(.dailyCare)),
            ("健康", "cross.fill", .featureGroup(.healthBody)),
            ("成长档案", "folder.fill", .featureGroup(.archiveMemory)),
            ("家庭事务", "house.fill", .featureGroup(.householdHub)),
            ("Oasis 收益", "tree.fill", .wealthDashboard),
            ("椰子商店", "bag.fill", .coconutShop),
            ("扭蛋机", "circle.grid.cross.fill", .gacha),
            ("家庭周报", "chart.bar.doc.horizontal", .familyWeeklyReport)
        ]
        if PlantFeatureGate.allows(.plants) {
            destinations.insert(("植物", "leaf.fill", .plantsDashboard), at: 5)
        }
        return destinations
    }

    private func featureIcon(defaultIcon: String, availability: AppFeatureAvailability) -> String {
        switch availability {
        case .visible:
            defaultIcon
        case .hiddenLocked:
            "lock.fill"
        case .outOfScope:
            "eye.slash.fill"
        }
    }

    private func featureTint(_ availability: AppFeatureAvailability) -> Color {
        switch availability {
        case let .visible(status), let .hiddenLocked(status):
            Color(hex: status.step.tintHex)
        case .outOfScope:
            Color.ohanaSecondaryText
        }
    }

    private func featureBadgeText(_ availability: AppFeatureAvailability) -> String {
        switch availability {
        case .visible:
            localized(zh: "可用", en: "Open", de: "Offen")
        case let .hiddenLocked(status):
            "Lv.\(status.step.requiredLevel)"
        case .outOfScope:
            localized(zh: "隐藏", en: "Hidden", de: "Verborgen")
        }
    }

    private func featureBadgeForeground(_ availability: AppFeatureAvailability) -> Color {
        switch availability {
        case .visible:
            Color.arkInk
        case let .hiddenLocked(status):
            Color(hex: status.step.tintHex)
        case .outOfScope:
            Color.ohanaSecondaryText
        }
    }

    private func featureBadgeBackground(_ availability: AppFeatureAvailability) -> Color {
        switch availability {
        case .visible:
            Color.goPrimary
        case .hiddenLocked, .outOfScope:
            Color.ohanaControlFill
        }
    }

    private func featureStageText(_ availability: AppFeatureAvailability) -> String {
        switch availability {
        case let .visible(status), let .hiddenLocked(status):
            status.step.title(language: appLanguage)
        case .outOfScope:
            localized(zh: "当前版本不纳入范围", en: "Out of current scope", de: "Nicht im aktuellen Umfang")
        }
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }

    private func simulateUpgrade() {
        let previousLevel = simulatedLevel
        let nextLevel = min(10, simulatedLevel + 1)
        guard nextLevel > previousLevel else { return }

        withAnimation(GoMotion.feedback) {
            simulatedLevel = nextLevel
            simulatedProgress = nextLevel >= 10 ? 1 : 0.08
        }

        guard let step = AppFeatureRouteGuard.newlyUnlockedStages(from: previousLevel, to: nextLevel).last else {
            return
        }
        presentUnlockToast(step: step, currentLevel: nextLevel)
    }

    private func simulateDailyCompletion() {
        guard simulatedLevel < 10 else {
            presentGrowthPulse(level: simulatedLevel, energyDelta: 1, progress: 1)
            return
        }

        let nextProgress = min(1, simulatedProgress + 0.22)
        if nextProgress >= 1 {
            simulateUpgrade()
        } else {
            withAnimation(GoMotion.feedback) {
                simulatedProgress = nextProgress
            }
            presentGrowthPulse(level: simulatedLevel, energyDelta: 1, progress: nextProgress)
        }
    }

    private func resetSimulation() {
        unlockToastDismissTask?.cancel()
        unlockToastDismissTask = nil
        growthPulseDismissTask?.cancel()
        growthPulseDismissTask = nil
        withAnimation(GoMotion.feedback) {
            simulatedLevel = 1
            simulatedProgress = 0.48
            showsGuide = false
            unlockToastStatus = nil
            growthPulseStatus = nil
            openedRecommendationStep = nil
        }
    }

    private func presentUnlockToast(step: GrowthUnlockStep, currentLevel: Int) {
        unlockToastDismissTask?.cancel()
        growthPulseDismissTask?.cancel()
        growthPulseDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            growthPulseStatus = nil
            unlockToastStatus = GrowthUnlockStatus(step: step, currentLevel: currentLevel)
        }
        unlockToastDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3800) {
            dismissUnlockToast()
        }
    }

    private func dismissUnlockToast() {
        unlockToastDismissTask?.cancel()
        unlockToastDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            unlockToastStatus = nil
        }
    }

    private func presentRecommendedEntry(for step: GrowthUnlockStep) {
        dismissUnlockToast()
        withAnimation(GoMotion.feedback) {
            openedRecommendationStep = step
        }
    }

    private func presentGrowthPulse(level: Int, energyDelta: Int, progress: Double) {
        growthPulseDismissTask?.cancel()
        withAnimation(GoMotion.sheetEnter) {
            growthPulseStatus = GrowthLoopPulseStatus(
                currentLevel: level,
                energyDelta: energyDelta,
                progressPercent: min(100, max(0, Int((progress * 100).rounded())))
            )
        }
        growthPulseDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 2600) {
            dismissGrowthPulse()
        }
    }

    private func dismissGrowthPulse() {
        growthPulseDismissTask?.cancel()
        growthPulseDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            growthPulseStatus = nil
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let detailZh: String
    let detailEn: String
    let detailDe: String

    func title(language: String) -> String {
        localized(zh: titleZh, en: titleEn, de: titleDe, language: language)
    }

    func detail(language: String) -> String {
        localized(zh: detailZh, en: detailEn, de: detailDe, language: language)
    }

    private func localized(zh: String, en: String, de: String, language: String) -> String {
        switch language {
        case "en": en
        case "de": de
        default: zh
        }
    }
}
