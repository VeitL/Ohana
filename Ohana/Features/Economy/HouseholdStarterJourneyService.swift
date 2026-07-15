//
//  HouseholdStarterJourneyService.swift
//  Ohana
//
//  Pure starter-journey projection plus its checkpoint and reward chokepoints.
//

import Foundation
import SwiftData

enum HouseholdStarterJourneyService {
    static let checkpointActionType = "householdStarterJourneyCheckpoint"
    static let checkpointSourceModelName = "HouseholdStarterJourneyCheckpoint"
    static let rewardActionType = "householdStarterJourneyReward"
    static let rewardSourceModelName = "HouseholdStarterJourneyReward"

    private struct CheckpointMetadata: Codable, Equatable, Sendable {
        let journeyKey: String
        let taskRaw: String
        let checkpointRaw: String
        let resolutionRaw: String
        let targetKindRaw: String
        let targetID: String
    }

    private struct CandidateProgress {
        let id: UUID
        let completed: Set<HouseholdStarterJourneyCheckpoint>
        let resolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution]
    }

    private struct SnapshotProgress {
        let human: CandidateProgress?
        let petProfile: CandidateProgress?
        let identity: CandidateProgress?
        let health: CandidateProgress?
        let carePlan: CandidateProgress?
        let firstCare: CandidateProgress?
        let firstCareCompleted: Bool
        let hasLivingHuman: Bool
        let hasLivingPet: Bool
        let carePlanResolutionAvailable: Bool
    }

    private enum ActingHumanResolution {
        case resolved(Human)
        case missing
        case requiresSelection
    }

    nonisolated static func rewardTransactionKey(for task: HouseholdStarterJourneyTask) -> String {
        "householdStarter:v1:reward:\(task.rawValue)"
    }

    nonisolated static func checkpointRecordKey(
        task: HouseholdStarterJourneyTask,
        checkpoint: HouseholdStarterJourneyCheckpoint,
        subjectID: UUID
    ) -> String {
        "\(HouseholdStarterJourneyTask.journeyKey):\(task.rawValue):\(checkpoint.rawValue):\(checkpoint.targetKind.rawValue):\(subjectID.uuidString.lowercased())"
    }

    @MainActor
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: "ohana_has_onboarded")
            && StarterGiftService.isOasisHomeTabUnlocked(defaults: defaults)
    }

    nonisolated static func carePlanEvidence(
        targetPet: Pet,
        events: [Event],
        reminderEventIDs: Set<UUID>
    ) -> HouseholdStarterJourneyCarePlanEvidence {
        var hasExplicit = false
        var hasDefaultRecommended = false
        for event in events where event.relatedEntityId == targetPet.id.uuidString
            && event.recurrenceDays > 0 && !event.isCompleted {
            let hasReminder = reminderEventIDs.contains(event.id)
            let isDefault = CarePlanCalendarSync.isDefaultGeneratedCalendarPlan(
                event,
                pets: [targetPet],
                hasReminder: hasReminder
            )
            let isGenerated = CarePlanCalendarSync.isGeneratedCalendarPlan(
                event,
                pets: [targetPet],
                hasReminder: hasReminder
            )
            if isExplicitPetCarePlan(event, isGenerated: isGenerated, isDefault: isDefault) {
                hasExplicit = true
            } else if isDefault {
                hasDefaultRecommended = true
            }
        }
        return HouseholdStarterJourneyCarePlanEvidence(
            hasExplicitCarePlan: hasExplicit,
            hasDefaultRecommendedCarePlan: hasDefaultRecommended
        )
    }

    nonisolated static func buildSnapshot(
        enabled: Bool,
        activeHumanID: String?,
        humans: [Human],
        pets: [Pet],
        qualificationFacts: HouseholdStarterJourneyQualificationFacts,
        careLedgerEvents: [CareLedgerEvent],
        coconutLedgerEntries: [CoconutLedgerEntry]
    ) -> HouseholdStarterJourneySnapshot {
        guard enabled else { return .disabled }

        let livingHumans = humans
            .filter { $0.passedAwayDate == nil }
            .sorted(by: humanWasCreatedEarlier)
        let activeHumanUUID = activeHumanID
            .flatMap(UUID.init(uuidString:))
            .flatMap { requested in livingHumans.contains(where: { $0.id == requested }) ? requested : nil }
            ?? (livingHumans.count == 1 ? livingHumans.first?.id : nil)
        let firstLivingPet = pets
            .filter { $0.passedAwayDate == nil }
            .sorted(by: memberWasCreatedEarlier)
            .first
        let petFacts = qualificationFacts.targetPetID == firstLivingPet?.id
            ? qualificationFacts
            : .empty
        let resolutions = latestCheckpointResolutions(from: careLedgerEvents)
        let progress = makeSnapshotProgress(
            livingHumans: livingHumans,
            activeHumanID: activeHumanUUID,
            firstLivingPet: firstLivingPet,
            petFacts: petFacts,
            resolutions: resolutions,
            careLedgerEvents: careLedgerEvents
        )
        let states = makeTaskStates(
            progress: progress,
            claimedTasks: claimedTasks(
                careLedgerEvents: careLedgerEvents,
                coconutLedgerEntries: coconutLedgerEntries
            )
        )
        let visible = Array(states.lazy.filter {
            $0.status != .claimed && $0.status != .locked
        }.prefix(HouseholdStarterJourneyPolicy.maximumVisibleTaskCount))

        return HouseholdStarterJourneySnapshot(
            isEnabled: true,
            activeHumanID: activeHumanUUID,
            taskStates: states,
            visibleTaskStates: visible
        )
    }

    @discardableResult
    @MainActor
    static func recordResolution(
        task: HouseholdStarterJourneyTask,
        checkpoint: HouseholdStarterJourneyCheckpoint,
        resolution: HouseholdStarterJourneyResolution,
        subjectID: UUID,
        actingHumanID: String? = nil,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        careLedger: CareLedgerRecording = CareLedgerService()
    ) -> HouseholdStarterJourneyResolutionResult {
        guard checkpoint.task == task,
              checkpoint.allowedResolutions.contains(resolution) else {
            return .invalidCheckpoint
        }

        do {
            let livingHumans = try context.fetch(FetchDescriptor<Human>())
                .filter { $0.passedAwayDate == nil }
            let livingPets = try context.fetch(FetchDescriptor<Pet>())
                .filter { $0.passedAwayDate == nil }
            guard subjectExists(
                id: subjectID,
                kind: checkpoint.targetKind,
                humans: livingHumans,
                pets: livingPets
            ) else {
                return .missingSubject
            }
            if checkpoint == .acceptedRecommendedCarePlan,
               try !hasDefaultRecommendedCarePlan(
                   petID: subjectID,
                   livingPets: livingPets,
                   context: context
               ) {
                return .invalidCheckpoint
            }

            let actorResolution = resolveActingHuman(
                requestedID: actingHumanID,
                activeHumanID: activeHumanSelection.currentHumanId,
                humans: livingHumans
            )
            let actingHuman: Human
            switch actorResolution {
            case let .resolved(human):
                actingHuman = human
            case .missing:
                return .missingHuman
            case .requiresSelection:
                return .requiresHumanSelection
            }

            let recordKey = checkpointRecordKey(
                task: task,
                checkpoint: checkpoint,
                subjectID: subjectID
            )
            let existing = try checkpointEvents(recordKey: recordKey, context: context)
                .sorted(by: ledgerEventIsEarlier)
                .last
            if let existing,
               let metadata = decodeCheckpointMetadata(existing.metadataJSON),
               metadata.resolutionRaw == resolution.rawValue {
                return .unchanged(task: task, checkpoint: checkpoint, resolution: resolution)
            }

            let metadata = CheckpointMetadata(
                journeyKey: HouseholdStarterJourneyTask.journeyKey,
                taskRaw: task.rawValue,
                checkpointRaw: checkpoint.rawValue,
                resolutionRaw: resolution.rawValue,
                targetKindRaw: checkpoint.targetKind.rawValue,
                targetID: subjectID.uuidString.lowercased()
            )
            guard let metadataJSON = encodeCheckpointMetadata(metadata) else {
                return .persistenceFailed
            }
            careLedger.record(
                occurredAt: Date(),
                actorKind: .human,
                actorId: actingHuman.id.uuidString,
                subjectKind: .household,
                subjectId: nil,
                eventKind: .milestone,
                actionType: checkpointActionType,
                amountValue: 0,
                amountUnit: "",
                note: "",
                source: .service,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: checkpointSourceModelName,
                legacyModelId: recordKey,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: metadataJSON,
                context: context,
                save: false
            )
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return .persistenceFailed
            }
            return .recorded(task: task, checkpoint: checkpoint, resolution: resolution)
        } catch {
            context.rollback()
            OhanaLog.warning(
                "Household starter journey checkpoint failed: \(error.localizedDescription)",
                category: "Economy"
            )
            return .persistenceFailed
        }
    }

    @discardableResult
    @MainActor
    static func claim(
        task: HouseholdStarterJourneyTask,
        actingHumanID: String? = nil,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet providedWallet: CoconutWalletManaging? = nil,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        careLedger: CareLedgerRecording = CareLedgerService(),
        defaults: UserDefaults = .standard
    ) -> HouseholdStarterJourneyClaimResult {
        let questManager = providedQuestManager ?? QuestManager()
        let wallet = providedWallet ?? SwiftDataCoconutWalletManager()

        guard isEnabled(defaults: defaults) else {
            return .notEligible(task: task)
        }

        do {
            let loaded = try claimSnapshot(
                activeHumanID: actingHumanID ?? activeHumanSelection.currentHumanId,
                context: context
            )
            guard let state = loaded.snapshot.state(for: task) else {
                return .notEligible(task: task)
            }
            if state.isClaimed {
                return .alreadyClaimed(task: task, amount: task.rewardCoconuts)
            }
            guard state.isClaimable else { return .notEligible(task: task) }

            let actorResolution = resolveActingHuman(
                requestedID: actingHumanID,
                activeHumanID: activeHumanSelection.currentHumanId,
                humans: loaded.humans
            )
            let actingHuman: Human
            switch actorResolution {
            case let .resolved(human):
                actingHuman = human
            case .missing:
                return .missingHuman(task: task)
            case .requiresSelection:
                return .requiresHumanSelection(task: task)
            }

            return try persistClaim(
                task: task,
                actingHuman: actingHuman,
                context: context,
                questManager: questManager,
                wallet: wallet,
                careLedger: careLedger
            )
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            OhanaLog.warning(
                "Household starter journey claim failed: \(error.localizedDescription)",
                category: "Economy"
            )
            return .persistenceFailed(task: task)
        }
    }
}

