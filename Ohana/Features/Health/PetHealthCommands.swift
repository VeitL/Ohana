//
//  PetHealthCommands.swift
//  Ohana
//
//  Domain write boundaries for pet health, symptoms, and health-history deletion.
//

import Foundation
import SwiftData

struct PetHealthRecordCommandInput: Equatable {
    let type: HealthLogType
    let date: Date
    let name: String
    let note: String
    let vetName: String
    let cost: Double
    let expirationDate: Date?
    let nextCheckupDate: Date?
    let executorId: String?
    let source: CareLedgerSource
    let includesNameInNote: Bool
    let expirationReminderLeadDays: Int?

    init(
        type: HealthLogType,
        date: Date,
        name: String,
        note: String,
        vetName: String,
        cost: Double,
        expirationDate: Date?,
        nextCheckupDate: Date?,
        executorId: String?,
        source: CareLedgerSource,
        includesNameInNote: Bool,
        expirationReminderLeadDays: Int? = nil
    ) {
        self.type = type
        self.date = date
        self.name = name
        self.note = note
        self.vetName = vetName
        self.cost = max(0, cost.isFinite ? cost : 0)
        self.expirationDate = expirationDate
        self.nextCheckupDate = nextCheckupDate
        self.executorId = executorId
        self.source = source
        self.includesNameInNote = includesNameInNote
        self.expirationReminderLeadDays = expirationReminderLeadDays.map { max(0, $0) }
    }

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var composedNote: String {
        guard includesNameInNote else { return cleanNote }
        guard !cleanName.isEmpty else { return cleanNote }
        return cleanNote.isEmpty ? cleanName : "\(cleanName) - \(cleanNote)"
    }

    var recordName: String {
        cleanName.isEmpty ? type.rawValue : cleanName
    }
}

struct PetHealthCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let expenseLogID: UUID?
    let eventID: UUID?
    let reminderID: UUID?
    let coconutDelta: Int
    let didRecord: Bool
    let allowsDerivedEffects: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?

    init(
        logID: UUID,
        subjectID: UUID,
        expenseLogID: UUID?,
        eventID: UUID?,
        reminderID: UUID?,
        coconutDelta: Int,
        didRecord: Bool = true,
        allowsDerivedEffects: Bool = true,
        didPersist: Bool = true,
        persistenceErrorDescription: String? = nil
    ) {
        self.logID = logID
        self.subjectID = subjectID
        self.expenseLogID = expenseLogID
        self.eventID = eventID
        self.reminderID = reminderID
        self.coconutDelta = coconutDelta
        self.didRecord = didRecord
        self.allowsDerivedEffects = allowsDerivedEffects
        self.didPersist = didPersist
        self.persistenceErrorDescription = persistenceErrorDescription
    }
}

enum PetHealthCommandService {
    @discardableResult
    @MainActor
    static func recordHealth(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext,
        awardsReward: Bool = true,
        schedulesReminderNotification: Bool = true,
        questManager: QuestManager,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil,
        oasisRewards providedOasisRewards: OasisRewardManaging? = nil
    ) -> PetHealthCommandResult? {
        let intent = DomainCareFactCreateIntent(
            kind: .health(type: input.type, note: input.composedNote),
            occurredAt: input.date,
            executorId: input.executorId,
            source: .userCommand
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "PetHealthCommandService.recordHealth"
        ) else { return nil }
        let careLedger = providedCareLedger ?? CareLedgerService()
        let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
        let oasisRewards = providedOasisRewards ?? StaticOasisRewardManager(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        )
        let log = DomainCareFactWriter.createHealthLog(plan: write, context: context)
        log.vetName = input.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        log.cost = input.cost
        log.expirationDate = input.expirationDate
        log.nextCheckupDate = input.nextCheckupDate
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: input.date)

