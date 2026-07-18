//
//  OasisCritterViews.swift
//  Ohana
//
//  Electronic pet collection, milestone motivation, and lightweight care UI.
//

import SwiftData
import SwiftUI
import UIKit

struct OasisCritterIllustration: View {
    let catalogId: String
    var locked: Bool = false
    var size: CGFloat = 96
    var critter: OasisElectronicPet?
    var appearanceStageOverride: Int?

    var body: some View {
        ZStack {
            if let image = OasisCritterAssetResolver.image(
                catalogID: catalogId,
                stage: resolvedAppearanceStage
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.25)
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .frame(width: size, height: size)
        .grayscale(locked ? 1 : 0)
        .opacity(locked ? 0.42 : 1)
        .overlay {
            if locked {
                Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(.system(size: max(16, size * 0.18), weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: max(30, size * 0.32), height: max(30, size * 0.32))
                    .background(Color.goPrimary, in: Circle())
                    .offset(x: size * 0.28, y: -size * 0.28)
            }
        }
        .accessibilityHidden(true)
    }

    private var resolvedAppearanceStage: Int {
        if let appearanceStageOverride {
            max(1, min(OasisCritterPresentationRules.maxAppearanceStage, appearanceStageOverride))
        } else if let critter {
            max(
                max(1, min(OasisCritterPresentationRules.maxAppearanceStage, critter.appearanceStage)),
                OasisCritterPresentationRules.appearanceStage(forLevel: critter.level)
            )
        } else {
            1
        }
    }
}

nonisolated enum OasisCritterAssetResolver {
    static let stageSuffixes = ["Baby", "Child", "Teen", "Adult", "Elder"]

    @MainActor
    static func image(catalogID: String, stage: Int) -> UIImage? {
        assetCandidates(catalogID: catalogID, stage: stage)
            .lazy
            .compactMap { UIImage(named: $0) }
            .first
    }

    static func assetCandidates(catalogID: String, stage: Int) -> [String] {
        let normalizedStage = max(1, min(stageSuffixes.count, stage))
        let suffix = stageSuffixes[normalizedStage - 1]
        let baseName = OasisUpgradeRewardCatalog.critter(id: catalogID)?.assetName ?? "CritterLumo"
        return [
            "\(baseName)\(suffix)",
            "\(baseName)Baby",
            "CritterLumo\(suffix)",
            "CritterLumoBaby"
        ]
    }
}

enum OasisCritterViewMode: Equatable {
    case codex
    case nest
}

struct CompanionGrowthConfirmation: Identifiable {
    enum Kind {
        case awaken
        case starUpgrade
    }

    let kind: Kind
    let catalogID: String
    let critterID: UUID?
    let companionName: String
    let fundingPlan: CompanionFundingPlan

    var id: String {
        switch kind {
        case .awaken: "awaken:\(catalogID)"
        case .starUpgrade: "star:\(critterID?.uuidString ?? catalogID)"
        }
    }
}

struct OasisCritterCodexView: View {
    var mode: OasisCritterViewMode = .codex
    var initialCatalogId: String?
    var isPopup: Bool = false
    var onClose: (() -> Void)?
    let humans: [Human]
    let electronicPets: [OasisElectronicPet]
    let fragments: [OasisCritterFragmentBalance]
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""

    @State var selectedCatalogId = OasisUpgradeRewardCatalog.firstCritterId
    @State var focusedCodexCatalogId: String?
    @State var pulseCatalogId: String?
    @State var lastInteractionOutcome: OasisCritterInteractionOutcome?
    @State var pendingGrowthConfirmation: CompanionGrowthConfirmation?
    @State var rescuingCritterId: UUID?
    var treeMgr: OasisTreeManaging { appServices.oasisTree }
    @State var renderSnapshots: [UUID: OasisCritterRenderSnapshot] = [:]
    @State var featuredDisplayOverrides: [UUID: Bool] = [:]
    @State var lifecycleRefreshTask: Task<Void, Never>?
    @State var renderSnapshotTask: Task<Void, Never>?
    @State var critterCommandTasks: [String: Task<Void, Never>] = [:]
    @State var pulseCleanupTask: Task<Void, Never>?
    @State var rescueBusyCleanupTask: Task<Void, Never>?
    @State var outcomeCleanupTask: Task<Void, Never>?

    init(
        mode: OasisCritterViewMode = .codex,
        initialCatalogId: String? = nil,
        isPopup: Bool = false,
        onClose: (() -> Void)? = nil,
        humans: [Human] = [],
        electronicPets: [OasisElectronicPet] = [],
        fragments: [OasisCritterFragmentBalance] = [],
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        self.mode = mode
        self.initialCatalogId = initialCatalogId
        self.isPopup = isPopup
        self.onClose = onClose
        self.humans = humans
        self.electronicPets = electronicPets
        self.fragments = fragments
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var l: L10n { L10n(appLanguage) }
    var commandExecutor: OasisRewardCommandExecutor {
        OasisRewardCommandExecutor(
            context: modelContext,
            rewards: appServices.oasisRewards,
            shopInventory: appServices.shopInventory
        )
    }

    var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId && !$0.hasPassedAway }
    }

    var currentCoconutBalance: Int {
        commandExecutor.currentHumanCoconutBalance(
            humans: humans,
            currentActiveHumanId: currentActiveHumanId
        )
    }

    var body: some View {
        Group {
            if mode == .nest, isPopup {
                nestPopupBody
            } else {
                pageBody
            }
        }
        .onAppear {
            if let initialCatalogId {
                selectedCatalogId = initialCatalogId
            } else if let featured = electronicPets.first(where: { $0.isFeaturedOnOasis && !$0.isArchived }) ?? electronicPets.first(where: { !$0.isArchived }) {
                selectedCatalogId = featured.catalogId
            }
            scheduleRenderSnapshotRefresh(milliseconds: 30)
            scheduleLifecycleRefresh(milliseconds: 110)
        }
        .onDisappear {
            cancelDeferredWork()
        }
        .onChange(of: electronicPets.count) { _, _ in
            scheduleRenderSnapshotRefresh(milliseconds: 60)
        }
        .onChange(of: fragments.count) { _, _ in
            scheduleRenderSnapshotRefresh(milliseconds: 60)
        }
        .onChange(of: currentCoconutBalance) { _, _ in
            scheduleRenderSnapshotRefresh(milliseconds: 60)
        }
        .sheet(item: $pendingGrowthConfirmation) { confirmation in
            CompanionGrowthConfirmationSheet(
                confirmation: confirmation,
                localization: l,
                onConfirm: { confirmGrowth(confirmation) }
            )
        }
        .accessibilityIdentifier("oasis-critter-codex")
    }
}

private struct CompanionGrowthConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let confirmation: CompanionGrowthConfirmation
    let localization: L10n
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        localization.tr(zh: "伙伴", en: "Companion", de: "Begleiter"),
                        value: confirmation.companionName
                    )
                    LabeledContent(
                        localization.tr(zh: "专属碎片", en: "Specific fragments", de: "Spezifische Fragmente"),
                        value: "\(confirmation.fundingPlan.specificFragmentsUsed)◇"
                    )
                    LabeledContent(
                        localization.tr(zh: "伙伴星光", en: "Companion stardust", de: "Begleiter-Sternenstaub"),
                        value: "\(confirmation.fundingPlan.stardustUsed)✦"
                    )
                    LabeledContent(
                        localization.tr(zh: "椰子", en: "Coconuts", de: "Kokosnüsse"),
                        value: "\(confirmation.fundingPlan.coconutCost)🥥"
                    )
                } footer: {
                    Text(localization.tr(
                        zh: "会先使用这位伙伴的专属碎片，不足部分再由全岛通用星光补足。",
                        en: "Specific fragments are used first; island-wide stardust fills the remainder.",
                        de: "Zuerst werden spezifische Fragmente verwendet, dann Sternenstaub."
                    ))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.tr(zh: "确认", en: "Confirm", de: "Bestätigen")) {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(!confirmation.fundingPlan.isFullyFunded)
                }
            }
        }
    }

    private var title: String {
        switch confirmation.kind {
        case .awaken:
            localization.tr(zh: "确认唤醒", en: "Confirm awakening", de: "Erweckung bestätigen")
        case .starUpgrade:
            localization.tr(zh: "确认升星", en: "Confirm star upgrade", de: "Sternupgrade bestätigen")
        }
    }
}