private extension HouseholdStarterJourneyService {
    @MainActor
    static func claimSnapshot(
        activeHumanID: String?,
        context: ModelContext
    ) throws -> (snapshot: HouseholdStarterJourneySnapshot, humans: [Human]) {
        let humans = try context.fetch(FetchDescriptor<Human>())
        let pets = try context.fetch(FetchDescriptor<Pet>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let facts = try qualificationFacts(pets: pets, events: events, context: context)
        let careLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let coconutLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        return (
            buildSnapshot(
                enabled: true,
                activeHumanID: activeHumanID,
                humans: humans,
                pets: pets,
                qualificationFacts: facts,
                careLedgerEvents: careLedgerEvents,
                coconutLedgerEntries: coconutLedgerEntries
            ),
            humans
        )
    }

    @MainActor
    static func persistClaim(
        task: HouseholdStarterJourneyTask,
        actingHuman: Human,
        context: ModelContext,
        questManager: QuestManager,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording
    ) throws -> HouseholdStarterJourneyClaimResult {
        let occurredAt = Date()
        let title = rewardTitle(for: task)
        let metadataJSON = rewardMetadata(for: task)
        let rewardEvent = careLedger.record(
            occurredAt: occurredAt,
            actorKind: .human,
            actorId: actingHuman.id.uuidString,
            subjectKind: .household,
            subjectId: nil,
            eventKind: .coconut,
            actionType: rewardActionType,
            amountValue: Double(task.rewardCoconuts),
            amountUnit: "coconut",
            note: title,
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: rewardSourceModelName,
            legacyModelId: task.id,
            coconutDelta: task.rewardCoconuts,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: false
        )
        let delta = CoconutWalletDelta(
            accountKey: CoconutAccountKey.human(actingHuman.id),
            ownerKind: .human,
            ownerId: actingHuman.id.uuidString,
            ownerName: actingHuman.name,
            cachedBalance: actingHuman.coconutBalance,
            delta: task.rewardCoconuts,
            entryKind: .reward,
            source: .onboarding,
            title: title,
            emoji: "🥥",
            actorId: actingHuman.id.uuidString,
            actorName: actingHuman.name,
            subjectKind: .household,
            subjectId: nil,
            sourceModelName: rewardSourceModelName,
            sourceModelId: task.id,
            careLedgerEventId: rewardEvent.id.uuidString,
            metadataJSON: metadataJSON,
            occurredAt: occurredAt,
            transactionKey: rewardTransactionKey(for: task),
            human: actingHuman
        )
        let createdEntries = try wallet.apply(
            deltas: [delta],
            context: context,
            save: false,
            postsRewardFeedback: false,
            updatesProjection: false,
            projectionManager: nil
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            return .persistenceFailed(task: task)
        }
        questManager.recordWalletProjection(entries: createdEntries, postsRewardFeedback: true)
        return .claimed(task: task, humanID: actingHuman.id, amount: task.rewardCoconuts)
    }

    private nonisolated static func makeSnapshotProgress(
        livingHumans: [Human],
        activeHumanID: UUID?,
        firstLivingPet: Pet?,
        petFacts: HouseholdStarterJourneyQualificationFacts,
        resolutions: [String: HouseholdStarterJourneyResolution],
        careLedgerEvents: [CareLedgerEvent]
    ) -> SnapshotProgress {
        let human = selectCandidate(
            livingHumans.map { value in
                candidateProgress(
                    id: value.id,
                    checkpoints: [.humanAppearance, .humanOptionalDetails],
                    actual: [
                        .humanAppearance: hasMeaningfulAppearance(value),
                        .humanOptionalDetails: hasMeaningfulOptionalDetails(value)
                    ],
                    resolutions: resolutions
                )
            },
            preferredID: activeHumanID,
            requiredCount: HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: .humanProfile)
        )
        let petProfile = firstLivingPet.map { pet in
            candidateProgress(
                id: pet.id,
                checkpoints: [.petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare],
                actual: [
                    .petLifeStage: hasLifeStageProfile(pet),
                    .petBodyProfile: hasBodyProfile(pet),
                    .petPersonalityAppearance: hasPersonalityOrAppearance(pet),
                    .petDailyCare: hasDailyCareProfile(pet)
                ],
                resolutions: resolutions
            )
        }
        let identity = firstLivingPet.map { pet in
            candidateProgress(
                id: pet.id,
                checkpoints: [.petIdentityDocuments, .petEmergencyContact],
                actual: [
                    .petIdentityDocuments: hasIdentityProtection(pet, facts: petFacts),
                    .petEmergencyContact: hasEmergencyContact(pet)
                ],
                resolutions: resolutions
            )
        }
        let health = firstLivingPet.map { pet in
            candidateProgress(
                id: pet.id,
                checkpoints: [.petHealthProtection],
                actual: [.petHealthProtection: petFacts.hasPreventiveHealthRecord],
                resolutions: resolutions
            )
        }
        let carePlan = firstLivingPet.map { pet in
            carePlanProgress(for: pet, facts: petFacts, resolutions: resolutions)
        }
        let firstCareCompleted = firstLivingPet.map { pet in
            hasFirstCare(targetPetID: pet.id, careLedgerEvents: careLedgerEvents)
        } ?? false
        return SnapshotProgress(
            human: human,
            petProfile: petProfile,
            identity: identity,
            health: health,
            carePlan: carePlan,
            firstCare: firstLivingPet.map {
                CandidateProgress(id: $0.id, completed: [], resolutions: [:])
            },
            firstCareCompleted: firstCareCompleted,
            hasLivingHuman: !livingHumans.isEmpty,
            hasLivingPet: firstLivingPet != nil,
            carePlanResolutionAvailable: petFacts.hasDefaultRecommendedCarePlan
        )
    }

