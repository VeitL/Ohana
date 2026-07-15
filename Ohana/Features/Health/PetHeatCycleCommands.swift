//
//  PetHeatCycleCommands.swift
//  Ohana
//
//  Domain write boundaries for pet heat cycle records.
//

import Foundation
import SwiftData

struct PetHeatCycleCommandInput: Equatable {
    let startDate: Date
    let endDate: Date?
    let status: HeatCycleStatus
    let note: String
    let isMated: Bool
    let expectedDeliveryDate: Date?
    let recordedByHumanId: String?

    init(
        startDate: Date,
        endDate: Date?,
        status: HeatCycleStatus,
        note: String,
        isMated: Bool,
        expectedDeliveryDate: Date?,
        recordedByHumanId: String? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.note = note
        self.isMated = isMated
        self.expectedDeliveryDate = expectedDeliveryDate
        self.recordedByHumanId = recordedByHumanId
    }
}

struct PetHeatCycleCommandResult: Equatable {
    let subjectID: UUID
    let logID: UUID
    let status: HeatCycleStatus
}

enum PetHeatCycleCommandService {
    @discardableResult
    @MainActor
    static func recordHeatCycle(
        pet: Pet,
        input: PetHeatCycleCommandInput,
        context: ModelContext
    ) -> PetHeatCycleCommandResult? {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: input.startDate,
            writeKind: .care,
            context: context,
            logPrefix: "PetHeatCycleCommandService.recordHeatCycle"
        ) else { return nil }
        let recordedByHumanId = HumanActionAttributionPolicy.activeHumanID(
            input.recordedByHumanId,
            context: context
        )
        let log = DomainMemberFactWriter.createHeatCycleLog(
            plan: write,
            pet: pet,
            endDate: input.endDate,
            status: input.status,
            note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
            isMated: input.isMated,
            expectedDeliveryDate: input.expectedDeliveryDate,
            recordedByHumanId: recordedByHumanId,
            context: context
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return nil
        }

        return PetHeatCycleCommandResult(
            subjectID: pet.id,
            logID: log.id,
            status: input.status
        )
    }
}
