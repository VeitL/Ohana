//
//  TodayFocusCard+Runtime.swift
//  Ohana
//

import SwiftUI

extension TodayFocusCard {
    var renderDeckDependencyKey: String {
        [
            Self.snapshotDeckDependencyKey(snapshot),
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
        case .quest(let q): return questSkipKey(for: q)
        case .familyTask(let task): return familyTaskSkipKey(for: task)
        case .coconutExchange(let request): return exchangeSkipKey(for: request)
        case .negative(let s): return negativeSkipKey(for: s)
        case .memory(let m): return "memory:\(m.headline)"
        case .celebrate: return "celebrate"
        case .welcome: return "welcome"
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
        if let petId = signal.petId, let alertType = signal.healthAlertType {
            return "negative:health:\(petId.uuidString):\(alertType.rawValue)"
        }
        return "negative:\(signal.title)|\(signal.detail)"
    }

    static func snapshotDeckDependencyKey(_ snapshot: TodayFocusSnapshot) -> String {
        [
            snapshot.refreshedQuests.map { "\($0.id):\($0.isCompleted)" }.joined(separator: "|"),
            snapshot.assignedFamilyTasks.map { "\($0.id.uuidString):\($0.statusRaw):\(timestamp($0.updatedAt))" }.joined(separator: "|"),
            snapshot.pendingExchangeRequests.map { "\($0.id.uuidString):\($0.statusRaw):\(timestamp($0.updatedAt))" }.joined(separator: "|"),
            snapshot.negativeSignals.map { negativeSkipKey(for: $0) }.joined(separator: "|"),
            "pets:\(snapshot.pets.count)",
            "plants:\(snapshot.plants.count)",
            "humans:\(snapshot.humans.count)"
        ].joined(separator: "#")
    }

    static func timestamp(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
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
            selectedFocusIndex = 0
            hiddenFocusVersion += 1
        }
        rebuildRenderDeck(disablesAnimations: false)
        TodayFocusHiddenStateStore.clearSkippedFocusKeys()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func persistHiddenFocusKeys() {
        TodayFocusHiddenStateStore.save(
            skippedFocusKeys: skippedFocusKeys,
            closedNegativeKeys: closedNegativeKeys
        )
    }

    static func loadSkippedFocusKeys() -> Set<String> {
        TodayFocusHiddenStateStore.loadSkippedFocusKeys()
    }

    static func loadClosedNegativeKeys() -> Set<String> {
        TodayFocusHiddenStateStore.loadClosedNegativeKeys()
    }

    @ViewBuilder
    func cardBackground(_ accent: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
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
