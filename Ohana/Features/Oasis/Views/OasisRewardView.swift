//
//  OasisRewardView.swift
//  Ohana
//
//  绿洲圣地 — 生命之树动态进化 + 注入能量 + Bento 功能区
//

import SwiftData
import SwiftUI

struct OasisRewardRuntimeModifier: ViewModifier {
    let shouldRunAmbientMotion: Bool
    let currentActiveHumanId: String
    let petsCount: Int
    let humansCount: Int
    let plantsCount: Int
    let electronicPetsCount: Int
    let critterFragmentsCount: Int
    let activeHumanCoconutBalance: Int
    let rulesTrigger: Bool
    let inventoryTrigger: Bool
    let injectEnergyTrigger: Int
    let isEmbeddedPrepared: Bool
    let isEmbeddedVisible: Bool
    let isEmbeddedActive: Bool
    let makeupConfirmationTitle: String
    let makeupConfirmationConfirmTitle: String
    let makeupConfirmationCancelTitle: String
    let makeupConfirmationBinding: Binding<Bool>
    @Binding var confirmationRoute: OasisConfirmationRoute?
    let onAppearAction: () -> Void
    let onDisappearAction: () -> Void
    let onAmbientMotionChanged: (Bool) -> Void
    let onActiveHumanChanged: () -> Void
    let onRefreshOasisEnergy: () -> Void
    let onRefreshFeaturedCritterLifecycle: () -> Void
    let onRefreshRenderSnapshots: () -> Void
    let onInjectTreeEnergy: () -> Void
    let onEmbeddedPreparedChanged: (Bool) -> Void
    let onEmbeddedVisibleChanged: (Bool) -> Void
    let onEmbeddedActiveChanged: (Bool) -> Void
    let onApplyMakeup: (String) -> Void
    let onOpenSheet: (OasisSheetRoute) -> Void

    func body(content: Content) -> some View {
        content
            .modifier(lifecycleModifier)
            .modifier(identityModifier)
            .modifier(makeupConfirmationModifier)
            .modifier(oasisDataRefreshModifier)
            .modifier(sheetTriggerModifier)
            .modifier(injectionTriggerModifier)
            .modifier(embeddedStateModifier)
    }

    private var lifecycleModifier: OasisRewardLifecycleModifier {
        OasisRewardLifecycleModifier(
            onAppearAction: onAppearAction,
            onDisappearAction: onDisappearAction
        )
    }

    private var identityModifier: OasisRewardIdentityModifier {
        OasisRewardIdentityModifier(
            shouldRunAmbientMotion: shouldRunAmbientMotion,
            currentActiveHumanId: currentActiveHumanId,
            onAmbientMotionChanged: onAmbientMotionChanged,
            onActiveHumanChanged: onActiveHumanChanged
        )
    }

    private var makeupConfirmationModifier: OasisRewardMakeupConfirmationModifier {
        OasisRewardMakeupConfirmationModifier(
            makeupConfirmationTitle: makeupConfirmationTitle,
            confirmTitle: makeupConfirmationConfirmTitle,
            cancelTitle: makeupConfirmationCancelTitle,
            makeupConfirmationBinding: makeupConfirmationBinding,
            confirmationRoute: $confirmationRoute,
            onApplyMakeup: onApplyMakeup
        )
    }

    private var oasisDataRefreshModifier: OasisRewardDataRefreshModifier {
        OasisRewardDataRefreshModifier(
            petsCount: petsCount,
            humansCount: humansCount,
            plantsCount: plantsCount,
            electronicPetsCount: electronicPetsCount,
            critterFragmentsCount: critterFragmentsCount,
            activeHumanCoconutBalance: activeHumanCoconutBalance,
            onRefreshOasisEnergy: onRefreshOasisEnergy,
            onRefreshFeaturedCritterLifecycle: onRefreshFeaturedCritterLifecycle,
            onRefreshRenderSnapshots: onRefreshRenderSnapshots
        )
    }

