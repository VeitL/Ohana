//
//  TodayFocusCard+ContentCards.swift
//  Ohana
//

import SwiftUI

extension TodayFocusCard {
    @ViewBuilder
    func cardContent(_ content: TodayFocusContent) -> some View {
        switch content {
        case let .quest(q): questCard(q)
        case let .familyTask(t): familyTaskCard(t)
        case let .coconutExchange(request): exchangeCard(request)
        case let .negative(s): negativeCard(s)
        case .celebrate: celebrateCard
        case .welcome: welcomeCard
        }
    }

    // MARK: - Quest card

    func questCard(_ q: IslandQuest) -> some View {
        let accent = Color.goPrimary
        return HStack(spacing: 8) {
            Button {
                OhanaFeedback.light()
                onOpenQuest(q)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(q.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 1.0)
                        questMetaRow(q)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier(questCardAccessibilityIdentifier(for: q))
            .frame(maxWidth: .infinity, alignment: .leading)

            focusActionButton(
                icon: questActionIcon(for: q),
                title: questActionTitle(for: q),
                accent: accent
            ) {
                OhanaFeedback.medium()
                onCompleteQuest(q)
            }
            .accessibilityIdentifier(questActionAccessibilityIdentifier(for: q))
        }
        .padding(.horizontal, TodayFocusCardLayout.contentHorizontalPadding)
        .padding(.vertical, TodayFocusCardLayout.contentVerticalPadding)
        .background(cardBackground(accent))
    }

    func familyTaskCard(_ task: TodayFocusFamilyTaskSnapshot) -> some View {
        let accent = task.hasReward ? Color.goTeal : Color.goPurple
        let rewardText = task.rewardCoconuts > 0 ? " · +\(task.rewardCoconuts)🥥" : ""
        let performer = task.completedByName ?? l.tr(zh: "对方", en: "Someone", de: "Jemand")
        let actionTitle = task.status == .pendingReview
            ? l.tr(zh: "去确认", en: "Review", de: "Prüfen")
            : l.tr(zh: "去处理", en: "Open", de: "Öffnen")
        return HStack(spacing: 8) {
            Button {
                OhanaFeedback.light()
                onTapFamilyTask(task)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 1.0)
                        Text(taskStatusLine(task, performer: performer, rewardText: rewardText))
                            .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 0.72)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            focusActionButton(
                icon: task.status == .pendingReview ? "checkmark.seal.fill" : "arrow.right",
                title: actionTitle,
                accent: accent
            ) {
                OhanaFeedback.medium()
                onTapFamilyTask(task)
            }
        }
        .padding(.horizontal, TodayFocusCardLayout.contentHorizontalPadding)
        .padding(.vertical, TodayFocusCardLayout.contentVerticalPadding)
        .background(cardBackground(accent))
        .ohanaPing(trigger: task.statusRaw, accent: Color.goYellow, isEnabled: task.status == .pendingReview && task.hasReward)
        .ohanaShine(trigger: task.statusRaw, cornerRadius: OhanaRadius.input, isEnabled: task.status == .pendingReview)
    }

