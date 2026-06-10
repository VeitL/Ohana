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
            .onAppear(perform: onAppearAction)
            .onDisappear(perform: onDisappearAction)
            .onChange(of: shouldRunAmbientMotion) { _, shouldAnimate in
                onAmbientMotionChanged(shouldAnimate)
            }
            .onChange(of: currentActiveHumanId) { _, _ in
                onActiveHumanChanged()
            }
            .modifier(makeupConfirmationModifier)
            .onChange(of: petsCount) { onRefreshOasisEnergy() }
            .onChange(of: humansCount) { onRefreshOasisEnergy() }
            .onChange(of: plantsCount) { onRefreshOasisEnergy() }
            .onChange(of: electronicPetsCount) { _, _ in onRefreshFeaturedCritterLifecycle() }
            .onChange(of: critterFragmentsCount) { _, _ in onRefreshRenderSnapshots() }
            .onChange(of: activeHumanCoconutBalance) { _, _ in onRefreshRenderSnapshots() }
            .onChange(of: rulesTrigger) { _, _ in onOpenSheet(.coconutRules) }
            .onChange(of: inventoryTrigger) { _, _ in onOpenSheet(.inventory) }
            .onChange(of: injectEnergyTrigger) { _, _ in onInjectTreeEnergy() }
            .onChange(of: isEmbeddedPrepared) { _, isPrepared in onEmbeddedPreparedChanged(isPrepared) }
            .onChange(of: isEmbeddedVisible) { _, isVisible in onEmbeddedVisibleChanged(isVisible) }
            .onChange(of: isEmbeddedActive) { _, isActive in onEmbeddedActiveChanged(isActive) }
    }

    var makeupConfirmationModifier: some ViewModifier {
        OasisRewardMakeupConfirmationModifier(
            makeupConfirmationTitle: makeupConfirmationTitle,
            confirmTitle: makeupConfirmationConfirmTitle,
            cancelTitle: makeupConfirmationCancelTitle,
            makeupConfirmationBinding: makeupConfirmationBinding,
            confirmationRoute: $confirmationRoute,
            onApplyMakeup: onApplyMakeup
        )
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
    @State var lastLevel: TreeLevel = .lv1
    @State var isInjecting: Bool = false
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
    @State var treeHarvestBuffer = OasisTreeHarvestBuffer()
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code

    var treeMgr: OasisTreeManaging { appServices.oasisTree }
    var l: L10n { L10n(appLanguage) }
    var liveData: OasisRewardLiveDataSnapshot { liveDataStore.snapshot }
    var pets: [Pet] { liveData.pets }
    var humans: [Human] { liveData.humans }
    var plants: [Plant] { liveData.plants }
    var upgradeCoconuts: [OasisUpgradeCoconut] { liveData.upgradeCoconuts }
    var electronicPets: [OasisElectronicPet] { liveData.electronicPets }
    var critterFragments: [OasisCritterFragmentBalance] { liveData.critterFragments }
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
        activeSheetRoute = route
    }

    func lockedLevel(for route: OasisSheetRoute) -> Int? {
        switch route {
        case .coconutShop:
            lockedLevel(requiredLevel: shopUnlockLevel)
        case .gacha:
            lockedLevel(requiredLevel: gachaUnlockLevel)
        case .critterCodex:
            lockedLevel(requiredLevel: critterUnlockLevel)
        case .coconutRules, .achievements, .inventory, .checkInDetail:
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
        humans.first { $0.id.uuidString == currentActiveHumanId }
    }

    var activeHumanCoconutBalance: Int {
        if let coconutBalanceVisualOverride {
            return coconutBalanceVisualOverride
        }
        return actionSnapshot.activeCoconutBalance > 0
            ? actionSnapshot.activeCoconutBalance
            : (activeHuman?.coconutBalance ?? humans.reduce(0) { $0 + $1.coconutBalance })
    }

    var canInjectTreeEnergy: Bool {
        actionSnapshot.canInjectCoconuts ?? (activeHumanCoconutBalance >= 80)
    }

    var contentTopInset: CGFloat {
        hideToolbar ? 32 : 64
    }

    var treeSceneTopPadding: CGFloat {
        hideToolbar ? 10 : 12
    }

    var shouldRunAmbientMotion: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible && isVisibleStatePrepared)
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