    private var sheetTriggerModifier: OasisRewardSheetTriggerModifier {
        OasisRewardSheetTriggerModifier(
            rulesTrigger: rulesTrigger,
            inventoryTrigger: inventoryTrigger,
            onOpenSheet: onOpenSheet
        )
    }

    private var injectionTriggerModifier: OasisRewardInjectionTriggerModifier {
        OasisRewardInjectionTriggerModifier(
            injectEnergyTrigger: injectEnergyTrigger,
            onInjectTreeEnergy: onInjectTreeEnergy
        )
    }

    private var embeddedStateModifier: OasisRewardEmbeddedStateModifier {
        OasisRewardEmbeddedStateModifier(
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            onEmbeddedPreparedChanged: onEmbeddedPreparedChanged,
            onEmbeddedVisibleChanged: onEmbeddedVisibleChanged,
            onEmbeddedActiveChanged: onEmbeddedActiveChanged
        )
    }
}

private struct OasisRewardLifecycleModifier: ViewModifier {
    let onAppearAction: () -> Void
    let onDisappearAction: () -> Void
    @State private var appearHandoffTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                scheduleAppearHandoff()
            }
            .onDisappear {
                appearHandoffTask?.cancel()
                appearHandoffTask = nil
                onDisappearAction()
            }
    }

    private func scheduleAppearHandoff() {
        appearHandoffTask?.cancel()
        appearHandoffTask = OhanaFrameScheduler.runAfterNextFrame {
            onAppearAction()
            appearHandoffTask = nil
        }
    }
}

private struct OasisRewardIdentityModifier: ViewModifier {
    let shouldRunAmbientMotion: Bool
    let currentActiveHumanId: String
    let onAmbientMotionChanged: (Bool) -> Void
    let onActiveHumanChanged: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: shouldRunAmbientMotion) { _, shouldAnimate in
                onAmbientMotionChanged(shouldAnimate)
            }
            .onChange(of: currentActiveHumanId) { _, _ in
                onActiveHumanChanged()
            }
    }
}

private struct OasisRewardDataRefreshModifier: ViewModifier {
    let petsCount: Int
    let humansCount: Int
    let plantsCount: Int
    let electronicPetsCount: Int
    let critterFragmentsCount: Int
    let activeHumanCoconutBalance: Int
    let onRefreshOasisEnergy: () -> Void
    let onRefreshFeaturedCritterLifecycle: () -> Void
    let onRefreshRenderSnapshots: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: petsCount) { _, _ in onRefreshOasisEnergy() }
            .onChange(of: humansCount) { _, _ in onRefreshOasisEnergy() }
            .onChange(of: plantsCount) { _, _ in onRefreshOasisEnergy() }
            .onChange(of: electronicPetsCount) { _, _ in onRefreshFeaturedCritterLifecycle() }
            .onChange(of: critterFragmentsCount) { _, _ in onRefreshRenderSnapshots() }
            .onChange(of: activeHumanCoconutBalance) { _, _ in onRefreshRenderSnapshots() }
    }
}

private struct OasisRewardSheetTriggerModifier: ViewModifier {
    let rulesTrigger: Bool
    let inventoryTrigger: Bool
    let onOpenSheet: (OasisSheetRoute) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: rulesTrigger) { _, _ in onOpenSheet(.coconutRules) }
            .onChange(of: inventoryTrigger) { _, _ in onOpenSheet(.inventory) }
    }
}

private struct OasisRewardInjectionTriggerModifier: ViewModifier {
    let injectEnergyTrigger: Int
    let onInjectTreeEnergy: () -> Void
    @State private var injectHandoffTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onDisappear {
                injectHandoffTask?.cancel()
                injectHandoffTask = nil
            }
            .onChange(of: injectEnergyTrigger) { _, _ in
                scheduleInjectHandoff()
            }
    }

    private func scheduleInjectHandoff() {
        injectHandoffTask?.cancel()
        injectHandoffTask = OhanaFrameScheduler.runAfterNextFrame {
            onInjectTreeEnergy()
            injectHandoffTask = nil
        }
    }
}

