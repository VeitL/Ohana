//
//  OasisCritterViews.swift
//  Ohana
//
//  Electronic pet collection, milestone motivation, and lightweight care UI.
//

import SwiftUI
import SwiftData

struct OasisCritterIllustration: View {
    let catalogId: String
    var locked: Bool = false
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            if catalogId == OasisUpgradeRewardCatalog.firstCritterId {
                nana
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

    private var nana: some View {
        ZStack {
            Ellipse()
                .fill(Color.ohanaPrimaryText.opacity(0.16))
                .frame(width: size * 0.66, height: size * 0.13)
                .blur(radius: 5)
                .offset(y: size * 0.39)

            Image("CritterNana")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.88, height: size * 1.08)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
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

struct OasisCritterCodexView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Query(sort: \OasisElectronicPet.obtainedAt) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt) private var fragments: [OasisCritterFragmentBalance]
    @Query(sort: \OasisCritterActionLog.createdAt, order: .reverse) private var actionLogs: [OasisCritterActionLog]

    @State private var selectedCatalogId = OasisUpgradeRewardCatalog.firstCritterId
    @State private var pulseCatalogId: String?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    collectionStrip
                    selectedDetail
                    recentActions
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            if let featured = electronicPets.first(where: { $0.isFeaturedOnOasis && !$0.isArchived }) ?? electronicPets.first(where: { !$0.isArchived }) {
                selectedCatalogId = featured.catalogId
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album"))
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) 已唤醒", en: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) awake", de: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) wach"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button {
                dismiss()
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

