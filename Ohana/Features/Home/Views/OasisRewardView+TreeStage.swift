//
//  OasisRewardView+TreeStage.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Life Tree Stage

    var treeSceneCard: some View {
        treeSceneCard(stageHeight: 540, treeVisualHeight: 300, isCompact: false)
    }

    func treeSceneCard(metrics: OasisEmbeddedLayoutMetrics) -> some View {
        treeSceneCard(
            stageHeight: metrics.treeCardHeight,
            treeVisualHeight: metrics.treeVisualHeight,
            isCompact: true
        )
    }

    private func treeSceneCard(stageHeight: CGFloat, treeVisualHeight: CGFloat, isCompact: Bool) -> some View {
        let stageShape = RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
        return ZStack {
            stageBackground(shape: stageShape)

            stageStars

            Circle()
                .fill(Color.goYellow)
                .frame(width: 26, height: 26) // a11y: allow decorative celestial dot
                .shadow(color: Color.goYellow.opacity(0.68), radius: 14, x: 0, y: 0) // ui-v4: allow Oasis stage celestial glow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 24)
                .padding(.trailing, 28)

            stageIslandBase

            stageTreeGlow

            treeEnergyBeam

            VStack(spacing: 0) {
                stageTopHUD
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.top, isCompact ? 10 : 16)

                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    BeautifulCoconutTree(
                        level: treeVisualLevel.rawValue,
                        isInjecting: isInjecting,
                        growthProgress: treeVisualProgressToNextLevel,
                        injectionPulseToken: injectionPulseToken,
                        pendingUpgradeCoconutCount: pendingUpgradeCoconuts.count,
                        dailyCoconutCount: dailyTreeCoconutCount,
                        allowsAmbientMotion: shouldRunAmbientMotion,
                        harvestedCoconuts: harvestedCoconutIndices,
                        onHarvest: { harvestTreeCoconut($0) }
                    )
                    .shadow(color: Color.goPrimary.opacity(glowBreathing ? 0.42 : 0.16), radius: glowBreathing ? 22 : 10, x: 0, y: 0) // ui-v4: allow Oasis tree focus glow
                    .scaleEffect(treeScale * treeInjectionVisualScale)
                    .animation(GoMotion.hero, value: treeScale)
                    .animation(interactionMotionBudget.allowsMotion ? GoMotion.feedback : GoMotion.reduced, value: treeInjectionProgress)
                    .frame(height: treeVisualHeight)
                    .padding(.bottom, isCompact ? 2 : 16)

                    treeCritterEntryButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .offset(x: isCompact ? 66 : 78, y: isCompact ? -18 : -28)
                        .zIndex(5)
                }

                stageUpgradeCoconutDock
                    .padding(.horizontal, 18)
                    .padding(.bottom, isCompact ? 6 : 10)

                stageEnergyRail
                    .padding(.horizontal, 18)
                    .padding(.bottom, isCompact ? 8 : 12)

                stageInjectButton
                    .padding(.horizontal, 18)
                    .padding(.bottom, isCompact ? 10 : 18)
            }

            if let reward = openedUpgradeReward {
                OasisStageOpenedRewardCard(
                    reward: reward,
                    localization: l,
                    onClose: {
                        withAnimation(GoMotion.feedback) {
                            dismissUpgradeReward()
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }

            if levelUpBadgeVisible {
                stageLevelUpBadge
            }
        }
        .frame(height: stageHeight)
        .clipShape(stageShape)
        .overlay(stageShape.strokeBorder(Color.goPrimary.opacity(0.22), lineWidth: 1))
        .contentShape(stageShape)
        .onAppear {
            treeStageAppearTask?.cancel()
            treeStageAppearTask = OhanaFrameScheduler.runAfterNextFrame {
                refreshTreeHarvestSnapshot()
                updateGlowMotion()
                treeStageAppearTask = nil
            }
        }
        .onChange(of: treeVisualLevel) { oldLevel, newLevel in
            refreshTreeHarvestSnapshot()
            if newLevel.rawValue > oldLevel.rawValue {
                triggerLevelUpFeedback()
            }
        }
    }

    func stageBackground(shape: RoundedRectangle) -> some View {
        shape
            .fill(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color(hex: "D9E8FA"), Color(hex: "BFD1EA"), Color(hex: "8DA8D4")]
                        : [Color(hex: "081338"), Color(hex: "051027"), Color(hex: "020617")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .fill(
                        RadialGradient(
                            colors: [treeVisualLevel.glowColor.opacity(colorScheme == .light ? 0.22 : 0.32), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 300
                        )
                    )
            }
    }

    var stageStars: some View {
        ZStack {
            ForEach(0 ..< 24, id: \.self) { i in
                let size = CGFloat([1.5, 2.0, 2.5, 1.8][i % 4])
                Circle()
                    .fill(Color.ohanaPrimaryText.opacity(Double([0.28, 0.44, 0.24, 0.5][i % 4])))
                    .frame(width: size, height: size)
                    .offset(x: starPositions[i].0, y: starPositions[i].1)
            }
        }
        .opacity(colorScheme == .light ? 0.45 : 1)
    }

    var stageIslandBase: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .light
                            ? [Color(hex: "D4B989"), Color(hex: "B58B55")]
                            : [Color(hex: "E2A545"), Color(hex: "9A5B22")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 304, height: 56)
                .blur(radius: 0.2)

            Ellipse()
                .fill(Color.black.opacity(colorScheme == .light ? 0.12 : 0.26)) // ui-v4: allow grounded island stage shadow
                .frame(width: 250, height: 18)
                .offset(y: 11)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 110)
        .allowsHitTesting(false)
    }

    var stageTreeGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [treeVisualLevel.glowColor.opacity(glowBreathing ? 0.30 : 0.10), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 190
                    )
                )
                .frame(width: 340, height: 340)
                .scaleEffect(glowBreathing ? 1.08 : 0.94)
                .animation(
                    shouldRunAmbientMotion
                        ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated stage glow; smoothness: allow visible-only ambient tree glow
                        : nil,
                    value: glowBreathing
                )

            Circle()
                .stroke(Color.goPrimary.opacity(glowBreathing ? 0.18 : 0.05), lineWidth: 2)
                .frame(width: 250, height: 250)
                .blur(radius: glowBreathing ? 7 : 2)
                .animation(
                    shouldRunAmbientMotion
                        ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated stage ring; smoothness: allow visible-only ambient tree ring
                        : nil,
                    value: glowBreathing
                )
        }
        .offset(y: -32)
        .allowsHitTesting(false)
    }

    var treeEnergyBeam: some View {
        let progress = max(0, min(1, treeInjectionProgress))
        return VStack(spacing: 0) {
            Spacer()
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.goPrimary.opacity(0), Color.goPrimary.opacity(0.85), Color.goTeal.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 2 + 7 * progress, height: 52 + 168 * progress)
                .blur(radius: 10 - 5 * progress)
                .opacity(0.9 * Double(progress))
                .offset(y: -18 - 120 * progress)
                .animation(
                    interactionMotionBudget.allowsMotion ? GoMotion.feedback : GoMotion.reduced,
                    value: treeInjectionProgress
                )
        }
        .allowsHitTesting(false)
    }

    var stageTopHUD: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                OhanaFeedback.light()
                openSheet(.growthRoadmap)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lv.\(treeVisualLevel.rawValue)")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(treeVisualLevel.displayName)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .accessibilityLabel(l.tr(
                zh: "椰子树等级 Lv.\(treeVisualLevel.rawValue)",
                en: "Coconut Tree level \(treeVisualLevel.rawValue)",
                de: "Kokosbaum Stufe \(treeVisualLevel.rawValue)"
            ))
            .accessibilityHint(l.tr(
                zh: "打开升级路线和解锁规则",
                en: "Open upgrade roadmap and unlock rules",
                de: "Upgrade-Roadmap und Freischaltregeln öffnen"
            ))

            Spacer(minLength: 4)
        }
    }

    var treeCritterEntryButton: some View {
        let critter = featuredCritter
        let catalogId = critter?.catalogId ?? nextCritterTargetCatalogId
        let snapshot = critter.map { critterRenderSnapshot(for: $0).lifecycle }
        let tint = snapshot.map { critterLifecycleTint(for: $0.state) } ?? Color.goPrimary
        let statusIcon = snapshot.map { critterLifecycleIcon(for: $0.state) } ?? "lock.fill"
        let lockedLevel = lockedLevel(requiredLevel: critterUnlockLevel)
        let isLocked = lockedLevel != nil || critter == nil

        return Button {
            guard lockedLevel == nil else {
                OhanaFeedback.error()
                return
            }
            openCritterEntry()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if !isLocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    critterLifecycleAuraTint(snapshot?.state ?? .healthy).opacity(snapshot?.state == .healthy ? 0.42 : 0.68),
                                    critterLifecycleAuraTint(snapshot?.state ?? .healthy).opacity(0.18),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 6,
                                endRadius: 42
                            )
                        )
                        .frame(width: 82, height: 82)
                        .blur(radius: snapshot?.state == .healthy ? 8 : 12)
                        .shadow(color: critterLifecycleAuraTint(snapshot?.state ?? .healthy).opacity(snapshot?.state == .healthy ? 0.24 : 0.54), radius: 18, y: 0) // ui-v4: allow state aura for tree critter
                }

                OasisCritterIllustration(catalogId: catalogId, locked: isLocked, size: 60, critter: critter)
                    .offset(y: -2)

                Image(systemName: statusIcon)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(snapshot?.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                    .frame(width: 22, height: 22) // a11y: allow decorative critter status badge
                    .background(tint, in: Circle())
                    .overlay(Circle().strokeBorder(Color.ohanaCardSurface.opacity(0.84), lineWidth: 1))
                    .offset(x: 3, y: 3)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                Text(critterEntryBadgeTitle(critter: critter, lockedLevel: lockedLevel))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ohanaCardSurface.opacity(0.84), in: Capsule())
                    .offset(y: 13)
            }
            .frame(width: 82, height: 88)
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(
            lockedLevel.map {
                lockedLevelAccessibility(
                    l.tr(zh: "电子宠物", en: "Critters", de: "Critter"),
                    level: $0
                )
            } ?? (critter == nil ? nextCritterGoalText : l.tr(zh: "电子宠物小窝", en: "Critter nest", de: "Critter-Nest"))
        )
    }

    func critterEntryBadgeTitle(critter: OasisElectronicPet?, lockedLevel: Int?) -> String {
        if let lockedLevel {
            return l.tr(zh: "Lv.\(lockedLevel) 解锁", en: "Lv.\(lockedLevel)", de: "Lv.\(lockedLevel)")
        }
        return critter?.displayName(l) ?? l.tr(zh: "Lv.10", en: "Lv.10", de: "Lv.10")
    }

    func lockedLevelAccessibility(_ title: String, level: Int) -> String {
        "\(title), \(l.tr(zh: "Lv.\(level) 解锁", en: "unlocks at level \(level)", de: "ab Level \(level)"))"
    }

    var critterNestPopupOverlay: some View {
        GeometryReader { proxy in
            let progress = min(max(critterNestPopupProgress, 0), 1)
            ZStack {
                Color.black.opacity(0.34 * Double(progress)) // ui-v4: allow modal scrim
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeCritterNest()
                    }

                OasisCritterCodexRouteContainer(
                    mode: .nest,
                    isPopup: true,
                    onClose: {
                        closeCritterNest()
                    },
                    onPresentCoconutLog: onPresentCoconutLog ?? { _ in }
                )
                .frame(
                    width: min(proxy.size.width - 20, 430),
                    height: min(proxy.size.height - 86, 760)
                )
                .padding(.horizontal, 10)
                .scaleEffect(0.92 + 0.08 * progress, anchor: .center)
                .offset(y: (1 - progress) * 24)
                .opacity(Double(progress))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(progress > 0.04)
        }
    }

    var critterNestPopupOpenAnimation: Animation {
        shouldRunAmbientMotion ? GoMotion.heroExpand : GoMotion.reduced
    }

    var critterNestPopupCloseAnimation: Animation {
        shouldRunAmbientMotion ? GoMotion.heroCollapse : GoMotion.reduced
    }

    var critterNestPopupCloseDelay: Double {
        shouldRunAmbientMotion ? 0.54 : 0.12
    }

    func closeCritterNest() {
        guard showCritterNest || critterNestPopupProgress > 0.001 else { return }
        withAnimation(critterNestPopupCloseAnimation) {
            critterNestPopupProgress = 0
        }
        critterNestCloseTask?.cancel()
        critterNestCloseTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: UInt64(critterNestPopupCloseDelay * 1000)) {
            if critterNestPopupProgress <= 0.001 {
                showCritterNest = false
            }
            critterNestCloseTask = nil
        }
    }

    var stageUpgradeCoconutDock: some View {
        HStack(spacing: 10) {
            if let reward = openedUpgradeReward {
                HStack(spacing: 6) {
                    OasisRewardKindIcon(reward: reward, size: 13)
                    Text(reward.title(l))
                        .lineLimit(1)
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color.ohanaControlFill, in: Capsule())
            }

            if pendingUpgradeCoconuts.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles") // a11y: allow decorative empty-state sparkle
                        .accessibilityHidden(true)
                    Text(nextStageHint)
                        .lineLimit(1)
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                ForEach(Array(pendingUpgradeCoconuts.prefix(3)), id: \.id) { coconut in
                    stageUpgradeCoconutButton(coconut)
                }
                if pendingUpgradeCoconuts.count > 3 {
                    Text("+\(pendingUpgradeCoconuts.count - 3)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 42, height: 42) // a11y: allow noninteractive overflow count chip
                        .background(Color.ohanaControlFill, in: Circle())
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }

    func stageUpgradeCoconutButton(_ coconut: OasisUpgradeCoconut) -> some View {
        let isOpening = openingUpgradeCoconutId == coconut.id
        let isMilestone = coconut.rewardKind == .electronicPet
        return Button {
            openUpgradeCoconut(coconut)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Text("🥥")
                    .font(OhanaFont.metric(size: 28))
                    .rotationEffect(.degrees(isOpening ? -12 : 0))
                    .scaleEffect(isOpening ? 1.14 : 1)
                    .frame(width: 48, height: 48)
                    .background(isMilestone ? Color.goPrimary.opacity(0.18) : Color.ohanaControlFill, in: Circle())
                Image(systemName: "hammer.fill") // a11y: allow decorative button badge
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 19, height: 19) // a11y: allow decorative button badge
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.feedback, value: isOpening)
        .accessibilityLabel("\(coconut.title(l)) \(l.tr(zh: "敲开", en: "Open", de: "Öffnen"))")
    }

    var stageEnergyRail: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(treeVisualLevel == .lv10 ? l.tr(zh: "满级", en: "Max", de: "Max") : "\(treeVisualTotalEnergy)/\(treeVisualNextLevelThreshold)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                Text(treePassiveIncomeAmount > 0 ? "+\(treePassiveIncomeAmount)🥥/d" : "Lv.5 🥥")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * treeVisualProgressToNextLevel))
                        .contentTransition(.numericText())
                }
                .frame(height: 8)
                .animation(GoMotion.page, value: treeVisualProgressToNextLevel)
            }
            .frame(height: 8)
        }
    }

    var stageInjectButton: some View {
        let canInject = canInjectTreeEnergy
        let unavailableReason = treeInjectionUnavailableReason
        return Button {
            if canInject {
                injectTreeEnergy()
            } else {
                handleBlockedTreeInjectionTap()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill") // a11y: allow decorative action icon paired with label
                    .font(OhanaFont.subheadline(.black))
                    .accessibilityHidden(true)
                Text(unavailableReason ?? l.tr(zh: "注入 +20XP", en: "Infuse +20XP", de: "+20XP einspeisen"))
                    .font(OhanaFont.callout(.black))
                if unavailableReason == nil {
                    Text("-80🥥")
                        .font(OhanaFont.caption(.black))
                        .opacity(0.66)
                }
            }
            .foregroundStyle(canInject ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(canInject ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(canInject ? 1 : 0.55)
        .accessibilityHint(unavailableReason ?? l.tr(
            zh: "消耗 80 个椰子，为生命之树增加 20 点成长经验",
            en: "Spend 80 coconuts to add 20 growth XP to the Life Tree",
            de: "Verbraucht 80 Kokosnüsse für 20 Wachstums-XP"
        ))
    }

    var stageLevelUpBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles") // a11y: allow decorative level badge icon
                .font(OhanaFont.footnote(.black))
                .accessibilityHidden(true)
            Text("Lv.\(treeVisualLevel.rawValue)")
                .font(OhanaFont.caption(.black))
                .monospacedDigit()
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.goPrimary, in: Capsule())
        .shadow(color: Color.goPrimary.opacity(0.55), radius: 16, x: 0, y: 6) // ui-v4: allow transient level-up celebration
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .transition(.scale.combined(with: .opacity))
        .allowsHitTesting(false)
    }

    var nextStageHint: String {
        if treeVisualLevel == .lv10 {
            return l.tr(zh: "树冠已觉醒", en: "Tree awakened", de: "Baum erwacht")
        }
        return l.tr(zh: "下一颗升级椰子在树上成长", en: "Next upgrade coconut is growing", de: "Nächste Upgrade-Kokosnuss wächst")
    }

    var nextCritterTargetCatalogId: String {
        let ownedIds = Set(electronicPets.filter { !$0.isArchived }.map(\.catalogId))
        return OasisUpgradeRewardCatalog.critters
            .sorted { $0.sourceLevel < $1.sourceLevel }
            .first { !ownedIds.contains($0.id) }?
            .id ?? OasisUpgradeRewardCatalog.firstCritterId
    }

    func harvestTreeCoconut(_ idx: Int) {
        guard idx >= 0,
              idx < dailyTreeCoconutCount,
              !harvestedCoconutIndices.contains(idx),
              !treeHarvestBuffer.pendingIndices.contains(idx) else { return }
        OhanaFeedback.medium()
        withAnimation(GoMotion.feedback) {
            _ = harvestedCoconutIndices.insert(idx)
        }
        applyCoconutBalanceVisualDelta(1)
        treeHarvestBuffer.pendingIndices.insert(idx)
        treeHarvestBuffer.commitTask?.cancel()
        treeHarvestBuffer.commitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            commitPendingTreeHarvests()
        }
    }

    func commitPendingTreeHarvests(reconcile: Bool = true) {
        let pendingIndices = treeHarvestBuffer.pendingIndices
        guard !pendingIndices.isEmpty else {
            treeHarvestBuffer.commitTask = nil
            return
        }

        let capacity = BeautifulCoconutTree.coconutCapacity(for: treeVisualLevel.rawValue)
        var awardedCount = 0
        var latestSnapshot: OasisDailyTreeCoconutSnapshot?
        for index in pendingIndices.sorted() {
            let before = treeMgr.dailyTreeCoconutSnapshot(maxCoconutCount: capacity)
            guard !before.harvestedIndices.contains(index) else {
                latestSnapshot = before
                continue
            }
            let after = treeMgr.markDailyTreeCoconutHarvested(index, maxCoconutCount: capacity)
            latestSnapshot = after
            if after.harvestedIndices.contains(index) {
                awardedCount += 1
            }
        }

        treeHarvestBuffer.pendingIndices.removeAll()
        if let latestSnapshot {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                harvestedCoconutIndices = latestSnapshot.harvestedIndices
            }
        }
        if awardedCount > 0 {
            commandExecutor.awardHarvestedTreeCoconuts(awardedCount)
        }
        if reconcile {
            reconcileCoconutBalanceAfterCommand()
        }
        treeHarvestBuffer.commitTask = nil
    }

    func applyCoconutBalanceVisualDelta(_ amount: Int) {
        guard amount != 0 else { return }
        let targetBalance = max(0, activeHumanCoconutBalance + amount)
        withAnimation(GoMotion.feedback) {
            coconutBalanceVisualOverride = targetBalance
            actionSnapshot.activeCoconutBalance = targetBalance
            actionSnapshot.canInjectCoconuts = targetBalance >= 80
            bentoSnapshot.shopMetric = "\(targetBalance)"
        }
    }

    func reconcileCoconutBalanceAfterCommand() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            rebuildOasisRenderSnapshots()
            coconutBalanceVisualOverride = nil
        }
    }

    func openCritterEntry() {
        guard !showCritterNest, critterNestPopupProgress <= 0.001 else { return }
        OhanaFeedback.light()
        critterNestCloseTask?.cancel()
        critterNestCloseTask = nil
        critterNestOpenTask?.cancel()
        critterNestOpenTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 40) {
            showCritterNest = true
            critterNestPopupProgress = max(critterNestPopupProgress, 0.001)
            withAnimation(critterNestPopupOpenAnimation) {
                critterNestPopupProgress = 1
            }
            critterNestOpenTask = nil
        }
    }

    func injectTreeEnergy() {
        guard !treeInjectionLocked else {
            handleBlockedTreeInjectionTap()
            return
        }
        guard hasAvailableTreeInjection else {
            handleBlockedTreeInjectionTap()
            return
        }

        let motionBudget = interactionMotionBudget
        let visualAnimation = motionBudget.allowsMotion ? GoMotion.feedback : GoMotion.reduced
        let commandDelay: UInt64 = motionBudget.usesFullMotion ? 280 : 120
        let resetDelay: UInt64 = motionBudget.usesFullMotion ? 230 : 120
        let thawDelay: UInt64 = motionBudget.usesFullMotion ? 120 : 48
        let beforeLevel = treeVisualLevel
        let beforeBalance = activeHumanCoconutBalance
        let targetBalance = max(0, beforeBalance - 80)
        let targetEnergy = treeMgr.totalEnergy + 20
        let targetLevel = treeMgr.treeLevel(forTotalEnergy: targetEnergy)
        let isLevelUp = targetLevel.rawValue > beforeLevel.rawValue
        let pulseBoost: CGFloat = motionBudget.usesFullMotion ? (isLevelUp ? 0.045 : 0.026) : 0.01
        injectionPulseToken += 1
        let pulseToken = injectionPulseToken
        OhanaFeedback.light()
        treeInjectionLocked = true
        withAnimation(visualAnimation) {
            coconutBalanceVisualOverride = targetBalance
            actionSnapshot.activeCoconutBalance = targetBalance
            actionSnapshot.canInjectCoconuts = targetBalance >= 80
            bentoSnapshot.shopMetric = "\(targetBalance)"
            treeVisualEnergyOverride = targetEnergy
            isInjecting = true
            treeInjectionBoost = pulseBoost
            treeInjectionProgress = 1
        }
        if isLevelUp {
            triggerLevelUpFeedback()
        }

        treeCommandTask?.cancel()
        treeCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: commandDelay) {
            let didInject = commandExecutor.injectTreeEnergy(treeManager: treeMgr)
            if didInject {
                treeCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: thawDelay) {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        rebuildOasisRenderSnapshots()
                        isInjecting = false
                        treeInjectionLocked = false
                        treeVisualEnergyOverride = nil
                        coconutBalanceVisualOverride = nil
                    }
                    treeCommandTask = nil
                }
            } else {
                injectionResetTask?.cancel()
                injectionResetTask = nil
                withAnimation(visualAnimation) {
                    isInjecting = false
                    treeInjectionLocked = false
                    treeInjectionProgress = 0
                    treeInjectionBoost = 0.026
                    treeVisualEnergyOverride = nil
                    coconutBalanceVisualOverride = nil
                }
                rebuildOasisRenderSnapshots()
                OhanaFeedback.error()
                treeCommandTask = nil
            }
        }

        injectionResetTask?.cancel()
        injectionResetTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: resetDelay) {
            guard injectionPulseToken == pulseToken else {
                injectionResetTask = nil
                return
            }
            withAnimation(visualAnimation) {
                treeInjectionProgress = 0
            }
            injectionResetTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
                guard injectionPulseToken == pulseToken else {
                    injectionResetTask = nil
                    return
                }
                treeInjectionBoost = 0.026
                injectionResetTask = nil
            }
        }
    }

    func handleBlockedTreeInjectionTap() {
        OhanaFeedback.error()
        scheduleOasisRenderSnapshotRefresh(milliseconds: 60)
    }
}
