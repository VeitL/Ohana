//
//  TaskCenterSystemJourneyProjection.swift
//  Ohana
//
//  Projects onboarding and starter-gift journeys into Task Center items.
//

import Foundation

nonisolated enum TaskCenterSystemJourneyProjection {
    static let createFirstPetItemID = "system-journey-create-first-pet"
    static let claimStarterGiftItemID = "system-journey-claim-starter-gift"
    static let createFirstPetRewardCoconuts = 50

    static func makeItems(
        destinations: Set<TaskCenterSystemDestination>,
        pets: [Pet],
        humans: [Human],
        now: Date
    ) -> [TaskCenterItemSnapshot] {
        guard humans.contains(where: { !$0.hasPassedAway }) else { return [] }
        let hasActivePet = pets.contains(where: { !$0.hasPassedAway })

        if hasActivePet, destinations.contains(.claimStarterGift) {
            return [
                TaskCenterItemSnapshot(
                    id: claimStarterGiftItemID,
                    eventID: nil,
                    reminderID: nil,
                    familyTaskID: nil,
                    source: .systemJourney,
                    systemDestination: .claimStarterGift,
                    systemJourneyPresentationState: .rewardReady,
                    title: L10n.current.tr(
                        zh: "领取首宠奖励",
                        en: "Claim your first-pet gift",
                        de: "Belohnung für das erste Tier abholen"
                    ),
                    subject: .household,
                    eventType: nil,
                    symbol: "gift.fill",
                    occurrenceDate: now,
                    scheduledAt: now,
                    dueAt: nil,
                    isAllDay: true,
                    isRecurring: false,
                    urgency: .standard,
                    workflowStatus: .active,
                    availableActions: [],
                    participantHumanIDs: [],
                    rewardCoconuts: createFirstPetRewardCoconuts
                )
            ]
        }

        guard !hasActivePet, destinations.contains(.createFirstPet) else { return [] }
        return [
            TaskCenterItemSnapshot(
                id: createFirstPetItemID,
                eventID: nil,
                reminderID: nil,
                familyTaskID: nil,
                source: .systemJourney,
                systemDestination: .createFirstPet,
                systemJourneyPresentationState: .actionRequired,
                title: L10n.current.tr(
                    zh: "建立第一只宠物",
                    en: "Create your first pet",
                    de: "Erstes Haustier erstellen"
                ),
                subject: .household,
                eventType: nil,
                symbol: "pawprint.fill",
                occurrenceDate: now,
                scheduledAt: now,
                dueAt: nil,
                isAllDay: true,
                isRecurring: false,
                urgency: .standard,
                workflowStatus: .active,
                availableActions: [],
                participantHumanIDs: [],
                rewardCoconuts: createFirstPetRewardCoconuts
            )
        ]
    }
}
