//
//  MomentCommands.swift
//  Ohana
//
//  Moment write boundary and revision publishing.
//

import Foundation
import SwiftData

struct MomentCommandResult: Equatable {
    let savedLogIDs: [UUID]
    let coconutDelta: Int
}

enum MomentCommandService {
    @discardableResult
    @MainActor
    static func recordMoment(
        pet: Pet?,
        note: String,
        photoData: [Data],
        locationLatitude: Double,
        locationLongitude: Double,
        locationPlacename: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> MomentCommandResult {
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNote.isEmpty || !photoData.isEmpty else {
            return MomentCommandResult(savedLogIDs: [], coconutDelta: 0)
        }
        let payloads = photoData.isEmpty ? [Data(count: 1)] : photoData
        let shouldSanitizePayloads = !photoData.isEmpty
        var savedLogs: [PetPhotoLog] = []
        var writes: [AuthorizedDomainMemberFactWrite] = []
        for (index, data) in payloads.enumerated() {
            let logDate = date.addingTimeInterval(Double(index) * 0.01)
            let imageData = shouldSanitizePayloads
                ? AttachmentPrivacySanitizer.sanitizedData(
                    data,
                    filename: "moment-photo-\(index).jpg",
                    isImage: true
                )
                : data
            let write = if let pet {
                DomainMemberFactWriteAuthorizer.authorizePetFact(
                    pet: pet,
                    occurredAt: logDate,
                    writeKind: .memorial,
                    executorId: executorId,
                    context: context,
                    logPrefix: "MomentCommandService.recordMoment"
                )
            } else {
                DomainMemberFactWriteAuthorizer.authorizeUnscopedFact(
                    occurredAt: logDate,
                    writeKind: .memorial,
                    executorId: executorId,
                    context: context,
                    logPrefix: "MomentCommandService.recordMoment"
                )
            }
            guard let write else { continue }
            let log = DomainMemberFactWriter.createPetPhotoLog(
                plan: write,
                imageData: imageData,
                date: logDate,
                note: cleanNote,
                pet: pet,
                locationLatitude: locationLatitude,
                locationLongitude: locationLongitude,
                locationPlacename: locationPlacename,
                context: context
            )
            savedLogs.append(log)
            writes.append(write)
        }
        guard !savedLogs.isEmpty else {
            return MomentCommandResult(savedLogIDs: [], coconutDelta: 0)
        }

        var coconutDelta = 0
        if let savedLog = savedLogs.first,
           let write = writes.first,
           write.allowsDerivedEffects {
            do {
                DomainMemberFactEffectsDispatcher.run(plan: write) { actor in
                    let reward = EconomyRewardDiscipline.awardNonCareReward(
                        type: .general(
                            humanReward: 1,
                            petReward: 0,
                            emoji: "📸",
                            title: DomainCareRewardGeneralTitle.momentCapture
                        ),
                        pet: pet,
                        context: context,
                        executorId: actor.rewardExecutorId,
                        questManager: questManager
                    )
                    coconutDelta = reward.humanGot + reward.petGot
                    careLedger.record(
                        occurredAt: savedLog.date,
                        actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                        actorId: actor.effectiveExecutorId,
                        subjectKind: pet == nil ? .system : .pet,
                        subjectId: pet?.id.uuidString,
                        eventKind: .milestone,
                        actionType: "petMoment",
                        amountValue: 0,
                        amountUnit: "",
                        note: savedLog.note,
                        source: .quickAction,
                        sourceEventId: nil,
                        sourceReminderId: nil,
                        legacyModelName: "PetPhotoLog",
                        legacyModelId: savedLog.id.uuidString,
                        coconutDelta: coconutDelta,
                        rewardLogId: nil,
                        privacyFieldRaw: nil,
                        metadataJSON: "",
                        context: context,
                        save: false
                    )
                }
                try saveMomentChanges(context: context)
            } catch {
                context.rollback()
                questManager.wallet.refreshQuestProjection(context: context, manager: questManager)
                #if DEBUG
                    OhanaLog.error("[MomentCommandService] moment reward save failed: \(error.localizedDescription)", category: "Economy")
                #endif
                return MomentCommandResult(savedLogIDs: [], coconutDelta: 0)
            }
        } else {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return MomentCommandResult(savedLogIDs: [], coconutDelta: 0)
            }
        }

        return MomentCommandResult(savedLogIDs: savedLogs.map(\.id), coconutDelta: coconutDelta)
    }

    @MainActor
    private static func saveMomentChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            throw MomentCommandPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }
}

enum MomentCommandPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "moment.command.persistence.failed",
                defaultValue: "Unable to save the moment.",
                comment: "Shown when a pet moment cannot be saved."
            )
        }
    }
}

@MainActor
struct MomentCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let careLedger: CareLedgerRecording

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            careLedger: CareLedgerService()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            careLedger: CareLedgerService()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            careLedger: services.careLedger
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        careLedger: CareLedgerRecording
    ) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
        self.careLedger = careLedger
    }

    @discardableResult
    func recordMoment(
        pet: Pet?,
        note noteText: String,
        photoData: [Data],
        locationLatitude: Double,
        locationLongitude: Double,
        locationPlacename: String,
        executorId: String?,
        date: Date = Date(),
        revisionNote: String
    ) -> MomentCommandResult {
        let result = MomentCommandService.recordMoment(
            pet: pet,
            note: noteText,
            photoData: photoData,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            locationPlacename: locationPlacename,
            context: context,
            executorId: executorId,
            date: date,
            questManager: questManager,
            careLedger: careLedger
        )
        revisions.publishQuickMoment(result, petID: pet?.id, note: revisionNote)
        return result
    }
}
