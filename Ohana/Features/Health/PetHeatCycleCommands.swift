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
        let log = DomainMemberFactWriter.createHeatCycleLog(
            plan: write,
            pet: pet,
            endDate: input.endDate,
            status: input.status,
            note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
            isMated: input.isMated,
            expectedDeliveryDate: input.expectedDeliveryDate,
            context: context
        )
        context.safeSave()

        return PetHeatCycleCommandResult(
            subjectID: pet.id,
            logID: log.id,
            status: input.status
        )
    }
}
