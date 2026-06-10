//
//  TodayFocusCard+Runtime.swift
//  Ohana
//

import SwiftUI

extension TodayFocusCard {
    var renderDeckDependencyKey: String {
        [
            Self.snapshotDeckDependencyKey(snapshot),
            "hiddenDay:\(hiddenFocusDayToken)",
            "hidden:\(hiddenFocusVersion)"
        ].joined(separator: "#")
    }

    func rebuildRenderDeck(disablesAnimations: Bool) {
        let next = TodayFocusRenderDeck.make(
            snapshot: snapshot,
            skippedFocusKeys: skippedFocusKeys,
            closedNegativeKeys: closedNegativeKeys
        )
        var transaction = Transaction(animation: disablesAnimations ? nil : GoMotion.hero)
        transaction.disablesAnimations = disablesAnimations
        withTransaction(transaction) {
            renderDeck = next
        }
    }

    var contentIdentity: String {
        renderDeck.identity
    }

    var animationIdentity: String {
        if freezesToFrontCard {
            guard let frozenFrontContent else { return "frozen:pending" }
            return "frozen:\(contentKey(frozenFrontContent))"
        }
        return contentIdentity
    }

    var cardContentAnimation: Animation? {
        if freezesToFrontCard || presentation == .compactStack {
            return nil
        }
        return GoMotion.hero
    }

    var focusCardCountChangeKey: Int {
        freezesToFrontCard ? -1 : focusCards.count
    }

    func confirmExchange(_ request: TodayFocusExchangeRequestSnapshot) {
        onConfirmExchange(request)
    }

    func contentKey(_ content: TodayFocusContent) -> String {
        Self.contentKey(for: content)
    }

    static func contentKey(for content: TodayFocusContent) -> String {
        switch content {
        case let .quest(q): questSkipKey(for: q)
        case let .familyTask(task): familyTaskSkipKey(for: task)
        case let .coconutExchange(request): exchangeSkipKey(for: request)
        case let .negative(s): negativeSkipKey(for: s)
        case let .memory(m): "memory:\(m.headline)"
        case .celebrate: "celebrate"
        case .welcome: "welcome"
        }
    }

    func questSkipKey(_ quest: IslandQuest) -> String {
        Self.questSkipKey(for: quest)
    }

    static func questSkipKey(for quest: IslandQuest) -> String {
        "quest:\(quest.id)"
    }

    func familyTaskSkipKey(_ task: TodayFocusFamilyTaskSnapshot) -> String {
        Self.familyTaskSkipKey(for: task)
    }

    static func familyTaskSkipKey(for task: TodayFocusFamilyTaskSnapshot) -> String {
        "familyTask:\(task.id.uuidString)"
    }

    func exchangeSkipKey(_ request: TodayFocusExchangeRequestSnapshot) -> String {
        Self.exchangeSkipKey(for: request)
    }

    static func exchangeSkipKey(for request: TodayFocusExchangeRequestSnapshot) -> String {
        "coconutExchange:\(request.id.uuidString)"
    }

    func negativeSkipKey(_ signal: IslandNegativeSignal) -> String {
        Self.negativeSkipKey(for: signal)
    }

    static func negativeSkipKey(for signal: IslandNegativeSignal) -> String {
        signal.id
    }

    static func snapshotDeckDependencyKey(_ snapshot: TodayFocusSnapshot) -> String {
        [
            "day:\(snapshot.dayToken)",
            snapshot.refreshedQuests.map { quest in
                [
                    quest.id,
                    quest.title,
                    quest.subtitle,
                    quest.emoji,
                    "\(quest.isCompleted)",
                    quest.targetPetId?.uuidString ?? "",
                    quest.targetPlantId?.uuidString ?? ""
                ].joined(separator: ":")
            }.joined(separator: "|"),
            snapshot.assignedFamilyTasks.map { task in
                [
                    task.id.uuidString,
                    task.title,
                    task.statusRaw,
                    task.createdByName,
                    task.assignedToId ?? "",
                    task.assignedToName ?? "",
                    task.claimedById ?? "",
                    task.claimedByName ?? "",
                    task.completedByName ?? "",
                    "\(task.rewardCoconuts)",
                    "\(timestamp(task.updatedAt))"
                ].joined(separator: ":")
            }.joined(separator: "|"),
            snapshot.pendingExchangeRequests.map { request in
                [
                    request.id.uuidString,
                    request.senderName,
                    request.receiverId,
                    request.statusRaw,
                    request.currencyCode,
                    "\(request.localAmount)",
                    "\(request.coconutCost)",
                    "\(timestamp(request.updatedAt))"
                ].joined(separator: ":")
            }.joined(separator: "|"),
            snapshot.negativeSignals.map { signal in
                [
                    negativeSkipKey(for: signal),
                    signal.title,
                    signal.detail,
                    signal.iconName,
                    "\(signal.severity)",
                    signal.petId?.uuidString ?? "",
                    signal.plantId?.uuidString ?? "",
                    signal.healthAlertType?.rawValue ?? "",
                    signal.routeHint?.rawValue ?? ""
                ].joined(separator: ":")
            }.joined(separator: "|"),
            "pets:\(snapshot.pets.map { "\($0.id.uuidString):\($0.name):\($0.currentStreak):\($0.coconutBalance):\($0.hasPassedAway)" }.joined(separator: "|"))",
            "plants:\(snapshot.plants.map { "\($0.id.uuidString):\($0.name):\($0.wateringIntervalDays):\($0.fertilizingIntervalDays):\(timestamp($0.lastWateredDate)):\(timestamp($0.lastFertilizedDate))" }.joined(separator: "|"))",
            "humans:\(snapshot.humans.map { "\($0.id.uuidString):\($0.name):\($0.coconutBalance)" }.joined(separator: "|"))"
        ].joined(separator: "#")
    }