        guard write.allowsDerivedEffects else {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return PetHealthCommandResult(
                    logID: log.id,
                    subjectID: pet.id,
                    expenseLogID: nil,
                    eventID: nil,
                    reminderID: nil,
                    coconutDelta: 0,
                    didRecord: false,
                    allowsDerivedEffects: false,
                    didPersist: false,
                    persistenceErrorDescription: saveResult.errorDescription
                )
            }
            return PetHealthCommandResult(
                logID: log.id,
                subjectID: pet.id,
                expenseLogID: nil,
                eventID: nil,
                reminderID: nil,
                coconutDelta: 0,
                allowsDerivedEffects: false
            )
        }

        var expenseWrite: (expense: PetExpenseLog, write: AuthorizedDomainCareFactWrite)?
        var event: Event?
        var reminder: Reminder?
        var coconutDelta = 0
        var rewardMetadataJSON = ""

        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            expenseWrite = makeExpenseIfNeeded(
                pet: pet,
                input: input,
                actor: actor,
                context: context
            )
            let expirationSchedule = makeExpirationScheduleIfNeeded(
                pet: pet,
                input: input,
                context: context
            )
            event = expirationSchedule?.event
            reminder = expirationSchedule?.reminder

            let reward: (humanGot: Int, petGot: Int)
            if awardsReward {
                reward = EconomyRewardDiscipline.awardCareAction(
                    type: .health,
                    pet: pet,
                    context: context,
                    executorId: actor.rewardExecutorId,
                    questManager: questManager
                )
                oasisRewards.rewardFeaturedCritterFromCare(type: .health, context: context)
            } else {
                reward = (humanGot: 0, petGot: 0)
            }
            coconutDelta = careLedger.rewardDelta(reward)
            rewardMetadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)

            careLedger.record(
                occurredAt: log.date,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .health,
                actionType: input.type.rawValue,
                amountValue: input.cost,
                amountUnit: input.cost > 0 ? "currency" : "",
                note: log.note,
                source: input.source,
                sourceEventId: event?.id.uuidString,
                sourceReminderId: nil,
                legacyModelName: "PetHealthLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: coconutDelta,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: rewardMetadataJSON,
                context: context,
                save: false
            )

            if let expenseWrite {
                let expense = expenseWrite.expense
                DomainCareFactEffectsDispatcher.run(plan: expenseWrite.write) { expenseActor in
                    careLedger.record(
                        occurredAt: expense.date,
                        actorKind: expenseActor.effectiveExecutorId == nil ? .unknown : .human,
                        actorId: expenseActor.effectiveExecutorId,
                        subjectKind: .pet,
                        subjectId: pet.id.uuidString,
                        eventKind: .expense,
                        actionType: ExpenseCategory.medical.rawValue,
                        amountValue: expense.amount,
                        amountUnit: "currency",
                        note: expense.note,
                        source: input.source,
                        sourceEventId: nil,
                        sourceReminderId: nil,
                        legacyModelName: "PetExpenseLog",
                        legacyModelId: expense.id.uuidString,
                        coconutDelta: 0,
                        rewardLogId: nil,
                        privacyFieldRaw: nil,
                        metadataJSON: "",
                        context: context,
                        save: false
                    )
                }
            }

            careLedger.syncLedgerEnergyIfNeeded(metadataJSON: rewardMetadataJSON, context: context)
        }

        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetHealthCommandResult(
                logID: log.id,
                subjectID: pet.id,
                expenseLogID: nil,
                eventID: nil,
                reminderID: nil,
                coconutDelta: 0,
                didRecord: false,
                allowsDerivedEffects: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        if schedulesReminderNotification, let reminder {
            Task { @MainActor in
                await reminderScheduling.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: input.source,
                    existingNotificationIds: nil,
                    operation: "schedule",
                    saveLedger: true
                )
            }
        }
        return PetHealthCommandResult(
            logID: log.id,
            subjectID: pet.id,
            expenseLogID: expenseWrite?.expense.id,
            eventID: event?.id,
            reminderID: reminder?.id,
            coconutDelta: coconutDelta,
            allowsDerivedEffects: true
        )
    }

    @MainActor
    private static func makeExpenseIfNeeded(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        actor: EconomyRewardOwnerResolution,
        context: ModelContext
    ) -> (expense: PetExpenseLog, write: AuthorizedDomainCareFactWrite)? {
        guard input.cost > 0 else { return nil }
        let intent = DomainCareFactCreateIntent(
            kind: .expense(
                amount: input.cost,
                category: .medical,
                note: input.recordName,
                sharedSessionId: ""
            ),
            occurredAt: input.date,
            executorId: input.executorId,
            source: .userCommand
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "PetHealthCommandService.recordHealth.expense",
            actorOverride: actor
        ) else { return nil }
        return (
            expense: DomainCareFactWriter.createExpenseLog(plan: write, context: context),
            write: write
        )
    }

    @MainActor
    private static func makeExpirationScheduleIfNeeded(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> (event: Event, reminder: Reminder?)? {
        guard let dueDate = input.expirationDate,
              let eventType = expirationEventType(for: input.type)
        else { return nil }

        let reminderDates: [Date]
        if let leadDays = input.expirationReminderLeadDays {
            let scheduledAt = Calendar.current.date(
                byAdding: .day,
                value: -leadDays,
                to: dueDate
            ) ?? dueDate
            reminderDates = scheduledAt > Date() ? [scheduledAt] : []
        } else {
            reminderDates = []
        }

        let intent = DomainScheduleCreateIntent(
            title: "\(eventType.emoji) \(pet.name) · \(input.recordName)到期提醒",
            startDate: dueDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            reminderDates: reminderDates,
            writeKind: .care,
            source: .userCommand
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }
        let result = DomainScheduleWriter.createEvent(plan: plan, context: context)
        let event = result.event
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: dueDate)
        let reminder = result.reminders.first
        if let reminder {
            CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: reminder.scheduledAt)
        }
        return (event, reminder)
    }

    private static func expirationEventType(for type: HealthLogType) -> EventType? {
        switch type {
        case .vaccine:
            .vaccine
        case .dewormingInternal:
            .internalDeworming
        case .dewormingExternal:
            .externalDeworming
        default:
            nil
        }
    }
}

