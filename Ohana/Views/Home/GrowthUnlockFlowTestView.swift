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
                detailZh: "照护越稳定，树等级越高，健康、家庭、植物和奖励会逐步打开。",
                detailEn: "Consistent care grows the tree and gradually opens health, family, plants, and rewards.",
                detailDe: "Stetige Pflege lässt den Baum wachsen und öffnet Gesundheit, Familie, Pflanzen und Belohnungen."
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
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 38, height: 38)
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
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 6)
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct GrowthUnlockFlowTestView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var simulatedLevel = 1
    @State private var showsGuide = false
    @State private var unlockToastStatus: GrowthUnlockStatus?
    @State private var unlockToastDismissTask: Task<Void, Never>?

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
                        levelControl
                        onboardingPreview
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
                        onDismiss: dismissUnlockToast
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(16)
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
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .onDisappear {
            unlockToastDismissTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 20, weight: .black))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            Stepper(value: $simulatedLevel, in: 1...10) {
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var onboardingPreview: some View {
        Button {
            withAnimation(GoMotion.feedback) {
                showsGuide = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18, weight: .black))
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(zh: "播放首次使用引导", en: "Play first-run guide", de: "Ersteinführung starten"))
                        .font(OhanaFont.callout(.black))
                    Text(localized(zh: "不写入真实完成状态", en: "Does not change real completion state", de: "Ändert keinen echten Status"))
                        .font(OhanaFont.caption2(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .black))
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var featureMatrix: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "功能入口状态", en: "Feature entry states", de: "Funktionsstatus"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(previewDestinations, id: \.title) { item in
                    let status = GrowthUnlockPolicy.status(for: item.destination, currentLevel: simulatedLevel)
                    featureCell(title: item.title, icon: item.icon, status: status)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func featureCell(title: String, icon: String, status: GrowthUnlockStatus) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: status.isUnlocked ? icon : "lock.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(hex: status.step.tintHex))
                Spacer()
                Text(status.isUnlocked ? localized(zh: "可用", en: "Open", de: "Offen") : "Lv.\(status.step.requiredLevel)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(status.isUnlocked ? Color.arkInk : Color(hex: status.step.tintHex))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(status.isUnlocked ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }

            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)

            Text(status.step.title(language: appLanguage))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var currentStage: GrowthUnlockStep {
        GrowthUnlockPolicy.stages
            .last(where: { simulatedLevel >= $0.requiredLevel }) ?? GrowthUnlockPolicy.stages[0]
    }

    private var simulatedProgressToNextLevel: Double {
        simulatedLevel >= 10 ? 1 : 0.48
    }

    private var previewDestinations: [(title: String, icon: String, destination: FMDest)] {
        [
            ("每日照护", "sun.max.fill", .featureGroup(.dailyCare)),
            ("健康", "cross.fill", .featureGroup(.healthBody)),
            ("成长档案", "folder.fill", .featureGroup(.archiveMemory)),
            ("家庭事务", "house.fill", .featureGroup(.householdHub)),
            ("植物", "leaf.fill", .plantsDashboard),
            ("椰子商店", "bag.fill", .coconutShop),
            ("扭蛋机", "circle.grid.cross.fill", .gacha),
            ("家庭周报", "chart.bar.doc.horizontal", .familyWeeklyReport)
        ]
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }

    private func simulateUpgrade() {
        let previousLevel = simulatedLevel
        let nextLevel = min(10, simulatedLevel + 1)
        guard nextLevel > previousLevel else { return }

        withAnimation(GoMotion.feedback) {
            simulatedLevel = nextLevel
        }

        guard let step = GrowthUnlockPolicy.newlyUnlockedStages(from: previousLevel, to: nextLevel).last else {
            return
        }
        presentUnlockToast(step: step, currentLevel: nextLevel)
    }

    private func resetSimulation() {
        unlockToastDismissTask?.cancel()
        unlockToastDismissTask = nil
        withAnimation(GoMotion.feedback) {
            simulatedLevel = 1
            showsGuide = false
            unlockToastStatus = nil
        }
    }

    private func presentUnlockToast(step: GrowthUnlockStep, currentLevel: Int) {
        unlockToastDismissTask?.cancel()
        withAnimation(GoMotion.sheetEnter) {
            unlockToastStatus = GrowthUnlockStatus(step: step, currentLevel: currentLevel)
        }
        unlockToastDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3_800) {
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
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}
