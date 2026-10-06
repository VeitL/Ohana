//
//  HumanHealthConditionCommands.swift
//  Ohana
//
//  Authorized write boundary for Human condition tracking and observations.
//

import Foundation
import SwiftData

nonisolated struct HumanHealthConditionCommandInput: Equatable, Sendable {
    let name: String
    let category: HumanHealthConditionCategory
    let trackingStatus: HumanHealthTrackingStatus
    let startedOn: Date?
    let carePlan: String
    let notes: String
    /// `nil` preserves existing private linkage during an update; create treats it as empty.
    let linkedMedicationIDs: [UUID]?
    let linkedMetricKeys: [String]
    let recordedByHumanId: String?

    init(
        name: String,
        category: HumanHealthConditionCategory = .other,
        trackingStatus: HumanHealthTrackingStatus = .active,
        startedOn: Date? = nil,
        carePlan: String = "",
        notes: String = "",
        linkedMedicationIDs: [UUID]? = [],
        linkedMetricKeys: [String] = [],
        recordedByHumanId: String? = nil
    ) {
        self.name = name
        self.category = category
        self.trackingStatus = trackingStatus
        self.startedOn = startedOn
        self.carePlan = carePlan
        self.notes = notes
        self.linkedMedicationIDs = linkedMedicationIDs
        self.linkedMetricKeys = linkedMetricKeys
        self.recordedByHumanId = recordedByHumanId
    }
}

nonisolated struct HumanHealthObservationCommandInput: Equatable, Sendable {
    let recordedAt: Date
    let severity: Int
    let moodScore: Int?
    let sleepHours: Double?
    let symptomTags: [String]
    let possibleTriggers: String
    let careActions: String
    /// `nil` preserves an existing private medication observation during an update.
    let medicationResponse: HumanMedicationResponse?
    /// `nil` preserves existing private side-effect text during an update.
    let sideEffects: String?
    let notes: String
    let recordedByHumanId: String?

    init(
        recordedAt: Date = Date(),
        severity: Int,
        moodScore: Int? = nil,
        sleepHours: Double? = nil,
        symptomTags: [String] = [],
        possibleTriggers: String = "",
        careActions: String = "",
        medicationResponse: HumanMedicationResponse? = .unknown,
        sideEffects: String? = "",
        notes: String = "",
        recordedByHumanId: String? = nil
    ) {
        self.recordedAt = recordedAt
        self.severity = severity
        self.moodScore = moodScore
        self.sleepHours = sleepHours
        self.symptomTags = symptomTags
        self.possibleTriggers = possibleTriggers
        self.careActions = careActions
        self.medicationResponse = medicationResponse
        self.sideEffects = sideEffects
        self.notes = notes
        self.recordedByHumanId = recordedByHumanId
    }
}

nonisolated struct HumanHealthConditionCommandResult: Equatable, Sendable {
    let humanID: UUID
    let conditionID: UUID
    let didChange: Bool
    let persistenceErrorDescription: String?
}

nonisolated struct HumanHealthObservationCommandResult: Equatable, Sendable {
    let humanID: UUID
    let conditionID: UUID
    let observationID: UUID
    let didChange: Bool
    let persistenceErrorDescription: String?
}

@MainActor
enum HumanHealthConditionCommandService {
    private static let cleanContextErrorDescription =
        "Human health condition command requires a clean ModelContext"

    @discardableResult
    static func createCondition(
        human: Human,
        input: HumanHealthConditionCommandInput,
        context: ModelContext
    ) -> HumanHealthConditionCommandResult {
        let proposedID = UUID()
        guard !context.hasChanges else {
            return conditionFailure(
                human: human,
                conditionID: proposedID,
                errorDescription: cleanContextErrorDescription
            )
        }
        let now = Date()
        guard let values = conditionValues(input, human: human, context: context, now: now),
              let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                  human: human,
                  occurredAt: now,
                  modifiedAt: now,
                  writeKind: .care,
                  context: context,
                  logPrefix: "HumanHealthConditionCommandService.createCondition"
              )
        else {
            return conditionFailure(human: human, conditionID: proposedID)
        }

