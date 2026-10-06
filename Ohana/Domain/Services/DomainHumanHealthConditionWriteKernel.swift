//
//  DomainHumanHealthConditionWriteKernel.swift
//  Ohana
//
//  Persistent fact writer for Human condition tracking.
//

import Foundation
import SwiftData

nonisolated struct DomainHumanHealthConditionValues {
    let name: String
    let category: HumanHealthConditionCategory
    let trackingStatus: HumanHealthTrackingStatus
    let startedOn: Date?
    let carePlan: String
    let notes: String
    let linkedMedicationIDs: [UUID]?
    let linkedMetricKeys: [String]
    let recordedByHumanId: String?
}

nonisolated struct DomainHumanHealthObservationValues {
    let recordedAt: Date
    let severity: Int
    let moodScore: Int?
    let sleepHours: Double?
    let symptomTags: [String]
    let possibleTriggers: String
    let careActions: String
    let medicationResponse: HumanMedicationResponse?
    let sideEffects: String?
    let notes: String
    let recordedByHumanId: String?
}

nonisolated extension DomainMemberFactWriter {
    @discardableResult
    static func createHumanHealthCondition(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        values: DomainHumanHealthConditionValues,
        context: ModelContext
    ) -> HumanHealthCondition {
        plan.consume()
        let condition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: values.name,
            category: values.category,
            trackingStatus: values.trackingStatus,
            startedOn: values.startedOn,
            carePlan: values.carePlan,
            notes: values.notes,
            linkedMedicationIDs: values.linkedMedicationIDs ?? [],
            linkedMetricKeys: values.linkedMetricKeys,
            recordedByHumanId: values.recordedByHumanId,
            createdAt: plan.modifiedAt,
            updatedAt: plan.modifiedAt
        )
        context.insert(condition)
        CloudSyncMutationRecorder.markModified(condition, context: context, modifiedAt: plan.modifiedAt)
        return condition
    }

    static func updateHumanHealthCondition(
        plan: AuthorizedDomainMemberFactWrite,
        condition: HumanHealthCondition,
        human: Human,
        values: DomainHumanHealthConditionValues,
        context: ModelContext
    ) {
        plan.consume()
        condition.humanId = human.id.uuidString
        condition.name = values.name
        condition.category = values.category
        condition.trackingStatus = values.trackingStatus
        condition.startedOn = values.startedOn
        condition.carePlan = values.carePlan
        condition.notes = values.notes
        if let linkedMedicationIDs = values.linkedMedicationIDs {
            condition.linkedMedicationIDs = linkedMedicationIDs
        }
        condition.linkedMetricKeys = values.linkedMetricKeys
        if let recordedByHumanId = values.recordedByHumanId {
            condition.recordedByHumanId = recordedByHumanId
        }
        condition.updatedAt = plan.modifiedAt
        CloudSyncMutationRecorder.markModified(condition, context: context, modifiedAt: plan.modifiedAt)
    }

    static func deleteHumanHealthCondition(
        plan: AuthorizedDomainMemberFactWrite,
        condition: HumanHealthCondition,
        observations: [HumanHealthObservation],
        context: ModelContext
    ) {
        plan.consume()
        for observation in observations {
            CloudSyncMutationRecorder.markDeleted(
                observation,
                context: context,
                deletedAt: plan.modifiedAt,
                deletedByHumanId: plan.actor.effectiveExecutorId
            )
            context.delete(observation)
        }
        CloudSyncMutationRecorder.markDeleted(
            condition,
            context: context,
            deletedAt: plan.modifiedAt,
            deletedByHumanId: plan.actor.effectiveExecutorId
        )
        context.delete(condition)
    }

    @discardableResult
    static func createHumanHealthObservation(
        plan: AuthorizedDomainMemberFactWrite,
        condition: HumanHealthCondition,
        human: Human,
        values: DomainHumanHealthObservationValues,
        context: ModelContext
    ) -> HumanHealthObservation {
        plan.consume()
        let observation = HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: condition.id.uuidString,
            recordedAt: values.recordedAt,
            severity: values.severity,
            moodScore: values.moodScore,
            sleepHours: values.sleepHours,
            symptomTags: values.symptomTags,
            possibleTriggers: values.possibleTriggers,
            careActions: values.careActions,
            medicationResponse: values.medicationResponse ?? .unknown,
            sideEffects: values.sideEffects ?? "",
            notes: values.notes,
            recordedByHumanId: values.recordedByHumanId,
            createdAt: plan.modifiedAt,
            updatedAt: plan.modifiedAt
        )
        context.insert(observation)
        CloudSyncMutationRecorder.markModified(observation, context: context, modifiedAt: plan.modifiedAt)
        return observation
    }

    static func updateHumanHealthObservation(
        plan: AuthorizedDomainMemberFactWrite,
        observation: HumanHealthObservation,
        condition: HumanHealthCondition,
        human: Human,
        values: DomainHumanHealthObservationValues,
        context: ModelContext
    ) {
        plan.consume()
        observation.humanId = human.id.uuidString
        observation.conditionId = condition.id.uuidString
        observation.recordedAt = values.recordedAt
        observation.severity = values.severity
        observation.moodScore = values.moodScore
        observation.sleepHours = values.sleepHours
        observation.symptomTags = values.symptomTags
        observation.possibleTriggers = values.possibleTriggers
        observation.careActions = values.careActions
        if let medicationResponse = values.medicationResponse {
            observation.medicationResponse = medicationResponse
        }
        if let sideEffects = values.sideEffects {
            observation.sideEffects = sideEffects
        }
        observation.notes = values.notes
        if let recordedByHumanId = values.recordedByHumanId {
            observation.recordedByHumanId = recordedByHumanId
        }
        observation.updatedAt = plan.modifiedAt
        CloudSyncMutationRecorder.markModified(observation, context: context, modifiedAt: plan.modifiedAt)
    }

    static func deleteHumanHealthObservation(
        plan: AuthorizedDomainMemberFactWrite,
        observation: HumanHealthObservation,
        context: ModelContext
    ) {
        plan.consume()
        CloudSyncMutationRecorder.markDeleted(
            observation,
            context: context,
            deletedAt: plan.modifiedAt,
            deletedByHumanId: plan.actor.effectiveExecutorId
        )
        context.delete(observation)
    }
}
