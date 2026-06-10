//
//  OasisRewardView+Critters.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Electronic Pet Motivation

    var oasisCritterMotivationCard: some View {
        let codexLockedLevel = lockedLevel(requiredLevel: critterUnlockLevel)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                if let critter = featuredCritter {
                    OasisCritterIllustration(catalogId: critter.catalogId, locked: false, size: 104, critter: critter)
                        .scaleEffect(critterActionPulseId == critter.id ? 1.06 : 1)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Text(l.tr(zh: "电子宠物小窝", en: "Critter Nest", de: "Critter-Nest"))
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(l.tr(zh: critter.rarity.zh, en: critter.rarity.en, de: critter.rarity.de))
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.ohanaPrimaryActionText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(critterRarityColor(critter.rarity), in: Capsule())
                        }
                        Text(critter.displayName(l))
                            .font(OhanaFont.title(.black))
                            .foregroundStyle(Color.goPrimary)
                            .contentTransition(.numericText())
                        HStack(spacing: 8) {
                            critterQuickMetric(icon: "fork.knife", value: "\(critter.hunger)")
                            critterQuickMetric(icon: "face.smiling", value: "\(critter.mood)")
                            critterQuickMetric(icon: "cross.case.fill", value: "\(critter.health)")
                            critterQuickMetric(icon: "heart.fill", value: "B\(critterRenderSnapshot(for: critter).bondLevel)")
                            critterQuickMetric(icon: "star.fill", value: "\(critter.starLevel)")
                        }
                    }
                } else {
                    OasisCritterIllustration(catalogId: OasisUpgradeRewardCatalog.firstCritterId, locked: true, size: 104)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.tr(zh: "升级生命树，唤醒电子宠物", en: "Level the tree. Wake critters.", de: "Baum leveln. Critter wecken."))
                            .font(OhanaFont.title2(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                        Text(nextCritterGoalText)
                            .font(OhanaFont.footnote(.black))
                            .foregroundStyle(Color.goPrimary)
                        milestoneProgressBar
                    }
                }

                Spacer(minLength: 4)

                if let codexLockedLevel {
                    lockedCritterCodexLabel(level: codexLockedLevel)
                } else {
                    Image(systemName: "chevron.right") // a11y: allow decorative disclosure cue
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .accessibilityHidden(true)
                }
            }

            if featuredCritter == nil {
                HStack(spacing: 10) {
                    critterMilestonePill(level: 10, catalogId: OasisUpgradeRewardCatalog.firstCritterId)
                    critterMilestonePill(level: 20, catalogId: OasisUpgradeRewardCatalog.legendaryCritterId)
                }
            } else if let critter = featuredCritter {
                let snapshot = critterRenderSnapshot(for: critter)
                let wish = snapshot.dailyWish
                critterLifeStrip(critter, snapshot: snapshot.lifecycle)
                if let wish {
                    critterWishStrip(wish, critter: critter, isCompleted: snapshot.isDailyWishCompleted)
                }
                if let lastCritterInteractionOutcome, lastCritterInteractionOutcome.success {
                    critterOutcomeStrip(lastCritterInteractionOutcome)
                }
                if snapshot.lifecycle.isRescuable {
                    HStack(spacing: 8) {
                        critterNestAction(
                            icon: "cross.case.fill",
                            title: l.tr(zh: "照顾一下", en: "Care now", de: "Pflegen"),
                            cost: l.tr(zh: "免费", en: "Free", de: "Gratis"),
                            enabled: rescuingCritterId != critter.id,
                            highlighted: true
                        ) {
                            rescue(with: critter)
                        }
                    }
                }
                HStack(spacing: 8) {
                    critterNestAction(
                        icon: "fork.knife",
                        title: l.tr(zh: "喂养", en: "Feed", de: "Füttern"),
                        cost: critterInteractionCostText(snapshot.feedCost),
                        enabled: snapshot.canFeed,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .feed
                    ) {
                        interact(with: critter, action: .feed)
                    }
                    critterNestAction(
                        icon: "sparkles",
                        title: l.tr(zh: "玩耍", en: "Play", de: "Spielen"),
                        cost: critterInteractionCostText(snapshot.playCost),
                        enabled: snapshot.canPlay,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .play
                    ) {
                        interact(with: critter, action: .play)
                    }
                    critterNestAction(
                        icon: "moon.fill",
                        title: l.tr(zh: "休息", en: "Rest", de: "Ruhen"),
                        cost: critterInteractionCostText(snapshot.restCost),
                        enabled: snapshot.canRest,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .rest
                    ) {
                        interact(with: critter, action: .rest)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.16), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .onTapGesture {
            guard codexLockedLevel == nil else {
                OhanaFeedback.error()
                return
            }
            OhanaFeedback.light()
            openSheet(.critterCodex)
        }
        .accessibilityLabel(codexLockedLevel.map {
            lockedLevelAccessibility(l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album"), level: $0)
        } ?? l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album"))
    }

    func lockedCritterCodexLabel(level: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .accessibilityHidden(true)
            Text(l.tr(zh: "Lv.\(level) 解锁", en: "Lv.\(level)", de: "Lv.\(level)"))
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
    }

    var featuredCritter: OasisElectronicPet? {
        electronicPets
            .filter { !$0.isArchived }
            .filter { $0.lifeState != .dead }
            .sorted {
                if $0.isFeaturedOnOasis != $1.isFeaturedOnOasis {
                    return $0.isFeaturedOnOasis && !$1.isFeaturedOnOasis
                }
                if $0.habitatSlot != $1.habitatSlot { return $0.habitatSlot < $1.habitatSlot }
                return $0.obtainedAt < $1.obtainedAt
            }
            .first
    }

    func critterRenderSnapshot(for critter: OasisElectronicPet) -> OasisCritterRenderSnapshot {
        critterRenderSnapshots[critter.id] ?? OasisCritterRenderSnapshot.lightweight(
            for: critter,
            rewards: appServices.oasisRewards
        )
    }

    var nextCritterMilestoneLevel: Int {
        OasisUpgradeRewardCatalog.critter(id: nextCritterTargetCatalogId)?.sourceLevel ?? 10
    }

    var nextCritterGoalText: String {
        guard let entry = OasisUpgradeRewardCatalog.critter(id: nextCritterTargetCatalogId) else {
            return l.tr(zh: "Lv.10 保底 Lumo", en: "Lv.10 guarantees Lumo", de: "Lv.10 garantiert Lumo")
        }
        if treeVisualLevel.rawValue < entry.sourceLevel {
            return l.tr(
                zh: "Lv.\(entry.sourceLevel) 保底 \(entry.nameZh)",
                en: "Lv.\(entry.sourceLevel) guarantees \(entry.nameEn)",
                de: "Lv.\(entry.sourceLevel) garantiert \(entry.nameDe)"
            )
        }
        return l.tr(zh: "\(entry.nameZh) 正在树上等待", en: "\(entry.nameEn) is waiting in the tree", de: "\(entry.nameDe) wartet im Baum")
    }

    var milestoneProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ohanaControlFill)
                Capsule()
                    .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * nextCritterProgress)
                    .animation(GoMotion.feedback, value: nextCritterProgress)
            }
        }
        .frame(height: 9)
    }

    var nextCritterProgress: CGFloat {
        let targetEnergy = nextCritterMilestoneLevel == 5 ? 500 : 3600
        guard targetEnergy > 0 else { return 1 }
        return min(1, max(0, CGFloat(treeVisualTotalEnergy) / CGFloat(targetEnergy)))
    }

    func critterMilestonePill(level: Int, catalogId: String) -> some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: catalogId)
        let isReached = treeVisualLevel.rawValue >= level
        return HStack(spacing: 8) {
            OasisCritterIllustration(catalogId: catalogId, locked: !isReached, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("Lv.\(level)")
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(isReached ? Color.goPrimary : Color.ohanaPrimaryText)
                Text(entry?.name(l) ?? "")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func critterQuickMetric(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(OhanaFont.caption2(.black))
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.caption2(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    func critterLifeStrip(_ critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot) -> some View {
        HStack(spacing: 9) {
            Image(systemName: critterLifecycleIcon(for: snapshot.state))
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(snapshot.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow decorative lifecycle badge paired with state text
                .background(critterLifecycleTint(for: snapshot.state), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.state.name(l))
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.text(critterRenderSnapshot(for: critter).prompt))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func critterWishStrip(_ wish: OasisCritterDailyWish, critter: OasisElectronicPet, isCompleted: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : wish.icon)
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(isCompleted ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow decorative wish badge paired with text
                .background(isCompleted ? Color.goPrimary : critterRarityColor(critter.rarity), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCompleted ? l.tr(zh: "今日小愿望完成", en: "Tiny wish complete", de: "Kleiner Wunsch erfüllt") : wish.title(l))
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(isCompleted ? l.tr(zh: "明天还有新的心愿。", en: "New wish tomorrow.", de: "Morgen gibt es einen neuen Wunsch.") : wish.rewardText(l))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(isCompleted ? Color.goPrimary : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .animation(GoMotion.feedback, value: isCompleted)
    }

    func critterOutcomeStrip(_ outcome: OasisCritterInteractionOutcome) -> some View {
        HStack(spacing: 8) {
            Image(systemName: outcome.completedDailyWish ? "sparkles" : "heart.fill")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(outcome.completedDailyWish ? Color.arkInk : Color.goPrimary)
                .frame(width: 28, height: 28) // a11y: allow decorative outcome badge paired with text
                .background(outcome.completedDailyWish ? Color.goYellow : Color.ohanaControlFill, in: Circle())
                .accessibilityHidden(true)
            Text(outcome.message(l))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
            let reward = outcome.rewardText(l)
            if !reward.isEmpty {
                Text(reward)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    func critterNestAction(icon: String, title: String, cost: String, enabled: Bool = true, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.footnote(.black))
                Text(title)
                    .font(OhanaFont.caption(.black))
                Text(cost)
                    .font(OhanaFont.caption2(.black))
                    .opacity(0.62)
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(enabled ? (highlighted ? Color.goYellow : Color.goPrimary) : Color.ohanaControlFill, in: Capsule())
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    func critterInteractionCostText(_ cost: Int) -> String {
        cost == 0 ? l.tr(zh: "免费", en: "Free", de: "Gratis") : "\(cost)🥥"
    }

    func critterRarityColor(_ rarity: OasisElectronicPetRarity) -> Color {
        switch rarity {
        case .common: Color.goTeal
        case .rare: Color(hex: "7C6CFF")
        case .epic: Color(hex: "B45CFF")
        case .legendary: Color.goOrange
        }
    }

    func critterLifecycleIcon(for state: OasisCritterLifeState) -> String {
        switch state {
        case .healthy: "heart.fill"
        case .needsCare: "hand.raised.fill"
        case .atRisk: "exclamationmark.circle.fill"
        case .sick: "cross.case.fill"
        case .critical: "hourglass"
        case .dead: "leaf.fill"
        }
    }

    func critterLifecycleTint(for state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy: Color.goPrimary
        case .needsCare: Color.goTeal
        case .atRisk: Color.goOrange
        case .sick: Color.goPurple
        case .critical: Color.goYellow
        case .dead: Color.ohanaCardSurface
        }
    }

    func critterLifecycleAuraTint(_ state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy:
            Color.goPrimary
        case .dead:
            Color.ohanaTertiaryText
        case .needsCare, .atRisk, .sick, .critical:
            Color.goRed
        }
    }

    // MARK: - Upgrade Coconut Dock

    var oasisUpgradeRewardDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let reward = openedUpgradeReward {
                OasisOpenedUpgradeRewardDockCard(
                    reward: reward,
                    localization: l,
                    onClose: {
                        withAnimation(GoMotion.feedback) {
                            dismissUpgradeReward()
                        }
                    }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if !pendingUpgradeCoconuts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles") // a11y: allow decorative section icon
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.goPrimary)
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "升级椰子", en: "Upgrade Coconuts", de: "Upgrade-Kokosnüsse"))
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text("\(pendingUpgradeCoconuts.count)")
                            .font(OhanaFont.footnote(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.goPrimary, in: Capsule())
                    }

                    ForEach(Array(pendingUpgradeCoconuts.prefix(3)), id: \.id) { coconut in
                        upgradeCoconutRow(coconut)
                    }
                }
            }

            if !electronicPets.isEmpty {
                critterCompanionStrip
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    func upgradeCoconutRow(_ coconut: OasisUpgradeCoconut) -> some View {
        let isOpening = openingUpgradeCoconutId == coconut.id
        let isMilestone = coconut.rewardKind == .electronicPet
        return Button {
            openUpgradeCoconut(coconut)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isMilestone ? Color.goPrimary.opacity(0.2) : Color.ohanaControlFill)
                        .frame(width: 46, height: 46)
                    Text("🥥")
                        .font(OhanaFont.metric(size: 26))
                        .rotationEffect(.degrees(isOpening ? -12 : 0))
                        .scaleEffect(isOpening ? 1.16 : 1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Lv.\(coconut.level) · \(coconut.title(l))")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isMilestone
                        ? l.tr(zh: "里程碑保底", en: "Milestone guaranteed", de: "Meilenstein garantiert")
                        : coconut.description(l))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(isMilestone ? Color.goPrimary : Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "hammer.fill") // a11y: allow decorative row action icon
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(coconut.title(l)) \(l.tr(zh: "敲开", en: "Open", de: "Öffnen"))")
    }

    var critterCompanionStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill") // a11y: allow decorative section icon
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)
                Text(l.tr(zh: "电子宠物", en: "Critters", de: "Critter"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                fragmentSummary
            }

            ForEach(Array(electronicPets.prefix(2)), id: \.id) { critter in
                critterCompanionCard(critter)
            }
        }
    }

    var fragmentSummary: some View {
        HStack(spacing: 4) {
            Text("◇")
                .font(OhanaFont.footnote(.black))
            Text("\(actionSnapshot.critterFragmentTotal)")
                .font(OhanaFont.footnote(.black))
        }
        .foregroundStyle(Color.goPrimary)
    }

    func critterCompanionCard(_ critter: OasisElectronicPet) -> some View {
        let snapshot = critterRenderSnapshot(for: critter)
        let lifecycle = snapshot.lifecycle
        let isDead = lifecycle.state == .dead
        return HStack(spacing: 12) {
            OasisCritterIllustration(catalogId: critter.catalogId, locked: false, size: 58, critter: critter)
                .scaleEffect(critterActionPulseId == critter.id ? 1.08 : 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(critter.displayName(l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: critter.rarity.zh, en: critter.rarity.en, de: critter.rarity.de))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.goPrimary, in: Capsule())
                }

                HStack(spacing: 6) {
                    critterMeter(value: critter.hunger, icon: "fork.knife")
                    critterMeter(value: critter.mood, icon: "face.smiling")
                    critterMeter(value: critter.health, icon: "cross.case.fill")
                    critterMeter(value: snapshot.bondProgress, icon: "heart.fill")
                }
                Text(lifecycle.state.name(l))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(isDead ? Color.ohanaTertiaryText : Color.goPrimary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 7) {
                if lifecycle.isRescuable {
                    critterActionButton(icon: "cross.case.fill", cost: l.tr(zh: "免费", en: "Free", de: "Gratis"), enabled: rescuingCritterId != critter.id) {
                        rescue(with: critter)
                    }
                } else {
                    critterActionButton(
                        icon: "carrot.fill",
                        cost: critterInteractionCostText(snapshot.feedCost),
                        enabled: snapshot.canFeed
                    ) {
                        interact(with: critter, action: .feed)
                    }
                    critterActionButton(
                        icon: "sparkles",
                        cost: critterInteractionCostText(snapshot.playCost),
                        enabled: snapshot.canPlay
                    ) {
                        interact(with: critter, action: .play)
                    }
                    critterActionButton(
                        icon: "star.fill",
                        cost: "\(snapshot.starFragmentsCost)◇",
                        enabled: snapshot.canUpgradeStar
                    ) {
                        upgradeCritterStar(critter)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    func critterMeter(value: Int, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(OhanaFont.caption2(.bold))
                .accessibilityHidden(true)
            Text("\(max(0, min(100, value)))")
                .font(OhanaFont.caption2(.black))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    func critterActionButton(icon: String, cost: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(OhanaFont.footnote(.black))
                    .accessibilityHidden(true)
                Text(cost)
                    .font(OhanaFont.caption2(.black))
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: 44, height: 44)
            .background(enabled ? Color.goPrimary : Color.ohanaControlFill, in: Circle())
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    func openUpgradeCoconut(_ coconut: OasisUpgradeCoconut) {
        guard openingUpgradeCoconutId == nil else { return }
        OhanaFeedback.medium()
        withAnimation(GoMotion.feedback) {
            openingUpgradeCoconutId = coconut.id
            dismissUpgradeReward()
        }
        upgradeRewardTask?.cancel()
        upgradeRewardTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            do {
                let result = try commandExecutor.openUpgradeCoconut(coconut)
                result.isMilestoneCritter ? OhanaFeedback.success() : OhanaFeedback.warning()
                withAnimation(GoMotion.fab) {
                    presentUpgradeReward(result)
                    openingUpgradeCoconutId = nil
                }
                if result.isMilestoneCritter {
                    spawnEnergyParticles(count: 16)
                }
                rebuildOasisRenderSnapshots()
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    openingUpgradeCoconutId = nil
                }
            }
            upgradeRewardTask = nil
        }
    }

    func interact(with critter: OasisElectronicPet, action: OasisCritterAction) {
        guard critterActionPulseId == nil else { return }
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            critterActionPulseId = critter.id
        }
        critterCommandTask?.cancel()
        critterCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            do {
                let outcome = try commandExecutor.interact(with: critter, action: action)
                applyCritterInteractionOutcome(outcome, critter: critter)
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
            }
            critterCommandTask = nil
        }
    }

    func applyCritterInteractionOutcome(_ outcome: OasisCritterInteractionOutcome, critter: OasisElectronicPet) {
        if outcome.success {
            OhanaFeedback.light()
            withAnimation(GoMotion.feedback) {
                critterActionPulseId = critter.id
                lastCritterInteractionOutcome = outcome
            }
            critterPulseCleanupTask?.cancel()
            critterPulseCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 350) {
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
                critterPulseCleanupTask = nil
            }
            clearCritterInteractionOutcomeLater(outcome)
            rebuildOasisRenderSnapshots()
        } else {
            OhanaFeedback.warning()
            withAnimation(GoMotion.feedback) {
                critterActionPulseId = nil
            }
        }
    }

    func rescue(with critter: OasisElectronicPet) {
        guard rescuingCritterId == nil else { return }
        rescuingCritterId = critter.id
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            critterActionPulseId = critter.id
        }
        clearRescueBusyState(for: critter.id)

        critterCommandTask?.cancel()
        critterCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            do {
                let outcome = try commandExecutor.rescue(critter)
                applyCritterInteractionOutcome(outcome, critter: critter)
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
            }
            critterCommandTask = nil
        }
    }

    func clearRescueBusyState(for critterId: UUID) {
        rescueBusyCleanupTask?.cancel()
        rescueBusyCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 450) {
            guard rescuingCritterId == critterId else {
                rescueBusyCleanupTask = nil
                return
            }
            rescuingCritterId = nil
            rescueBusyCleanupTask = nil
        }
    }

    func clearCritterInteractionOutcomeLater(_ outcome: OasisCritterInteractionOutcome) {
        critterOutcomeCleanupTask?.cancel()
        critterOutcomeCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3400) {
            guard lastCritterInteractionOutcome == outcome else {
                critterOutcomeCleanupTask = nil
                return
            }
            withAnimation(GoMotion.reduced) {
                lastCritterInteractionOutcome = nil
            }
            critterOutcomeCleanupTask = nil
        }
    }

    func upgradeCritterStar(_ critter: OasisElectronicPet) {
        guard critterActionPulseId == nil else { return }
        OhanaFeedback.light()
        withAnimation(GoMotion.fab) {
            critterActionPulseId = critter.id
        }
        critterCommandTask?.cancel()
        critterCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            do {
                if try commandExecutor.upgradeStar(critter) {
                    OhanaFeedback.success()
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = critter.id
                    }
                    rebuildOasisRenderSnapshots()
                } else {
                    OhanaFeedback.warning()
                }
                critterPulseCleanupTask?.cancel()
                critterPulseCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 400) {
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = nil
                    }
                    critterPulseCleanupTask = nil
                }
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
            }
            critterCommandTask = nil
        }
    }
}