        let condition = DomainMemberFactWriter.createHumanHealthCondition(
            plan: write,
            human: human,
            values: values,
            context: context
        )
        return saveCondition(human: human, conditionID: condition.id, context: context)
    }

    @discardableResult
    static func updateCondition(
        _ condition: HumanHealthCondition,
        human: Human,
        input: HumanHealthConditionCommandInput,
        context: ModelContext
    ) -> HumanHealthConditionCommandResult {
        guard !context.hasChanges else {
            return conditionFailure(
                human: human,
                conditionID: condition.id,
                errorDescription: cleanContextErrorDescription
            )
        }
        let now = Date()
        guard owns(condition, human: human),
              let values = conditionValues(input, human: human, context: context, now: now),
              let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                  human: human,
                  occurredAt: now,
                  modifiedAt: now,
                  writeKind: .care,
                  context: context,
                  logPrefix: "HumanHealthConditionCommandService.updateCondition"
              )
        else {
            return conditionFailure(human: human, conditionID: condition.id)
        }

        DomainMemberFactWriter.updateHumanHealthCondition(
            plan: write,
            condition: condition,
            human: human,
            values: values,
            context: context
        )
        return saveCondition(human: human, conditionID: condition.id, context: context)
    }

    @discardableResult
    static func deleteCondition(
        _ condition: HumanHealthCondition,
        human: Human,
        context: ModelContext
    ) -> HumanHealthConditionCommandResult {
        guard !context.hasChanges else {
            return conditionFailure(
                human: human,
                conditionID: condition.id,
                errorDescription: cleanContextErrorDescription
            )
        }
        let now = Date()
        guard owns(condition, human: human),
              let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                  human: human,
                  occurredAt: now,
                  modifiedAt: now,
                  writeKind: .care,
                  context: context,
                  logPrefix: "HumanHealthConditionCommandService.deleteCondition"
              )
        else {
            return conditionFailure(human: human, conditionID: condition.id)
        }

        let conditionID = condition.id
        let observations: [HumanHealthObservation]
        do {
            let conditionKey = conditionID.uuidString
            let conditionKeyLower = conditionKey.lowercased()
            let descriptor = FetchDescriptor<HumanHealthObservation>(
                predicate: #Predicate<HumanHealthObservation> { observation in
                    observation.conditionId.contains(conditionKey) ||
                        observation.conditionId.contains(conditionKeyLower)
                }
            )
            // The store query is scoped to this condition. Canonical filtering
            // retains whitespace/case compatibility without loading unrelated rows.
            observations = try context.fetch(descriptor)
                .filter { normalizedUUID($0.conditionId) == conditionID }
        } catch {
            return conditionFailure(
                human: human,
                conditionID: conditionID,
                errorDescription: error.localizedDescription
            )
        }

        DomainMemberFactWriter.deleteHumanHealthCondition(
            plan: write,
            condition: condition,
            observations: observations,
            context: context
        )
        return saveCondition(human: human, conditionID: conditionID, context: context)
    }

    @discardableResult
    static func recordObservation(
        condition: HumanHealthCondition,
        human: Human,
        input: HumanHealthObservationCommandInput,
        context: ModelContext
    ) -> HumanHealthObservationCommandResult {
        let proposedID = UUID()
        guard !context.hasChanges else {
            return observationFailure(
                human: human,
                conditionID: condition.id,
                observationID: proposedID,
                errorDescription: cleanContextErrorDescription
            )
        }
        let now = Date()
        guard owns(condition, human: human),
              let values = observationValues(input, context: context, now: now),
              let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                  human: human,
                  occurredAt: now,
                  modifiedAt: now,
                  writeKind: .care,
                  context: context,
                  logPrefix: "HumanHealthConditionCommandService.recordObservation"
              )
        else {
            return observationFailure(
                human: human,
                conditionID: condition.id,
                observationID: proposedID
            )
        }

        let observation = DomainMemberFactWriter.createHumanHealthObservation(
            plan: write,
            condition: condition,
            human: human,
            values: values,
            context: context
        )
        return saveObservation(
            human: human,
            conditionID: condition.id,
            observationID: observation.id,
            context: context
        )
    }

    @discardableResult
    static func updateObservation(
        _ observation: HumanHealthObservation,
        condition: HumanHealthCondition,
        human: Human,
        input: HumanHealthObservationCommandInput,
        context: ModelContext
    ) -> HumanHealthObservationCommandResult {
        guard !context.hasChanges else {
            return observationFailure(
                human: human,
                conditionID: condition.id,
                observationID: observation.id,
                errorDescription: cleanContextErrorDescription
            )
        }
        let now = Date()
        guard owns(condition, human: human),
              owns(observation, condition: condition, human: human),
              let values = observationValues(input, context: context, now: now),
              let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                  human: human,
                  occurredAt: now,
                  modifiedAt: now,
                  writeKind: .care,
                  context: context,
                  logPrefix: "HumanHealthConditionCommandService.updateObservation"
              )
        else {
            return observationFailure(
                human: human,
                conditionID: condition.id,
                observationID: observation.id
            )
        }

        DomainMemberFactWriter.updateHumanHealthObservation(
            plan: write,
            observation: observation,
            condition: condition,
            human: human,
            values: values,
            context: context
        )
        return saveObservation(
            human: human,
            conditionID: condition.id,
            observationID: observation.id,
            context: context
        )
    }

    @discardableResult
    static func deleteObservation(
        _ observation: HumanHealthObservation,
        condition: HumanHealthCondition,
        human: Human,
        context: ModelContext
    ) -> HumanHealthObservationCommandResult {
        guard !context.hasChanges else {
            return observationFailure(
                human: human,
                conditionID: condition.id,
                observationID: observation.id,
                errorDescription: cleanContextErrorDescription
            )
        }
        let now = Date()
        guard owns(condition, human: human),
              owns(observation, condition: condition, human: human),
              let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                  human: human,
                  occurredAt: now,
                  modifiedAt: now,
                  writeKind: .care,
                  context: context,
                  logPrefix: "HumanHealthConditionCommandService.deleteObservation"
              )
        else {
            return observationFailure(
                human: human,
                conditionID: condition.id,
                observationID: observation.id
            )
        }

        let observationID = observation.id
        DomainMemberFactWriter.deleteHumanHealthObservation(
            plan: write,
            observation: observation,
            context: context
        )
        return saveObservation(
            human: human,
            conditionID: condition.id,
            observationID: observationID,
            context: context
        )
    }

    private static func conditionValues(
        _ input: HumanHealthConditionCommandInput,
        human: Human,
        context: ModelContext,
        now: Date
    ) -> DomainHumanHealthConditionValues? {
        let name = clean(input.name)
        guard !name.isEmpty,
              input.startedOn.map({ $0 <= now }) ?? true
        else { return nil }

        let linkedMedicationIDs: [UUID]?
        if let requestedMedicationIDs = input.linkedMedicationIDs {
            let humanID = human.id.uuidString
            let humanIDLower = humanID.lowercased()
            var ownedMedicationIDs = Set<UUID>()
            do {
                for medicationID in unique(requestedMedicationIDs) {
                    var descriptor = FetchDescriptor<HumanMedication>(
                        predicate: #Predicate<HumanMedication> { medication in
                            medication.id == medicationID &&
                                (medication.humanId.contains(humanID) || medication.humanId.contains(humanIDLower))
                        }
                    )
                    descriptor.fetchLimit = 4
                    let candidates = try context.fetch(descriptor)
                    if candidates.contains(where: { normalizedUUID($0.humanId) == human.id }) {
                        ownedMedicationIDs.insert(medicationID)
                    }
                }
            } catch {
                return nil
            }
            linkedMedicationIDs = unique(requestedMedicationIDs).filter(ownedMedicationIDs.contains)
        } else {
            linkedMedicationIDs = nil
        }

        return DomainHumanHealthConditionValues(
            name: name,
            category: input.category,
            trackingStatus: input.trackingStatus,
            startedOn: input.startedOn,
            carePlan: clean(input.carePlan),
            notes: clean(input.notes),
            linkedMedicationIDs: linkedMedicationIDs,
            linkedMetricKeys: uniqueNonempty(input.linkedMetricKeys),
            recordedByHumanId: HumanActionAttributionPolicy.activeHumanID(
                input.recordedByHumanId,
                context: context
            )
        )
    }

    private static func observationValues(
        _ input: HumanHealthObservationCommandInput,
        context: ModelContext,
        now: Date
    ) -> DomainHumanHealthObservationValues? {
        guard input.recordedAt <= now,
              (0 ... 10).contains(input.severity),
              input.moodScore.map({ (1 ... 10).contains($0) }) ?? true,
              input.sleepHours.map({ $0.isFinite && (0 ... 24).contains($0) }) ?? true
        else { return nil }

        return DomainHumanHealthObservationValues(
            recordedAt: input.recordedAt,
            severity: input.severity,
            moodScore: input.moodScore,
            sleepHours: input.sleepHours,
            symptomTags: uniqueNonempty(input.symptomTags),
            possibleTriggers: clean(input.possibleTriggers),
            careActions: clean(input.careActions),
            medicationResponse: input.medicationResponse,
            sideEffects: input.sideEffects.map { clean($0) },
            notes: clean(input.notes),
            recordedByHumanId: HumanActionAttributionPolicy.activeHumanID(
                input.recordedByHumanId,
                context: context
            )
        )
    }

    private static func owns(_ condition: HumanHealthCondition, human: Human) -> Bool {
        normalizedUUID(condition.humanId) == human.id
    }

    private static func owns(
        _ observation: HumanHealthObservation,
        condition: HumanHealthCondition,
        human: Human
    ) -> Bool {
        normalizedUUID(observation.humanId) == human.id
            && normalizedUUID(observation.conditionId) == condition.id
    }

    private static func normalizedUUID(_ raw: String) -> UUID? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func saveCondition(
        human: Human,
        conditionID: UUID,
        context: ModelContext
    ) -> HumanHealthConditionCommandResult {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return conditionFailure(
                human: human,
                conditionID: conditionID,
                errorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthConditionCommandResult(
            humanID: human.id,
            conditionID: conditionID,
            didChange: true,
            persistenceErrorDescription: nil
        )
    }

    private static func saveObservation(
        human: Human,
        conditionID: UUID,
        observationID: UUID,
        context: ModelContext
    ) -> HumanHealthObservationCommandResult {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return observationFailure(
                human: human,
                conditionID: conditionID,
                observationID: observationID,
                errorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthObservationCommandResult(
            humanID: human.id,
            conditionID: conditionID,
            observationID: observationID,
            didChange: true,
            persistenceErrorDescription: nil
        )
    }

    private static func conditionFailure(
        human: Human,
        conditionID: UUID,
        errorDescription: String? = nil
    ) -> HumanHealthConditionCommandResult {
        HumanHealthConditionCommandResult(
            humanID: human.id,
            conditionID: conditionID,
            didChange: false,
            persistenceErrorDescription: errorDescription
        )
    }

    private static func observationFailure(
        human: Human,
        conditionID: UUID,
        observationID: UUID,
        errorDescription: String? = nil
    ) -> HumanHealthObservationCommandResult {
        HumanHealthObservationCommandResult(
            humanID: human.id,
            conditionID: conditionID,
            observationID: observationID,
            didChange: false,
            persistenceErrorDescription: errorDescription
        )
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unique(_ values: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func uniqueNonempty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let cleaned = clean(value)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return nil }
            return cleaned
        }
    }
}

