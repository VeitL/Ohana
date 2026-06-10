//
//  TodayFocusCard.swift
//  Ohana
//
//  首页简化 · 岛屿三层重构（P0）
//  首页 Today Focus 水平滑动卡组：
//  按优先级智能选出"今天最该做的 1 件事"，单卡呈现 + 微动效。
//
//  优先级：异常趋势/医疗风险 > 未完成委托 > 记忆碎片 > 全部完成庆祝 > 岛屿探访
//
//  v3 render snapshot：父级 Host/Store 准备首屏数据，卡片只负责绘制。
//

import SwiftUI

enum TodayFocusCardPresentation {
    case board
    case compactStack
}

// MARK: - TodayFocusCard

struct TodayFocusCard: View {
    let snapshot: TodayFocusSnapshot
    let presentation: TodayFocusCardPresentation
    var onOpenQuest: (IslandQuest) -> Void = { _ in }
    var onCompleteQuest: (IslandQuest) -> Void = { _ in }
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void = { _ in }
    var onTapMemory: () -> Void = {}
    var onTapOasis: () -> Void = {}
    var onTapFamilyTask: (TodayFocusFamilyTaskSnapshot) -> Void = { _ in }
    var onConfirmExchange: (TodayFocusExchangeRequestSnapshot) -> Void = { _ in }
    var freezesToFrontCard: Bool = false
    var allowsAmbientMotion: Bool = false

    @State var bounceEmoji = false
    @State var pulse: CGFloat = 0
    @State var selectedFocusIndex = 0
    @State var skippedFocusKeys: Set<String>
    @State var closedNegativeKeys: Set<String>
    @State var hiddenFocusVersion = 0
    @State var renderDeck: TodayFocusRenderDeck
    @State var frozenFrontContent: TodayFocusContent?
    @GestureState var focusDragX: CGFloat = 0

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage("today_focus_enable_ambient_motion") var enablesAmbientMotion = false

    var l: L10n { L10n(appLanguage) }

    init(
        snapshot: TodayFocusSnapshot,
        presentation: TodayFocusCardPresentation = .board,
        onOpenQuest: @escaping (IslandQuest) -> Void = { _ in },
        onCompleteQuest: @escaping (IslandQuest) -> Void = { _ in },
        onTapNegativeSignal: @escaping (IslandNegativeSignal) -> Void = { _ in },
        onTapMemory: @escaping () -> Void = {},
        onTapOasis: @escaping () -> Void = {},
        onTapFamilyTask: @escaping (TodayFocusFamilyTaskSnapshot) -> Void = { _ in },
        onConfirmExchange: @escaping (TodayFocusExchangeRequestSnapshot) -> Void = { _ in },
        freezesToFrontCard: Bool = false,
        allowsAmbientMotion: Bool = false
    ) {
        let skippedFocusKeys = TodayFocusCard.loadSkippedFocusKeys()
        let closedNegativeKeys = TodayFocusCard.loadClosedNegativeKeys()
        self.snapshot = snapshot
        self.presentation = presentation
        self.onOpenQuest = onOpenQuest
        self.onCompleteQuest = onCompleteQuest
        self.onTapNegativeSignal = onTapNegativeSignal
        self.onTapMemory = onTapMemory
        self.onTapOasis = onTapOasis
        self.onTapFamilyTask = onTapFamilyTask
        self.onConfirmExchange = onConfirmExchange
        self.freezesToFrontCard = freezesToFrontCard
        self.allowsAmbientMotion = allowsAmbientMotion
        _skippedFocusKeys = State(initialValue: skippedFocusKeys)
        _closedNegativeKeys = State(initialValue: closedNegativeKeys)
        _renderDeck = State(initialValue: TodayFocusRenderDeck.make(
            snapshot: snapshot,
            skippedFocusKeys: skippedFocusKeys,
            closedNegativeKeys: closedNegativeKeys
        ))
    }

    var shouldReduceWork: Bool {
        !surfaceGate.allowsAmbientMotion
    }

    var surfaceGate: SurfaceActivityGate {
        workloadPolicy.surfaceGate(
            isVisible: allowsAmbientMotion && !freezesToFrontCard,
            isCovered: freezesToFrontCard,
            isLive: allowsAmbientMotion,
            allowsAmbientOptIn: enablesAmbientMotion && !reduceMotion
        )
    }

    var refreshedQuests: [IslandQuest] {
        snapshot.refreshedQuests
    }

