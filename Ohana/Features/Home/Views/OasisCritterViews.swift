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
            if catalogId == OasisUpgradeRewardCatalog.firstCritterId {
                lumo
            } else if catalogId == OasisUpgradeRewardCatalog.legendaryCritterId {
                auroraLuma
            } else {
                sproutMochi
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

    var lumo: some View {
        ZStack {
            Ellipse()
                .fill(Color.ohanaPrimaryText.opacity(0.16))
                .frame(width: size * 0.62, height: size * 0.12)
                .blur(radius: 5)
                .offset(y: size * 0.39)

            if let image = lumoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.92, height: size * 1.18)
            } else {
                sproutMochi
            }
        }
    }

    var lumoImage: UIImage? {
        lumoAssetCandidates.lazy.compactMap { UIImage(named: $0) }.first
    }

    var lumoAssetCandidates: [String] {
        let baseName = OasisUpgradeRewardCatalog.critter(id: catalogId)?.assetName ?? "CritterLumo"
        let stageName = lumoEvolutionStageName
        return [
            "\(baseName)\(stageName)",
            "\(baseName)Adult",
            baseName
        ]
    }

    var lumoEvolutionStageName: String {
        if let critter, critter.lifeState == .dead, critter.deathReason == .oldAge {
            return "Elder"
        }
        let stage: Int = if let appearanceStageOverride {
            max(1, min(OasisCritterPresentationRules.maxAppearanceStage, appearanceStageOverride))
        } else if let critter {
            max(
                max(1, min(OasisCritterPresentationRules.maxAppearanceStage, critter.appearanceStage)),
                OasisCritterPresentationRules.appearanceStage(forLevel: critter.level)
            )
        } else {
            1
        }
        switch stage {
        case 1:
            return "Baby"
        case 2:
            return "Child"
        case 3:
            return "Teen"
        case 4:
            return "Adult"
        default:
            return "Elder"
        }
    }

    var sproutMochi: some View {
        ZStack {
            Ellipse()
                .fill(Color.ohanaPrimaryText.opacity(0.18))
                .frame(width: size * 0.58, height: size * 0.13)
                .blur(radius: 5)
                .offset(y: size * 0.38)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "E8FFE3"), Color(hex: "86D98B"), Color(hex: "43A45F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.46, height: size * 0.68)
                .rotationEffect(.degrees(-4))

            HStack(spacing: size * 0.1) {
                Circle().fill(Color(hex: "10231B")).frame(width: size * 0.06, height: size * 0.075)
                Circle().fill(Color(hex: "10231B")).frame(width: size * 0.06, height: size * 0.075)
            }
            .offset(y: size * 0.02)

            Capsule()
                .fill(Color(hex: "10231B").opacity(0.85))
                .frame(width: size * 0.13, height: size * 0.025)
                .offset(y: size * 0.15)

            OasisCritterLeafShape()
                .fill(
                    LinearGradient(colors: [Color(hex: "C8FF7A"), Color(hex: "38B765")], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.32, height: size * 0.24)
                .rotationEffect(.degrees(-22))
                .offset(x: -size * 0.12, y: -size * 0.42)

            OasisCritterLeafShape()
                .fill(
                    LinearGradient(colors: [Color(hex: "D8FF91"), Color(hex: "48C56F")], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.28, height: size * 0.22)
                .rotationEffect(.degrees(24))
                .offset(x: size * 0.13, y: -size * 0.42)
        }
    }

    var auroraLuma: some View {
        ZStack {
            Ellipse()
                .fill(Color.ohanaPrimaryText.opacity(0.22))
                .frame(width: size * 0.62, height: size * 0.14)
                .blur(radius: 6)
                .offset(y: size * 0.38)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.ohanaCardSurface, Color(hex: "9FE7FF"), Color(hex: "7F5CFF")],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size * 0.58, height: size * 0.58)

            ForEach(0 ..< 4, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "D7FFFE"), Color(hex: "9277FF").opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.08, height: size * CGFloat(0.36 - Double(index) * 0.03))
                    .rotationEffect(.degrees(Double(index - 2) * 18))
                    .offset(x: CGFloat(index - 2) * size * 0.11, y: -size * 0.36)
            }

            HStack(spacing: size * 0.12) {
                Circle().fill(Color(hex: "10122F")).frame(width: size * 0.055, height: size * 0.07)
                Circle().fill(Color(hex: "10122F")).frame(width: size * 0.055, height: size * 0.07)
            }

            Circle()
                .stroke(Color.ohanaCardSurface.opacity(0.85), lineWidth: max(1.5, size * 0.018))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: size * 0.2, y: -size * 0.15)

            Image(systemName: "sparkle") // a11y: allow decorative icon covered by surrounding text or control
                .font(.system(size: size * 0.16, weight: .black))
                .foregroundStyle(Color.ohanaCardSurface)
                .offset(x: -size * 0.22, y: -size * 0.18)
        }
    }
}

struct OasisCritterLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.14),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.82),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.14)
        )
        return path
    }
}

enum OasisCritterViewMode: Equatable {
    case codex
    case nest
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
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""

    @State var selectedCatalogId = OasisUpgradeRewardCatalog.firstCritterId
    @State var focusedCodexCatalogId: String?
    @State var pulseCatalogId: String?
    @State var lastInteractionOutcome: OasisCritterInteractionOutcome?
    @State var rescuingCritterId: UUID?
    var treeMgr: OasisTreeManaging { appServices.oasisTree }
    @State var renderSnapshots: [UUID: OasisCritterRenderSnapshot] = [:]
    @State var featuredDisplayOverrides: [UUID: Bool] = [:]
    @State var lifecycleRefreshTask: Task<Void, Never>?
    @State var renderSnapshotTask: Task<Void, Never>?
    @State var critterCommandTasks: [UUID: Task<Void, Never>] = [:]
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
        humans.first { $0.id.uuidString == currentActiveHumanId }
    }

    var currentCoconutBalance: Int {
        activeHuman?.coconutBalance ?? humans.reduce(0) { $0 + $1.coconutBalance }
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
    }
}
