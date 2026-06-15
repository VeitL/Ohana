//
//  CalendarTaskCompletionSyncService.swift
//  Ohana
//

import Foundation
import SwiftData

enum CalendarTaskCompletionSyncService {
    private static let calendarSource = CareLedgerSource.calendar.rawValue

    enum PetTaskSyncResult: Equatable {
        case noOp
        case activeCompleted
        case reopened

        var shouldCompleteOccurrence: Bool {
            self == .activeCompleted
        }

        var didWriteFact: Bool {
            switch self {
            case .activeCompleted, .reopened:
                true
            case .noOp:
                false
            }
        }

        var allowsDerivedEffects: Bool {
            switch self {
            case .activeCompleted, .reopened:
                true
            case .noOp:
                false
            }
        }
    }

    struct GeneratedRewardTrace {
        let reward: (humanGot: Int, petGot: Int)
        let walletEntries: [CoconutLedgerEntry]
        let budgetEvents: [EconomyBudgetUsageEvent]
        let metadataJSON: String

        var coconutDelta: Int {
            max(0, reward.humanGot) + max(0, reward.petGot)
        }
    }

    struct CalendarGeneratedFactOnlyRecords {
        var careLogs: [PetCareLog] = []
        var pottyLogs: [PetPottyLog] = []
        var hygieneLogs: [PetHygieneLog] = []

        var isEmpty: Bool {
            careLogs.isEmpty && pottyLogs.isEmpty && hygieneLogs.isEmpty
        }
    }

