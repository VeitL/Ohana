//
//  TaskCenterStarterJourneyProjection.swift
//  Ohana
//
//  Maps the household starter journey value snapshot into Task Center rows.
//

import Foundation

nonisolated extension TaskCenterSystemJourneyProjection {
    static func makeVisibleItems(
        destinations: Set<TaskCenterSystemDestination>,
        starterJourney: HouseholdStarterJourneySnapshot?,
        pets: [Pet],
        humans: [Human],
        now: Date
    ) -> [TaskCenterItemSnapshot] {
        let starterItems = makeItems(
            destinations: destinations,
            pets: pets,
            humans: humans,
            now: now
        )
        guard starterItems.isEmpty else { return starterItems }
        return Array(makeItems(
            starterJourney: starterJourney,
            pets: pets,
            humans: humans,
            now: now
        ).prefix(HouseholdStarterJourneyPolicy.maximumVisibleTaskCount))
    }

    static func makeItems(
        starterJourney: HouseholdStarterJourneySnapshot?,
        pets: [Pet],
        humans: [Human],
        now: Date
    ) -> [TaskCenterItemSnapshot] {
        guard let starterJourney, starterJourney.isEnabled else { return [] }
        return starterJourney.visibleTaskStates.compactMap { state in
            guard let presentationState = presentationState(for: state.status) else { return nil }
            return TaskCenterItemSnapshot(
                id: state.task.id,
                eventID: nil,
                reminderID: nil,
                familyTaskID: nil,
                source: .systemJourney,
                systemDestination: destination(for: state.task),
                systemJourneyPresentationState: presentationState,
                title: title(for: state.task),
                subject: subject(for: state, pets: pets, humans: humans),
                eventType: nil,
                symbol: symbol(for: state.task),
                occurrenceDate: now,
                scheduledAt: now,
                dueAt: nil,
                isAllDay: true,
                isRecurring: false,
                urgency: .standard,
                workflowStatus: .active,
                availableActions: [],
                participantHumanIDs: [],
                rewardCoconuts: state.rewardCoconuts
            )
        }
    }

    private static func presentationState(
        for status: HouseholdStarterJourneyTaskState.Status
    ) -> TaskCenterSystemJourneyPresentationState? {
        switch status {
        case .actionRequired: .actionRequired
        case .claimable: .rewardReady
        case .locked, .claimed: nil
        }
    }

    private static func destination(
        for task: HouseholdStarterJourneyTask
    ) -> TaskCenterSystemDestination {
        switch task {
        case .humanProfile: .completeHumanProfile
        case .petProfile: .completeFirstPetProfile
        case .identityProtection: .confirmPetIdentityProtection
        case .healthProtection: .confirmPetPreventiveCare
        case .carePlan: .configureFirstCarePlan
        case .firstCare: .recordFirstCare
        }
    }

    private static func title(for task: HouseholdStarterJourneyTask) -> String {
        switch task {
        case .humanProfile:
            L10n.current.tr(
                zh: "完善我的成员卡",
                en: "Complete my member card",
                de: "Meine Mitgliedskarte ergänzen"
            )
        case .petProfile:
            L10n.current.tr(
                zh: "完善首只宠物档案",
                en: "Complete the first pet profile",
                de: "Profil des ersten Haustiers ergänzen"
            )
        case .identityProtection:
            L10n.current.tr(
                zh: "确认证件与保障状态",
                en: "Review identity and protection",
                de: "Dokumente und Schutz prüfen"
            )
        case .healthProtection:
            L10n.current.tr(
                zh: "确认疫苗与保健状态",
                en: "Review vaccines and preventive care",
                de: "Impfungen und Vorsorge prüfen"
            )
        case .carePlan:
            L10n.current.tr(
                zh: "建立首个照护计划",
                en: "Set up the first care plan",
                de: "Ersten Pflegeplan einrichten"
            )
        case .firstCare:
            L10n.current.tr(
                zh: "完成首次真实照护",
                en: "Complete the first real care action",
                de: "Erste echte Pflege abschließen"
            )
        }
    }

    private static func symbol(for task: HouseholdStarterJourneyTask) -> String {
        switch task {
        case .humanProfile: "person.crop.circle.badge.checkmark"
        case .petProfile: "pawprint.circle.fill"
        case .identityProtection: "checkmark.shield.fill"
        case .healthProtection: "syringe.fill"
        case .carePlan: "calendar.badge.checkmark"
        case .firstCare: "heart.fill"
        }
    }

    private static func subject(
        for state: HouseholdStarterJourneyTaskState,
        pets: [Pet],
        humans: [Human]
    ) -> TaskSubjectSnapshot {
        guard let targetID = state.targetID else { return .household }
        if state.task == .humanProfile,
           let human = humans.first(where: { $0.id == targetID }) {
            return TaskSubjectSnapshot(
                kind: .human,
                id: human.id,
                name: human.name,
                themeColorHex: human.themeColorHex
            )
        }
        if let pet = pets.first(where: { $0.id == targetID }) {
            return TaskSubjectSnapshot(
                kind: .pet,
                id: pet.id,
                name: pet.name,
                themeColorHex: pet.themeColorHex
            )
        }
        return .household
    }
}
