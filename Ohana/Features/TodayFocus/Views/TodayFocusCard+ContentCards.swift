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

    func carouselCardContent(_ content: TodayFocusContent, selected: Int, count: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: TodayFocusCardLayout.carouselCornerRadius, style: .continuous)
        return ZStack(alignment: .topTrailing) {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(carouselTitle(for: content))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Image(systemName: "chevron.right") // a11y: allow decorative chevron; card label carries the action
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                            .foregroundStyle(Color.arkInk.opacity(0.88))
                            .accessibilityHidden(true)

                        Spacer(minLength: 26)
                    }

                    Text(carouselSubtitle(for: content))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.48))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 7)

                    Spacer(minLength: 0)

                    carouselPageIndicator(count: count, selected: selected)
                        .padding(.bottom, 2)
                }
                .padding(.leading, 18)
                .padding(.trailing, 38)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background {
                    carouselBackground(shape: shape)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .strokeBorder(Color.arkInk.opacity(0.06), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .clipShape(shape)
                .shadow( // ui-v4: allow reference-matched floating Today Focus banner shadow
                    color: Color.arkInk.opacity(0.12),
                    radius: 18,
                    x: 0,
                    y: 10
                )
                .allowsHitTesting(false)

                Button {
                    activateCarouselContent(content)
                } label: {
                    shape
                        .fill(Color.goCardWhite.opacity(0.001))
                        .contentShape(shape)
                }
                .buttonStyle(.plain) // ui-v4: allow transparent hit proxy; activation supplies the visible card transition
                .accessibilityHidden(true)
                .zIndex(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(carouselTitle(for: content)). \(carouselSubtitle(for: content))")
            .accessibilityIdentifier(carouselCardAccessibilityIdentifier(for: content))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                activateCarouselContent(content)
            }

            if canDismissFocusContent(content) {
                Button {
                    dismissFocusContent(content)
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative close glyph; button label is set below
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.arkInk.opacity(0.20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "收起这张卡片", en: "Dismiss this card", de: "Diese Karte ausblenden"))
                .padding(.top, 8)
                .padding(.trailing, 10)
                .zIndex(2)
            }
        }
    }

    @ViewBuilder
    func carouselBackground(shape: RoundedRectangle) -> some View {
        if #available(iOS 26.0, *) {
            shape
                .fill(Color.ohanaCardSurface.opacity(0.46))
                .glassEffect(.regular.interactive(false), in: shape) // ui-v4: allow reference-matched translucent Today Focus banner
                .overlay {
                    shape.fill(Color.goCardWhite.opacity(0.32))
                }
        } else {
            shape
                .fill(.regularMaterial) // ui-v4: allow pre-iOS-26 translucent Today Focus banner fallback
                .overlay {
                    shape.fill(Color.goCardWhite.opacity(0.28))
                }
        }
    }

    func carouselTitle(for content: TodayFocusContent) -> String {
        switch content {
        case let .quest(quest):
            quest.title
        case let .familyTask(task):
            task.status == .pendingReview
                ? l.tr(zh: "确认协作任务", en: "Review shared task", de: "Aufgabe prüfen")
                : task.title
        case .coconutExchange:
            l.tr(zh: "确认线下收款", en: "Confirm cash received", de: "Zahlung bestätigen")
        case let .negative(signal):
            signal.title
        case .celebrate:
            hasNoHiddenFocusCards
                ? l.tr(zh: "今日清空", en: "All clear", de: "Alles klar")
                : l.tr(zh: "已收起项目", en: "Hidden today", de: "Heute ausgeblendet")
        case .welcome:
            l.tr(zh: "添加第一只宠物", en: "Add your first pet", de: "Erstes Haustier hinzufügen")
        }
    }

    func carouselSubtitle(for content: TodayFocusContent) -> String {
        switch content {
        case let .quest(quest):
            if !quest.subtitle.isEmpty {
                return quest.subtitle
            }
            if let name = questTargetName(quest) {
                return l.tr(
                    zh: "\(name) 今天需要你看一下。",
                    en: "\(name) needs a quick check today.",
                    de: "\(name) braucht heute einen kurzen Check."
                )
            }
            return l.tr(zh: "完成今天最重要的一件事。", en: "Take care of the most important thing today.", de: "Erledige heute das Wichtigste.")
        case let .familyTask(task):
            let rewardText = task.rewardCoconuts > 0 ? " · +\(task.rewardCoconuts)" : ""
            let performer = task.completedByName ?? l.tr(zh: "对方", en: "Someone", de: "Jemand")
            return taskStatusLine(task, performer: performer, rewardText: rewardText)
        case let .coconutExchange(request):
            let amount = CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)
            return "\(request.senderName) → \(amount) · \(request.coconutCost)"
        case let .negative(signal):
            return signal.detail.isEmpty ? negativeStatusText(for: signal) : signal.detail
        case .celebrate:
            return hasNoHiddenFocusCards
                ? l.tr(zh: "今天的重点都处理完了。", en: "Today's focus is handled.", de: "Der Fokus für heute ist erledigt.")
                : l.tr(zh: "点这里恢复今天收起的项目。", en: "Tap to restore hidden items for today.", de: "Tippen, um ausgeblendete Punkte wiederherzustellen.")
        case .welcome:
            return l.tr(zh: "先让伙伴住进岛屿。", en: "Bring a companion home first.", de: "Hol zuerst einen Begleiter nach Hause.")
        }
    }

    func activateCarouselContent(_ content: TodayFocusContent) {
        OhanaFeedback.light()
        switch content {
        case let .quest(quest):
            onOpenQuest(quest)
        case let .familyTask(task):
            onTapFamilyTask(task)
        case let .coconutExchange(request):
            onOpenExchange(request)
        case let .negative(signal):
            onTapNegativeSignal(signal)
        case .celebrate:
            if hasNoHiddenFocusCards {
                onTapOasis()
            } else {
                restoreSkippedFocusCards()
            }
        case .welcome:
            onTapOasis()
        }
    }

    func carouselCardAccessibilityIdentifier(for content: TodayFocusContent) -> String {
        switch content {
        case let .quest(quest):
            questCardAccessibilityIdentifier(for: quest)
        case .welcome:
            "home-add-first-pet-card"
        default:
            "today-focus-carousel-card-\(contentKey(content))"
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
        if let plantCareType = IslandQuestEngine.plantCareType(fromQuestId: quest.id) {
            return plantQuestActionIcon(for: plantCareType)
        }
        if quest.id.hasPrefix("q_water_") { return "drop.fill" }
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
        if let plantCareType = IslandQuestEngine.plantCareType(fromQuestId: quest.id) { return plantQuestActionTitle(for: plantCareType) }
        if quest.id.hasPrefix("q_water_") { return l.tr(zh: "喂水", en: "Water", de: "Wasser") }
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

    func plantQuestActionIcon(for type: PlantCareType) -> String {
        switch type {
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .repotting: "arrow.triangle.2.circlepath"
        case .pruning: "scissors"
        case .misting: "drop.triangle.fill"
        case .rotating: "arrow.clockwise"
        case .leafCleaning: "sparkles"
        case .pestCheck: "magnifyingglass"
        case .photo: "camera.fill"
        case .newLeaf: "leaf.circle.fill"
        case .yellowLeaf: "exclamationmark.triangle.fill"
        case .pestFound: "exclamationmark.triangle.fill"
        case .customNote: "note.text"
        }
    }

    func plantQuestActionTitle(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            l.tr(zh: "浇水", en: "Water", de: "Gießen")
        case .fertilizing:
            l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        case .repotting:
            l.tr(zh: "换盆", en: "Repot", de: "Umtopfen")
        case .pruning:
            l.tr(zh: "修剪", en: "Prune", de: "Schneiden")
        case .misting:
            l.tr(zh: "喷雾", en: "Mist", de: "Sprühen")
        case .rotating:
            l.tr(zh: "转盆", en: "Rotate", de: "Drehen")
        case .leafCleaning:
            l.tr(zh: "清洁", en: "Clean", de: "Reinigen")
        case .pestCheck:
            l.tr(zh: "检查", en: "Check", de: "Prüfen")
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            l.tr(zh: "记录", en: "Log", de: "Loggen")
        }
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

    func carouselPageIndicator(count: Int, selected: Int) -> some View {
        let visibleCount = min(max(count, 1), 5)
        let selectedDot = carouselVisibleDotIndex(selected: selected, count: count, visibleCount: visibleCount)
        return HStack(spacing: 5) {
            ForEach(0 ..< visibleCount, id: \.self) { idx in
                Capsule()
                    .fill(idx == selectedDot ? Color.arkInk.opacity(0.48) : Color.arkInk.opacity(0.14))
                    .frame(width: idx == selectedDot ? 9 : 4, height: 3)
                    .animation(GoMotion.feedback, value: selectedDot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(l.tr(
            zh: "今日重点 \(min(selected + 1, count)) / \(count)",
            en: "Today Focus \(min(selected + 1, count)) of \(count)",
            de: "Today Focus \(min(selected + 1, count)) von \(count)"
        ))
    }

    func carouselVisibleDotIndex(selected: Int, count: Int, visibleCount: Int) -> Int {
        guard count > 1, visibleCount > 1 else { return 0 }
        if count <= visibleCount {
            return min(max(selected, 0), visibleCount - 1)
        }
        let ratio = Double(min(max(selected, 0), count - 1)) / Double(count - 1)
        return min(max(Int((ratio * Double(visibleCount - 1)).rounded()), 0), visibleCount - 1)
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
