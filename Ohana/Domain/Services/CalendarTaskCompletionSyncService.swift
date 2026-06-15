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

    private enum CalendarFactInsertDecision {
        case insert
        case activeCompleted
        case reopened
        case noOp

        var result: PetTaskSyncResult? {
            switch self {
            case .insert:
                nil
            case .activeCompleted:
                .activeCompleted
            case .reopened:
                .reopened
            case .noOp:
                .noOp
            }
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
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        economy providedEconomy: CareEventEconomyAwarding? = nil
    ) -> PetTaskSyncResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let economy = providedEconomy ?? CareEventServiceDependencies.liveEconomy()
        guard isPetTask(event: event),
              let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else { return .noOp }

        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        if let careType = careType(for: event) {
            let intent = careIntent(
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                modifiedAt: operationDate,
                executorId: executorId
            )
            guard let write = authorizeCalendarFact(pet: pet, intent: intent, context: context) else { return .noOp }
            if let result = calendarFactInsertDecision(
                event: event,
                occurrenceDate: occurrenceDate,
                pet: pet,
                isCompleted: isCompleted,
                context: context,
                economy: economy
            ).result { return result }
            guard insertCareLog(
                write: write,
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger,
                economy: economy
            ) else { return .noOp }
            return write.allowsDerivedEffects ? .activeCompleted : .noOp
        }

        if let pottyType = pottyType(for: event) {
            let intent = DomainCareFactCreateIntent(
                kind: .potty(
                    type: pottyType,
                    sharedSessionId: calendarFactOnlySessionId(for: event, occurrenceDate: occurrenceDate)
                ),
                occurredAt: occurredAt,
                modifiedAt: operationDate,
                executorId: executorId
            )
            guard let write = authorizeCalendarFact(pet: pet, intent: intent, context: context) else { return .noOp }
            if let result = calendarFactInsertDecision(
                event: event,
                occurrenceDate: occurrenceDate,
                pet: pet,
                isCompleted: isCompleted,
                context: context,
                economy: economy
            ).result { return result }
            guard insertPottyLog(
                write: write,
                pet: pet,
                event: event,
                pottyType: pottyType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger,
                economy: economy
            ) else { return .noOp }
            return write.allowsDerivedEffects ? .activeCompleted : .noOp
        }

        if let hygieneType = hygieneType(for: event) {
            let intent = DomainCareFactCreateIntent(
                kind: .hygiene(type: hygieneType, sharedSessionId: ""),
                occurredAt: occurredAt,
                modifiedAt: operationDate,
                executorId: executorId
            )
            guard let write = authorizeCalendarFact(pet: pet, intent: intent, context: context) else { return .noOp }
            if let result = calendarFactInsertDecision(
                event: event,
                occurrenceDate: occurrenceDate,
                pet: pet,
                isCompleted: isCompleted,
                context: context,
                economy: economy
            ).result { return result }
            guard insertHygieneLog(
                write: write,
                pet: pet,
                event: event,
                hygieneType: hygieneType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger,
                economy: economy
            ) else { return .noOp }
            return write.allowsDerivedEffects ? .activeCompleted : .noOp
        }
        return .noOp
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
        return calendarFactIntent(
            pet: pet,
            event: event,
            occurredAt: occurredAt,
            occurrenceDate: occurrenceDate,
            modifiedAt: occurredAt,
            executorId: executorId
        ).flatMap {
            authorizeCalendarFact(pet: pet, intent: $0, context: context)
        }?.writesFact == true
    }

    @MainActor
    static func canCompletePetTask(event: Event, occurrenceDate: Date, pets: [Pet], context: ModelContext, executorId: String?) -> Bool {
        guard isPetTask(event: event),
              let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else {
            return false
        }
        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        return calendarFactIntent(
            pet: pet,
            event: event,
            occurredAt: occurredAt,
            occurrenceDate: occurrenceDate,
            modifiedAt: occurredAt,
            executorId: executorId
        ).flatMap {
            authorizeCalendarFact(pet: pet, intent: $0, context: context)
        }?.allowsDerivedEffects == true
    }

    @MainActor
    private static func calendarFactInsertDecision(
        event: Event,
        occurrenceDate: Date,
        pet: Pet,
        isCompleted: Bool,
        context: ModelContext,
        economy: CareEventEconomyAwarding
    ) -> CalendarFactInsertDecision {
        if !isCompleted {
            deleteCalendarGeneratedRecords(event: event, occurrenceDate: occurrenceDate, context: context, economy: economy)
            deleteCalendarGeneratedFactOnlyRecords(event: event, occurrenceDate: occurrenceDate, pet: pet, context: context)
            return .reopened
        }
        if !calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context).isEmpty {
            return .activeCompleted
        }
        return calendarGeneratedFactOnlyRecords(event: event, occurrenceDate: occurrenceDate, pet: pet, context: context).isEmpty
            ? .insert
            : .noOp
    }

    @MainActor
    private static func calendarFactIntent(
        pet: Pet,
        event: Event,
        occurredAt: Date,
        occurrenceDate: Date,
        modifiedAt: Date,
        executorId: String?
    ) -> DomainCareFactCreateIntent? {
        if let careType = careType(for: event) {
            return careIntent(
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                modifiedAt: modifiedAt,
                executorId: executorId
            )
        }
        if let pottyType = pottyType(for: event) {
            return DomainCareFactCreateIntent(
                kind: .potty(
                    type: pottyType,
                    sharedSessionId: calendarFactOnlySessionId(for: event, occurrenceDate: occurrenceDate)
                ),
                occurredAt: occurredAt,
                modifiedAt: modifiedAt,
                executorId: executorId
            )
        }
        if let hygieneType = hygieneType(for: event) {
            return DomainCareFactCreateIntent(
                kind: .hygiene(type: hygieneType, sharedSessionId: ""),
                occurredAt: occurredAt,
                modifiedAt: modifiedAt,
                executorId: executorId
            )
        }
        return nil
    }

    @MainActor
    private static func careIntent(
        pet: Pet,
        event: Event,
        careType: CareType,
        occurredAt: Date,
        occurrenceDate: Date,
        modifiedAt: Date,
        executorId: String?
    ) -> DomainCareFactCreateIntent {
        let amountGrams = careType == .feeding ? feedAmount(from: event, fallback: pet.dailyPortionGrams) : 0
        let amountMl = careType == .watering ? 250.0 : 0
        return DomainCareFactCreateIntent(
            kind: .care(
                type: careType,
                amountGrams: amountGrams,
                amountMl: amountMl,
                note: noteMarker(for: event, occurrenceDate: occurrenceDate, careType: careType),
                foodKind: event.foodKind,
                treatKind: nil,
                autoFeedDedupKey: "",
                sharedSessionId: ""
            ),
            occurredAt: occurredAt,
            modifiedAt: modifiedAt,
            executorId: executorId
        )
    }

    @MainActor
    private static func authorizeCalendarFact(
        pet: Pet,
        intent: DomainCareFactCreateIntent,
        context: ModelContext
    ) -> AuthorizedDomainCareFactWrite? {
        DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "CalendarTaskCompletionSyncService.syncPetTask"
        )
    }

    @MainActor
    private static func insertCareLog(
        write: AuthorizedDomainCareFactWrite,
        pet: Pet,
        event: Event,
        careType: CareType,
        occurredAt: Date,
        occurrenceDate: Date,
        rewardDate: Date,
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        economy: CareEventEconomyAwarding
    ) -> Bool {
        let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log
        context.safeSave()
        let rewardTrace = awardGeneratedCare(
            plan: write,
            action: rewardAction(for: careType, pet: pet),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            context: context,
            economy: economy
        )
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            recordCalendarLedger(
                occurredAt: occurredAt,
                executorId: actor.effectiveExecutorId,
                pet: pet,
                event: event,
                occurrenceDate: occurrenceDate,
                sourceReminderId: sourceReminderId,
                eventKind: .care,
                actionType: careType.rawValue,
                amountValue: log.careType == .feeding ? log.amountGrams : log.amountMl,
                amountUnit: log.careType == .feeding ? "g" : (log.careType == .watering ? "ml" : ""),
                legacyModelName: "PetCareLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: rewardTrace.coconutDelta,
                metadataJSON: rewardTrace.metadataJSON,
                context: context,
                careLedger: careLedger
            )
        }
        return true
    }

    @MainActor
    private static func insertPottyLog(
        write: AuthorizedDomainCareFactWrite,
        pet: Pet,
        event: Event,
        pottyType: PottyType,
        occurredAt: Date,
        occurrenceDate: Date,
        rewardDate: Date,
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        economy: CareEventEconomyAwarding
    ) -> Bool {
        let log = DomainCareFactWriter.createPottyLog(plan: write, context: context)
        context.safeSave()
        let rewardTrace = awardGeneratedCare(
            plan: write,
            action: .potty(isLitter: false),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            context: context,
            economy: economy
        )
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            recordCalendarLedger(
                occurredAt: occurredAt,
                executorId: actor.effectiveExecutorId,
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
        }
        return true
    }

    @MainActor
    private static func insertHygieneLog(
        write: AuthorizedDomainCareFactWrite,
        pet: Pet,
        event: Event,
        hygieneType: HygieneType,
        occurredAt: Date,
        occurrenceDate: Date,
        rewardDate: Date,
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        economy: CareEventEconomyAwarding
    ) -> Bool {
        let log = DomainCareFactWriter.createHygieneLog(plan: write, context: context)
        context.safeSave()
        let rewardTrace = awardGeneratedCare(
            plan: write,
            action: .care(type: hygieneType),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            context: context,
            economy: economy
        )
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            recordCalendarLedger(
                occurredAt: occurredAt,
                executorId: actor.effectiveExecutorId,
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
        }
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
    private static func deleteCalendarGeneratedRecords(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext,
        economy: CareEventEconomyAwarding
    ) {
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
            clearCooldown(for: ledger, context: context, economy: economy)
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
        plan: AuthorizedDomainCareFactWrite,
        action: DomainCareRewardAction,
        pet: Pet,
        occurrenceDate: Date,
        rewardDate: Date,
        context: ModelContext,
        economy: CareEventEconomyAwarding
    ) -> GeneratedRewardTrace {
        DomainCareFactEffectsDispatcher.map(
            plan: plan,
            default: GeneratedRewardTrace(
                reward: (0, 0),
                walletEntries: [],
                budgetEvents: [],
                metadataJSON: occurrenceMetadata(for: occurrenceDate)
            )
        ) { actor in
            let walletBefore = Set(fetchOrLog(FetchDescriptor<CoconutLedgerEntry>(), context: context, operation: "fetch wallet entries before calendar reward").map(\.id))
            let budgetBefore = Set(fetchOrLog(FetchDescriptor<EconomyBudgetUsageEvent>(), context: context, operation: "fetch budget events before calendar reward").map(\.id))
            let reward = economy.awardCareAction(
                type: action,
                pet: pet,
                context: context,
                quality: .none,
                date: rewardDate,
                executorId: actor.rewardExecutorId
            )
            let walletEntries = fetchOrLog(FetchDescriptor<CoconutLedgerEntry>(), context: context, operation: "fetch wallet entries after calendar reward")
                .filter { !walletBefore.contains($0.id) }
            let budgetEvents = fetchOrLog(FetchDescriptor<EconomyBudgetUsageEvent>(), context: context, operation: "fetch budget events after calendar reward")
                .filter { !budgetBefore.contains($0.id) }
            let metadataJSON = generatedMetadata(
                occurrenceDate: occurrenceDate,
                rewardMetadata: economy.rewardMetadata(for: reward),
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
    private static func clearCooldown(for ledger: CareLedgerEvent, context: ModelContext, economy: CareEventEconomyAwarding) {
        guard let petId = ledger.subjectId.flatMap(UUID.init(uuidString:)),
              let action = rewardAction(legacyModelName: ledger.legacyModelName, actionType: ledger.actionType, petName: pet(id: petId, context: context)?.name) else {
            return
        }
        economy.clearCooldown(petId: petId, type: action)
    }
}