struct PetSymptomCommandInput: Equatable {
    let date: Date
    let category: SymptomCategory
    let symptomName: String
    let severity: SymptomSeverity
    let note: String
    let photoData: Data?

    var cleanSymptomName: String {
        symptomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PetSymptomCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let ledgerEventID: UUID
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

enum PetSymptomCommandService {
    @discardableResult
    @MainActor
    static func recordSymptom(
        pet: Pet,
        input: PetSymptomCommandInput,
        context: ModelContext,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> PetSymptomCommandResult? {
        guard !input.cleanSymptomName.isEmpty,
              let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
                  pet: pet,
                  occurredAt: input.date,
                  writeKind: .care,
                  context: context,
                  logPrefix: "PetSymptomCommandService.recordSymptom"
              ) else { return nil }
        let careLedger = providedCareLedger ?? CareLedgerService()

        let log = DomainMemberFactWriter.createSymptomLog(
            plan: write,
            pet: pet,
            category: input.category,
            symptomName: input.cleanSymptomName,
            severity: input.severity,
            note: input.cleanNote,
            photoData: input.photoData,
            context: context
        )

        var ledgerEvent: CareLedgerEvent?
        DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
            ledgerEvent = careLedger.record(
                occurredAt: log.date,
                actorKind: .unknown,
                actorId: nil,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .health,
                actionType: "symptom",
                amountValue: 0,
                amountUnit: "",
                note: log.symptomName,
                source: .detail,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "SymptomLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "",
                context: context,
                save: false
            )
        }
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetSymptomCommandResult(
                logID: log.id,
                subjectID: pet.id,
                ledgerEventID: ledgerEvent?.id ?? UUID(),
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }

        guard let ledgerEvent else { return nil }
        return PetSymptomCommandResult(
            logID: log.id,
            subjectID: pet.id,
            ledgerEventID: ledgerEvent.id,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }
}

struct PetHealthDeleteResult: Equatable {
    let subjectID: UUID
    let recordID: UUID
    let kind: String
    let didDelete: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

enum PetHealthDeleteCommandService {
    @discardableResult
    @MainActor
    static func deleteHealthLog(
        _ log: PetHealthLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return PetHealthDeleteResult(
                subjectID: pet.id,
                recordID: log.id,
                kind: "health",
                didDelete: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let recordID = log.id
        let deletedAt = Date()
        let deferredNotifications = DeferredReminderNotificationCanceller()
        PhysicalDeletionService.deletePetScopedRecord(
            log,
            pet: pet,
            context: context,
            deletedAt: deletedAt,
            notifications: deferredNotifications
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetHealthDeleteResult(
                subjectID: pet.id,
                recordID: recordID,
                kind: "health",
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        deferredNotifications.commit(to: OhanaNotifications.current)
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "health",
            didDelete: true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func deleteSymptomLog(
        _ log: SymptomLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return PetHealthDeleteResult(
                subjectID: pet.id,
                recordID: log.id,
                kind: "symptom",
                didDelete: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let recordID = log.id
        let deletedAt = Date()
        deleteLedgerEvents(modelName: "SymptomLog", modelId: recordID, context: context, deletedAt: deletedAt)
        CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt)
        context.delete(log)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetHealthDeleteResult(
                subjectID: pet.id,
                recordID: recordID,
                kind: "symptom",
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "symptom",
            didDelete: true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func deleteHeatCycleLog(
        _ log: HeatCycleLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return PetHealthDeleteResult(
                subjectID: pet.id,
                recordID: log.id,
                kind: "heat",
                didDelete: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let recordID = log.id
        let deletedAt = Date()
        deleteLedgerEvents(modelName: "HeatCycleLog", modelId: recordID, context: context, deletedAt: deletedAt)
        CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt)
        context.delete(log)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetHealthDeleteResult(
                subjectID: pet.id,
                recordID: recordID,
                kind: "heat",
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "heat",
            didDelete: true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private static func deleteLedgerEvents(
        modelName: String,
        modelId: UUID,
        context: ModelContext,
        deletedAt: Date
    ) {
        let idString = modelId.uuidString
        let events = fetchAll(CareLedgerEvent.self, context: context).filter {
            $0.legacyModelName == modelName && $0.legacyModelId == idString
        }
        for event in events {
            CloudSyncMutationRecorder.markDeleted(event, context: context, deletedAt: deletedAt)
            context.delete(event)
        }
    }

    private static func fetchAll<T: PersistentModel>(_: T.Type, context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}

private final class DeferredReminderNotificationCanceller: ReminderNotificationScheduling, @unchecked Sendable {
    private var cancelledNotificationIds: [String] = []

    func schedule(reminder _: Reminder) {}

    func schedule(
        reminder _: Reminder,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.skippedUserDisabled("{}"))
    }

    func schedule(
        reminder _: Reminder,
        deliveryDate _: Date?,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.skippedUserDisabled("{}"))
    }

    func pendingNotificationIds() async -> Set<String> { [] }

    func scheduleRollingWindow(reminders _: [Reminder]) {}

    func refillWindowIfNeeded(allReminders _: [Reminder]) {}

    func cancel(notificationId: String) {
        guard !notificationId.isEmpty else { return }
        cancelledNotificationIds.append(notificationId)
    }

    func cancelAll(for _: Pet, reminders: [Reminder]) {
        cancelledNotificationIds.append(contentsOf: reminders.map(\.notificationId).filter { !$0.isEmpty })
    }

    func compensate(reminders _: [Reminder]) {}

    func commit(to notifications: ReminderNotificationScheduling) {
        for notificationId in cancelledNotificationIds {
            notifications.cancel(notificationId: notificationId)
        }
    }
}
