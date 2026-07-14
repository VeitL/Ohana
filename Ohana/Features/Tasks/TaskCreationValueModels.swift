//
//  TaskCreationValueModels.swift
//  Ohana
//
//  Sendable values shared by task-creation entry points.
//

import Foundation

nonisolated enum TaskCreationSubjectKind: String, Codable, CaseIterable, Hashable, Sendable {
    case pet
    case plant
}

/// A stable, persistence-independent care discriminator for task creation.
///
/// The cases intentionally cover only care facts that the calendar completion
/// pipeline can materialize today. Values do not retain SwiftData models or
/// legacy model enums, so they can safely cross actor and navigation boundaries.
nonisolated enum TaskCareKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case petFeeding = "pet.care.feeding"
    case petWatering = "pet.care.watering"
    case petLitter = "pet.care.litter"
    case petPlay = "pet.care.play"
    case petPotty = "pet.potty.perfectPoop"
    case petHygieneTeeth = "pet.hygiene.teeth"
    case petHygieneNails = "pet.hygiene.nails"
    case petHygieneEars = "pet.hygiene.ears"
    case petHygieneBrushing = "pet.hygiene.brushing"
    case petHygieneBath = "pet.hygiene.bath"
    case plantWatering = "plant.care.watering"
    case plantFertilizing = "plant.care.fertilizing"
    case plantRepotting = "plant.care.repotting"
    case plantPruning = "plant.care.pruning"
    case plantMisting = "plant.care.misting"
    case plantRotating = "plant.care.rotating"
    case plantLeafCleaning = "plant.care.leafCleaning"
    case plantPestCheck = "plant.care.pestCheck"

    nonisolated var id: String { rawValue }

    nonisolated var subjectKind: TaskCreationSubjectKind {
        switch self {
        case .petFeeding,
             .petWatering,
             .petLitter,
             .petPlay,
             .petPotty,
             .petHygieneTeeth,
             .petHygieneNails,
             .petHygieneEars,
             .petHygieneBrushing,
             .petHygieneBath:
            .pet
        case .plantWatering,
             .plantFertilizing,
             .plantRepotting,
             .plantPruning,
             .plantMisting,
             .plantRotating,
             .plantLeafCleaning,
             .plantPestCheck:
            .plant
        }
    }

    nonisolated var eventType: EventType {
        switch self {
        case .petFeeding, .petWatering, .petPlay, .petPotty:
            .daily
        case .petLitter:
            .litterBox
        case .petHygieneTeeth,
             .petHygieneNails,
             .petHygieneEars,
             .petHygieneBrushing,
             .petHygieneBath:
            .grooming
        case .plantWatering:
            .watering
        case .plantFertilizing:
            .fertilizing
        case .plantRepotting:
            .plantRepotting
        case .plantPruning:
            .plantPruning
        case .plantMisting:
            .plantMisting
        case .plantRotating:
            .plantRotation
        case .plantLeafCleaning:
            .plantLeafCleaning
        case .plantPestCheck:
            .plantPestCheck
        }
    }

    /// SF Symbol used when a task-creation surface has no more specific icon.
    nonisolated var defaultIcon: String {
        switch self {
        case .petFeeding:
            CareType.feeding.systemIconName
        case .petWatering:
            CareType.watering.systemIconName
        case .petLitter:
            CareType.litter.systemIconName
        case .petPlay:
            CareType.play.systemIconName
        case .petPotty:
            PottyType.perfectPoop.systemIconName
        case .petHygieneTeeth:
            HygieneType.teeth.systemIconName
        case .petHygieneNails:
            HygieneType.nails.systemIconName
        case .petHygieneEars:
            HygieneType.ears.systemIconName
        case .petHygieneBrushing:
            HygieneType.brushing.systemIconName
        case .petHygieneBath:
            HygieneType.bath.systemIconName
        case .plantWatering,
             .plantFertilizing,
             .plantRepotting,
             .plantPruning,
             .plantMisting,
             .plantRotating,
             .plantLeafCleaning,
             .plantPestCheck:
            eventType.silhouetteSymbol
        }
    }

    nonisolated var defaultEmoji: String {
        switch self {
        case .petFeeding:
            CareType.feeding.emoji
        case .petWatering:
            CareType.watering.emoji
        case .petLitter:
            CareType.litter.emoji
        case .petPlay:
            CareType.play.emoji
        case .petPotty:
            PottyType.perfectPoop.emoji
        case .petHygieneTeeth:
            HygieneType.teeth.emoji
        case .petHygieneNails:
            HygieneType.nails.emoji
        case .petHygieneEars:
            HygieneType.ears.emoji
        case .petHygieneBrushing:
            HygieneType.brushing.emoji
        case .petHygieneBath:
            HygieneType.bath.emoji
        case .plantWatering:
            PlantCareType.watering.emoji
        case .plantFertilizing:
            PlantCareType.fertilizing.emoji
        case .plantRepotting:
            PlantCareType.repotting.emoji
        case .plantPruning:
            PlantCareType.pruning.emoji
        case .plantMisting:
            PlantCareType.misting.emoji
        case .plantRotating:
            PlantCareType.rotating.emoji
        case .plantLeafCleaning:
            PlantCareType.leafCleaning.emoji
        case .plantPestCheck:
            PlantCareType.pestCheck.emoji
        }
    }

    nonisolated func localizedTitle(l: L10n = .current) -> String {
        switch self {
        case .petFeeding:
            l.careTypeUILabel(.feeding)
        case .petWatering:
            l.careTypeUILabel(.watering)
        case .petLitter:
            l.careTypeUILabel(.litter)
        case .petPlay:
            l.careTypeUILabel(.play)
        case .petPotty:
            l.pottyTypeUILabel(.perfectPoop)
        case .petHygieneTeeth:
            l.hygieneTypeUILabel(.teeth)
        case .petHygieneNails:
            l.hygieneTypeUILabel(.nails)
        case .petHygieneEars:
            l.hygieneTypeUILabel(.ears)
        case .petHygieneBrushing:
            l.hygieneTypeUILabel(.brushing)
        case .petHygieneBath:
            l.hygieneTypeUILabel(.bath)
        case .plantWatering:
            PlantCareType.watering.displayName(l: l)
        case .plantFertilizing:
            PlantCareType.fertilizing.displayName(l: l)
        case .plantRepotting:
            PlantCareType.repotting.displayName(l: l)
        case .plantPruning:
            PlantCareType.pruning.displayName(l: l)
        case .plantMisting:
            PlantCareType.misting.displayName(l: l)
        case .plantRotating:
            PlantCareType.rotating.displayName(l: l)
        case .plantLeafCleaning:
            PlantCareType.leafCleaning.displayName(l: l)
        case .plantPestCheck:
            PlantCareType.pestCheck.displayName(l: l)
        }
    }
}

