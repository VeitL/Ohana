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
        guard pet.canWriteHealthFacts else { return nil }
        let log = HeatCycleLog(
            startDate: input.startDate,
            endDate: input.endDate,
            status: input.status,
            note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
            isMated: input.isMated,
            expectedDeliveryDate: input.expectedDeliveryDate,
            pet: pet
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: input.startDate)
        context.safeSave()

        return PetHeatCycleCommandResult(
            subjectID: pet.id,
            logID: log.id,
            status: input.status
        )
    }
}