private struct OasisRewardEmbeddedStateModifier: ViewModifier {
    let isEmbeddedPrepared: Bool
    let isEmbeddedVisible: Bool
    let isEmbeddedActive: Bool
    let onEmbeddedPreparedChanged: (Bool) -> Void
    let onEmbeddedVisibleChanged: (Bool) -> Void
    let onEmbeddedActiveChanged: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isEmbeddedPrepared) { _, isPrepared in onEmbeddedPreparedChanged(isPrepared) }
            .onChange(of: isEmbeddedVisible) { _, isVisible in onEmbeddedVisibleChanged(isVisible) }
            .onChange(of: isEmbeddedActive) { _, isActive in onEmbeddedActiveChanged(isActive) }
    }
}

struct OasisRewardMakeupConfirmationModifier: ViewModifier {
    let makeupConfirmationTitle: String
    let confirmTitle: String
    let cancelTitle: String
    let makeupConfirmationBinding: Binding<Bool>
    @Binding var confirmationRoute: OasisConfirmationRoute?
    let onApplyMakeup: (String) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                makeupConfirmationTitle,
                isPresented: makeupConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button(confirmTitle) {
                    if let date = confirmationRoute?.makeupDate {
                        onApplyMakeup(date)
                    }
                    confirmationRoute = nil
                }
                Button(cancelTitle, role: .cancel) {
                    confirmationRoute = nil
                }
            }
    }
}

struct OasisEmbeddedLayoutMetrics: Equatable {
    let topPadding: CGFloat
    let sectionSpacing: CGFloat
    let bottomPadding: CGFloat
    let treeCardHeight: CGFloat
    let treeVisualHeight: CGFloat
    let bentoGridHeight: CGFloat

    var totalHeight: CGFloat {
        topPadding + treeCardHeight + sectionSpacing + bentoGridHeight + bottomPadding
    }
}

enum OasisEmbeddedLayoutPolicy {
    static let compactTreeStageChromeHeight: CGFloat = 210

    static func metrics(availableHeight: CGFloat) -> OasisEmbeddedLayoutMetrics {
        let height = max(0, availableHeight)
        guard height > 0 else {
            return OasisEmbeddedLayoutMetrics(
                topPadding: 0,
                sectionSpacing: 0,
                bottomPadding: 0,
                treeCardHeight: 0,
                treeVisualHeight: 0,
                bentoGridHeight: 0
            )
        }

        let topPadding: CGFloat = height >= 620 ? 4 : 2
        let sectionSpacing: CGFloat = height >= 620 ? 8 : 6
        let bottomPadding: CGFloat = height >= 620 ? 8 : 6
        let chromeHeight = topPadding + sectionSpacing + bottomPadding
        let contentHeight = max(0, height - chromeHeight)
        let idealBentoHeight = min(124, max(92, contentHeight * 0.19))
        let bentoGridHeight = min(idealBentoHeight, contentHeight * 0.34)
        let treeCardHeight = max(0, contentHeight - bentoGridHeight)
        let idealTreeVisualHeight = min(260, max(170, treeCardHeight * 0.58))
        let treeVisualHeight = min(
            idealTreeVisualHeight,
            max(0, treeCardHeight - compactTreeStageChromeHeight)
        )

        return OasisEmbeddedLayoutMetrics(
            topPadding: topPadding,
            sectionSpacing: sectionSpacing,
            bottomPadding: bottomPadding,
            treeCardHeight: treeCardHeight,
            treeVisualHeight: treeVisualHeight,
            bentoGridHeight: bentoGridHeight
        )
    }
}

