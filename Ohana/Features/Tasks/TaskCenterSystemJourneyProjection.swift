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
    static let createFirstPetRewardCoconuts = 0

    static func makeItems(
        destinations: Set<TaskCenterSystemDestination>,
        pets: [Pet],
        humans: [Human],
        now: Date
    ) -> [TaskCenterItemSnapshot] {
        guard humans.contains(where: { !$0.hasPassedAway }) else { return [] }
        let hasActivePet = pets.contains(where: { !$0.hasPassedAway })
        var items: [TaskCenterItemSnapshot] = []

        if destinations.contains(.claimStarterGift) {
            items.append(
                TaskCenterItemSnapshot(
                    id: claimStarterGiftItemID,
                    eventID: nil,
                    reminderID: nil,
                    familyTaskID: nil,
                    source: .systemJourney,
                    systemDestination: .claimStarterGift,
                    systemJourneyPresentationState: .rewardReady,
                    title: L10n.current.tr(
                        zh: "领取新人礼包并解锁椰子树",
                        en: "Claim your welcome gift and unlock the coconut tree",
                        de: "Willkommensgeschenk abholen und Kokosbaum freischalten",
                        es: "Reclama tu regalo y desbloquea el cocotero",
                        pt: "Resgate seu presente e desbloqueie o coqueiro",
                        fr: "Récupérez votre cadeau et débloquez le cocotier",
                        ja: "ウェルカムギフトを受け取り、ココナッツツリーを解放",
                        ko: "환영 선물을 받고 코코넛 나무 잠금 해제",
                        it: "Riscatta il regalo e sblocca l’albero di cocco"
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
                    rewardCoconuts: StarterGiftPolicy.giftAmount
                )
            )
        }

        if !hasActivePet, destinations.contains(.createFirstPet) {
            items.append(TaskCenterItemSnapshot(
                id: createFirstPetItemID,
                eventID: nil,
                reminderID: nil,
                familyTaskID: nil,
                source: .suggestion,
                systemDestination: .createFirstPet,
                systemJourneyPresentationState: .actionRequired,
                title: L10n.current.tr(
                    zh: "也可以添加一位宠物伙伴",
                    en: "You can also add a pet companion",
                    de: "Du kannst auch einen tierischen Begleiter hinzufügen",
                    es: "También puedes añadir una mascota",
                    pt: "Você também pode adicionar um pet",
                    fr: "Vous pouvez aussi ajouter un animal",
                    ja: "ペットの仲間も追加できます",
                    ko: "반려동물 친구도 추가할 수 있어요",
                    it: "Puoi anche aggiungere un animale"
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
            ))
        }

        return items
    }
}
