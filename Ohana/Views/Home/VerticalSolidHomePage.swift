//
//  VerticalSolidHomePage.swift
//  Ohana
//
//  Portrait solid home page composition: Today Focus plus the real-data card scene.
//

import SwiftUI

struct VerticalSolidHomePage<QuickActions: View, ContextMenuContent: View>: View {
    let size: CGSize
    let safeBottom: CGFloat
    let displayCards: [FocusCard]
    let pets: [Pet]
    let activePets: [Pet]
    let plants: [Plant]
    let reminders: [Reminder]
    let humans: [Human]
    let events: [Event]
    let activePet: Pet?
    let selectedCardId: UUID?
    let heroProgress: CGFloat
    let heroDirection: Int
    let reduceMotion: Bool
    let isVisible: Bool
    let isLive: Bool
    let showFirstSuccessCard: Bool
    let firstQuickCheckInCompleted: Bool
    @Binding var isTodayFocusCollapsed: Bool
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusCard) -> Void
    let onCollapse: () -> Void
    let onLongPress: (FocusCard) -> Void
    let onAddPet: () -> Void
    let onAddHuman: () -> Void
    let onOpenQuest: (IslandQuest) -> Void
    let onCompleteQuest: (IslandQuest) -> Void
    let onTapNegativeSignal: (IslandNegativeSignal) -> Void
    let onTapOasis: () -> Void
    let onTapFamilyTask: (FamilyCollaborationTask) -> Void
    let onConfirmExchange: (CoconutExchangeRequest) -> Void
    let onFirstSuccessFeed: (Pet) -> Void
    let onFirstSuccessPlay: (Pet) -> Void
    let onFirstSuccessMoment: (Pet) -> Void

    var body: some View {
        let focusHeight = min(136, max(130, size.height * 0.16))
        let collapsedTopInset = focusHeight + 12
        let focusReveal = selectedCardId == nil
            ? CGFloat(1)
            : 1 - transitionSmooth(heroProgress, 0.10, 0.42)

        return ZStack(alignment: .top) {
            if displayCards.isEmpty {
                EmptyStateWelcomeCard(
                    onAddPet: onAddPet,
                    onAddHuman: onAddHuman
                )
                .padding(.horizontal, K.cardMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FocusHomeVerticalSolidScene(
                    cards: displayCards,
                    pets: pets,
                    safeTop: 0,
                    safeBottom: safeBottom,
                    selectedCardId: selectedCardId,
                    progress: heroProgress,
                    heroDirection: heroDirection,
                    reduceMotion: reduceMotion,
                    isVisible: isVisible,
                    embedsQuickActionsInCard: true,
                    collapsedTopInset: collapsedTopInset,
                    quickActions: quickActions,
                    contextMenu: contextMenu,
                    onSelect: onSelect,
                    onCollapse: onCollapse,
                    onLongPress: onLongPress
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VerticalHomeTaskDeck(
                isCollapsed: $isTodayFocusCollapsed,
                isVisible: isVisible,
                isLive: selectedCardId == nil && isVisible,
                pendingCount: reminders.count,
                height: focusHeight,
                activePets: activePets,
                plants: plants,
                reminders: reminders,
                humans: humans,
                events: events,
                activePet: activePet,
                showFirstSuccessCard: showFirstSuccessCard,
                firstQuickCheckInCompleted: firstQuickCheckInCompleted,
                onOpenQuest: onOpenQuest,
                onCompleteQuest: onCompleteQuest,
                onTapNegativeSignal: onTapNegativeSignal,
                onTapOasis: onTapOasis,
                onTapFamilyTask: onTapFamilyTask,
                onConfirmExchange: onConfirmExchange,
                onFirstSuccessFeed: onFirstSuccessFeed,
                onFirstSuccessPlay: onFirstSuccessPlay,
                onFirstSuccessMoment: onFirstSuccessMoment
            )
            .padding(.horizontal, 8)
            .opacity(Double(focusReveal))
            .scaleEffect(0.985 + 0.015 * focusReveal, anchor: .top)
            .allowsHitTesting(focusReveal > 0.96 && selectedCardId == nil)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func transitionSmooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        let x = min(max((value - start) / (end - start), 0), 1)
        return x * x * (3 - 2 * x)
    }
}
