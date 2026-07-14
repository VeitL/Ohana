import Foundation
import Testing
@testable import Ohana

struct TaskCreationValueModelsTests {
    @Test func stableRawValuesAndSubjectKindsCoverSupportedCareFacts() {
        let expectedRawValues: [TaskCareKind: String] = [
            .petFeeding: "pet.care.feeding",
            .petWatering: "pet.care.watering",
            .petLitter: "pet.care.litter",
            .petPlay: "pet.care.play",
            .petPotty: "pet.potty.perfectPoop",
            .petHygieneTeeth: "pet.hygiene.teeth",
            .petHygieneNails: "pet.hygiene.nails",
            .petHygieneEars: "pet.hygiene.ears",
            .petHygieneBrushing: "pet.hygiene.brushing",
            .petHygieneBath: "pet.hygiene.bath",
            .plantWatering: "plant.care.watering",
            .plantFertilizing: "plant.care.fertilizing",
            .plantRepotting: "plant.care.repotting",
            .plantPruning: "plant.care.pruning",
            .plantMisting: "plant.care.misting",
            .plantRotating: "plant.care.rotating",
            .plantLeafCleaning: "plant.care.leafCleaning",
            .plantPestCheck: "plant.care.pestCheck"
        ]

        #expect(TaskCareKind.allCases.count == expectedRawValues.count)
        #expect(Set(TaskCareKind.allCases.map(\.rawValue)).count == TaskCareKind.allCases.count)
        for kind in TaskCareKind.allCases {
            #expect(kind.rawValue == expectedRawValues[kind])
            #expect(TaskCareKind(rawValue: kind.rawValue) == kind)
            #expect(kind.subjectKind == (kind.rawValue.hasPrefix("pet.") ? .pet : .plant))
        }
    }

    @Test func eventTypeMappingsRemainExplicit() {
        let expected: [TaskCareKind: EventType] = [
            .petFeeding: .daily,
            .petWatering: .daily,
            .petLitter: .litterBox,
            .petPlay: .daily,
            .petPotty: .daily,
            .petHygieneTeeth: .grooming,
            .petHygieneNails: .grooming,
            .petHygieneEars: .grooming,
            .petHygieneBrushing: .grooming,
            .petHygieneBath: .grooming,
            .plantWatering: .watering,
            .plantFertilizing: .fertilizing,
            .plantRepotting: .plantRepotting,
            .plantPruning: .plantPruning,
            .plantMisting: .plantMisting,
            .plantRotating: .plantRotation,
            .plantLeafCleaning: .plantLeafCleaning,
            .plantPestCheck: .plantPestCheck
        ]

        for kind in TaskCareKind.allCases {
            #expect(kind.eventType == expected[kind])
        }
    }

    @Test func supportedPetCareTypesRoundTripAndUnsupportedTypesStayOut() {
        let supported: [(CareType, TaskCareKind)] = [
            (.feeding, .petFeeding),
            (.watering, .petWatering),
            (.litter, .petLitter),
            (.play, .petPlay)
        ]
        for (careType, kind) in supported {
            #expect(TaskCareKind(careType: careType) == kind)
            #expect(kind.careType == careType)
        }

        let unsupported: [CareType] = [
            .waterChange,
            .filterClean,
            .cageCleaning,
            .freeFlight,
            .misting,
            .substrateChange
        ]
        for careType in unsupported {
            #expect(TaskCareKind(careType: careType) == nil)
        }
    }

    @Test func pottyMappingIncludesOnlyCalendarMaterializableDefault() {
        #expect(TaskCareKind(pottyType: .perfectPoop) == .petPotty)
        #expect(TaskCareKind.petPotty.pottyType == .perfectPoop)
        #expect(TaskCareKind(pottyType: .softPoop) == nil)
        #expect(TaskCareKind(pottyType: .liquidPoop) == nil)
        #expect(TaskCareKind(pottyType: .pee) == nil)
    }