final class OasisTreeHarvestBuffer {
    var pendingIndices: Set<Int> = []
    var commitTask: Task<Void, Never>?
}

struct OasisRewardView: View {
    var hideToolbar: Bool = false
    var rulesTrigger: Bool = false
    var inventoryTrigger: Bool = false
    var injectEnergyTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @StateObject var liveDataStore = OasisRewardLiveDataStore()

    @State var treeScale: CGFloat = 1.0
    @State var treeGlow: CGFloat = 0.4
    @State var activeSheetRoute: OasisSheetRoute?
    @State var activeFullScreenRoute: OasisFullScreenRoute?
    @State var activeOverlayRoute: OasisOverlayRoute?
    @State var activeBentoFeatureInfo: OasisBentoFeatureInfo?
    @State var confirmationRoute: OasisConfirmationRoute?
    @State var showCritterNest = false
    @State var critterNestPopupProgress: CGFloat = 0
    @State var energyParticles: [EnergyParticle] = []
    // 模块六：打卡日历
    @State var checkedInDates: Set<String> = [] // "yyyy-MM-dd" 格式
    @State var makeupPackCount: Int = 0 // 补签包数量
    @State var makeupDates: Set<String> = [] // 补签过的日期集合
    @State var lastClaimedMilestone: Int = 0
    @State var calendarDisplayMonth: Date = .init()
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""
    @Environment(\.colorScheme) var colorScheme
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared

    var isMaterial: Bool { false }
    var matBg: Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    var matAccent: Color { Color(hex: "FF5A00") }
    @State var lastLevel: TreeLevel = .lv0
    @State var isInjecting: Bool = false
    @State var treeInjectionLocked = false
    @State var treeInjectionProgress: CGFloat = 0
    @State var treeInjectionBoost: CGFloat = 0.026
    @State var injectionPulseToken = 0
    @State var levelUpPulse = false
    @State var levelUpBadgeVisible = false
    @State var openingUpgradeCoconutId: UUID?
    @State var critterActionPulseId: UUID?
    @State var lastCritterInteractionOutcome: OasisCritterInteractionOutcome?
    @State var rescuingCritterId: UUID?
    // 任务7：环境光晕 + 树上每日椰子
    @State var glowBreathing: Bool = false
    @State var dailyTreeCoconutCount = 0
    @State var harvestedCoconutIndices: Set<Int> = []
    @State var treeVisualEnergyOverride: Int?
    @State var coconutBalanceVisualOverride: Int?
    @State var isVisible = false
    @State var isVisibleStatePrepared = false
    @State var actionSnapshot = OasisRewardActionSnapshot()
    @State var bentoSnapshot = OasisBentoSnapshot()
    @State var critterRenderSnapshots: [UUID: OasisCritterRenderSnapshot] = [:]
    @State var treePassiveIncomeAmount = 0
    @State var preparedWorkTask: Task<Void, Never>?
    @State var visibleWorkTask: Task<Void, Never>?
    @State var renderSnapshotTask: Task<Void, Never>?
    @State var treeCommandTask: Task<Void, Never>?
    @State var upgradeRewardTask: Task<Void, Never>?
    @State var critterCommandTask: Task<Void, Never>?
    @State var checkInCommandTask: Task<Void, Never>?
    @State var critterNestOpenTask: Task<Void, Never>?
    @State var critterNestCloseTask: Task<Void, Never>?
    @State var injectionResetTask: Task<Void, Never>?
    @State var levelUpFeedbackTask: Task<Void, Never>?
    @State var particleCleanupTask: Task<Void, Never>?
    @State var critterPulseCleanupTask: Task<Void, Never>?
    @State var critterOutcomeCleanupTask: Task<Void, Never>?
    @State var rescueBusyCleanupTask: Task<Void, Never>?
    @State var treeStageAppearTask: Task<Void, Never>?
    @State var treeHarvestBuffer = OasisTreeHarvestBuffer()
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage(OasisPlantDecorStore.equippedSceneKey) var equippedPlantDecorScene = ""
    @AppStorage(OasisPlantDecorStore.equippedPotSkinKey) var equippedPlantPotSkin = ""

