//
//  SharedPetActionRecorderSupport.swift
//  Ohana
//
//  Small value bundles and focused collaborators used by shared-pet writes.
//

import Foundation
import SwiftData

struct SharedPetRecordedFacts {
    let careLogs: [(Pet, PetCareLog)]
    let pottyLogs: [(Pet, PetPottyLog)]
    let pottyLog: PetPottyLog?
    let hygieneLogs: [(Pet, PetHygieneLog)]
    let expenseLogs: [(Pet, PetExpenseLog)]
    let walkLogs: [(Pet, PetWalkLog)]

    var hasFacts: Bool {
        !careLogs.isEmpty || !pottyLogs.isEmpty || pottyLog != nil ||
            !hygieneLogs.isEmpty || !expenseLogs.isEmpty || !walkLogs.isEmpty
    }

    func writtenTargets(sourcePet: Pet) -> [Pet] {
        var result: [Pet] = []
        func append(_ pet: Pet) {
            guard !result.contains(where: { $0.id == pet.id }) else { return }
            result.append(pet)
        }

        careLogs.map(\.0).forEach(append)
        pottyLogs.map(\.0).forEach(append)
        hygieneLogs.map(\.0).forEach(append)
        expenseLogs.map(\.0).forEach(append)
        walkLogs.map(\.0).forEach(append)
        if pottyLog != nil {
            append(sourcePet)
        }
        return result
    }

    func ledgerFacts(targets: [Pet]) -> SharedPetLedgerRecordFacts {
        SharedPetLedgerRecordFacts(
            targets: targets,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            pottyLog: pottyLog,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )
    }
}

struct SharedPetLedgerRecordFacts {
    let targets: [Pet]
    let careLogs: [(Pet, PetCareLog)]
    let pottyLogs: [(Pet, PetPottyLog)]
    let pottyLog: PetPottyLog?
    let hygieneLogs: [(Pet, PetHygieneLog)]
    let expenseLogs: [(Pet, PetExpenseLog)]
    let walkLogs: [(Pet, PetWalkLog)]
}

@MainActor
enum SharedCareSessionStager {
    static func stage(
        _ session: SharedCareSession,
        descriptor: SharedPetActionDescriptor,
        sessionTargets: [Pet],
        writtenTargets: [Pet],
        facts: SharedPetRecordedFacts,
        context: ModelContext
    ) {
        session.sourcePetId = writtenTargets.first(where: { $0.id == descriptor.sourcePet.id })?.id.uuidString
            ?? writtenTargets.first?.id.uuidString
            ?? descriptor.sourcePet.id.uuidString
        session.targetPetIdsRaw = sessionTargets.map(\.id.uuidString).joined(separator: "|")
        session.speciesRaw = sessionTargets.first?.species ?? descriptor.sourcePet.species
        context.insert(session)
        if let primary = primaryLegacyModel(facts: facts) {
            session.primaryLegacyModelName = primary.name
            session.primaryLegacyModelId = primary.id
        }
        CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: descriptor.date)
    }

    private static func primaryLegacyModel(
        facts: SharedPetRecordedFacts
    ) -> (name: String, id: String)? {
        if let log = facts.careLogs.first?.1 { return ("PetCareLog", log.id.uuidString) }
        if let log = facts.pottyLogs.first?.1 { return ("PetPottyLog", log.id.uuidString) }
        if let pottyLog = facts.pottyLog { return ("PetPottyLog", pottyLog.id.uuidString) }
        if let log = facts.hygieneLogs.first?.1 { return ("PetHygieneLog", log.id.uuidString) }
        if let log = facts.expenseLogs.first?.1 { return ("PetExpenseLog", log.id.uuidString) }
        if let log = facts.walkLogs.first?.1 { return ("PetWalkLog", log.id.uuidString) }
        return nil
    }
}

struct SharedPetActionRevisionInput {
    let descriptor: SharedPetActionDescriptor
    let session: SharedCareSession
    let targets: [Pet]
    let careLogs: [PetCareLog]
    let pottyLogs: [PetPottyLog]
    let pottyLog: PetPottyLog?
    let hygieneLogs: [PetHygieneLog]
    let expenseLogs: [PetExpenseLog]
    let walkLogs: [PetWalkLog]
    let reward: (humanGot: Int, petGot: Int)
}

@MainActor
enum SharedCareRevisionDeriver {
    static func derive(
        _ input: SharedPetActionRevisionInput,
        derivations: CareDerivationExecutor
    ) {
        var affected = Set(input.targets.map(\.id))
        affected.insert(input.session.id)
        input.careLogs.forEach { affected.insert($0.id) }
        input.pottyLogs.forEach { affected.insert($0.id) }
        if let pottyLog = input.pottyLog { affected.insert(pottyLog.id) }
        input.hygieneLogs.forEach { affected.insert($0.id) }
        input.expenseLogs.forEach { affected.insert($0.id) }
        input.walkLogs.forEach { affected.insert($0.id) }
        derivations.derive(
            .active(
                disposition: .active,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: input.descriptor.sourcePet.id,
                    logIDs: Array(affected),
                    factDate: input.descriptor.date,
                    operationDate: input.descriptor.date
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: .quickCare(
                        entityID: input.descriptor.sourcePet.id,
                        action: "shared.\(input.descriptor.actionKind.rawValue)"
                    ),
                    affectedEntityIDs: affected,
                    note: "sharedPetAction.\(input.descriptor.actionKind.rawValue)"
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: input.reward.humanGot,
                    petDelta: input.reward.petGot
                ),
                sharedSession: CareWriteOutcome.SharedSessionPayload(
                    sessionID: input.session.id,
                    sourcePetID: input.descriptor.sourcePet.id,
                    targetPetIDs: input.targets.map(\.id)
                )
            )
        )
    }
}