    @Test func explicitHygieneTypesRoundTrip() {
        let expected: [(HygieneType, TaskCareKind)] = [
            (.teeth, .petHygieneTeeth),
            (.nails, .petHygieneNails),
            (.ears, .petHygieneEars),
            (.brushing, .petHygieneBrushing),
            (.bath, .petHygieneBath)
        ]

        for (hygieneType, expectedKind) in expected {
            let kind = TaskCareKind(hygieneType: hygieneType)
            #expect(kind == expectedKind)
            #expect(kind.hygieneType == hygieneType)
        }
    }

    @Test func schedulablePlantCareTypesRoundTripAndObservationTypesStayOut() {
        let expected: [(PlantCareType, TaskCareKind)] = [
            (.watering, .plantWatering),
            (.fertilizing, .plantFertilizing),
            (.repotting, .plantRepotting),
            (.pruning, .plantPruning),
            (.misting, .plantMisting),
            (.rotating, .plantRotating),
            (.leafCleaning, .plantLeafCleaning),
            (.pestCheck, .plantPestCheck)
        ]

        #expect(expected.map(\.0.rawValue).sorted() == PlantCareCategory.schedulableCareTypes.map(\.rawValue).sorted())
        for (plantCareType, kind) in expected {
            #expect(TaskCareKind(plantCareType: plantCareType) == kind)
            #expect(kind.plantCareType == plantCareType)
        }

        let observationTypes: [PlantCareType] = [.photo, .newLeaf, .yellowLeaf, .pestFound, .customNote]
        for plantCareType in observationTypes {
            #expect(TaskCareKind(plantCareType: plantCareType) == nil)
        }
    }

    @Test func titlesAndIconsUseExistingLocalizedDomainMappings() {
        let en = L10n("en")
        let de = L10n("de")

        #expect(TaskCareKind.petFeeding.localizedTitle(l: en) == "Feeding")
        #expect(TaskCareKind.petHygieneTeeth.localizedTitle(l: de) == "Zähne")
        #expect(TaskCareKind.plantLeafCleaning.localizedTitle(l: en) == "Clean leaves")
        #expect(TaskCareKind.petFeeding.defaultIcon == CareType.feeding.systemIconName)
        #expect(TaskCareKind.petPotty.defaultIcon == PottyType.perfectPoop.systemIconName)
        #expect(TaskCareKind.plantPestCheck.defaultIcon == EventType.plantPestCheck.silhouetteSymbol)
        #expect(TaskCareKind.allCases.allSatisfy { !$0.defaultIcon.isEmpty && !$0.defaultEmoji.isEmpty })
    }

    @Test func presetDerivesAndValidatesSubjectKindWithoutLiveModels() {
        let subjectID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let requestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let derived = TaskCreationPreset(
            subjectID: subjectID,
            careKind: .plantWatering,
            requestID: requestID
        )

        #expect(derived.subjectKind == .plant)
        #expect(derived.subjectID == subjectID)
        #expect(derived.careKind == .plantWatering)
        #expect(derived.requestID == requestID)
        #expect(TaskCreationPreset(
            subjectKind: .pet,
            subjectID: subjectID,
            careKind: .petFeeding,
            requestID: requestID
        ) != nil)
        #expect(TaskCreationPreset(
            subjectKind: .pet,
            subjectID: subjectID,
            careKind: .plantWatering,
            requestID: requestID
        ) == nil)
    }

    @Test func taskCreationValuesAreSendable() {
        requireSendable(TaskCareKind.self)
        requireSendable(TaskCreationSubjectKind.self)
        requireSendable(TaskCreationPreset.self)
    }

    @Test func careCreationRouteCarriesExactSubjectAndRequestIdentity() {
        let subjectID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let requestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let preset = TaskCreationPreset(
            subjectID: subjectID,
            careKind: .petLitter,
            requestID: requestID
        )
        let context = TaskCenterRouteContext.createCare(preset)

        #expect(context.scope == .pet(subjectID))
        #expect(context.creationPreset == preset)
        #expect(context.preselectedEntityType == EntityKind.pet.rawValue)
        #expect(context.preselectedEntityId == subjectID.uuidString)
        #expect(AppSheetRoute.taskCenter(context).id.contains(requestID.uuidString))
    }

    private func requireSendable(_: (some Sendable).Type) {}
}