    var treeMgr: OasisTreeManaging { appServices.oasisTree }
    var l: L10n { L10n(appLanguage) }
    var liveData: OasisRewardLiveDataSnapshot { liveDataStore.snapshot }
    var pets: [Pet] { liveData.pets }
    var humans: [Human] { liveData.humans }
    var plants: [Plant] { liveData.plants }
    var upgradeCoconuts: [OasisUpgradeCoconut] { liveData.upgradeCoconuts }
    var electronicPets: [OasisElectronicPet] { liveData.electronicPets }
    var critterFragments: [OasisCritterFragmentBalance] { liveData.critterFragments }
    var plantAmbienceSnapshot: OasisPlantAmbienceSnapshot {
        OasisPlantAmbiencePolicy.snapshot(
            plantCareEventCount: liveData.plantCareLedgerEventCount,
            currentLevel: treeVisualLevel.rawValue,
            equippedSceneID: equippedPlantDecorScene,
            equippedPotSkinID: equippedPlantPotSkin
        )
    }

    var commandExecutor: OasisRewardCommandExecutor {
        OasisRewardCommandExecutor(
            context: modelContext,
            rewards: appServices.oasisRewards,
            shopInventory: appServices.shopInventory
        )
    }

    var shopUnlockLevel: Int {
        GrowthUnlockPolicy.status(for: FMDest.coconutShop, currentLevel: 0).step.requiredLevel
    }

    var achievementUnlockLevel: Int {
        GrowthUnlockPolicy.status(for: PetFeature.achievements, currentLevel: 0).step.requiredLevel
    }

    var gachaUnlockLevel: Int {
        GrowthUnlockPolicy.status(for: FMDest.gacha, currentLevel: 0).step.requiredLevel
    }

    var critterUnlockLevel: Int {
        OasisUpgradeRewardCatalog.critter(id: OasisUpgradeRewardCatalog.firstCritterId)?.sourceLevel ?? 10
    }

    var openedUpgradeReward: OasisOpenedUpgradeReward? {
        activeOverlayRoute?.upgradeReward
    }

    func openSheet(_ route: OasisSheetRoute) {
        if lockedLevel(for: route) != nil {
            OhanaFeedback.error()
            return
        }
        GrowthNewFeatureStore.markVisited(route)
        activeSheetRoute = route
    }

    func lockedLevel(for route: OasisSheetRoute) -> Int? {
        switch route {
        case .coconutShop:
            lockedLevel(requiredLevel: shopUnlockLevel)
        case .achievements:
            lockedLevel(requiredLevel: achievementUnlockLevel)
        case .gacha:
            lockedLevel(requiredLevel: gachaUnlockLevel)
        case .critterCodex:
            lockedLevel(requiredLevel: critterUnlockLevel)
        case .coconutRules, .growthRoadmap, .inventory, .checkInDetail:
            nil
        }
    }

    func lockedLevel(requiredLevel: Int) -> Int? {
        treeMgr.treeLevel.rawValue >= requiredLevel ? nil : requiredLevel
    }

    func openFullScreen(_ route: OasisFullScreenRoute) {
        activeFullScreenRoute = route
    }

    func presentUpgradeReward(_ reward: OasisOpenedUpgradeReward) {
        activeOverlayRoute = .upgradeReward(reward: reward)
    }

    func dismissUpgradeReward() {
        activeOverlayRoute = nil
    }

    var treeVisualTotalEnergy: Int {
        treeVisualEnergyOverride ?? treeMgr.totalEnergy
    }

    var treeVisualLevel: TreeLevel {
        treeMgr.treeLevel(forTotalEnergy: treeVisualTotalEnergy)
    }