@MainActor
struct HumanHealthConditionCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func createCondition(
        human: Human,
        input: HumanHealthConditionCommandInput,
        note: String = ""
    ) -> HumanHealthConditionCommandResult {
        let result = HumanHealthConditionCommandService.createCondition(
            human: human,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthCondition(result, action: "create", note: note)
        }
        return result
    }

    @discardableResult
    func updateCondition(
        _ condition: HumanHealthCondition,
        human: Human,
        input: HumanHealthConditionCommandInput,
        note: String = ""
    ) -> HumanHealthConditionCommandResult {
        let result = HumanHealthConditionCommandService.updateCondition(
            condition,
            human: human,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthCondition(result, action: "update", note: note)
        }
        return result
    }

    @discardableResult
    func deleteCondition(
        _ condition: HumanHealthCondition,
        human: Human,
        note: String = ""
    ) -> HumanHealthConditionCommandResult {
        let result = HumanHealthConditionCommandService.deleteCondition(
            condition,
            human: human,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthCondition(result, action: "delete", note: note)
        }
        return result
    }

    @discardableResult
    func recordObservation(
        condition: HumanHealthCondition,
        human: Human,
        input: HumanHealthObservationCommandInput,
        note: String = ""
    ) -> HumanHealthObservationCommandResult {
        let result = HumanHealthConditionCommandService.recordObservation(
            condition: condition,
            human: human,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthObservation(result, action: "record", note: note)
        }
        return result
    }

    @discardableResult
    func updateObservation(
        _ observation: HumanHealthObservation,
        condition: HumanHealthCondition,
        human: Human,
        input: HumanHealthObservationCommandInput,
        note: String = ""
    ) -> HumanHealthObservationCommandResult {
        let result = HumanHealthConditionCommandService.updateObservation(
            observation,
            condition: condition,
            human: human,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthObservation(result, action: "update", note: note)
        }
        return result
    }

    @discardableResult
    func deleteObservation(
        _ observation: HumanHealthObservation,
        condition: HumanHealthCondition,
        human: Human,
        note: String = ""
    ) -> HumanHealthObservationCommandResult {
        let result = HumanHealthConditionCommandService.deleteObservation(
            observation,
            condition: condition,
            human: human,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthObservation(result, action: "delete", note: note)
        }
        return result
    }
}
