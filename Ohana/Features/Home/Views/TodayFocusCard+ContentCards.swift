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
        case let .memory(m): memoryCard(m)
        case .celebrate: celebrateCard
        case .welcome: welcomeCard
        }
    }

    // MARK: - Quest card

    func questCard(_ q: IslandQuest) -> some View {
        let accent = Color.goPrimary
        return HStack(spacing: 14) {
            Button {
                OhanaFeedback.light()
                onOpenQuest(q)
            } label: {
                HStack(spacing: 14) {
                    iconBubble(emoji: q.emoji, accent: accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(q.title)
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .todayFocusReadableShadow(strength: 1.08)
                        questMetaRow(q)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 6) {
                Button {
                    OhanaFeedback.medium()
                    onCompleteQuest(q)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                        Text(l.tr(zh: "打卡", en: "Check in", de: "Abhaken"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .quest(q), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    func familyTaskCard(_ task: TodayFocusFamilyTaskSnapshot) -> some View {
        let accent = task.hasReward ? Color.goTeal : Color.goPurple
        let rewardText = task.rewardCoconuts > 0 ? " · +\(task.rewardCoconuts)🥥" : ""
        let performer = task.completedByName ?? l.tr(zh: "对方", en: "Someone", de: "Jemand")
        let actionTitle = task.status == .pendingReview
            ? l.tr(zh: "去确认", en: "Review", de: "Prüfen")
            : l.tr(zh: "去处理", en: "Open", de: "Öffnen")
        return HStack(spacing: 14) {
            Button {
                OhanaFeedback.light()
                onTapFamilyTask(task)
            } label: {
                HStack(spacing: 14) {
                    iconBubble(emoji: task.emoji, accent: accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .todayFocusReadableShadow(strength: 1.08)
                        Text(taskStatusLine(task, performer: performer, rewardText: rewardText))
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                            .lineLimit(1)
                            .todayFocusReadableShadow(strength: 0.82)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 6) {
                Button {
                    OhanaFeedback.medium()
                    onTapFamilyTask(task)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                        Text(actionTitle)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .familyTask(task), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
        .ohanaPing(trigger: task.statusRaw, accent: Color.goYellow, isEnabled: task.status == .pendingReview && task.hasReward)
        .ohanaShine(trigger: task.statusRaw, cornerRadius: OhanaRadius.input, isEnabled: task.status == .pendingReview)
    }

    func exchangeCard(_ request: TodayFocusExchangeRequestSnapshot) -> some View {
        let accent = Color.goYellow
        let amount = CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)
        return HStack(spacing: 14) {
            iconBubble(emoji: "💱", accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "确认线下收款", en: "Confirm cash received", de: "Zahlung bestätigen"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 1.08)
                Text("\(request.senderName) → \(amount) · \(request.coconutCost)🥥")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 0.82)
            }

            Spacer(minLength: 6)

            VStack(spacing: 6) {
                Button {
                    confirmExchange(request)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                        Text(l.tr(zh: "已收到", en: "Received", de: "Erhalten"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .coconutExchange(request), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    @ViewBuilder
    func questMetaRow(_ quest: IslandQuest) -> some View {
        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            let tokens = refreshedQuests.filter { IslandQuestEngine.isOasisBuildQuest($0.id) }.prefix(3)
            HStack(spacing: 5) {
                ForEach(Array(tokens), id: \.id) { token in
                    HStack(spacing: 4) {
                        Text(token.emoji)
                            .font(OhanaFont.adaptive(size: 10))
                        Image(systemName: token.isCompleted ? "checkmark" : "circle.fill")
                            .font(.system(size: token.isCompleted ? 8 : 5, weight: .black))
                    }
                    .foregroundStyle(token.isCompleted ? Color.goPrimary : Color.ohanaSecondaryText)
                    .frame(width: 36, height: 20) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(Color.ohanaControlFill, in: Capsule())
                }
            }
            .accessibilityLabel(l.tr(zh: "岛屿建设任务", en: "Oasis build quests", de: "Oase-Aufgaben"))
        } else if let name = questTargetName(quest) {
            compactMetaChip(icon: "person.crop.circle.fill", text: name, tint: Color.goPrimary)
        } else {
            compactMetaChip(icon: "clock.fill", text: l.tr(zh: "今天", en: "Today", de: "Heute"), tint: Color.goPrimary)
        }
    }

    func compactMetaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))

            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .todayFocusReadableShadow(strength: 0.55)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
    }

    func questTargetName(_ quest: IslandQuest) -> String? {
        if let petId = quest.targetPetId,
           let pet = snapshot.pets.first(where: { $0.id == petId }) {
            return pet.name
        }
        if let plantId = quest.targetPlantId,
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
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + pulse * 0.08)
                Image(systemName: s.iconName)
                    .font(OhanaFont.adaptive(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(s.title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .todayFocusReadableShadow(strength: 1.08)
                Text(negativeStatusText(for: s))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .todayFocusReadableShadow(strength: 0.82)
            }

            Spacer(minLength: 6)

            VStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTapNegativeSignal(s)
                } label: {
                    Text(negativeActionTitle(for: s))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                skipButton(for: .negative(s), accent: accent)
            }
        }
        .padding(14)
        .background(cardBackground(accent))
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

    // MARK: - Memory fragment card

    func memoryCard(_ m: MemoryFragment) -> some View {
        let accent = m.accentColor
        return HStack(spacing: 14) {
            iconBubble(emoji: m.emoji, accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(m.headline)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 1.08)
                Text(m.subline)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                    .lineLimit(2)
                    .todayFocusReadableShadow(strength: 0.82)
            }

            Spacer(minLength: 6)

            Button { onTapMemory() } label: {
                Image(systemName: "sparkles").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(accent.opacity(0.15), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Celebrate card

    var celebrateCard: some View {
        let accent = Color.goYellow
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + pulse * 0.1)
                Text("🎉")
                    .font(OhanaFont.adaptive(size: 30))
                    .scaleEffect(bounceEmoji ? 1.1 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(skippedFocusKeys.isEmpty
                    ? l.tr(zh: "今日清空", en: "All clear", de: "Alles klar")
                    : l.tr(zh: "已暂时跳过", en: "Skipped today", de: "Heute übersprungen"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .todayFocusReadableShadow(strength: 1.08)
            }

            Spacer(minLength: 6)

            Button {
                if skippedFocusKeys.isEmpty {
                    onTapOasis()
                } else {
                    restoreSkippedFocusCards()
                }
            } label: {
                Text(skippedFocusKeys.isEmpty
                    ? l.tr(zh: "绿洲", en: "Oasis", de: "Oase")
                    : l.tr(zh: "恢复", en: "Restore", de: "Zurück"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Welcome card

    var welcomeCard: some View {
        let accent = Color.goPrimary
        return HStack(spacing: 14) {
            iconBubble(emoji: "🏝️", accent: accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "岛屿欢迎你", en: "Welcome home", de: "Willkommen"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .todayFocusReadableShadow(strength: 1.08)
            }
            Spacer()
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Helpers

    @ViewBuilder
    func iconBubble(emoji: String, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 52, height: 52)
                .scaleEffect(1 + pulse * 0.06)
            Text(emoji)
                .font(OhanaFont.adaptive(size: 28))
                .offset(y: pulse * 0.8 - 0.4)
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
        .accessibilityLabel("今日任务 \(min(selected + 1, count)) / \(count)")
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