extension TaskCareKind {
    nonisolated init?(careType: CareType) {
        switch careType {
        case .feeding:
            self = .petFeeding
        case .watering:
            self = .petWatering
        case .litter:
            self = .petLitter
        case .play:
            self = .petPlay
        case .waterChange, .filterClean, .cageCleaning, .freeFlight, .misting, .substrateChange:
            return nil
        }
    }

    nonisolated var careType: CareType? {
        switch self {
        case .petFeeding:
            .feeding
        case .petWatering:
            .watering
        case .petLitter:
            .litter
        case .petPlay:
            .play
        default:
            nil
        }
    }

    nonisolated init?(pottyType: PottyType) {
        guard pottyType == .perfectPoop else { return nil }
        self = .petPotty
    }

    nonisolated var pottyType: PottyType? {
        self == .petPotty ? .perfectPoop : nil
    }

    nonisolated init(hygieneType: HygieneType) {
        switch hygieneType {
        case .teeth:
            self = .petHygieneTeeth
        case .nails:
            self = .petHygieneNails
        case .ears:
            self = .petHygieneEars
        case .brushing:
            self = .petHygieneBrushing
        case .bath:
            self = .petHygieneBath
        }
    }

    nonisolated var hygieneType: HygieneType? {
        switch self {
        case .petHygieneTeeth:
            .teeth
        case .petHygieneNails:
            .nails
        case .petHygieneEars:
            .ears
        case .petHygieneBrushing:
            .brushing
        case .petHygieneBath:
            .bath
        default:
            nil
        }
    }

    nonisolated init?(plantCareType: PlantCareType) {
        guard plantCareType.isSchedulablePlantCare else { return nil }
        switch plantCareType {
        case .watering:
            self = .plantWatering
        case .fertilizing:
            self = .plantFertilizing
        case .repotting:
            self = .plantRepotting
        case .pruning:
            self = .plantPruning
        case .misting:
            self = .plantMisting
        case .rotating:
            self = .plantRotating
        case .leafCleaning:
            self = .plantLeafCleaning
        case .pestCheck:
            self = .plantPestCheck
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            return nil
        }
    }

    nonisolated var plantCareType: PlantCareType? {
        switch self {
        case .plantWatering:
            .watering
        case .plantFertilizing:
            .fertilizing
        case .plantRepotting:
            .repotting
        case .plantPruning:
            .pruning
        case .plantMisting:
            .misting
        case .plantRotating:
            .rotating
        case .plantLeafCleaning:
            .leafCleaning
        case .plantPestCheck:
            .pestCheck
        default:
            nil
        }
    }
}

nonisolated struct TaskCreationPreset: Equatable, Hashable, Sendable {
    let subjectKind: TaskCreationSubjectKind
    let subjectID: UUID
    let careKind: TaskCareKind
    let requestID: UUID

    init(subjectID: UUID, careKind: TaskCareKind, requestID: UUID = UUID()) {
        self.subjectKind = careKind.subjectKind
        self.subjectID = subjectID
        self.careKind = careKind
        self.requestID = requestID
    }

    init?(
        subjectKind: TaskCreationSubjectKind,
        subjectID: UUID,
        careKind: TaskCareKind,
        requestID: UUID = UUID()
    ) {
        guard subjectKind == careKind.subjectKind else { return nil }
        self.subjectKind = subjectKind
        self.subjectID = subjectID
        self.careKind = careKind
        self.requestID = requestID
    }
}
