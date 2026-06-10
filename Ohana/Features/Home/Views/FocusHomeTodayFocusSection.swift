//
//  FocusHomeTodayFocusSection.swift
//  Ohana
//
//  First-screen Today Focus strip extracted from the main home view.
//

import SwiftUI

struct FocusHomeTodayFocusSection: View {
    let snapshot: TodayFocusSnapshot
    let activePet: Pet?
    let showFirstSuccessCard: Bool
    let firstQuickCheckInCompleted: Bool
    let isExpanded: Bool
    let cardMargin: CGFloat
    let animation: Animation
    let onOpenQuest: (IslandQuest) -> Void
    let onCompleteQuest: (IslandQuest) -> Void
    let onTapNegativeSignal: (IslandNegativeSignal) -> Void
    let onTapOasis: () -> Void
    let onTapFamilyTask: (FamilyCollaborationTask) -> Void
    let onFirstSuccessFeed: (Pet) -> Void
    let onFirstSuccessPlay: (Pet) -> Void
    let onFirstSuccessMoment: (Pet) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(height: 216)
                .padding(.top, 12)

            TodayFocusCarousel(cardMargin: cardMargin, animation: animation) { cardWidth in
                TodayFocusQuestCardHost(
                    snapshot: snapshot,
                    isLive: !isExpanded,
                    onOpenQuest: onOpenQuest,
                    onCompleteQuest: onCompleteQuest,
                    onTapNegativeSignal: onTapNegativeSignal,
                    onTapOasis: onTapOasis,
                    onTapFamilyTask: onTapFamilyTask
                )
                .frame(width: cardWidth)

                if showFirstSuccessCard,
                   !firstQuickCheckInCompleted,
                   let activePet {
                    HomeFirstSuccessCard(
                        pet: activePet,
                        onFeed: { onFirstSuccessFeed(activePet) },
                        onPlay: { onFirstSuccessPlay(activePet) },
                        onMoment: { onFirstSuccessMoment(activePet) }
                    )
                    .frame(width: cardWidth)
                }
            }
            .opacity(isExpanded ? 0 : 1)
            .scaleEffect(isExpanded ? 0.965 : 1, anchor: .top)
            .allowsHitTesting(!isExpanded)
            .animation(animation, value: isExpanded)
        }
        .frame(height: 228, alignment: .top)
        .clipped()
        .allowsHitTesting(!isExpanded)
        .accessibilityHidden(isExpanded)
        .animation(animation, value: isExpanded)
    }
}
