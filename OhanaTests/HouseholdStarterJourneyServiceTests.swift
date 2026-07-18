import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HouseholdStarterJourneyServiceTests {
    @Test func catalogAndSnapshotStaySmallAndAnchorCurrentHumanAndFirstPet() throws {
        #expect(HouseholdStarterJourneyPolicy.totalRewardCoconuts == 400)
        #expect(HouseholdStarterJourneyTask.humanProfile.rewardCoconuts == 100)
        #expect(HouseholdStarterJourneyTask.petProfile.rewardCoconuts == 100)
        #expect(HouseholdStarterJourneyTask.identityProtection.rewardCoconuts == 60)
        #expect(HouseholdStarterJourneyTask.healthProtection.rewardCoconuts == 80)
        #expect(HouseholdStarterJourneyTask.carePlan.rewardCoconuts == 40)
        #expect(HouseholdStarterJourneyTask.firstCare.rewardCoconuts == 20)
        #expect(HouseholdStarterJourneyCheckpoint.petIdentityDocuments.allowedResolutions.contains(.preferNotToSay))
        #expect(HouseholdStarterJourneyCheckpoint.petHealthProtection.allowedResolutions.contains(.preferNotToSay))

        let firstHuman = Human(name: "First")
        firstHuman.createdAt = Date(timeIntervalSince1970: 1)
        firstHuman.birthday = Date(timeIntervalSince1970: 1)
        firstHuman.avatarImageSignature = "custom"
        let activeHuman = Human(name: "Active")
        activeHuman.createdAt = Date(timeIntervalSince1970: 2)
        let firstPet = Pet(name: "First pet", species: "cat")
        firstPet.createdAt = Date(timeIntervalSince1970: 1)
        let laterPet = Pet(name: "Later pet", species: "dog")
        laterPet.createdAt = Date(timeIntervalSince1970: 2)
        laterPet.birthday = Date()
        laterPet.gender = "female"
        laterPet.avatarImageSignature = "custom"

        let snapshot = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: activeHuman.id.uuidString,
            humans: [firstHuman, activeHuman],
            pets: [laterPet, firstPet],
            qualificationFacts: HouseholdStarterJourneyQualificationFacts(
                targetPetID: laterPet.id,
                hasProtectionDocument: true,
                hasInsurance: true,
                hasPreventiveHealthRecord: true,
                hasExplicitCarePlan: true,
                hasDefaultRecommendedCarePlan: true
            ),
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )

        #expect(snapshot.activeHumanID == activeHuman.id)
        #expect(snapshot.state(for: .humanProfile)?.targetID == activeHuman.id)
        #expect(snapshot.state(for: .petProfile)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .identityProtection)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .healthProtection)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .carePlan)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .firstCare)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .petProfile)?.completedCheckpointCount == 0)
        #expect(snapshot.state(for: .firstCare)?.status == .actionRequired)
        #expect(snapshot.visibleTaskStates.count == 3)
    }

    @Test func resolutionsAreWhitelistedIdempotentAndDoNotPersistProfileValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Sensitive name")
        context.insert(human)
        try context.save()
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)

        let first = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            resolution: .reviewed,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
        let duplicate = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            resolution: .reviewed,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
        let invalid = HouseholdStarterJourneyService.recordResolution(
            task: .carePlan,
            checkpoint: .acceptedRecommendedCarePlan,
            resolution: .preferNotToSay,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )

        #expect(first.didSucceed)
        #expect(duplicate == .unchanged(task: .humanProfile, checkpoint: .humanAppearance, resolution: .reviewed))
        #expect(invalid == .invalidCheckpoint)
        let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
        }
        #expect(markers.count == 1)
        #expect(!markers[0].metadataJSON.contains(human.name))
    }

    @Test func alternateResolutionPathsReloadLatestChoiceWithoutLeakingOrCreatingDuplicateMarkers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Private human")
        let pet = Pet(name: "Private pet", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        let checkpoint = HouseholdStarterJourneyCheckpoint.petIdentityDocuments
        let resolutions: [HouseholdStarterJourneyResolution] = [
            .reviewed,
            .unknown,
            .notApplicable,
            .preferNotToSay
        ]

        for resolution in resolutions {
            let result = HouseholdStarterJourneyService.recordResolution(
                task: .identityProtection,
                checkpoint: checkpoint,
                resolution: resolution,
                subjectID: pet.id,
                context: context,
                activeHumanSelection: selection
            )
            #expect(result == .recorded(
                task: .identityProtection,
                checkpoint: checkpoint,
                resolution: resolution
            ))
        }

        let recordKey = HouseholdStarterJourneyService.checkpointRecordKey(
            task: .identityProtection,
            checkpoint: checkpoint,
            subjectID: pet.id
        )
        var markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
                && $0.legacyModelId == recordKey
        }
        #expect(markers.count == resolutions.count)
        for marker in markers {
            let resolutionIndex = resolutions.firstIndex {
                marker.metadataJSON.contains("\"resolutionRaw\":\"\($0.rawValue)\"")
            }
            #expect(resolutionIndex != nil)
            if let resolutionIndex {
                let timestamp = Date(timeIntervalSince1970: Double(resolutionIndex + 1))
                marker.occurredAt = timestamp
                marker.createdAt = timestamp
            }
            #expect(marker.note.isEmpty)
            #expect(marker.privacyFieldRaw == nil)
            #expect(!marker.metadataJSON.contains(human.name))
            #expect(!marker.metadataJSON.contains(pet.name))
        }
        try context.save()

        let duplicate = HouseholdStarterJourneyService.recordResolution(
            task: .identityProtection,
            checkpoint: checkpoint,
            resolution: .preferNotToSay,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: selection
        )
        #expect(duplicate == .unchanged(
            task: .identityProtection,
            checkpoint: checkpoint,
            resolution: .preferNotToSay
        ))

        markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
                && $0.legacyModelId == recordKey
        }
        let snapshot = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: markers,
            coconutLedgerEntries: []
        )
        let state = try #require(snapshot.state(for: .identityProtection))
        #expect(markers.count == resolutions.count)
        #expect(state.completedCheckpointCount == 1)
        #expect(state.completedCheckpoints == [checkpoint])
        #expect(state.checkpointResolutions[checkpoint] == .preferNotToSay)
        #expect(state.status == .actionRequired)
    }

    @Test func laterRealIdentityFactSupersedesEarlierResolutionWithoutDoubleCounting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Resolution owner")
        let pet = Pet(name: "Resolution pet", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let checkpoint = HouseholdStarterJourneyCheckpoint.petIdentityDocuments
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        let result = HouseholdStarterJourneyService.recordResolution(
            task: .identityProtection,
            checkpoint: checkpoint,
            resolution: .notApplicable,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: selection
        )
        #expect(result == .recorded(
            task: .identityProtection,
            checkpoint: checkpoint,
            resolution: .notApplicable
        ))

        let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
        }
        let resolutionBacked = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: markers,
            coconutLedgerEntries: []
        )
        let resolutionState = try #require(resolutionBacked.state(for: .identityProtection))
        #expect(resolutionState.completedCheckpointCount == 1)
        #expect(resolutionState.completedCheckpoints == [checkpoint])
        #expect(resolutionState.checkpointResolutions[checkpoint] == .notApplicable)

        pet.microchipID = "real-chip-after-skip"
        try context.save()
        let factBacked = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: markers,
            coconutLedgerEntries: []
        )
        let factState = try #require(factBacked.state(for: .identityProtection))
        #expect(factState.completedCheckpointCount == 1)
        #expect(factState.completedCheckpoints == [checkpoint])
        #expect(factState.checkpointResolutions[checkpoint] == nil)
        #expect(factState.status == .actionRequired)
    }

    @Test func laterRealPreventiveHealthFactSupersedesEarlierResolutionWithoutDoubleCounting() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Health owner")
        let pet = Pet(name: "Health pet", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let checkpoint = HouseholdStarterJourneyCheckpoint.petHealthProtection
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        #expect(HouseholdStarterJourneyService.recordResolution(
            task: .healthProtection,
            checkpoint: checkpoint,
            resolution: .notApplicable,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: selection
        ) == .recorded(
            task: .healthProtection,
            checkpoint: checkpoint,
            resolution: .notApplicable
        ))

        let recordKey = HouseholdStarterJourneyService.checkpointRecordKey(
            task: .healthProtection,
            checkpoint: checkpoint,
            subjectID: pet.id
        )
        var markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
                && $0.legacyModelId == recordKey
        }
        #expect(markers.count == 1)

        let resolutionReference = try await TaskCenterRouteDataActor(
            modelContainer: container
        ).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let resolutionState = try #require(
            resolutionReference.snapshot.starterJourney?.state(for: .healthProtection)
        )
        #expect(resolutionState.completedCheckpointCount == 1)
        #expect(resolutionState.completedCheckpoints == [checkpoint])
        #expect(resolutionState.checkpointResolutions == [checkpoint: .notApplicable])
        #expect(resolutionState.status == .claimable)

        context.insert(PetHealthLog(
            type: .vaccine,
            note: "Rabies",
            pet: pet,
            executorId: human.id.uuidString
        ))
        try context.save()

        let factReference = try await TaskCenterRouteDataActor(
            modelContainer: container
        ).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let factState = try #require(
            factReference.snapshot.starterJourney?.state(for: .healthProtection)
        )
        #expect(factState.completedCheckpointCount == 1)
        #expect(factState.completedCheckpoints == [checkpoint])
        #expect(factState.checkpointResolutions.isEmpty)
        #expect(factState.status == .claimable)

        markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
                && $0.legacyModelId == recordKey
        }
        #expect(markers.count == 1)
    }

    @Test func duplicateLatestResolutionAfterMoreThanEightRevisionsIsUnchanged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        let checkpoint = HouseholdStarterJourneyCheckpoint.petIdentityDocuments
        let resolutions: [HouseholdStarterJourneyResolution] = [
            .reviewed,
            .unknown,
            .notApplicable,
            .preferNotToSay,
            .reviewed,
            .unknown,
            .notApplicable,
            .preferNotToSay,
            .unknown
        ]
        let recordKey = HouseholdStarterJourneyService.checkpointRecordKey(
            task: .identityProtection,
            checkpoint: checkpoint,
            subjectID: pet.id
        )
        var knownMarkerIDs: Set<UUID> = []

        for (index, resolution) in resolutions.enumerated() {
            let result = HouseholdStarterJourneyService.recordResolution(
                task: .identityProtection,
                checkpoint: checkpoint,
                resolution: resolution,
                subjectID: pet.id,
                context: context,
                activeHumanSelection: selection
            )
            #expect(result == .recorded(
                task: .identityProtection,
                checkpoint: checkpoint,
                resolution: resolution
            ))

            let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
                $0.actionType == HouseholdStarterJourneyService.checkpointActionType
                    && $0.legacyModelId == recordKey
            }
            let newMarkers = markers.filter { !knownMarkerIDs.contains($0.id) }
            #expect(newMarkers.count == 1)
            if let marker = newMarkers.first {
                let timestamp = Date(timeIntervalSince1970: Double(index + 1))
                marker.occurredAt = timestamp
                marker.createdAt = timestamp
                knownMarkerIDs.insert(marker.id)
            }
            try context.save()
        }

        let duplicate = HouseholdStarterJourneyService.recordResolution(
            task: .identityProtection,
            checkpoint: checkpoint,
            resolution: .unknown,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: selection
        )
        #expect(duplicate == .unchanged(
            task: .identityProtection,
            checkpoint: checkpoint,
            resolution: .unknown
        ))
        let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
                && $0.legacyModelId == recordKey
        }
        #expect(markers.count == resolutions.count)
    }

    @Test func everyThreeOfFourPersistedPetProfilePathsBecomeClaimable() throws {
        let checkpoints = HouseholdStarterJourneyTask.petProfile.checkpoints

        for omitted in checkpoints {
            let container = try makeContainer()
            let context = container.mainContext
            let human = Human(name: "Ava")
            let pet = Pet(name: "Momo", species: "cat")
            context.insert(human)
            context.insert(pet)
            try context.save()
            let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)

            for checkpoint in checkpoints where checkpoint != omitted {
                let result = HouseholdStarterJourneyService.recordResolution(
                    task: .petProfile,
                    checkpoint: checkpoint,
                    resolution: .reviewed,
                    subjectID: pet.id,
                    context: context,
                    activeHumanSelection: selection
                )
                #expect(result.didSucceed)
            }

            let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
                $0.actionType == HouseholdStarterJourneyService.checkpointActionType
            }
            let snapshot = HouseholdStarterJourneyService.buildSnapshot(
                enabled: true,
                activeHumanID: human.id.uuidString,
                humans: [human],
                pets: [pet],
                qualificationFacts: .empty,
                careLedgerEvents: markers,
                coconutLedgerEntries: []
            )
            let state = try #require(snapshot.state(for: .petProfile))
            #expect(state.completedCheckpointCount == 3)
            #expect(state.status == .claimable)
            #expect(!state.completedCheckpoints.contains(omitted))
        }
    }

    @Test func sparsePetProfileAnswersCompleteWithoutFabricatingProfileFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let pet = Pet(name: "Sparse", species: "dog")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        let answers: [(HouseholdStarterJourneyCheckpoint, HouseholdStarterJourneyResolution)] = [
            (.petBodyProfile, .notApplicable),
            (.petPersonalityAppearance, .preferNotToSay),
            (.petDailyCare, .reviewed)
        ]
        for (checkpoint, resolution) in answers {
            let result = HouseholdStarterJourneyService.recordResolution(
                task: .petProfile,
                checkpoint: checkpoint,
                resolution: resolution,
                subjectID: pet.id,
                context: context,
                activeHumanSelection: selection
            )
            #expect(result == .recorded(
                task: .petProfile,
                checkpoint: checkpoint,
                resolution: resolution
            ))
        }

        let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
        }
        let snapshot = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: markers,
            coconutLedgerEntries: []
        )
        let state = try #require(snapshot.state(for: .petProfile))

        #expect(markers.count == 3)
        #expect(state.completedCheckpointCount == 3)
        #expect(state.status == .claimable)
        #expect(state.completedCheckpoints == [
            .petBodyProfile,
            .petPersonalityAppearance,
            .petDailyCare
        ])
        #expect(state.checkpointResolutions == [
            .petBodyProfile: .notApplicable,
            .petPersonalityAppearance: .preferNotToSay,
            .petDailyCare: .reviewed
        ])
        #expect(!state.completedCheckpoints.contains(.petLifeStage))

        let factsOnlySnapshot = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )
        let factsOnlyState = try #require(factsOnlySnapshot.state(for: .petProfile))
        #expect(factsOnlyState.completedCheckpointCount == 0)
        #expect(factsOnlyState.completedCheckpoints.isEmpty)
        #expect(pet.gender == "unknown")
        #expect(pet.personalityTagsRaw.isEmpty)
        #expect(pet.avatarAttachmentState == .absent)
        #expect(pet.cardPopoutAttachmentState == .absent)
    }

    @Test func carePlanResolutionNeedsARealRecommendedPlanAndFirstCareNeedsARealCareFact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let unavailable = HouseholdStarterJourneyService.recordResolution(
            task: .carePlan,
            checkpoint: .acceptedRecommendedCarePlan,
            resolution: .reviewed,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        )
        #expect(unavailable == .invalidCheckpoint)

        let base = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: HouseholdStarterJourneyQualificationFacts(
                targetPetID: pet.id,
                hasProtectionDocument: false,
                hasInsurance: false,
                hasPreventiveHealthRecord: false,
                hasExplicitCarePlan: false,
                hasDefaultRecommendedCarePlan: true
            ),
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )
        #expect(base.state(for: .carePlan)?.availableResolutionCheckpoints == [.acceptedRecommendedCarePlan])
        #expect(base.state(for: .firstCare)?.status == .actionRequired)

        let unrelated = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: "weight"
        )
        let care = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: "feeding"
        )
        let withoutCare = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: [unrelated],
            coconutLedgerEntries: []
        )
        let withCare = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: [unrelated, care],
            coconutLedgerEntries: []
        )
        #expect(withoutCare.state(for: .firstCare)?.status == .actionRequired)
        #expect(withCare.state(for: .firstCare)?.status == .claimable)
    }

    @Test func claimIsGatedAtomicAndHouseholdIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        context.insert(human)
        try context.save()
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        qualifyHumanProfile(human: human, context: context, selection: selection)

        let blockedDefaults = try makeDefaults()
        blockedDefaults.set(true, forKey: "ohana_has_onboarded")
        blockedDefaults.set(true, forKey: StarterGiftStorageKey.pending)
        let blocked = HouseholdStarterJourneyService.claim(
            task: .humanProfile,
            context: context,
            activeHumanSelection: selection,
            defaults: blockedDefaults
        )
        #expect(blocked == .notEligible(task: .humanProfile))
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)

        let enabledDefaults = try makeDefaults()
        enabledDefaults.set(true, forKey: "ohana_has_onboarded")
        let observingWallet = ObservingWallet()
        let claimed = HouseholdStarterJourneyService.claim(
            task: .humanProfile,
            context: context,
            wallet: observingWallet,
            activeHumanSelection: selection,
            defaults: enabledDefaults
        )
        let retry = HouseholdStarterJourneyService.claim(
            task: .humanProfile,
            context: context,
            wallet: observingWallet,
            activeHumanSelection: selection,
            defaults: enabledDefaults
        )

        #expect(claimed == .claimed(task: .humanProfile, humanID: human.id, amount: 100))
        #expect(retry == .alreadyClaimed(task: .humanProfile, amount: 100))
        #expect(observingWallet.calls.count == 1)
        #expect(observingWallet.calls.first?.0 == false)
        #expect(observingWallet.calls.first?.1 == false)
        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].transactionKey == HouseholdStarterJourneyService.rewardTransactionKey(for: .humanProfile))
        #expect(!entries[0].transactionKey.contains(human.id.uuidString))
        let rewardEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.rewardActionType
        }
        #expect(rewardEvents.count == 1)
    }

    @Test func routeReloadKeepsActiveHumanCheckpointsBeyondGlobalMarkerLimit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active early Human")
        activeHuman.createdAt = Date(timeIntervalSince1970: 1)
        let pet = Pet(name: "Starter Pet", species: "dog")
        pet.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(activeHuman)
        context.insert(pet)

        var noiseHumans: [Human] = []
        for index in 0 ..< 33 {
            let human = Human(name: "Later Human \(index)")
            human.createdAt = Date(timeIntervalSince1970: Double(index + 2))
            context.insert(human)
            noiseHumans.append(human)
        }
        try context.save()

        let selection = FixedActiveHumanSelection(currentHumanId: activeHuman.id.uuidString)
        for (checkpoint, resolution) in [
            (HouseholdStarterJourneyCheckpoint.humanAppearance, HouseholdStarterJourneyResolution.reviewed),
            (.humanOptionalDetails, .preferNotToSay)
        ] {
            #expect(HouseholdStarterJourneyService.recordResolution(
                task: .humanProfile,
                checkpoint: checkpoint,
                resolution: resolution,
                subjectID: activeHuman.id,
                context: context,
                activeHumanSelection: selection
            ).didSucceed)
        }
        for human in noiseHumans {
            #expect(HouseholdStarterJourneyService.recordResolution(
                task: .humanProfile,
                checkpoint: .humanAppearance,
                resolution: .reviewed,
                subjectID: human.id,
                context: context,
                activeHumanSelection: selection
            ).didSucceed)
            #expect(HouseholdStarterJourneyService.recordResolution(
                task: .humanProfile,
                checkpoint: .humanOptionalDetails,
                resolution: .preferNotToSay,
                subjectID: human.id,
                context: context,
                activeHumanSelection: selection
            ).didSucceed)
        }

        let activeAppearanceKey = HouseholdStarterJourneyService.checkpointRecordKey(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            subjectID: activeHuman.id
        )
        let activeOptionalKey = HouseholdStarterJourneyService.checkpointRecordKey(
            task: .humanProfile,
            checkpoint: .humanOptionalDetails,
            subjectID: activeHuman.id
        )
        let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
        }
        #expect(markers.count == 68)
        var laterIndex = 0
        for marker in markers {
            let timestamp: Date
            switch marker.legacyModelId {
            case activeAppearanceKey:
                timestamp = Date(timeIntervalSince1970: 1)
            case activeOptionalKey:
                timestamp = Date(timeIntervalSince1970: 2)
            default:
                timestamp = Date(timeIntervalSince1970: Double(100 + laterIndex))
                laterIndex += 1
            }
            marker.occurredAt = timestamp
            marker.createdAt = timestamp
        }
        try context.save()
        #expect(markers.filter {
            $0.legacyModelId == activeAppearanceKey || $0.legacyModelId == activeOptionalKey
        }.count == 2)

        let reference = try await TaskCenterRouteDataActor(modelContainer: container).load(
            loadPlants: false,
            activeHumanID: activeHuman.id.uuidString,
            starterJourneyEnabled: true
        )
        let journey = try #require(reference.snapshot.starterJourney)
        let state = try #require(journey.state(for: .humanProfile))
        #expect(state.targetID == activeHuman.id)
        #expect(state.completedCheckpointCount == 2)
        #expect(state.completedCheckpoints == [.humanAppearance, .humanOptionalDetails])
        #expect(state.checkpointResolutions == [
            .humanAppearance: .reviewed,
            .humanOptionalDetails: .preferNotToSay
        ])
        #expect(state.status == .claimable)
    }

    @Test func routeReloadKeepsOldExplicitCarePlanBeyondEventFetchLimit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Care plan owner")
        let pet = Pet(name: "Long-term care pet", species: "dog")
        human.createdAt = Date(timeIntervalSince1970: 1)
        pet.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(human)
        context.insert(pet)

        let explicitPlan = Event(
            title: "Original feeding plan",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            taskCareKindRaw: TaskCareKind.petFeeding.rawValue
        )
        explicitPlan.recurrenceDays = 1
        explicitPlan.createdAt = Date(timeIntervalSince1970: 2)
        context.insert(explicitPlan)

        var laterGenericEvents: [Event] = []
        for index in 0 ..< 64 {
            let event = Event(
                title: "Generic recurring event \(index)",
                eventType: EventType.daily.rawValue,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 1
            event.createdAt = Date(timeIntervalSince1970: Double(index + 100))
            context.insert(event)
            laterGenericEvents.append(event)
        }
        try context.save()

        let genericEvidence = HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: laterGenericEvents,
            reminderEventIDs: []
        )
        #expect(!genericEvidence.hasExplicitCarePlan)
        #expect(!genericEvidence.hasDefaultRecommendedCarePlan)
        #expect(HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: [explicitPlan] + laterGenericEvents,
            reminderEventIDs: []
        ).hasExplicitCarePlan)

        let reference = try await TaskCenterRouteDataActor(modelContainer: container).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let journey = try #require(reference.snapshot.starterJourney)
        let state = try #require(journey.state(for: .carePlan))
        #expect(state.targetID == pet.id)
        #expect(state.completedCheckpoints == [.acceptedRecommendedCarePlan])
        #expect(state.completedCheckpointCount == 1)
        #expect(state.checkpointResolutions.isEmpty)
        #expect(state.availableResolutionCheckpoints.isEmpty)
        #expect(state.status == .claimable)
    }

    @Test func routeReloadKeepsOldStoredGeneratedCarePlanBeyondEventFetchLimit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Stored plan owner")
        let pet = Pet(name: "Stored plan pet", species: "cat")
        human.createdAt = Date(timeIntervalSince1970: 1)
        pet.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(human)
        context.insert(pet)

        let storedPlan = Event(
            title: "Original play plan",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        storedPlan.recurrenceDays = 1
        storedPlan.createdAt = Date(timeIntervalSince1970: 2)
        context.insert(storedPlan)
        insertLaterGenericCarePlanEvents(targetPet: pet, context: context)
        try context.save()

        let storageKey = "careCalendarEventId_play_\(pet.id.uuidString)"
        UserDefaults.standard.set(storedPlan.id.uuidString, forKey: storageKey)
        defer { UserDefaults.standard.removeObject(forKey: storageKey) }
        #expect(HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: [storedPlan],
            reminderEventIDs: []
        ).hasExplicitCarePlan)

        let reference = try await TaskCenterRouteDataActor(modelContainer: container).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let journey = try #require(reference.snapshot.starterJourney)
        let state = try #require(journey.state(for: .carePlan))
        #expect(state.completedCheckpoints == [.acceptedRecommendedCarePlan])
        #expect(state.status == .claimable)
    }

    @Test func oldStoredDefaultCarePlanStaysAcceptableAndResolutionGateAgrees() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Default plan owner")
        let pet = Pet(name: "Default plan pet", species: "dog")
        human.createdAt = Date(timeIntervalSince1970: 1)
        pet.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(human)
        context.insert(pet)
        insertLaterGenericCarePlanEvents(targetPet: pet, context: context)

        let defaultPlan = Event(
            title: "Original default feeding plan",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        defaultPlan.recurrenceDays = 1
        defaultPlan.createdAt = Date(timeIntervalSince1970: 2)
        context.insert(defaultPlan)
        try context.save()

        let storageKey = "careCalendarEventId_default_feed_\(pet.id.uuidString)"
        UserDefaults.standard.set(defaultPlan.id.uuidString, forKey: storageKey)
        defer { UserDefaults.standard.removeObject(forKey: storageKey) }
        #expect(HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: [defaultPlan],
            reminderEventIDs: []
        ).hasDefaultRecommendedCarePlan)

        let reference = try await TaskCenterRouteDataActor(modelContainer: container).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let journey = try #require(reference.snapshot.starterJourney)
        let state = try #require(journey.state(for: .carePlan))
        #expect(state.completedCheckpoints.isEmpty)
        #expect(state.availableResolutionCheckpoints == [.acceptedRecommendedCarePlan])
        #expect(state.status == .actionRequired)

        let resolution = HouseholdStarterJourneyService.recordResolution(
            task: .carePlan,
            checkpoint: .acceptedRecommendedCarePlan,
            resolution: .reviewed,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        )
        #expect(resolution == .recorded(
            task: .carePlan,
            checkpoint: .acceptedRecommendedCarePlan,
            resolution: .reviewed
        ))
    }

    @Test func laterExplicitCarePlanSupersedesEarlierResolutionWithoutDoubleCounting() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Care plan owner")
        let pet = Pet(name: "Care plan pet", species: "dog")
        context.insert(human)
        context.insert(pet)

        let defaultPlan = Event(
            title: "Default feeding plan",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        defaultPlan.recurrenceDays = 1
        context.insert(defaultPlan)
        try context.save()

        let storageKey = "careCalendarEventId_default_feed_\(pet.id.uuidString)"
        UserDefaults.standard.set(defaultPlan.id.uuidString, forKey: storageKey)
        defer { UserDefaults.standard.removeObject(forKey: storageKey) }

        let checkpoint = HouseholdStarterJourneyCheckpoint.acceptedRecommendedCarePlan
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        #expect(HouseholdStarterJourneyService.recordResolution(
            task: .carePlan,
            checkpoint: checkpoint,
            resolution: .reviewed,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: selection
        ) == .recorded(
            task: .carePlan,
            checkpoint: checkpoint,
            resolution: .reviewed
        ))

        let resolutionReference = try await TaskCenterRouteDataActor(
            modelContainer: container
        ).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let resolutionState = try #require(
            resolutionReference.snapshot.starterJourney?.state(for: .carePlan)
        )
        #expect(resolutionState.completedCheckpointCount == 1)
        #expect(resolutionState.completedCheckpoints == [checkpoint])
        #expect(resolutionState.checkpointResolutions == [checkpoint: .reviewed])
        #expect(resolutionState.status == .claimable)

        let explicitPlan = Event(
            title: "Explicit feeding plan",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            taskCareKindRaw: TaskCareKind.petFeeding.rawValue
        )
        explicitPlan.recurrenceDays = 1
        context.insert(explicitPlan)
        try context.save()

        let factReference = try await TaskCenterRouteDataActor(
            modelContainer: container
        ).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            starterJourneyEnabled: true
        )
        let factState = try #require(
            factReference.snapshot.starterJourney?.state(for: .carePlan)
        )
        #expect(factState.completedCheckpointCount == 1)
        #expect(factState.completedCheckpoints == [checkpoint])
        #expect(factState.checkpointResolutions.isEmpty)
        #expect(factState.status == .claimable)
    }

    private func qualifyHumanProfile(
        human: Human,
        context: ModelContext,
        selection: FixedActiveHumanSelection
    ) {
        _ = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            resolution: .reviewed,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
        _ = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanOptionalDetails,
            resolution: .preferNotToSay,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
    }

    private func insertLaterGenericCarePlanEvents(targetPet: Pet, context: ModelContext) {
        for index in 0 ..< 64 {
            let event = Event(
                title: "Later generic recurring event \(index)",
                eventType: EventType.daily.rawValue,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: targetPet.id.uuidString
            )
            event.recurrenceDays = 1
            event.createdAt = Date(timeIntervalSince1970: Double(index + 100))
            context.insert(event)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(ArkSchemaV94.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "HouseholdStarterJourneyServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private struct FixedActiveHumanSelection: ActiveHumanSelecting {
        let currentHumanId: String?
        var currentHumanIdRaw: String { currentHumanId ?? "" }
    }

    private final class ObservingWallet: CoconutWalletManaging {
        private let wrapped = SwiftDataCoconutWalletManager()
        var calls: [(Bool, Bool)] = []

        func apply(
            deltas: [CoconutWalletDelta],
            context: ModelContext,
            save: Bool,
            postsRewardFeedback: Bool,
            updatesProjection: Bool,
            projectionManager: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            calls.append((postsRewardFeedback, updatesProjection))
            return try wrapped.apply(
                deltas: deltas,
                context: context,
                save: save,
                postsRewardFeedback: postsRewardFeedback,
                updatesProjection: updatesProjection,
                projectionManager: projectionManager
            )
        }

        func applyActorDelta(
            amount: Int,
            emoji: String,
            title: String,
            actorId: String?,
            actorName: String?,
            entryKind: CoconutWalletEntryKind,
            source: CoconutWalletSource,
            context: ModelContext,
            save: Bool,
            postsRewardFeedback: Bool,
            projectionManager: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            try wrapped.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
                entryKind: entryKind,
                source: source,
                context: context,
                save: save,
                postsRewardFeedback: postsRewardFeedback,
                projectionManager: projectionManager
            )
        }

        func totalBalance(context: ModelContext) -> Int { wrapped.totalBalance(context: context) }
        func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int {
            wrapped.balance(accountKey: accountKey, context: context, fallback: fallback)
        }
        func balance(for human: Human, context: ModelContext) -> Int { wrapped.balance(for: human, context: context) }
        func balance(for pet: Pet, context: ModelContext) -> Int { wrapped.balance(for: pet, context: context) }
        func legacySystemBalance(context: ModelContext, fallback: Int) -> Int {
            wrapped.legacySystemBalance(context: context, fallback: fallback)
        }
        func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext) {
            wrapped.setDeveloperOverrideBalance(amount: amount, for: human, displayName: displayName, context: context)
        }
        func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging?) {
            wrapped.refreshQuestProjection(context: context, manager: manager)
        }
        func bootstrapIfNeeded(context: ModelContext, projectionManager: CoconutProjectionManaging?) throws {
            try wrapped.bootstrapIfNeeded(context: context, projectionManager: projectionManager)
        }
    }
}
