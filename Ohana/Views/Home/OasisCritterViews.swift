//
//  OasisCritterViews.swift
//  Ohana
//
//  Electronic pet collection, milestone motivation, and lightweight care UI.
//

import SwiftUI
import SwiftData
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
                Image(systemName: "lock.fill")
                    .font(.system(size: max(16, size * 0.18), weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: max(30, size * 0.32), height: max(30, size * 0.32))
                    .background(Color.goPrimary, in: Circle())
                    .offset(x: size * 0.28, y: -size * 0.28)
            }
        }
        .accessibilityHidden(true)
    }

    private var lumo: some View {
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

    private var lumoImage: UIImage? {
        lumoAssetCandidates.lazy.compactMap { UIImage(named: $0) }.first
    }

    private var lumoAssetCandidates: [String] {
        let baseName = OasisUpgradeRewardCatalog.critter(id: catalogId)?.assetName ?? "CritterLumo"
        let stageName = lumoEvolutionStageName
        return [
            "\(baseName)\(stageName)",
            "\(baseName)Adult",
            baseName
        ]
    }

    private var lumoEvolutionStageName: String {
        if let critter, critter.lifeState == .dead && critter.deathReason == .oldAge {
            return "Elder"
        }
        let stage: Int
        if let appearanceStageOverride {
            stage = max(1, min(OasisUpgradeRewardService.maxCritterAppearanceStage, appearanceStageOverride))
        } else if let critter {
            stage = max(
                max(1, min(OasisUpgradeRewardService.maxCritterAppearanceStage, critter.appearanceStage)),
                OasisUpgradeRewardService.appearanceStage(forLevel: critter.level)
            )
        } else {
            stage = 1
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

    private var sproutMochi: some View {
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

    private var auroraLuma: some View {
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

            ForEach(0..<4, id: \.self) { index in
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

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.16, weight: .black))
                .foregroundStyle(Color.ohanaCardSurface)
                .offset(x: -size * 0.22, y: -size * 0.18)
        }
    }
}

private struct OasisCritterLeafShape: Shape {
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
    var initialCatalogId: String? = nil
    var isPopup: Bool = false
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var questManager = QuestManager.shared
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \OasisElectronicPet.obtainedAt) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt) private var fragments: [OasisCritterFragmentBalance]

    @State private var selectedCatalogId = OasisUpgradeRewardCatalog.firstCritterId
    @State private var focusedCodexCatalogId: String?
    @State private var pulseCatalogId: String?
    @State private var lastInteractionOutcome: OasisCritterInteractionOutcome?
    @State private var rescuingCritterId: UUID?
    @State private var showingCoconutLog = false
    @State private var treeMgr = OasisTreeManager.shared

    private var l: L10n { L10n(appLanguage) }
    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId }
    }
    private var currentCoconutBalance: Int {
        activeHuman?.coconutBalance ?? questManager.coconutCount
    }

    var body: some View {
        Group {
            if mode == .nest && isPopup {
                nestPopupBody
            } else {
                pageBody
            }
        }
        .onAppear {
            refreshLifecycleSnapshots()
            if let initialCatalogId {
                selectedCatalogId = initialCatalogId
            } else if let featured = electronicPets.first(where: { $0.isFeaturedOnOasis && !$0.isArchived }) ?? electronicPets.first(where: { !$0.isArchived }) {
                selectedCatalogId = featured.catalogId
            }
        }
        .sheet(isPresented: $showingCoconutLog) {
            coconutLogSheet
        }
    }

    private var pageBody: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if mode == .codex, focusedCodexCatalogId == nil {
                        collectionStrip
                    } else {
                        selectedDetail
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, mode == .codex && focusedCodexCatalogId == nil ? 28 : 56)
            }
        }
    }

    private var nestPopupBody: some View {
        VStack(spacing: 0) {
            popupChrome

            ScrollView(.vertical, showsIndicators: false) {
                selectedDetailContent
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
            }
        }
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 26, x: 0, y: 18) // ui-v4: allow centered modal lift
    }

    private var popupChrome: some View {
        HStack(spacing: 10) {
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                close()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle(entry: nil))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(headerSubtitle(entry: nil))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
            coconutBalanceButton
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var coconutLogSheet: some View {
        if let activeHuman {
            CoconutLogView(subject: .human(activeHuman.id))
        } else {
            CoconutLogView()
        }
    }

    private var header: some View {
        let entry = focusedCodexCatalogId.flatMap { OasisUpgradeRewardCatalog.critter(id: $0) }
        return HStack(alignment: .center, spacing: 12) {
            if mode == .codex, focusedCodexCatalogId != nil {
                Button {
                    withAnimation(GoMotion.stateChange) {
                        focusedCodexCatalogId = nil
                        lastInteractionOutcome = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "返回图鉴", en: "Back to codex", de: "Zurück zum Album"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle(entry: entry))
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(headerSubtitle(entry: entry))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private func close() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func headerTitle(entry: OasisElectronicPetCatalogEntry?) -> String {
        if let entry {
            return entry.name(l)
        }
        return mode == .codex
            ? l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album")
            : l.tr(zh: "电子宠物小窝", en: "Critter Nest", de: "Critter-Nest")
    }

    private func headerSubtitle(entry: OasisElectronicPetCatalogEntry?) -> String {
        if let entry {
            return entry.tagline(l)
        }
        return mode == .codex
            ? l.tr(zh: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) 已唤醒", en: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) awake", de: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) wach")
            : l.tr(zh: "状态、照护和今日小愿望", en: "Status, care, and today's wish", de: "Status, Pflege und heutiger Wunsch")
    }

    private var collectionStrip: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            ForEach(OasisUpgradeRewardCatalog.critters) { entry in
                let critter = ownedCritter(entry.id)
                let owned = critter != nil
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedCatalogId = entry.id
                        focusedCodexCatalogId = entry.id
                        lastInteractionOutcome = nil
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            OasisCritterIllustration(catalogId: entry.id, locked: !owned, size: 88, critter: critter)
                                .scaleEffect(pulseCatalogId == entry.id ? 1.06 : 1)
                            if critter?.isFeaturedOnOasis == true {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .frame(width: 22, height: 22)
                                    .background(Color.goPrimary, in: Circle())
                            }
                        }
                        Text(entry.name(l))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(collectionStatus(for: entry, owned: owned))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(owned ? Color.goPrimary : Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 154)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(owned ? Color.goPrimary.opacity(0.34) : Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityHint(l.tr(zh: "点按查看这个电子宠物的详细信息", en: "Tap to view this critter's details", de: "Tippen, um Details zu diesem Begleiter zu sehen"))
            }
        }
    }

    private var selectedDetailContent: some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: selectedCatalogId) ?? OasisUpgradeRewardCatalog.critters[0]
        let critter = ownedCritter(entry.id)
        let fragmentCount = fragments.first(where: { $0.catalogId == entry.id })?.amount ?? 0
        let awakeningCost = OasisUpgradeRewardService.awakeningCost(for: entry.rarity)
        return VStack(alignment: .leading, spacing: 16) {
            if critter == nil {
                VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    rarityColor(entry.rarity).opacity(critter == nil ? 0.08 : 0.26),
                                    Color.ohanaControlFill
                                ],
                                center: .top,
                                startRadius: 20,
                                endRadius: 220
                            )
                        )
                        .frame(height: 212)

                    OasisCritterIllustration(catalogId: entry.id, locked: critter == nil, size: 168, critter: critter)
                        .scaleEffect(pulseCatalogId == entry.id ? 1.08 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    HStack(spacing: 8) {
                        Text(l.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rarityColor(entry.rarity), in: Capsule())
                    }
                    .padding(12)
                }

                VStack(spacing: 6) {
                    Text(entry.name(l))
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(entry.tagline(l))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                    HStack(spacing: 7) {
                        codexMetric(value: "\(fragmentCount)◇", label: l.tr(zh: "碎片", en: "Fragments", de: "Fragmente"))
                        if critter == nil {
                            codexMetric(value: "\(awakeningCost.fragments)◇", label: l.tr(zh: "唤醒", en: "Awaken", de: "Wecken"))
                        }
                        if let critter {
                            codexMetric(value: "Lv.\(critter.level)", label: l.tr(zh: "等级", en: "Level", de: "Level"))
                            codexMetric(value: "\(critter.starLevel)★", label: l.tr(zh: "星级", en: "Stars", de: "Sterne"))
                            codexMetric(value: "B\(OasisUpgradeRewardService.bondLevel(for: critter))", label: l.tr(zh: "羁绊", en: "Bond", de: "Bindung"))
                            codexMetric(value: "\(OasisUpgradeRewardService.todayInteractionCount(for: critter, context: modelContext))/3", label: l.tr(zh: "今日", en: "Today", de: "Heute"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                }
            }

            if let critter {
                critterToySurface(entry: entry, critter: critter, fragmentCount: fragmentCount)
                if let lastInteractionOutcome, lastInteractionOutcome.success {
                    interactionOutcomeBanner(lastInteractionOutcome)
                }
                upgradeLevelButton(critter)
            } else {
                lockedRoadmap(entry, fragmentCount: fragmentCount)
            }
        }
    }

    private var selectedDetail: some View {
        selectedDetailContent
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private func critterToySurface(entry: OasisElectronicPetCatalogEntry, critter: OasisElectronicPet, fragmentCount: Int) -> some View {
        let snapshot = OasisUpgradeRewardService.lifecycleSnapshot(for: critter, context: modelContext)
        let wish = OasisUpgradeRewardService.displayDailyWish(for: critter, snapshot: snapshot)
        let wishCompleted = OasisUpgradeRewardService.isDailyWishCompleted(for: critter, wish: wish, context: modelContext)
        let isDead = snapshot.state == .dead
        let canFeed = !isDead && OasisUpgradeRewardService.canInteract(with: critter, action: .feed, context: modelContext)
        let canPlay = !isDead && OasisUpgradeRewardService.canInteract(with: critter, action: .play, context: modelContext)
        let canRest = !isDead && OasisUpgradeRewardService.canInteract(with: critter, action: .rest, context: modelContext)

        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(critter.displayName(l))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(lifecycleShortText(snapshot))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                        }
                    Spacer(minLength: 0)
                    if !(mode == .nest && isPopup) {
                        coconutBalanceButton
                    }
                }

                HStack(spacing: 7) {
                    toyInfoPill("Lv.\(min(OasisUpgradeRewardService.maxCritterLevel, max(1, critter.level)))")
                    toyInfoPill(l.tr(zh: "形态 \(OasisUpgradeRewardService.appearanceStage(forLevel: critter.level))", en: "Form \(OasisUpgradeRewardService.appearanceStage(forLevel: critter.level))", de: "Form \(OasisUpgradeRewardService.appearanceStage(forLevel: critter.level))"))
                    toyInfoPill(l.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de))
                    toyInfoPill("\(fragmentCount)◇")
                }
            }
            .padding(12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            GeometryReader { proxy in
                let width = proxy.size.width
                let auraTint = critterAuraTint(for: snapshot.state)
                ZStack {
                    critterAura(tint: auraTint, state: snapshot.state)
                        .frame(width: min(width * 0.94, 360), height: 350)
                        .position(x: width * 0.50, y: 218)

                    OasisCritterIllustration(catalogId: entry.id, locked: false, size: min(306, width * 0.82), critter: critter)
                        .scaleEffect(pulseCatalogId == entry.id ? 1.06 : 1)
                        .animation(GoMotion.feedback, value: pulseCatalogId)
                        .position(x: width * 0.50, y: 218)

                    homeDisplayToggle(critter)
                        .position(x: width - 72, y: 38)

                    toyActionButton(
                        icon: "fork.knife",
                        title: l.tr(zh: "喂", en: "Feed", de: "Füttern"),
                        cost: critterInteractionCostText(critter, action: .feed),
                        enabled: canFeed,
                        highlighted: !wishCompleted && wish.action == .feed
                    ) {
                        perform(.feed, critter: critter)
                    }
                    .position(x: width * 0.15, y: 138)

                    toyActionButton(
                        icon: "sparkles",
                        title: l.tr(zh: "玩", en: "Play", de: "Spiel"),
                        cost: critterInteractionCostText(critter, action: .play),
                        enabled: canPlay,
                        highlighted: !wishCompleted && wish.action == .play
                    ) {
                        perform(.play, critter: critter)
                    }
                    .position(x: width * 0.85, y: 138)

                    toyActionButton(
                        icon: "moon.fill",
                        title: l.tr(zh: "睡", en: "Rest", de: "Ruhen"),
                        cost: critterInteractionCostText(critter, action: .rest),
                        enabled: canRest,
                        highlighted: !wishCompleted && wish.action == .rest
                    ) {
                        perform(.rest, critter: critter)
                    }
                    .position(x: width * 0.15, y: 312)

                    toyActionButton(
                        icon: "cross.case.fill",
                        title: l.tr(zh: "照顾", en: "Care", de: "Pflege"),
                        cost: l.tr(zh: "免费", en: "Free", de: "Gratis"),
                        enabled: snapshot.isRescuable && rescuingCritterId != critter.id,
                        highlighted: snapshot.isRescuable
                    ) {
                        rescue(critter)
                    }
                    .position(x: width * 0.85, y: 312)
                }
            }
            .frame(height: 440)

            critterToyCharts(critter)
        }
    }

    private func toyInfoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.ohanaCardSurface.opacity(0.72), in: Capsule())
    }

    private var coconutBalanceButton: some View {
        CoconutBalanceCapsule(balance: currentCoconutBalance, showsDeltaAnimation: true) {
            showingCoconutLog = true
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .animation(GoMotion.feedback, value: currentCoconutBalance)
        .accessibilityLabel(l.tr(
            zh: "查看椰子历史，当前 \(currentCoconutBalance) 个椰子",
            en: "View coconut history, \(currentCoconutBalance) coconuts",
            de: "Kokosnuss-Verlauf ansehen, \(currentCoconutBalance) Kokosnüsse"
        ))
    }

    private func critterAura(tint: Color, state: OasisCritterLifeState) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(state == .healthy ? 0.48 : 0.62),
                            tint.opacity(0.20),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )
                .blur(radius: 12)
            Circle()
                .strokeBorder(tint.opacity(state == .healthy ? 0.32 : 0.58), lineWidth: state == .healthy ? 1.2 : 2)
                .scaleEffect(state == .healthy ? 0.82 : 0.94)
                .blur(radius: 5)
            Circle()
                .strokeBorder(Color.ohanaCardSurface.opacity(0.28), lineWidth: 1)
                .scaleEffect(0.58)
                .blur(radius: 2)
        }
        .allowsHitTesting(false)
        .shadow(color: tint.opacity(state == .healthy ? 0.30 : 0.56), radius: state == .healthy ? 24 : 34, y: 0) // ui-v4: allow state aura behind critter
    }

    private func homeDisplayToggle(_ critter: OasisElectronicPet) -> some View {
        HStack(spacing: 6) {
            Image(systemName: critter.isFeaturedOnOasis ? "house.fill" : "house.slash.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(critter.isFeaturedOnOasis ? Color.goPrimary : Color.ohanaTertiaryText)
                .frame(width: 16)

            Text(critter.isFeaturedOnOasis
                ? l.tr(zh: "首页显示", en: "Home", de: "Start")
                : l.tr(zh: "已隐藏", en: "Hidden", de: "Verborgen"))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(critter.isFeaturedOnOasis ? 0.86 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Toggle("", isOn: homeDisplayBinding(for: critter))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.goPrimary)
                .scaleEffect(0.62)
                .frame(width: 34, height: 22)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Color.ohanaControlFill, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .disabled(critter.lifeState == .dead)
        .opacity(critter.lifeState == .dead ? 0.42 : 1)
        .accessibilityLabel(critter.isFeaturedOnOasis
            ? l.tr(zh: "关闭首页显示", en: "Hide from home", de: "Von Startseite ausblenden")
            : l.tr(zh: "显示在首页", en: "Show on home", de: "Auf Startseite zeigen"))
    }

    private func homeDisplayBinding(for critter: OasisElectronicPet) -> Binding<Bool> {
        Binding(
            get: { critter.isFeaturedOnOasis },
            set: { newValue in
                guard newValue != critter.isFeaturedOnOasis else { return }
                toggleHomeDisplay(critter)
            }
        )
    }

    private func toyActionButton(icon: String, title: String, cost: String = "", enabled: Bool = true, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
                Text(title)
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                if !cost.isEmpty {
                    Text(cost)
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            (highlighted ? Color.arkInk.opacity(0.14) : Color.ohanaControlFill.opacity(0.95)),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(width: 78, height: 66)
            .background(highlighted ? Color.goPrimary : Color.ohanaCardSurface.opacity(0.96), in: shape)
            .overlay(
                shape.strokeBorder(
                    highlighted ? Color.arkInk.opacity(0.18) : Color.ohanaPrimaryText.opacity(0.12),
                    lineWidth: highlighted ? 1.3 : 1
                )
            )
            .shadow(color: (highlighted ? Color.goPrimary : Color.ohanaPrimaryText).opacity(highlighted ? 0.28 : 0.10), radius: highlighted ? 14 : 8, x: 0, y: 5) // ui-v4: allow toy action button lift
            .opacity(enabled ? 1 : 0.42)
            .contentShape(shape)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func critterToyCharts(_ critter: OasisElectronicPet) -> some View {
        let bondLevel = OasisUpgradeRewardService.bondLevel(for: critter)
        let xp = OasisUpgradeRewardService.xpProgress(for: critter)
        let xpPercent = Int(Double(xp) / Double(OasisUpgradeRewardService.critterXPPerLevel) * 100)

        return VStack(spacing: 10) {
            toyStatusRow(icon: "fork.knife", value: critter.hunger, label: l.tr(zh: "饱腹", en: "Fullness", de: "Satt"), tint: Color.goOrange)
            toyStatusRow(icon: "face.smiling", value: critter.mood, label: l.tr(zh: "心情", en: "Mood", de: "Laune"), tint: Color.goTeal)
            toyStatusRow(icon: "cross.case.fill", value: critter.health, label: l.tr(zh: "健康", en: "Health", de: "Gesund"), tint: Color.goPurple)
            toyStatusRow(icon: "heart.fill", value: OasisUpgradeRewardService.bondProgress(for: critter), label: l.tr(zh: "羁绊 B\(bondLevel)", en: "Bond B\(bondLevel)", de: "Bindung B\(bondLevel)"), tint: Color(hex: "FF6AA6"))
            toyProgressRow(icon: "bolt.fill", value: xpPercent, label: l.tr(zh: "成长 XP", en: "Growth XP", de: "Wachstum XP"), detail: "\(xp)/\(OasisUpgradeRewardService.critterXPPerLevel)", tint: Color.goPrimary)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func toyStatusRow(icon: String, value: Int, label: String, tint: Color) -> some View {
        let clampedValue = max(0, min(100, value))
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32)
                .background(tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 0)
                    Text("\(clampedValue)%")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }

                toyProgressTrack(value: clampedValue, tint: tint, height: 12)
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func toyProgressRow(icon: String, value: Int, label: String, detail: String, tint: Color) -> some View {
        let clampedValue = max(0, min(100, value))
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 32, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer(minLength: 0)
                    Text(detail)
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .monospacedDigit()
                }

                toyProgressTrack(value: clampedValue, tint: tint, height: 8)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func toyProgressTrack(value: Int, tint: Color, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ohanaCardSurface.opacity(0.78))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, value))) / 100)
                    .animation(GoMotion.feedback, value: value)
            }
        }
        .frame(height: height)
    }

    private func upgradeLevelButton(_ critter: OasisElectronicPet) -> some View {
        let isMax = critter.level >= OasisUpgradeRewardService.maxCritterLevel
        let canUpgrade = OasisUpgradeRewardService.canUpgradeLevel(for: critter)
        return Button {
            upgrade(critter)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isMax ? "sparkles" : "arrow.up.forward.circle.fill")
                    .font(.system(size: 18, weight: .black))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMax ? l.tr(zh: "已满级", en: "Final Form", de: "Endform") : l.tr(zh: "升级", en: "Upgrade", de: "Upgrade"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text(isMax
                        ? l.tr(zh: "Lumo 已经是最终形态", en: "Lumo is fully evolved", de: "Lumo ist voll entwickelt")
                        : l.tr(zh: "需要 \(OasisUpgradeRewardService.critterXPPerLevel - OasisUpgradeRewardService.xpProgress(for: critter)) XP", en: "\(OasisUpgradeRewardService.critterXPPerLevel - OasisUpgradeRewardService.xpProgress(for: critter)) XP needed", de: "\(OasisUpgradeRewardService.critterXPPerLevel - OasisUpgradeRewardService.xpProgress(for: critter)) XP nötig"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .opacity(0.82)
                }
                Spacer()
                Text(isMax ? "Lv.\(OasisUpgradeRewardService.maxCritterLevel)" : "\(OasisUpgradeRewardService.xpProgress(for: critter))/\(OasisUpgradeRewardService.critterXPPerLevel)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(canUpgrade ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(canUpgrade ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canUpgrade)
        .opacity(isMax || canUpgrade ? 1 : 0.72)
    }

    private func lifecycleShortText(_ snapshot: OasisCritterLifecycleSnapshot) -> String {
        switch snapshot.state {
        case .healthy: return l.tr(zh: "状态很好", en: "Settled", de: "Ruhig")
        case .needsCare: return l.tr(zh: "想你了", en: "Needs you", de: "Vermisst dich")
        case .atRisk: return l.tr(zh: "需要照顾", en: "Needs care", de: "Braucht Pflege")
        case .sick: return l.tr(zh: "有点没精神", en: "Low energy", de: "Wenig Energie")
        case .critical: return l.tr(zh: "请照顾一下", en: "Care now", de: "Jetzt pflegen")
        case .dead: return l.tr(zh: "纪念中", en: "Memorial", de: "Erinnerung")
        }
    }

    private func critterStateRows(_ critter: OasisElectronicPet) -> some View {
        VStack(spacing: 10) {
            codexBar(icon: "fork.knife", value: critter.hunger, tint: Color.goOrange)
            codexBar(icon: "face.smiling", value: critter.mood, tint: Color.goTeal)
            codexBar(icon: "cross.case.fill", value: critter.health, tint: Color.goPurple)
            critterBondBar(critter)
        }
    }

    private func critterLifecycleStatusCard(_ critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: lifecycleIcon(for: snapshot.state))
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(snapshot.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 40, height: 40)
                .background(lifecycleTint(for: snapshot.state), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.state.name(l))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(OasisUpgradeRewardService.gentlePrompt(for: critter, snapshot: snapshot, l: l))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(3)
                if snapshot.state == .dead, let diedAt = critter.diedAt {
                    Text(relative(diedAt))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dailyWishCard(_ wish: OasisCritterDailyWish, critter: OasisElectronicPet, isCompleted: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : wish.icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(isCompleted ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 40, height: 40)
                .background(isCompleted ? Color.goPrimary : rarityColor(critter.rarity), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(isCompleted ? l.tr(zh: "今日小愿望完成", en: "Tiny wish complete", de: "Kleiner Wunsch erfüllt") : wish.title(l))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isCompleted ? l.tr(zh: "明天它还会带来新的小心愿。", en: "Tomorrow brings a new little wish.", de: "Morgen kommt ein neuer kleiner Wunsch.") : wish.detail(l))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                Text(wish.rewardText(l))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(isCompleted ? Color.goPrimary : Color.ohanaTertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(GoMotion.feedback, value: isCompleted)
    }

    private func lockedRoadmap(_ entry: OasisElectronicPetCatalogEntry, fragmentCount: Int) -> some View {
        let level = entry.sourceLevel
        let cost = OasisUpgradeRewardService.awakeningCost(for: entry.rarity)
        let isLevelUnlocked = treeMgr.treeLevel.rawValue >= level
        let canAwaken = fragmentCount >= cost.fragments &&
            isLevelUnlocked &&
            OasisCritterEconomyService.canSpendCurrentHumanCoconuts(cost.coconuts, context: modelContext)
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 38, height: 38)
                    .background(Color.goPrimary, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "生命之树 Lv.\(level) 保底唤醒", en: "Guaranteed at Life Tree Lv.\(level)", de: "Garantiert bei Lebensbaum Lv.\(level)"))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isLevelUnlocked
                        ? l.tr(zh: "可以使用碎片唤醒。", en: "Fragments can awaken it now.", de: "Fragmente können es jetzt wecken.")
                        : l.tr(zh: "达到等级后可用碎片唤醒。", en: "Fragments unlock after this level.", de: "Fragmente werden ab diesem Level nutzbar."))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(Color.goPrimary)
                        .frame(width: proxy.size.width * CGFloat(min(1, Double(fragmentCount) / Double(cost.fragments))))
                        .animation(GoMotion.feedback, value: fragmentCount)
                }
            }
            .frame(height: 9)
            codexAction(
                icon: "sparkles",
                title: l.tr(zh: "碎片唤醒", en: "Awaken", de: "Wecken"),
                cost: "\(cost.fragments)◇ \(cost.coconuts)🥥",
                enabled: canAwaken
            ) {
                awaken(entry)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var ownedCount: Int {
        electronicPets.filter { !$0.isArchived }.count
    }

    private func ownedCritter(_ catalogId: String) -> OasisElectronicPet? {
        electronicPets.first { $0.catalogId == catalogId && !$0.isArchived }
    }

    private func collectionStatus(for entry: OasisElectronicPetCatalogEntry, owned: Bool) -> String {
        if owned { return l.tr(zh: "已唤醒", en: "Awake", de: "Wach") }
        let fragmentCount = fragments.first(where: { $0.catalogId == entry.id })?.amount ?? 0
        let cost = OasisUpgradeRewardService.awakeningCost(for: entry.rarity)
        if fragmentCount > 0 {
            return "\(fragmentCount)/\(cost.fragments)◇"
        }
        return "Lv.\(entry.sourceLevel)"
    }

    private func codexMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.goPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(minWidth: 52)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func codexBar(icon: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 24)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * CGFloat(max(0, min(100, value))) / 100)
                        .animation(GoMotion.feedback, value: value)
                }
            }
            .frame(height: 8)
            Text("\(max(0, min(100, value)))")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func critterBondBar(_ critter: OasisElectronicPet) -> some View {
        let progress = OasisUpgradeRewardService.bondProgress(for: critter)
        let level = OasisUpgradeRewardService.bondLevel(for: critter)
        return HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color(hex: "FF6AA6"))
                .frame(width: 24)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(Color(hex: "FF6AA6"))
                        .frame(width: proxy.size.width * CGFloat(progress) / 100)
                        .animation(GoMotion.feedback, value: progress)
                }
            }
            .frame(height: 8)
            Text("B\(level) \(progress)/100")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func critterGrowthRows(_ critter: OasisElectronicPet) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 24)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.ohanaControlFill)
                        Capsule()
                            .fill(Color.goPrimary)
                            .frame(width: proxy.size.width * CGFloat(max(0, min(100, critter.xp))) / 100)
                            .animation(GoMotion.feedback, value: critter.xp)
                    }
                }
                .frame(height: 8)
                Text("\(max(0, min(100, critter.xp)))/100")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Text(careHint(for: critter))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func interactionOutcomeBanner(_ outcome: OasisCritterInteractionOutcome) -> some View {
        HStack(spacing: 9) {
            Image(systemName: outcome.completedDailyWish ? "sparkles" : actionIcon(outcome.action))
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(outcome.completedDailyWish ? Color.arkInk : Color.goPrimary)
                .frame(width: 34, height: 34)
                .background(outcome.completedDailyWish ? Color.goYellow : Color.ohanaControlFill, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(outcome.message(l))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                let reward = outcome.rewardText(l)
                if !reward.isEmpty {
                    Text(reward)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func codexAction(icon: String, title: String, cost: String, enabled: Bool = true, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                if !cost.isEmpty {
                    Text(cost)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .opacity(0.62)
                    }
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(enabled ? (highlighted ? Color.goYellow : Color.goPrimary) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(enabled ? 1 : 0.52)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func perform(_ action: OasisCritterAction, critter: OasisElectronicPet) {
        do {
            let outcome = try OasisUpgradeRewardService.interactWithOutcome(with: critter, action: action, context: modelContext)
            withAnimation(GoMotion.feedback) {
                lastInteractionOutcome = outcome.success ? outcome : nil
            }
            feedback(for: critter.catalogId, success: outcome.success)
            if outcome.success {
                clearInteractionOutcomeLater(outcome)
            }
        } catch {
            feedback(for: critter.catalogId, success: false)
        }
    }

    private func rescue(_ critter: OasisElectronicPet) {
        guard rescuingCritterId == nil else { return }
        rescuingCritterId = critter.id
        defer { clearRescueBusyState(for: critter.id) }

        do {
            let outcome = try OasisUpgradeRewardService.rescueIfNeeded(for: critter, context: modelContext)
            withAnimation(GoMotion.feedback) {
                lastInteractionOutcome = outcome.success ? outcome : nil
            }
            feedback(for: critter.catalogId, success: outcome.success)
            if outcome.success {
                clearInteractionOutcomeLater(outcome)
            }
        } catch {
            feedback(for: critter.catalogId, success: false)
        }
    }

    private func clearRescueBusyState(for critterId: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard rescuingCritterId == critterId else { return }
            rescuingCritterId = nil
        }
    }

    private func upgrade(_ critter: OasisElectronicPet) {
        do {
            feedback(for: critter.catalogId, success: try OasisUpgradeRewardService.upgradeLevel(for: critter, context: modelContext))
        } catch {
            feedback(for: critter.catalogId, success: false)
        }
    }

    private func awaken(_ entry: OasisElectronicPetCatalogEntry) {
        do {
            if let critter = try OasisUpgradeRewardService.awakenWithFragments(catalogId: entry.id, context: modelContext) {
                withAnimation(GoMotion.fab) {
                    selectedCatalogId = critter.catalogId
                }
                feedback(for: entry.id, success: true)
            } else {
                feedback(for: entry.id, success: false)
            }
        } catch {
            feedback(for: entry.id, success: false)
        }
    }

    private func toggleHomeDisplay(_ critter: OasisElectronicPet) {
        guard critter.lifeState != .dead else {
            feedback(for: critter.catalogId, success: false)
            return
        }
        do {
            if critter.isFeaturedOnOasis {
                try OasisUpgradeRewardService.clearFeatured(critter, context: modelContext)
            } else {
                try OasisUpgradeRewardService.setFeatured(critter, context: modelContext)
            }
            feedback(for: critter.catalogId, success: true)
        } catch {
            feedback(for: critter.catalogId, success: false)
        }
    }

    private func feedback(for catalogId: String, success: Bool) {
        if success {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(GoMotion.feedback) { pulseCatalogId = catalogId }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(GoMotion.feedback) { pulseCatalogId = nil }
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func clearInteractionOutcomeLater(_ outcome: OasisCritterInteractionOutcome) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            guard lastInteractionOutcome == outcome else { return }
            withAnimation(GoMotion.reduced) {
                lastInteractionOutcome = nil
            }
        }
    }

    private func rarityColor(_ rarity: OasisElectronicPetRarity) -> Color {
        switch rarity {
        case .common: return Color.goTeal
        case .rare: return Color(hex: "7C6CFF")
        case .epic: return Color(hex: "B45CFF")
        case .legendary: return Color.goOrange
        }
    }

    private func actionIcon(_ action: OasisCritterAction) -> String {
        switch action {
        case .feed: return "fork.knife"
        case .play: return "sparkles"
        case .rest: return "moon.fill"
        case .rescue: return "cross.case.fill"
        case .levelUpgrade: return "arrow.up.forward.circle.fill"
        case .starUpgrade: return "star.fill"
        case .unlock: return "lock.open.fill"
        case .fragmentAwaken: return "sparkles"
        case .feature: return "house.fill"
        case .careEcho: return "heart.fill"
        case .death: return "leaf.fill"
        }
    }

    private func lifecycleIcon(for state: OasisCritterLifeState) -> String {
        switch state {
        case .healthy: return "heart.fill"
        case .needsCare: return "hand.raised.fill"
        case .atRisk: return "exclamationmark.circle.fill"
        case .sick: return "cross.case.fill"
        case .critical: return "hourglass"
        case .dead: return "leaf.fill"
        }
    }

    private func lifecycleTint(for state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy: return Color.goPrimary
        case .needsCare: return Color.goTeal
        case .atRisk: return Color.goOrange
        case .sick: return Color.goPurple
        case .critical: return Color.goYellow
        case .dead: return Color.ohanaCardSurface
        }
    }

    private func critterAuraTint(for state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy:
            return Color.goPrimary
        case .dead:
            return Color.ohanaTertiaryText
        case .needsCare, .atRisk, .sick, .critical:
            return Color.goRed
        }
    }

    private func starCostText(for critter: OasisElectronicPet) -> String {
        let cost = OasisUpgradeRewardService.starUpgradeCost(for: critter)
        return "\(cost.fragments)◇ \(cost.coconuts)🥥"
    }

    private func critterInteractionCostText(_ critter: OasisElectronicPet, action: OasisCritterAction) -> String {
        let cost = OasisUpgradeRewardService.interactionCost(for: critter, action: action, context: modelContext)
        return cost == 0 ? l.tr(zh: "免费", en: "Free", de: "Gratis") : "\(cost)🥥"
    }

    private func canUpgradeStar(_ critter: OasisElectronicPet) -> Bool {
        guard critter.lifeState != .dead else { return false }
        let cost = OasisUpgradeRewardService.starUpgradeCost(for: critter)
        let fragmentCount = fragments.first(where: { $0.catalogId == critter.catalogId })?.amount ?? 0
        return fragmentCount >= cost.fragments &&
            OasisCritterEconomyService.canSpendCurrentHumanCoconuts(cost.coconuts, context: modelContext)
    }

    private func careHint(for critter: OasisElectronicPet) -> String {
        let snapshot = OasisUpgradeRewardService.lifecycleSnapshot(for: critter, context: modelContext)
        return OasisUpgradeRewardService.gentlePrompt(for: critter, snapshot: snapshot, l: l)
    }

    private func refreshLifecycleSnapshots() {
        for critter in electronicPets where !critter.isArchived {
            OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: modelContext)
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