    private var collectionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(OasisUpgradeRewardCatalog.critters) { entry in
                    let critter = ownedCritter(entry.id)
                    let owned = critter != nil
                    Button {
                        withAnimation(GoMotion.feedback) {
                            selectedCatalogId = entry.id
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                OasisCritterIllustration(catalogId: entry.id, locked: !owned, size: 78)
                                    .scaleEffect(selectedCatalogId == entry.id ? 1.06 : 1)
                                if critter?.isFeaturedOnOasis == true {
                                    Image(systemName: "house.fill")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(Color.ohanaPrimaryActionText)
                                        .frame(width: 24, height: 24)
                                        .background(Color.goPrimary, in: Circle())
                                }
                            }
                            Text(entry.name(l))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(collectionStatus(for: entry, owned: owned))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(owned ? Color.goPrimary : Color.ohanaSecondaryText)
                        }
                        .frame(width: 116, height: 144)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(selectedCatalogId == entry.id ? Color.goPrimary.opacity(0.55) : Color.ohanaPrimaryText.opacity(0.08), lineWidth: selectedCatalogId == entry.id ? 1.6 : 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var selectedDetail: some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: selectedCatalogId) ?? OasisUpgradeRewardCatalog.critters[0]
        let critter = ownedCritter(entry.id)
        let fragmentCount = fragments.first(where: { $0.catalogId == entry.id })?.amount ?? 0
        let awakeningCost = OasisUpgradeRewardService.awakeningCost(for: entry.rarity)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                OasisCritterIllustration(catalogId: entry.id, locked: critter == nil, size: 124)
                    .scaleEffect(pulseCatalogId == entry.id ? 1.08 : 1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(entry.name(l))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rarityColor(entry.rarity), in: Capsule())
                    }
                    Text(entry.tagline(l))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        codexMetric(value: "\(fragmentCount)◇", label: l.tr(zh: "碎片", en: "Fragments", de: "Fragmente"))
                        if critter == nil {
                            codexMetric(value: "\(awakeningCost.fragments)◇", label: l.tr(zh: "唤醒", en: "Awaken", de: "Wecken"))
                        }
                        if let critter {
                            codexMetric(value: "Lv.\(critter.level)", label: l.tr(zh: "等级", en: "Level", de: "Level"))
                            codexMetric(value: "\(critter.starLevel)★", label: l.tr(zh: "星级", en: "Stars", de: "Sterne"))
                            codexMetric(value: "\(OasisUpgradeRewardService.todayInteractionCount(for: critter, context: modelContext))/3", label: l.tr(zh: "今日", en: "Today", de: "Heute"))
                        }
                    }
                }
            }

            if let critter {
                let canFeed = OasisUpgradeRewardService.canInteract(with: critter, action: .feed, context: modelContext)
                let canPlay = OasisUpgradeRewardService.canInteract(with: critter, action: .play, context: modelContext)
                let canRest = OasisUpgradeRewardService.canInteract(with: critter, action: .rest, context: modelContext)
                critterStateRows(critter)
                critterGrowthRows(critter)
                HStack(spacing: 10) {
                    codexAction(icon: "fork.knife", title: l.tr(zh: "喂养", en: "Feed", de: "Füttern"), cost: critterInteractionCostText(critter, action: .feed), enabled: canFeed) {
                        perform(.feed, critter: critter)
                    }
                    codexAction(icon: "sparkles", title: l.tr(zh: "玩耍", en: "Play", de: "Spielen"), cost: critterInteractionCostText(critter, action: .play), enabled: canPlay) {
                        perform(.play, critter: critter)
                    }
                    codexAction(icon: "moon.fill", title: l.tr(zh: "休息", en: "Rest", de: "Ruhen"), cost: "3/d", enabled: canRest) {
                        perform(.rest, critter: critter)
                    }
                }
                HStack(spacing: 10) {
                    codexAction(icon: "house.fill", title: critter.isFeaturedOnOasis ? l.tr(zh: "小窝中", en: "In nest", de: "Im Nest") : l.tr(zh: "展示", en: "Feature", de: "Zeigen"), cost: "") {
                        feature(critter)
                    }
                    codexAction(icon: "star.fill", title: l.tr(zh: "升星", en: "Star", de: "Stern"), cost: starCostText(for: critter), enabled: canUpgradeStar(critter)) {
                        upgrade(critter)
                    }
                }
            } else {
                lockedRoadmap(entry, fragmentCount: fragmentCount)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private func critterStateRows(_ critter: OasisElectronicPet) -> some View {
        VStack(spacing: 10) {
            codexBar(icon: "fork.knife", value: critter.hunger, tint: Color.goOrange)
            codexBar(icon: "face.smiling", value: critter.mood, tint: Color.goTeal)
            codexBar(icon: "heart.fill", value: min(100, critter.bond), tint: Color(hex: "FF6AA6"))
        }
    }

    private func lockedRoadmap(_ entry: OasisElectronicPetCatalogEntry, fragmentCount: Int) -> some View {
        let level = entry.id == OasisUpgradeRewardCatalog.legendaryCritterId ? 10 : 5
        let cost = OasisUpgradeRewardService.awakeningCost(for: entry.rarity)
        let canAwaken = fragmentCount >= cost.fragments &&
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
                    Text(l.tr(zh: "也可以攒碎片提前唤醒。", en: "Fragments can awaken it early.", de: "Fragmente können es früher wecken."))
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

    private var recentActions: some View {
        let relevant = actionLogs.filter { $0.critterCatalogId == selectedCatalogId }.prefix(8)
        return VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近互动", en: "Recent actions", de: "Letzte Aktionen"))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            if relevant.isEmpty {
                Text(l.tr(zh: "唤醒伙伴后，互动记录会出现在这里。", en: "Actions appear here after a companion wakes up.", de: "Aktionen erscheinen hier, sobald ein Begleiter wach ist."))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(Array(relevant), id: \.id) { log in
                    HStack(spacing: 10) {
                        Image(systemName: actionIcon(log.action))
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 30, height: 30)
                            .background(Color.ohanaControlFill, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.note(l))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(relative(log.createdAt))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        let deltaText = logDeltaText(log)
                        if !deltaText.isEmpty {
                            Text(deltaText)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(log.coconutDelta >= 0 && log.fragmentDelta >= 0 ? Color.goPrimary : Color.goOrange)
                        }
                    }
                    .padding(10)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
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
        return "Lv.\(entry.id == OasisUpgradeRewardCatalog.legendaryCritterId ? 10 : 5)"
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

    private func codexAction(icon: String, title: String, cost: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
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
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(enabled ? Color.goPrimary : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(enabled ? 1 : 0.52)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func perform(_ action: OasisCritterAction, critter: OasisElectronicPet) {
        do {
            feedback(for: critter.catalogId, success: try OasisUpgradeRewardService.interact(with: critter, action: action, context: modelContext))
        } catch {
            feedback(for: critter.catalogId, success: false)
        }
    }

    private func upgrade(_ critter: OasisElectronicPet) {
        do {
            feedback(for: critter.catalogId, success: try OasisUpgradeRewardService.upgradeStar(for: critter, context: modelContext))
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

    private func feature(_ critter: OasisElectronicPet) {
        guard !critter.isFeaturedOnOasis else {
            feedback(for: critter.catalogId, success: true)
            return
        }
        do {
            try OasisUpgradeRewardService.setFeatured(critter, context: modelContext)
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
        case .starUpgrade: return "star.fill"
        case .unlock: return "lock.open.fill"
        case .fragmentAwaken: return "sparkles"
        case .feature: return "house.fill"
        case .careEcho: return "heart.fill"
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
        let cost = OasisUpgradeRewardService.starUpgradeCost(for: critter)
        let fragmentCount = fragments.first(where: { $0.catalogId == critter.catalogId })?.amount ?? 0
        return fragmentCount >= cost.fragments &&
            OasisCritterEconomyService.canSpendCurrentHumanCoconuts(cost.coconuts, context: modelContext)
    }

    private func careHint(for critter: OasisElectronicPet) -> String {
        if critter.hunger < 35 {
            return l.tr(zh: "有点饿，喂一下会更有精神。", en: "A little hungry. Feeding helps.", de: "Etwas hungrig. Füttern hilft.")
        }
        if critter.mood < 35 {
            return l.tr(zh: "心情偏低，玩一下就会亮起来。", en: "Mood is low. Play will brighten it.", de: "Laune ist niedrig. Spielen hilft.")
        }
        if !OasisUpgradeRewardService.canInteract(with: critter, action: .rest, context: modelContext) {
            return l.tr(zh: "今天已经休息够啦。", en: "Rest is full for today.", de: "Ruhe ist für heute voll.")
        }
        return l.tr(zh: "轻轻互动，积累羁绊与经验。", en: "Gentle actions build bond and XP.", de: "Sanfte Aktionen geben Bindung und EP.")
    }

    private func logDeltaText(_ log: OasisCritterActionLog) -> String {
        var parts: [String] = []
        if log.xpDelta != 0 { parts.append("+\(log.xpDelta)XP") }
        if log.fragmentDelta != 0 { parts.append("\(log.fragmentDelta)◇") }
        if log.coconutDelta != 0 { parts.append("\(log.coconutDelta)🥥") }
        return parts.joined(separator: " ")
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