    func exchangeCard(_ request: TodayFocusExchangeRequestSnapshot) -> some View {
        let accent = Color.goYellow
        let amount = CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)
        return HStack(spacing: 8) {
            Button {
                OhanaFeedback.light()
                onOpenExchange(request)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "确认线下收款", en: "Confirm cash received", de: "Zahlung bestätigen"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 1.0)
                        Text("\(request.senderName) → \(amount) · \(request.coconutCost)🥥")
                            .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 0.72)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            focusActionButton(
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "已收到", en: "Received", de: "Erhalten"),
                accent: accent
            ) {
                confirmExchange(request)
            }
        }
        .padding(.horizontal, TodayFocusCardLayout.contentHorizontalPadding)
        .padding(.vertical, TodayFocusCardLayout.contentVerticalPadding)
        .background(cardBackground(accent))
    }

    @ViewBuilder
    func questMetaRow(_ quest: IslandQuest) -> some View {
        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            let tokens = Array(refreshedQuests
                .filter { IslandQuestEngine.isOasisBuildQuest($0.id) }
                .prefix(TodayFocusLimits.maxOasisBuildTokens))
            let completed = tokens.filter(\.isCompleted).count
            compactMetaChip(
                text: l.tr(
                    zh: "\(completed)/\(tokens.count) 入门",
                    en: "\(completed)/\(tokens.count) setup",
                    de: "\(completed)/\(tokens.count) Start"
                ),
                tint: Color.goPrimary
            )
            .accessibilityLabel(l.tr(zh: "岛屿建设任务", en: "Oasis build quests", de: "Oase-Aufgaben"))
        } else if let name = questTargetName(quest) {
            compactMetaChip(text: name, tint: Color.goPrimary)
        } else {
            compactMetaChip(text: l.tr(zh: "今天", en: "Today", de: "Heute"), tint: Color.goPrimary)
        }
    }

    func compactMetaChip(text: String, tint: Color) -> some View {
        HStack(spacing: 0) {
            Text(text)
                .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                .lineLimit(1)
                .todayFocusReadableShadow(strength: 0.55)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
    }

    func questTargetName(_ quest: IslandQuest) -> String? {
        if let petId = quest.targetPetId,
           let pet = snapshot.pets.first(where: { $0.id == petId }) {
            return pet.name
        }
        if PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel),
           let plantId = quest.targetPlantId,
           let plant = snapshot.plants.first(where: { $0.id == plantId }) {
            return plant.name
        }
        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           let human = snapshot.humans.first(where: { $0.id == humanId }) {
            return human.name
        }
        return nil
    }

    func taskStatusLine(_ task: TodayFocusFamilyTaskSnapshot, performer: String, rewardText: String) -> String {
        if task.status == .pendingReview {
            return l.tr(
                zh: "\(performer) 待确认\(rewardText)",
                en: "\(performer) · review\(rewardText)",
                de: "\(performer) · prüfen\(rewardText)"
            )
        }
        let target = task.assignedToName ?? task.claimedByName ?? l.tr(zh: "全家", en: "Open", de: "Offen")
        return "\(task.createdByName) → \(target)\(rewardText)"
    }

    // MARK: - Negative signal card

    func negativeCard(_ s: IslandNegativeSignal) -> some View {
        let accent = s.severity == .critical ? Color.goRed : Color.goYellow
        return HStack(spacing: 8) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapNegativeSignal(s)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 1.0)
                        Text(s.detail.isEmpty ? negativeStatusText(for: s) : s.detail)
                            .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(s.detail.isEmpty ? accent : Color.ohanaPrimaryText.opacity(0.62))
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 0.72)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            focusActionButton(
                icon: negativeActionIcon(for: s),
                title: negativeActionTitle(for: s),
                accent: accent
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onTapNegativeSignal(s)
            }
        }
        .padding(.horizontal, TodayFocusCardLayout.contentHorizontalPadding)
        .padding(.vertical, TodayFocusCardLayout.contentVerticalPadding)
        .background(cardBackground(accent))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.title). \(s.detail.isEmpty ? negativeStatusText(for: s) : s.detail)")
    }

    func negativeActionTitle(for signal: IslandNegativeSignal) -> String {
        switch signal.healthAlertType {
        case .weightGainAlert, .weightLossAlert:
            l.tr(zh: "趋势", en: "Trend", de: "Trend")
        case .drinkingWeightAlert:
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .none:
            signal.severity == .critical ? l.tr(zh: "处理", en: "Act", de: "Los") : l.tr(zh: "查看", en: "Open", de: "Öffnen")
        default:
            signal.severity == .critical ? l.tr(zh: "处理", en: "Act", de: "Los") : l.tr(zh: "查看", en: "Open", de: "Öffnen")
        }
    }

    func negativeStatusText(for signal: IslandNegativeSignal) -> String {
        signal.severity == .critical
            ? l.tr(zh: "紧急", en: "Urgent", de: "Dringend")
            : l.tr(zh: "关注", en: "Watch", de: "Achten")
    }

    // MARK: - Celebrate card

    var celebrateCard: some View {
        let accent = Color.goYellow
        return HStack(spacing: 8) {
            Button {
                OhanaFeedback.light()
                onTapOasis()
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasNoHiddenFocusCards
                            ? l.tr(zh: "今日清空", en: "All clear", de: "Alles klar")
                            : l.tr(zh: "已收起项目", en: "Hidden today", de: "Heute ausgeblendet"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 1.0)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            focusActionButton(
                icon: hasNoHiddenFocusCards ? "leaf.fill" : "arrow.uturn.backward",
                title: hasNoHiddenFocusCards
                    ? l.tr(zh: "绿洲", en: "Oasis", de: "Oase")
                    : l.tr(zh: "恢复", en: "Restore", de: "Zurück"),
                accent: accent
            ) {
                if hasNoHiddenFocusCards {
                    onTapOasis()
                } else {
                    restoreSkippedFocusCards()
                }
            }
        }
        .padding(.horizontal, TodayFocusCardLayout.contentHorizontalPadding)
        .padding(.vertical, TodayFocusCardLayout.contentVerticalPadding)
        .background(cardBackground(accent))
    }

    // MARK: - Welcome card

    var welcomeCard: some View {
        let accent = Color.goPrimary
        return HStack(spacing: 8) {
            Button {
                OhanaFeedback.light()
                onTapOasis()
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "添加第一只宠物", en: "Add your first pet", de: "Erstes Haustier hinzufügen"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 1.0)
                        Text(l.tr(zh: "先让伙伴住进岛屿", en: "Bring a companion home", de: "Hol einen Begleiter nach Hause"))
                            .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 0.72)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("home-add-first-pet-card")
            .frame(maxWidth: .infinity, alignment: .leading)

            focusActionButton(
                icon: "pawprint.circle.fill",
                title: l.tr(zh: "添加", en: "Add", de: "Neu"),
                accent: accent
            ) {
                OhanaFeedback.medium()
                onTapOasis()
            }
            .accessibilityIdentifier("home-add-first-pet-action")
        }
        .padding(.horizontal, TodayFocusCardLayout.contentHorizontalPadding)
        .padding(.vertical, TodayFocusCardLayout.contentVerticalPadding)
        .background(cardBackground(accent))
    }

    // MARK: - Helpers

    func focusActionButton(icon: String, title: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 10, weight: .black))

                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(accent, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func questActionIcon(for quest: IslandQuest) -> String {
        if IslandQuestEngine.medicationId(fromQuestId: quest.id) != nil { return "pills.fill" }
        if IslandQuestEngine.humanWeightId(fromQuestId: quest.id) != nil || quest.id.hasPrefix("q_weight_") {
            return "scalemass.fill"
        }
        if quest.id.hasPrefix("q_feed_") { return "fork.knife" }
        if quest.id.hasPrefix("q_water_plant_") || quest.id == "q_water_plant" { return "drop.fill" }
        if quest.id.hasPrefix("q_water_") { return "drop.fill" }
        if quest.id.hasPrefix("q_fertilize_plant_") || quest.id == "q_fertilize_plant" { return "leaf.fill" }
        if quest.id == "q_walk" || quest.id.hasPrefix("q_walk_") { return "figure.walk" }
        if quest.id == "q_potty" || quest.id.hasPrefix("q_potty_") { return "pawprint.fill" }
        if quest.id.hasPrefix("q_play_") { return "tennisball.fill" }
        if quest.id.hasPrefix("q_moment_") { return "camera.fill" }
        if IslandQuestEngine.eventId(fromQuestId: quest.id) != nil || quest.id == "q_reminder" {
            return "calendar.badge.checkmark"
        }
        if quest.id == IslandQuestEngine.oasisPetWizardQuestId { return "pawprint.circle.fill" }
        if quest.id == IslandQuestEngine.oasisFirstMealQuestId { return "fork.knife" }
        if quest.id == IslandQuestEngine.oasisThemeQuestId { return "paintpalette.fill" }
        return "checkmark"
    }

    func questActionTitle(for quest: IslandQuest) -> String {
        if IslandQuestEngine.medicationId(fromQuestId: quest.id) != nil {
            return l.tr(zh: "服药", en: "Dose", de: "Dosis")
        }
        if IslandQuestEngine.humanWeightId(fromQuestId: quest.id) != nil || quest.id.hasPrefix("q_weight_") {
            return l.tr(zh: "记录", en: "Log", de: "Loggen")
        }
        if quest.id.hasPrefix("q_feed_") { return l.tr(zh: "喂食", en: "Feed", de: "Füttern") }
        if quest.id.hasPrefix("q_water_plant_") || quest.id == "q_water_plant" {
            return l.tr(zh: "浇水", en: "Water", de: "Gießen")
        }
        if quest.id.hasPrefix("q_water_") { return l.tr(zh: "喂水", en: "Water", de: "Wasser") }
        if quest.id.hasPrefix("q_fertilize_plant_") || quest.id == "q_fertilize_plant" {
            return l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        }
        if quest.id == "q_walk" || quest.id.hasPrefix("q_walk_") { return l.tr(zh: "开始", en: "Start", de: "Start") }
        if quest.id == "q_potty" || quest.id.hasPrefix("q_potty_") { return l.tr(zh: "记录", en: "Log", de: "Loggen") }
        if quest.id.hasPrefix("q_play_") { return l.tr(zh: "陪玩", en: "Play", de: "Spielen") }
        if quest.id.hasPrefix("q_moment_") { return l.tr(zh: "记录", en: "Log", de: "Loggen") }
        if quest.id == IslandQuestEngine.oasisPetWizardQuestId { return l.tr(zh: "添加", en: "Add", de: "Hinzufügen") }
        if IslandQuestEngine.isOasisBuildQuest(quest.id) { return l.tr(zh: "前往", en: "Open", de: "Öffnen") }
        if IslandQuestEngine.eventId(fromQuestId: quest.id) != nil || quest.id == "q_reminder" {
            return l.tr(zh: "完成", en: "Done", de: "Fertig")
        }
        return l.tr(zh: "打卡", en: "Check in", de: "Abhaken")
    }

    func questCardAccessibilityIdentifier(for quest: IslandQuest) -> String {
        if quest.id == IslandQuestEngine.oasisPetWizardQuestId {
            return "home-add-first-pet-card"
        }
        return "today-focus-quest-card-\(quest.id)"
    }

    func questActionAccessibilityIdentifier(for quest: IslandQuest) -> String {
        if quest.id == IslandQuestEngine.oasisPetWizardQuestId {
            return "home-add-first-pet-action"
        }
        return "today-focus-quest-action-\(quest.id)"
    }

    func negativeActionIcon(for signal: IslandNegativeSignal) -> String {
        switch signal.routeHint {
        case .feed:
            "fork.knife"
        case .water:
            "drop.fill"
        case .potty:
            "pawprint.fill"
        case .walk:
            "figure.walk"
        case .weight:
            "scalemass.fill"
        case .medication:
            "pills.fill"
        case .health:
            signal.severity == .critical ? "cross.case.fill" : "heart.text.square.fill"
        case .allFeatures:
            "square.grid.2x2.fill"
        case .plant:
            "leaf.fill"
        case .petOverview:
            "pawprint.fill"
        case .none:
            switch signal.healthAlertType {
            case .weightGainAlert, .weightLossAlert:
                "scalemass.fill"
            case .drinkingWeightAlert:
                "drop.fill"
            case .noPotty:
                "pawprint.fill"
            case .noWalk:
                "figure.walk"
            default:
                signal.severity == .critical ? "cross.case.fill" : "arrow.right"
            }
        }
    }

    func rewardChip(_ amount: Int) -> some View {
        HStack(spacing: 3) {
            Text("+\(amount)")
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.goYellow)
                .contentTransition(.numericText())
                .animation(GoMotion.feedback, value: amount)
                .todayFocusReadableShadow(strength: 0.9)
            Text("🥥")
                .font(OhanaFont.adaptive(size: 10))
                .ohanaSymbolPulse(trigger: amount)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.goYellow.opacity(0.15), in: Capsule())
    }

    func focusPageIndicator(count: Int, selected: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0 ..< count, id: \.self) { idx in
                Capsule()
                    .fill(idx == selected ? Color.goPrimary : Color.ohanaControlFill)
                    .frame(width: idx == selected ? 16 : 5, height: 5)
                    .animation(GoMotion.feedback, value: selected)
                    .ohanaPhasePop(trigger: selected, enabled: idx == selected)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(l.tr(
            zh: "今日任务 \(min(selected + 1, count)) / \(count)",
            en: "Today Focus \(min(selected + 1, count)) of \(count)",
            de: "Today Focus \(min(selected + 1, count)) von \(count)"
        ))
    }

    func indexedStatus(current: Int?, total: Int, zh: String, en: String, de: String) -> String {
        guard total > 0 else { return content.statusText }
        let position = (current ?? 0) + 1
        return l.tr(
            zh: "\(position)/\(total) \(zh)",
            en: "\(position)/\(total) \(en)",
            de: "\(position)/\(total) \(de)"
        )
    }
}