    var pendingQuests: [IslandQuest] {
        renderDeck.pendingQuests
    }

    var assignedFamilyTasks: [TodayFocusFamilyTaskSnapshot] {
        renderDeck.assignedFamilyTasks
    }

    var pendingExchangeRequests: [TodayFocusExchangeRequestSnapshot] {
        renderDeck.pendingExchangeRequests
    }

    var negativeSignals: [IslandNegativeSignal] {
        renderDeck.negativeSignals
    }

    var focusCards: [TodayFocusContent] {
        renderDeck.cards
    }

    var content: TodayFocusContent {
        let cards = renderDeck.cards
        guard !cards.isEmpty else { return .welcome }
        return cards[min(selectedFocusIndex, cards.count - 1)]
    }

    var focusStatusText: String {
        switch content {
        case .quest(let quest):
            return indexedStatus(
                current: pendingQuests.firstIndex { questSkipKey($0) == questSkipKey(quest) },
                total: pendingQuests.count,
                zh: "个任务",
                en: "tasks",
                de: "Aufgaben"
            )
        case .familyTask(let task):
            return indexedStatus(
                current: assignedFamilyTasks.firstIndex { familyTaskSkipKey($0) == familyTaskSkipKey(task) },
                total: assignedFamilyTasks.count,
                zh: "协作",
                en: "collab",
                de: "Team"
            )
        case .coconutExchange(let request):
            return indexedStatus(
                current: pendingExchangeRequests.firstIndex { exchangeSkipKey($0) == exchangeSkipKey(request) },
                total: pendingExchangeRequests.count,
                zh: "待收款",
                en: "to confirm",
                de: "offen"
            )
        case .negative, .memory, .celebrate, .welcome:
            return content.statusText
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch presentation {
            case .board:
                boardBody
            case .compactStack:
                compactBody
            }
        }
        .onAppear {
            rebuildRenderDeck(disablesAnimations: true)
            if freezesToFrontCard {
                frozenFrontContent = content
            } else {
                startAmbientPulseIfNeeded()
            }
        }
        .onChange(of: freezesToFrontCard) { _, isFrozen in
            if isFrozen {
                frozenFrontContent = content
                pulse = 0
                bounceEmoji = false
            } else {
                frozenFrontContent = nil
                startAmbientPulseIfNeeded()
            }
        }
        .onChange(of: shouldReduceWork) { _, reduced in
            if reduced {
                pulse = 0
                bounceEmoji = false
            } else {
                startAmbientPulseIfNeeded()
            }
        }
        .onChange(of: renderDeckDependencyKey) { _, _ in
            rebuildRenderDeck(disablesAnimations: true)
        }
        .onChange(of: focusCardCountChangeKey) { _, count in
            guard count >= 0 else { return }
            if selectedFocusIndex >= count {
                selectedFocusIndex = max(0, count - 1)
            }
        }
        .animation(cardContentAnimation, value: animationIdentity)
    }
}

struct TodayFocusFrozenBackPlate: View {
    let depth: Int
    let width: CGFloat
    let height: CGFloat
    let topInset: CGFloat
    let spacing: CGFloat

    private var depthValue: CGFloat {
        CGFloat(depth)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    var body: some View {
        shape
            .fill(Color.ohanaControlFill.opacity(0.58 - min(Double(depth) * 0.08, 0.24)))
            .overlay {
                shape.strokeBorder(Color.goCardWhite.opacity(0.10), lineWidth: 1)
            }
            .frame(width: width, height: height)
            .scaleEffect(max(0.86, 1 - depthValue * 0.045))
            .offset(y: topInset + depthValue * spacing)
            .brightness(-depthValue * 0.055)
            .shadow( // ui-v4: allow Today Focus frozen deck to preserve stack depth during hero handoff
                color: Color.arkInk.opacity(max(0.06, 0.18 - Double(depth) * 0.025)),
                radius: max(8, 20 - depthValue * 2),
                x: 0,
                y: max(6, 14 - depthValue)
            )
            .zIndex(10 - Double(depth))
    }
}

extension View {
    func todayFocusReadableShadow(strength: Double = 1) -> some View {
        self
            .shadow(color: Color.arkInk.opacity(0.32 * strength), radius: 2.4 * strength, x: 0, y: 1.2) // ui-v4: allow requested Today Focus text readability shadow
            .shadow(color: Color.arkInk.opacity(0.16 * strength), radius: 8 * strength, x: 0, y: 3) // ui-v4: allow requested Today Focus text readability shadow
    }
}
