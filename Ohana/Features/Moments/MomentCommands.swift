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
        var savedLogs: [PetPhotoLog] = []
        for (index, data) in payloads.enumerated() {
            let log = PetPhotoLog(
                imageData: data,
                date: date.addingTimeInterval(Double(index) * 0.01),
                note: cleanNote,
                pet: pet,
                locationLatitude: locationLatitude,
                locationLongitude: locationLongitude,
                locationPlacename: locationPlacename
            )
            context.insert(log)
            savedLogs.append(log)
        }

        let coconutDelta = questManager.addCoconuts(
            1,
            emoji: "📸",
            title: "记录时刻 +1🥥",
            actorId: executorId,
            context: context,
            save: false
        )

        if let savedLog = savedLogs.first {
            careLedger.record(
                occurredAt: savedLog.date,
                actorKind: executorId == nil ? .unknown : .human,
                actorId: executorId,
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

        context.safeSave()

        return MomentCommandResult(savedLogIDs: savedLogs.map(\.id), coconutDelta: coconutDelta)
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