    @MainActor
    static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "CalendarTaskCompletionSyncService failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    @discardableResult
    static func syncPetTask(
        event: Event,
        occurrenceDate: Date,
        isCompleted: Bool,
        pets: [Pet],
        context: ModelContext,
        executorId: String?,
        operationDate: Date = Date(),
        sourceReminderId: String? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> PetTaskSyncResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        guard isPetTask(event: event),
              let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else { return .noOp }

        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: occurredAt,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else { return .noOp }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "CalendarTaskCompletionSyncService.syncPetTask"
        )
        if !isCompleted {
            deleteCalendarGeneratedRecords(event: event, occurrenceDate: occurrenceDate, context: context)
            deleteCalendarGeneratedFactOnlyRecords(event: event, occurrenceDate: occurrenceDate, pet: pet, context: context)
            return .reopened
        }
        if !calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context).isEmpty {
            return .activeCompleted
        }
        guard calendarGeneratedFactOnlyRecords(event: event, occurrenceDate: occurrenceDate, pet: pet, context: context).isEmpty else { return .noOp }

        let didInsert: Bool = if let careType = careType(for: event) {
            insertCareLog(
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                executorId: actor.effectiveExecutorId,
                rewardExecutorId: actor.rewardExecutorId,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger,
                disposition: disposition
            )
        } else if let pottyType = pottyType(for: event) {
            insertPottyLog(
                pet: pet,
                event: event,
                pottyType: pottyType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                executorId: actor.effectiveExecutorId,
                rewardExecutorId: actor.rewardExecutorId,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger,
                disposition: disposition
            )
        } else if let hygieneType = hygieneType(for: event) {
            insertHygieneLog(
                pet: pet,
                event: event,
                hygieneType: hygieneType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                executorId: actor.effectiveExecutorId,
                rewardExecutorId: actor.rewardExecutorId,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger,
                disposition: disposition
            )
        } else {
            false
        }
        guard didInsert else { return .noOp }
        return disposition.allowsDerivedEffects ? .activeCompleted : .noOp
    }

    static func isPetTask(event: Event) -> Bool {
        careType(for: event) != nil || pottyType(for: event) != nil || hygieneType(for: event) != nil
    }

    @MainActor
    static func canWritePetTaskFact(event: Event, occurrenceDate: Date, pets: [Pet], context: ModelContext, executorId: String?) -> Bool {
        guard isPetTask(event: event),
              let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else {
            return false
        }
        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        return CareFactWritePolicy.disposition(
            pet: pet,
            date: occurredAt,
            executorId: executorId,
            context: context
        ).writesFact
    }

    @MainActor
    static func canCompletePetTask(event: Event, occurrenceDate: Date, pets: [Pet], context: ModelContext, executorId: String?) -> Bool {
        guard isPetTask(event: event),
              let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else {
            return false
        }
        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        return CareFactWritePolicy.disposition(
            pet: pet,
            date: occurredAt,
            executorId: executorId,
            context: context
        ).allowsDerivedEffects
    }

    @MainActor
    private static func insertCareLog(
        pet: Pet,
        event: Event,
        careType: CareType,
        occurredAt: Date,
        occurrenceDate: Date,
        rewardDate: Date,
        executorId: String?,
        rewardExecutorId: String?,
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        disposition: CareFactWriteDisposition
    ) -> Bool {
        let amountGrams = careType == .feeding ? feedAmount(from: event, fallback: pet.dailyPortionGrams) : 0
        let amountMl = careType == .watering ? 250.0 : 0
        let log = PetCareLog(
            date: occurredAt,
            type: careType,
            amountGrams: amountGrams,
            amountMl: amountMl,
            note: noteMarker(for: event, occurrenceDate: occurrenceDate, careType: careType),
            foodKind: event.foodKind,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: rewardDate)
        context.safeSave()
        guard disposition.allowsDerivedEffects else { return true }
        let rewardTrace = awardGeneratedCare(
            action: rewardAction(for: careType, pet: pet),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            executorId: rewardExecutorId,
            context: context,
            careLedger: careLedger
        )
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            sourceReminderId: sourceReminderId,
            eventKind: .care,
            actionType: careType.rawValue,
            amountValue: careType == .feeding ? amountGrams : amountMl,
            amountUnit: careType == .feeding ? "g" : (careType == .watering ? "ml" : ""),
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: rewardTrace.coconutDelta,
            metadataJSON: rewardTrace.metadataJSON,
            context: context,
            careLedger: careLedger
        )
        return true
    }

    @MainActor
    private static func insertPottyLog(
        pet: Pet,
        event: Event,
        pottyType: PottyType,
        occurredAt: Date,
        occurrenceDate: Date,
        rewardDate: Date,
        executorId: String?,
        rewardExecutorId: String?,
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        disposition: CareFactWriteDisposition
    ) -> Bool {
        let log = PetPottyLog(
            date: occurredAt,
            type: pottyType,
            pet: pet,
            executorId: executorId,
            sharedSessionId: calendarFactOnlySessionId(for: event, occurrenceDate: occurrenceDate)
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: rewardDate)
        context.safeSave()
        guard disposition.allowsDerivedEffects else { return true }
        let rewardTrace = awardGeneratedCare(
            action: .potty(isLitter: false),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            executorId: rewardExecutorId,
            context: context,
            careLedger: careLedger
        )
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            sourceReminderId: sourceReminderId,
            eventKind: .potty,
            actionType: pottyType.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: rewardTrace.coconutDelta,
            metadataJSON: rewardTrace.metadataJSON,
            context: context,
            careLedger: careLedger
        )
        return true
    }

    @MainActor
    private static func insertHygieneLog(
        pet: Pet,
        event: Event,
        hygieneType: HygieneType,
        occurredAt: Date,
        occurrenceDate: Date,
        rewardDate: Date,
        executorId: String?,
        rewardExecutorId: String?,
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        disposition: CareFactWriteDisposition
    ) -> Bool {
        let log = PetHygieneLog(date: occurredAt, type: hygieneType, pet: pet, executorId: executorId)
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: rewardDate)
        context.safeSave()
        guard disposition.allowsDerivedEffects else { return true }
        let rewardTrace = awardGeneratedCare(
            action: .care(type: hygieneType),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            executorId: rewardExecutorId,
            context: context,
            careLedger: careLedger
        )
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            sourceReminderId: sourceReminderId,
            eventKind: .hygiene,
            actionType: hygieneType.rawValue,
            legacyModelName: "PetHygieneLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: rewardTrace.coconutDelta,
            metadataJSON: rewardTrace.metadataJSON,
            context: context,
            careLedger: careLedger
        )
        return true
    }

    @MainActor
    private static func recordCalendarLedger(
        occurredAt: Date,
        executorId: String?,
        pet: Pet,
        event: Event,
        occurrenceDate: Date,
        sourceReminderId: String?,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double = 0,
        amountUnit: String = "",
        legacyModelName: String,
        legacyModelId: String,
        coconutDelta: Int,
        metadataJSON: String,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        careLedger.record(
            occurredAt: occurredAt,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: eventKind,
            actionType: actionType,
            amountValue: amountValue,
            amountUnit: amountUnit,
            note: event.title,
            source: .calendar,
            sourceEventId: event.id.uuidString,
            sourceReminderId: sourceReminderId,
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            coconutDelta: coconutDelta,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: true
        )
    }

    @MainActor
    private static func deleteCalendarGeneratedRecords(event: Event, occurrenceDate: Date, context: ModelContext) {
        let ledgers = calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context)
        for ledger in ledgers {
            reverseWalletEntries(
                ids: uuidArray(named: "walletEntryIds", in: ledger.metadataJSON),
                context: context,
                occurredAt: Date()
            )
            tombstoneAndDeleteBudgetUsages(
                ids: uuidArray(named: "budgetUsageIds", in: ledger.metadataJSON),
                context: context,
                deletedAt: Date(),
                deletedByHumanId: ledger.actorId
            )
            clearCooldown(for: ledger, context: context)
            deleteLegacyModel(name: ledger.legacyModelName, idString: ledger.legacyModelId, context: context)
            CloudSyncMutationRecorder.markDeleted(ledger, context: context)
            context.delete(ledger)
        }
        if !ledgers.isEmpty { context.safeSave() }
    }

    @MainActor
    private static func deleteCalendarGeneratedFactOnlyRecords(
        event: Event,
        occurrenceDate: Date,
        pet: Pet,
        context: ModelContext
    ) {
        let records = calendarGeneratedFactOnlyRecords(
            event: event,
            occurrenceDate: occurrenceDate,
            pet: pet,
            context: context
        )
        for model in records.careLogs {
            CloudSyncMutationRecorder.markDeleted(model, pet: model.pet, context: context)
            context.delete(model)
        }
        for model in records.pottyLogs {
            CloudSyncMutationRecorder.markDeleted(model, pet: model.pet, context: context)
            context.delete(model)
        }
        for model in records.hygieneLogs {
            CloudSyncMutationRecorder.markDeleted(model, pet: model.pet, context: context)
            context.delete(model)
        }
        if !records.isEmpty { context.safeSave() }
    }

    @MainActor
    private static func deleteLegacyModel(name: String?, idString: String?, context: ModelContext) {
        guard let name, let idString, let id = UUID(uuidString: idString) else { return }
        switch name {
        case "PetCareLog":
            var descriptor = FetchDescriptor<PetCareLog>(predicate: #Predicate<PetCareLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = fetchOrLog(descriptor, context: context, operation: "fetch generated pet care log").first {
                CloudSyncMutationRecorder.markDeleted(model, pet: model.pet, context: context)
                context.delete(model)
            }
        case "PetPottyLog":
            var descriptor = FetchDescriptor<PetPottyLog>(predicate: #Predicate<PetPottyLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = fetchOrLog(descriptor, context: context, operation: "fetch generated pet potty log").first {
                CloudSyncMutationRecorder.markDeleted(model, pet: model.pet, context: context)
                context.delete(model)
            }
        case "PetHygieneLog":
            var descriptor = FetchDescriptor<PetHygieneLog>(predicate: #Predicate<PetHygieneLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = fetchOrLog(descriptor, context: context, operation: "fetch generated pet hygiene log").first {
                CloudSyncMutationRecorder.markDeleted(model, pet: model.pet, context: context)
                context.delete(model)
            }
        default:
            return
        }
    }

    @MainActor
    private static func calendarLedgerEntries(event: Event, occurrenceDate: Date, context: ModelContext) -> [CareLedgerEvent] {
        let eventId = event.id.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.sourceEventId == eventId }
        )
        descriptor.fetchLimit = 20
        let key = occurrenceKey(for: occurrenceDate)
        return fetchOrLog(descriptor, context: context, operation: "fetch calendar ledger entries").filter {
            $0.source == calendarSource && $0.metadataJSON.contains("\"occurrence\":\"\(key)\"")
        }
    }

    @MainActor
    private static func calendarGeneratedFactOnlyRecords(
        event: Event,
        occurrenceDate: Date,
        pet: Pet,
        context: ModelContext
    ) -> CalendarGeneratedFactOnlyRecords {
        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        if let careType = careType(for: event) {
            let marker = noteMarker(for: event, occurrenceDate: occurrenceDate, careType: careType)
            let logs = fetchOrLog(
                FetchDescriptor<PetCareLog>(),
                context: context,
                operation: "fetch calendar fact-only care logs"
            ).filter {
                $0.pet?.id == pet.id
                    && $0.careType == careType
                    && $0.note == marker
                    && sameTimestamp($0.date, occurredAt)
            }
            return CalendarGeneratedFactOnlyRecords(careLogs: logs)
        }

        if let pottyType = pottyType(for: event) {
            let marker = calendarFactOnlySessionId(for: event, occurrenceDate: occurrenceDate)
            let logs = fetchOrLog(
                FetchDescriptor<PetPottyLog>(),
                context: context,
                operation: "fetch calendar fact-only potty logs"
            ).filter {
                $0.pet?.id == pet.id
                    && $0.pottyType == pottyType
                    && ($0.sharedSessionId == marker || ($0.sharedSessionId.isEmpty && $0.walkLogId == nil))
                    && sameTimestamp($0.date, occurredAt)
            }
            return CalendarGeneratedFactOnlyRecords(pottyLogs: logs)
        }

        if let hygieneType = hygieneType(for: event) {
            let logs = fetchOrLog(
                FetchDescriptor<PetHygieneLog>(),
                context: context,
                operation: "fetch calendar fact-only hygiene logs"
            ).filter {
                $0.pet?.id == pet.id
                    && $0.hygieneType == hygieneType
                    && sameTimestamp($0.date, occurredAt)
            }
            return CalendarGeneratedFactOnlyRecords(hygieneLogs: logs)
        }

        return CalendarGeneratedFactOnlyRecords()
    }

    @MainActor
    private static func awardGeneratedCare(
        action: QuestManager.OhanaActionType,
        pet: Pet,
        occurrenceDate: Date,
        rewardDate: Date,
        executorId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) -> GeneratedRewardTrace {
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: rewardDate,
            executorId: executorId,
            context: context
        )
        guard disposition.allowsDerivedEffects else {
            return GeneratedRewardTrace(
                reward: (0, 0),
                walletEntries: [],
                budgetEvents: [],
                metadataJSON: occurrenceMetadata(for: occurrenceDate)
            )
        }
        let walletBefore = Set(fetchOrLog(FetchDescriptor<CoconutLedgerEntry>(), context: context, operation: "fetch wallet entries before calendar reward").map(\.id))
        let budgetBefore = Set(fetchOrLog(FetchDescriptor<EconomyBudgetUsageEvent>(), context: context, operation: "fetch budget events before calendar reward").map(\.id))
        let questManager = QuestManager()
        let reward = EconomyRewardDiscipline.awardCareAction(
            type: action,
            pet: pet,
            context: context,
            date: rewardDate,
            executorId: executorId,
            questManager: questManager
        )
        let walletEntries = fetchOrLog(FetchDescriptor<CoconutLedgerEntry>(), context: context, operation: "fetch wallet entries after calendar reward")
            .filter { !walletBefore.contains($0.id) }
        let budgetEvents = fetchOrLog(FetchDescriptor<EconomyBudgetUsageEvent>(), context: context, operation: "fetch budget events after calendar reward")
            .filter { !budgetBefore.contains($0.id) }
        let metadataJSON = generatedMetadata(
            occurrenceDate: occurrenceDate,
            rewardMetadata: careLedger.rewardMetadata(reward, questManager: questManager),
            walletEntries: walletEntries,
            budgetEvents: budgetEvents
        )
        return GeneratedRewardTrace(
            reward: reward,
            walletEntries: walletEntries,
            budgetEvents: budgetEvents,
            metadataJSON: metadataJSON
        )
    }

    @MainActor
    private static func reverseWalletEntries(ids: [UUID], context: ModelContext, occurredAt: Date) {
        let originals = walletEntries(ids: ids, context: context).filter { $0.affectsBalance && $0.delta > 0 }
        let deltas = originals.compactMap { entry -> CoconutWalletDelta? in
            let transactionKey = "calendarCareUndo:\(entry.transactionKey)"
            guard !hasWalletEntry(transactionKey: transactionKey, context: context) else { return nil }
            let ownerKind = entry.ownerKind
            return CoconutWalletDelta(
                accountKey: entry.accountKey,
                ownerKind: ownerKind,
                ownerId: entry.ownerId,
                ownerName: entry.ownerName,
                cachedBalance: entry.balanceAfter,
                delta: -entry.delta,
                entryKind: .adjustment,
                source: .careEvent,
                title: "撤销 \(entry.title)",
                emoji: "↩️",
                actorId: entry.actorId,
                actorName: entry.actorName,
                subjectKind: CareLedgerSubjectKind(rawValue: entry.subjectKindRaw) ?? .unknown,
                subjectId: entry.subjectId,
                sourceModelName: "CalendarCareUndo",
                sourceModelId: entry.id.uuidString,
                metadataJSON: reversalMetadata(for: entry),
                occurredAt: occurredAt,
                transactionKey: transactionKey,
                human: ownerKind == .human ? human(idString: entry.ownerId, context: context) : nil,
                pet: ownerKind == .pet ? pet(idString: entry.ownerId, context: context) : nil
            )
        }
        guard !deltas.isEmpty else { return }
        do {
            try CoconutWalletService.apply(deltas: deltas, context: context, save: false, postsRewardFeedback: false, updatesProjection: true)
        } catch {
            OhanaLog.warning("CalendarTaskCompletionSyncService failed to reverse wallet entries: \(error.localizedDescription)", category: "Economy")
        }
    }

    @MainActor
    private static func tombstoneAndDeleteBudgetUsages(
        ids: [UUID],
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        for event in budgetUsageEvents(ids: ids, context: context) {
            CloudSyncMutationRecorder.markDeleted(event, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(event)
        }
    }

    @MainActor
    private static func clearCooldown(for ledger: CareLedgerEvent, context: ModelContext) {
        guard let petId = ledger.subjectId.flatMap(UUID.init(uuidString:)),
              let action = rewardAction(legacyModelName: ledger.legacyModelName, actionType: ledger.actionType, petName: pet(id: petId, context: context)?.name) else {
            return
        }
        QuestManager().clearCooldown(petId: petId, type: action)
    }
}