    private nonisolated static func makeTaskStates(
        progress: SnapshotProgress,
        claimedTasks: Set<HouseholdStarterJourneyTask>
    ) -> [HouseholdStarterJourneyTaskState] {
        HouseholdStarterJourneyTask.allCases.map {
            makeTaskState(task: $0, progress: progress, isClaimed: claimedTasks.contains($0))
        }
    }

    private nonisolated static func makeTaskState(
        task: HouseholdStarterJourneyTask,
        progress: SnapshotProgress,
        isClaimed: Bool
    ) -> HouseholdStarterJourneyTaskState {
        let candidate: CandidateProgress?
        let completedCount: Int
        let hasRequiredSubject: Bool
        switch task {
        case .humanProfile:
            candidate = progress.human
            completedCount = candidate?.completed.count ?? 0
            hasRequiredSubject = progress.hasLivingHuman
        case .petProfile:
            candidate = progress.petProfile
            completedCount = candidate?.completed.count ?? 0
            hasRequiredSubject = progress.hasLivingHuman && progress.hasLivingPet
        case .identityProtection:
            candidate = progress.identity
            completedCount = candidate?.completed.count ?? 0
            hasRequiredSubject = progress.hasLivingHuman && progress.hasLivingPet
        case .healthProtection:
            candidate = progress.health
            completedCount = candidate?.completed.count ?? 0
            hasRequiredSubject = progress.hasLivingHuman && progress.hasLivingPet
        case .carePlan:
            candidate = progress.carePlan
            completedCount = candidate?.completed.count ?? 0
            hasRequiredSubject = progress.hasLivingHuman && progress.hasLivingPet
        case .firstCare:
            candidate = progress.firstCare
            completedCount = progress.firstCareCompleted ? 1 : 0
            hasRequiredSubject = progress.hasLivingHuman && progress.hasLivingPet
        }
        let requiredCount = HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task)
        let status: HouseholdStarterJourneyTaskState.Status = if isClaimed {
            .claimed
        } else if !hasRequiredSubject {
            .locked
        } else if completedCount >= requiredCount {
            .claimable
        } else {
            .actionRequired
        }
        let availableResolutions: Set<HouseholdStarterJourneyCheckpoint> = switch task {
        case .carePlan where progress.carePlanResolutionAvailable:
            [.acceptedRecommendedCarePlan]
        case .carePlan, .firstCare:
            []
        case .humanProfile, .petProfile, .identityProtection, .healthProtection:
            Set(task.checkpoints)
        }
        return HouseholdStarterJourneyTaskState(
            task: task,
            status: status,
            rewardCoconuts: task.rewardCoconuts,
            completedCheckpointCount: completedCount,
            requiredCheckpointCount: requiredCount,
            targetID: candidate?.id,
            completedCheckpoints: candidate?.completed ?? [],
            checkpointResolutions: candidate?.resolutions ?? [:],
            availableResolutionCheckpoints: availableResolutions
        )
    }

    private nonisolated static func candidateProgress(
        id: UUID,
        checkpoints: [HouseholdStarterJourneyCheckpoint],
        actual: [HouseholdStarterJourneyCheckpoint: Bool],
        resolutions: [String: HouseholdStarterJourneyResolution]
    ) -> CandidateProgress {
        var completed: Set<HouseholdStarterJourneyCheckpoint> = []
        var resolved: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution] = [:]
        for checkpoint in checkpoints {
            let key = checkpointRecordKey(
                task: checkpoint.task,
                checkpoint: checkpoint,
                subjectID: id
            )
            if actual[checkpoint] == true {
                completed.insert(checkpoint)
            }
            if let resolution = resolutions[key] {
                completed.insert(checkpoint)
                resolved[checkpoint] = resolution
            }
        }
        return CandidateProgress(id: id, completed: completed, resolutions: resolved)
    }

    private nonisolated static func selectCandidate(
        _ candidates: [CandidateProgress],
        preferredID: UUID?,
        requiredCount: Int
    ) -> CandidateProgress? {
        guard !candidates.isEmpty else { return nil }
        if let preferredID,
           let preferred = candidates.first(where: { $0.id == preferredID }) {
            return preferred
        }
        if let eligible = candidates.first(where: { $0.completed.count >= requiredCount }) {
            return eligible
        }
        if let preferredID,
           let preferred = candidates.first(where: { $0.id == preferredID }) {
            return preferred
        }
        return candidates.max { lhs, rhs in
            if lhs.completed.count != rhs.completed.count {
                return lhs.completed.count < rhs.completed.count
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    nonisolated static func latestCheckpointResolutions(
        from events: [CareLedgerEvent]
    ) -> [String: HouseholdStarterJourneyResolution] {
        var result: [String: HouseholdStarterJourneyResolution] = [:]
        for event in events.sorted(by: ledgerEventIsEarlier) {
            guard event.actionType == checkpointActionType,
                  event.legacyModelName == checkpointSourceModelName,
                  let recordKey = event.legacyModelId,
                  let metadata = decodeCheckpointMetadata(event.metadataJSON),
                  metadata.journeyKey == HouseholdStarterJourneyTask.journeyKey,
                  let task = HouseholdStarterJourneyTask(rawValue: metadata.taskRaw),
                  let checkpoint = HouseholdStarterJourneyCheckpoint(rawValue: metadata.checkpointRaw),
                  checkpoint.task == task,
                  let resolution = HouseholdStarterJourneyResolution(rawValue: metadata.resolutionRaw),
                  checkpoint.allowedResolutions.contains(resolution),
                  metadata.targetKindRaw == checkpoint.targetKind.rawValue,
                  let targetID = UUID(uuidString: metadata.targetID),
                  recordKey == checkpointRecordKey(
                      task: task,
                      checkpoint: checkpoint,
                      subjectID: targetID
                  ) else {
                continue
            }
            result[recordKey] = resolution
        }
        return result
    }

    nonisolated static func claimedTasks(
        careLedgerEvents: [CareLedgerEvent],
        coconutLedgerEntries: [CoconutLedgerEntry]
    ) -> Set<HouseholdStarterJourneyTask> {
        Set(HouseholdStarterJourneyTask.allCases.filter { task in
            let transactionKey = rewardTransactionKey(for: task)
            if coconutLedgerEntries.contains(where: { $0.transactionKey == transactionKey }) {
                return true
            }
            return careLedgerEvents.contains { event in
                event.actionType == rewardActionType
                    && event.legacyModelName == rewardSourceModelName
                    && event.legacyModelId == task.id
            }
        })
    }

    nonisolated static func hasMeaningfulAppearance(_ human: Human) -> Bool {
        // member-lifecycle-gate: allow read-only starter qualification
        if human.avatarAttachmentState == .present || !human.avatarImageSignature.isEmpty { return true }
        let emoji = normalized(human.avatarEmoji)
        return !emoji.isEmpty && emoji != "👤"
    }

    nonisolated static func hasMeaningfulOptionalDetails(_ human: Human) -> Bool {
        human.birthday != nil
            || !normalized(human.bloodType).isEmpty
            || !normalized(human.genderIdentityRaw ?? "").isEmpty
            || !normalized(human.nationality).isEmpty
            || !normalized(human.city).isEmpty
            || !normalized(human.mbti).isEmpty
            || human.heightCm > 0
    }

    nonisolated static func hasLifeStageProfile(_ pet: Pet) -> Bool {
        pet.birthday != nil || pet.homeDate != nil
    }

    nonisolated static func hasBodyProfile(_ pet: Pet) -> Bool {
        let gender = normalized(pet.gender).lowercased()
        return (!gender.isEmpty && gender != "unknown" && gender != "未知")
            || !normalized(pet.coatColor).isEmpty
            || !normalized(pet.birthCountry).isEmpty
            || !normalized(pet.birthCity).isEmpty
    }

    nonisolated static func hasPersonalityOrAppearance(_ pet: Pet) -> Bool {
        // member-lifecycle-gate: allow read-only starter qualification
        !normalized(pet.personalityTagsRaw).isEmpty
            || pet.avatarAttachmentState == .present
            || !pet.avatarImageSignature.isEmpty
            || pet.cardPopoutAttachmentState == .present
            || !pet.cardPopoutImageSignature.isEmpty
    }

    nonisolated static func hasDailyCareProfile(_ pet: Pet) -> Bool {
        !normalized(pet.foodBrand).isEmpty
            || pet.dailyPortionGrams > 0
            || pet.restockDate != nil
            || pet.restockWeight > 0
            || pet.foodPrice > 0
            || pet.casualOpenDate != nil
            || pet.casualDurationDays > 0
            || pet.foodReminderEnabled
    }

    nonisolated static func hasIdentityProtection(
        _ pet: Pet,
        facts: HouseholdStarterJourneyQualificationFacts
    ) -> Bool {
        !normalized(pet.microchipID).isEmpty
            || !normalized(pet.passportNumber).isEmpty
            || facts.hasProtectionDocument
            || facts.hasInsurance
    }

    nonisolated static func hasEmergencyContact(_ pet: Pet) -> Bool {
        !normalized(pet.vetContact).isEmpty
            || !normalized(pet.vetClinicName).isEmpty
            || !normalized(pet.vetDoctorName).isEmpty
            || !normalized(pet.vetAddress).isEmpty
            || !normalized(pet.allergies).isEmpty
    }

    nonisolated static func isExplicitPetCarePlan(
        _ event: Event,
        isGenerated: Bool,
        isDefault: Bool
    ) -> Bool {
        if isGenerated && !isDefault { return true }
        if let careKind = TaskCareKind(rawValue: event.taskCareKindRaw),
           careKind.subjectKind == .pet {
            return true
        }
        if !event.feedRuleKindRaw.isEmpty { return true }
        switch DomainEntityLinkRegistry.role(for: event) {
        case .petAutoFeeder, .petWaterPlan:
            return true
        case .directPet, .directHuman, .directPlant, .plantScoped, .petFoodStock,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .humanNote,
             .humanMedicationPlan, .unscoped, .unknown:
            return false
        }
    }

    @MainActor
    static func qualificationFacts(
        pets: [Pet],
        events: [Event],
        context: ModelContext
    ) throws -> HouseholdStarterJourneyQualificationFacts {
        guard let targetPet = pets
            .filter({ $0.passedAwayDate == nil })
            .sorted(by: memberWasCreatedEarlier)
            .first else {
            return .empty
        }
        let targetPetID = targetPet.id
        let targetPetIDRaw = targetPetID.uuidString
        let passport = DocumentCategory.passport.rawValue
        let medical = DocumentCategory.medical.rawValue
        let registration = DocumentCategory.registration.rawValue
        let other = DocumentCategory.other.rawValue
        var documentDescriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> { document in
                document.pet?.id == targetPetID
                    && (document.category == passport
                        || document.category == medical
                        || document.category == registration
                        || document.category == other)
            }
        )
        documentDescriptor.fetchLimit = 1

        var insuranceDescriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { insurance in
                insurance.pet?.id == targetPetID
            }
        )
        insuranceDescriptor.fetchLimit = 1

        let vaccine = HealthLogType.vaccine.rawValue
        let internalDeworming = HealthLogType.dewormingInternal.rawValue
        let externalDeworming = HealthLogType.dewormingExternal.rawValue
        let checkup = HealthLogType.checkup.rawValue
        var healthDescriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { log in
                log.pet?.id == targetPetID
                    && (log.type == vaccine
                        || log.type == internalDeworming
                        || log.type == externalDeworming
                        || log.type == checkup)
            }
        )
        healthDescriptor.fetchLimit = 1

        var reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.event?.relatedEntityId == targetPetIDRaw
            }
        )
        reminderDescriptor.fetchLimit = 128
        let reminderEventIDs = Set(try context.fetch(reminderDescriptor).compactMap { $0.event?.id })
        let carePlan = carePlanEvidence(
            targetPet: targetPet,
            events: events,
            reminderEventIDs: reminderEventIDs
        )
        return HouseholdStarterJourneyQualificationFacts(
            targetPetID: targetPetID,
            hasProtectionDocument: !(try context.fetch(documentDescriptor)).isEmpty,
            hasInsurance: !(try context.fetch(insuranceDescriptor)).isEmpty,
            hasPreventiveHealthRecord: !(try context.fetch(healthDescriptor)).isEmpty,
            hasExplicitCarePlan: carePlan.hasExplicitCarePlan,
            hasDefaultRecommendedCarePlan: carePlan.hasDefaultRecommendedCarePlan
        )
    }

    @MainActor
    static func hasDefaultRecommendedCarePlan(
        petID: UUID,
        livingPets: [Pet],
        context: ModelContext
    ) throws -> Bool {
        guard let pet = livingPets.first(where: { $0.id == petID }) else { return false }
        let petIDRaw = petID.uuidString
        var eventDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petIDRaw
                    && event.recurrenceDays > 0
                    && !event.isCompleted
            }
        )
        eventDescriptor.fetchLimit = 64
        var reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.event?.relatedEntityId == petIDRaw
            }
        )
        reminderDescriptor.fetchLimit = 128
        let events = try context.fetch(eventDescriptor)
        let reminderIDs = Set(try context.fetch(reminderDescriptor).compactMap { $0.event?.id })
        return carePlanEvidence(
            targetPet: pet,
            events: events,
            reminderEventIDs: reminderIDs
        ).hasDefaultRecommendedCarePlan
    }

    private nonisolated static func carePlanProgress(
        for pet: Pet,
        facts: HouseholdStarterJourneyQualificationFacts,
        resolutions: [String: HouseholdStarterJourneyResolution]
    ) -> CandidateProgress {
        let checkpoint = HouseholdStarterJourneyCheckpoint.acceptedRecommendedCarePlan
        let key = checkpointRecordKey(
            task: .carePlan,
            checkpoint: checkpoint,
            subjectID: pet.id
        )
        let hasExplicitPlan = facts.hasExplicitCarePlan
        let hasAnyPlan = hasExplicitPlan || facts.hasDefaultRecommendedCarePlan
        var completed: Set<HouseholdStarterJourneyCheckpoint> = []
        var recordedResolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution] = [:]
        if hasExplicitPlan {
            completed.insert(checkpoint)
        }
        if hasAnyPlan, let resolution = resolutions[key] {
            completed.insert(checkpoint)
            recordedResolutions[checkpoint] = resolution
        }
        return CandidateProgress(
            id: pet.id,
            completed: completed,
            resolutions: recordedResolutions
        )
    }

    nonisolated static func hasFirstCare(
        targetPetID: UUID,
        careLedgerEvents: [CareLedgerEvent]
    ) -> Bool {
        let allowedKinds: Set<CareLedgerEventKind> = [.care, .potty, .walk, .hygiene]
        return careLedgerEvents.contains { event in
            event.subjectKind == CareLedgerSubjectKind.pet.rawValue
                && event.subjectId == targetPetID.uuidString
                && allowedKinds.contains(event.eventKindEnum)
        }
    }

    nonisolated static func ledgerEventIsEarlier(_ lhs: CareLedgerEvent, _ rhs: CareLedgerEvent) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated static func memberWasCreatedEarlier(_ lhs: Pet, _ rhs: Pet) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated static func humanWasCreatedEarlier(_ lhs: Human, _ rhs: Human) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func encodeCheckpointMetadata(_ metadata: CheckpointMetadata) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(metadata) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated static func decodeCheckpointMetadata(_ value: String) -> CheckpointMetadata? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CheckpointMetadata.self, from: data)
    }

    @MainActor
    static func checkpointEvents(
        recordKey: String,
        context: ModelContext
    ) throws -> [CareLedgerEvent] {
        let actionType = checkpointActionType
        let modelName = checkpointSourceModelName
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType == actionType
                    && event.legacyModelName == modelName
                    && event.legacyModelId == recordKey
            }
        )
        descriptor.fetchLimit = 8
        return try context.fetch(descriptor)
    }

    @MainActor
    private static func resolveActingHuman(
        requestedID: String?,
        activeHumanID: String?,
        humans: [Human]
    ) -> ActingHumanResolution {
        let livingHumans = humans.filter { $0.passedAwayDate == nil }
        if let requestedID = normalized(requestedID ?? "").nilIfEmpty {
            if let id = UUID(uuidString: requestedID),
               let human = livingHumans.first(where: { $0.id == id }) {
                return .resolved(human)
            }
            if livingHumans.count == 1, let only = livingHumans.first {
                return .resolved(only)
            }
            return .missing
        }
        if let activeID = activeHumanID,
           let id = UUID(uuidString: activeID),
           let human = livingHumans.first(where: { $0.id == id }) {
            return .resolved(human)
        }
        if livingHumans.count == 1, let only = livingHumans.first {
            return .resolved(only)
        }
        return livingHumans.isEmpty ? .missing : .requiresSelection
    }

    nonisolated static func subjectExists(
        id: UUID,
        kind: HouseholdStarterJourneyTargetKind,
        humans: [Human],
        pets: [Pet]
    ) -> Bool {
        switch kind {
        case .human:
            humans.contains { $0.id == id }
        case .pet:
            pets.contains { $0.id == id }
        case .household:
            false
        }
    }

    nonisolated static func rewardMetadata(for task: HouseholdStarterJourneyTask) -> String {
        let object: [String: Any] = [
            "journeyKey": HouseholdStarterJourneyTask.journeyKey,
            "rewardCoconuts": task.rewardCoconuts,
            "task": task.rawValue
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    nonisolated static func rewardTitle(for task: HouseholdStarterJourneyTask) -> String {
        let l = L10n.current
        switch task {
        case .humanProfile:
            return l.tr(zh: "完善成员资料", en: "Complete a member profile", de: "Mitgliedsprofil vervollständigen")
        case .petProfile:
            return l.tr(zh: "完善宠物资料", en: "Complete a pet profile", de: "Tierprofil vervollständigen")
        case .identityProtection:
            return l.tr(zh: "确认证件与保障", en: "Review identity and protection", de: "Identität und Schutz prüfen")
        case .healthProtection:
            return l.tr(zh: "确认健康保护状态", en: "Review health protection", de: "Gesundheitsschutz prüfen")
        case .carePlan:
            return l.tr(zh: "建立照护计划", en: "Set up a care plan", de: "Pflegeplan einrichten")
        case .firstCare:
            return l.tr(zh: "完成首次照护", en: "Complete first care", de: "Erste Pflege abschließen")
        }
    }
}