    static func timestamp(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970)
    }

    static func timestamp(_ date: Date?) -> Int {
        guard let date else { return 0 }
        return timestamp(date)
    }

    func skipButton(for content: TodayFocusContent, accent: Color) -> some View {
        let isNegative: Bool = {
            if case .negative = content { return true }
            return false
        }()
        return Button {
            skipFocusCard(content)
        } label: {
            Text(isNegative ? l.tr(zh: "关闭", en: "Close", de: "Schließen") : l.tr(zh: "跳过", en: "Skip", de: "Überspringen"))
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.58))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.ohanaControlFill, in: Capsule())
                .overlay(Capsule().strokeBorder(accent.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isNegative ? l.tr(zh: "关闭这条提醒", en: "Close this alert", de: "Hinweis schließen") : l.tr(zh: "跳过这张卡", en: "Skip this card", de: "Karte überspringen"))
    }

    func skipFocusCard(_ content: TodayFocusContent) {
        let key = contentKey(content)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(GoMotion.hero) {
            switch content {
            case .negative:
                _ = closedNegativeKeys.insert(key)
            default:
                _ = skippedFocusKeys.insert(key)
            }
            hiddenFocusVersion += 1
        }
        rebuildRenderDeck(disablesAnimations: false)
        persistHiddenFocusKeys()
        let nextCount = focusCards.count
        if selectedFocusIndex >= nextCount {
            selectedFocusIndex = max(0, nextCount - 1)
        }
    }

    func restoreSkippedFocusCards() {
        withAnimation(GoMotion.hero) {
            skippedFocusKeys.removeAll()
            closedNegativeKeys.removeAll()
            selectedFocusIndex = 0
            hiddenFocusVersion += 1
        }
        rebuildRenderDeck(disablesAnimations: false)
        TodayFocusHiddenStateStore.clearHiddenFocusKeys(date: Self.hiddenFocusDate(for: hiddenFocusDayToken))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func persistHiddenFocusKeys() {
        TodayFocusHiddenStateStore.save(
            skippedFocusKeys: skippedFocusKeys,
            closedNegativeKeys: closedNegativeKeys,
            date: Self.hiddenFocusDate(for: hiddenFocusDayToken)
        )
    }

    func reloadHiddenFocusKeysIfNeeded(for snapshotDayToken: Int) {
        let dayToken = snapshotDayToken == 0 ? Self.currentHiddenFocusDayToken() : snapshotDayToken
        guard dayToken != hiddenFocusDayToken else { return }
        hiddenFocusDayToken = dayToken
        skippedFocusKeys = Self.loadSkippedFocusKeys(dayToken: dayToken)
        closedNegativeKeys = Self.loadClosedNegativeKeys(dayToken: dayToken)
        selectedFocusIndex = 0
        hiddenFocusVersion += 1
    }

    static func currentHiddenFocusDayToken(date: Date = Date()) -> Int {
        TodayFocusSnapshot.dayToken(for: date)
    }

    static func hiddenFocusDate(for dayToken: Int) -> Date {
        guard dayToken > 0 else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(dayToken))
    }

    static func loadSkippedFocusKeys(dayToken: Int? = nil) -> Set<String> {
        if let dayToken {
            return TodayFocusHiddenStateStore.loadSkippedFocusKeys(date: hiddenFocusDate(for: dayToken))
        }
        return TodayFocusHiddenStateStore.loadSkippedFocusKeys()
    }

    static func loadClosedNegativeKeys(dayToken: Int? = nil) -> Set<String> {
        if let dayToken {
            return TodayFocusHiddenStateStore.loadClosedNegativeKeys(date: hiddenFocusDate(for: dayToken))
        }
        return TodayFocusHiddenStateStore.loadClosedNegativeKeys()
    }

    @ViewBuilder
    func cardBackground(_ accent: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
        if presentation == .compactStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            accent.mix(with: .white, by: 0.22).opacity(0.96),
                            accent.mix(with: .black, by: 0.10).opacity(0.96),
                            Color.arkInk.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    shape
                        .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
                }
                .clipShape(shape)
                .compositingGroup()
        } else {
            ZStack {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive(false), in: shape) // ui-v4: allow Today Focus card glass preview
                    .ohanaBreathingGlow(accent: accent, isActive: !shouldReduceWork)
            }
            .clipShape(shape)
            .compositingGroup()
        }
    }
}