    var treeVisualProgressToNextLevel: Double {
        treeMgr.progressToNextLevel(forTotalEnergy: treeVisualTotalEnergy)
    }

    var treeVisualNextLevelThreshold: Int {
        treeMgr.nextLevelThreshold(forTotalEnergy: treeVisualTotalEnergy)
    }

    var pendingUpgradeCoconuts: [OasisUpgradeCoconut] {
        upgradeCoconuts
            .filter { !$0.isOpened }
            .sorted { $0.level < $1.level }
    }

    var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId && !$0.hasPassedAway }
    }

    var activeHumanCoconutBalance: Int {
        if let coconutBalanceVisualOverride {
            return coconutBalanceVisualOverride
        }
        guard let activeHuman else { return 0 }
        if actionSnapshot.activeCoconutBalance > 0 || actionSnapshot.canInjectCoconuts != nil {
            return actionSnapshot.activeCoconutBalance
        }
        return activeHuman.coconutBalance
    }

    var canInjectTreeEnergy: Bool {
        treeInjectionUnavailableReason == nil
    }

    var hasAvailableTreeInjection: Bool {
        hasEnoughCoconutsForTreeInjection &&
            treeMgr.canUseInjectionPackage(cost: OasisTreeEnergyInjectionPolicy.starterPackageCost)
    }

    var hasEnoughCoconutsForTreeInjection: Bool {
        actionSnapshot.canInjectCoconuts ??
            (activeHumanCoconutBalance >= OasisTreeEnergyInjectionPolicy.starterPackageCost)
    }

    var treeInjectionUnavailableReason: String? {
        if treeInjectionLocked {
            return l.tr(zh: "注入中", en: "Injecting", de: "Wird eingespeist")
        }
        if !hasEnoughCoconutsForTreeInjection {
            return l.tr(zh: "椰子不足", en: "Not enough coconuts", de: "Nicht genug Kokosnüsse")
        }
        return nil
    }

    var contentTopInset: CGFloat {
        hideToolbar ? 32 : 64
    }

    var treeSceneTopPadding: CGFloat {
        hideToolbar ? 10 : 12
    }

    var shouldRunAmbientMotion: Bool {
        let isMotionEligible = !hideToolbar || isEmbeddedActive
        return workloadPolicy.shouldAnimate(isVisible: isVisible && isVisibleStatePrepared && isMotionEligible)
    }

    var interactionMotionBudget: OhanaMotionBudget {
        workloadPolicy.interactionMotionBudget(
            isVisible: (isVisible || shouldTreatEmbeddedAsVisible) && isOasisPrepared
        )
    }

    var isOasisPrepared: Bool {
        isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive
    }

    var shouldTreatEmbeddedAsVisible: Bool {
        isEmbeddedVisible || isEmbeddedActive
    }

    var treeInjectionVisualScale: CGFloat {
        1 + treeInjectionProgress * treeInjectionBoost
    }

    var makeupConfirmationTitle: String {
        confirmationRoute?.makeupDate.map {
            l.tr(zh: "补签 \($0)？", en: "Make up \($0)?", de: "\($0) nachtragen?")
        } ?? ""
    }

    var makeupConfirmationConfirmTitle: String {
        l.tr(
            zh: "消耗 1 个补签包确认补签",
            en: "Use 1 makeup pack",
            de: "1 Nachtragspaket nutzen"
        )
    }

    var makeupConfirmationCancelTitle: String {
        l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")
    }

    var makeupConfirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmationRoute != nil },
            set: { newValue in
                if !newValue {
                    confirmationRoute = nil
                }
            }
        )
    }

    struct EnergyParticle: Identifiable {
        let id = UUID()
        var offsetX: CGFloat = .random(in: -80 ... 80)
        var offsetY: CGFloat = 0
        var opacity: Double = 1.0
    }
}

#Preview {
    OasisRewardView()
        .modelContainer(SharedModelContainer.make())
}
