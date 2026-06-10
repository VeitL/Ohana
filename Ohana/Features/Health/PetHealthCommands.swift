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
    ) -> PetHealthCommandResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
        let oasisRewards = providedOasisRewards ?? StaticOasisRewardManager(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        )
        let log = PetHealthLog(
            date: input.date,
            type: input.type,
            note: input.composedNote,
            pet: pet,
            executorId: input.executorId
        )
        log.vetName = input.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        log.cost = input.cost
        log.expirationDate = input.expirationDate
        log.nextCheckupDate = input.nextCheckupDate
        context.insert(log)

        let expense = makeExpenseIfNeeded(
            pet: pet,
            input: input,
            context: context
        )
        let event = makeExpirationEventIfNeeded(
            pet: pet,
            input: input,
            context: context
        )
        let reminder = makeExpirationReminderIfNeeded(
            event: event,
            input: input,
            context: context
        )

        let reward: (humanGot: Int, petGot: Int)
        if awardsReward {
            reward = questManager.awardAction(type: .health, pet: pet, context: context)
            oasisRewards.rewardFeaturedCritterFromCare(type: .health, context: context)
        } else {
            reward = (humanGot: 0, petGot: 0)
        }
        let coconutDelta = careLedger.rewardDelta(reward)
        let rewardMetadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)

        careLedger.record(
            occurredAt: log.date,
            actorKind: input.executorId == nil ? .unknown : .human,
            actorId: input.executorId,
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

        if let expense {
            careLedger.record(
                occurredAt: expense.date,
                actorKind: input.executorId == nil ? .unknown : .human,
                actorId: input.executorId,
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

        context.safeSave()
        careLedger.syncOasisTreeEnergyIfNeeded(metadataJSON: rewardMetadataJSON, context: context)
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
            expenseLogID: expense?.id,
            eventID: event?.id,
            reminderID: reminder?.id,
            coconutDelta: coconutDelta
        )
    }

    @MainActor
    private static func makeExpenseIfNeeded(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> PetExpenseLog? {
        guard input.cost > 0 else { return nil }
        let expense = PetExpenseLog(
            date: input.date,
            amount: input.cost,
            category: .medical,
            note: input.recordName,
            pet: pet,
            executorId: input.executorId
        )
        context.insert(expense)
        return expense
    }

    @MainActor
    private static func makeExpirationEventIfNeeded(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> Event? {
        guard let dueDate = input.expirationDate,
              let eventType = expirationEventType(for: input.type)
        else { return nil }
        let event = Event(
            title: "\(eventType.emoji) \(pet.name) · \(input.recordName)到期提醒",
            startDate: dueDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(event)
        return event
    }

    @MainActor
    private static func makeExpirationReminderIfNeeded(
        event: Event?,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> Reminder? {
        guard let event,
              let dueDate = input.expirationDate,
              let leadDays = input.expirationReminderLeadDays
        else { return nil }

        let scheduledAt = Calendar.current.date(
            byAdding: .day,
            value: -leadDays,
            to: dueDate
        ) ?? dueDate
        guard scheduledAt > Date() else { return nil }

        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        reminder.statusEnum = .pending
        context.insert(reminder)
        return reminder
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
        guard !input.cleanSymptomName.isEmpty else { return nil }
        let careLedger = providedCareLedger ?? CareLedgerService()

        let log = SymptomLog(
            date: input.date,
            category: input.category,
            symptomName: input.cleanSymptomName,
            severity: input.severity,
            note: input.cleanNote,
            photoData: input.photoData,
            pet: pet
        )
        context.insert(log)

        let ledgerEvent = careLedger.record(
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
        context.safeSave()

        return PetSymptomCommandResult(
            logID: log.id,
            subjectID: pet.id,
            ledgerEventID: ledgerEvent.id
        )
    }
}

struct PetHealthDeleteResult: Equatable {
    let subjectID: UUID
    let recordID: UUID
    let kind: String
    let didDelete: Bool
}

enum PetHealthDeleteCommandService {
    @discardableResult
    @MainActor
    static func deleteHealthLog(
        _ log: PetHealthLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        let recordID = log.id
        context.delete(log)
        context.safeSave()
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "health",
            didDelete: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteSymptomLog(
        _ log: SymptomLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        let recordID = log.id
        context.delete(log)
        context.safeSave()
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "symptom",
            didDelete: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteHeatCycleLog(
        _ log: HeatCycleLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        let recordID = log.id
        context.delete(log)
        context.safeSave()
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "heat",
            didDelete: true
        )
    }
}

@MainActor
struct PetHealthCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let careLedger: CareLedgerRecording
    let reminderScheduling: ReminderSchedulingManaging
    let oasisRewards: OasisRewardManaging

    init(context: ModelContext) {
        let questManager = QuestManager()
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: questManager,
            careLedger: CareLedgerService(),
            reminderScheduling: ReminderSchedulingManager(),
            oasisRewards: StaticOasisRewardManager(
                activeHumanSelection: UserDefaultsActiveHumanSelection(),
                wallet: SwiftDataCoconutWalletManager(),
                questManager: questManager
            )
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        let questManager = QuestManager()
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: questManager,
            careLedger: CareLedgerService(),
            reminderScheduling: ReminderSchedulingManager(),
            oasisRewards: StaticOasisRewardManager(
                activeHumanSelection: UserDefaultsActiveHumanSelection(),
                wallet: SwiftDataCoconutWalletManager(),
                questManager: questManager
            )
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            careLedger: services.careLedger,
            reminderScheduling: services.reminderScheduling,
            oasisRewards: services.oasisRewards
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        careLedger: CareLedgerRecording,
        reminderScheduling: ReminderSchedulingManaging,
        oasisRewards: OasisRewardManaging
    ) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
        self.careLedger = careLedger
        self.reminderScheduling = reminderScheduling
        self.oasisRewards = oasisRewards
    }

    @discardableResult
    func recordHealth(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        awardsReward: Bool = true,
        schedulesReminderNotification: Bool = true,
        note: String
    ) -> PetHealthCommandResult {
        let result = PetHealthCommandService.recordHealth(
            pet: pet,
            input: input,
            context: context,
            awardsReward: awardsReward,
            schedulesReminderNotification: schedulesReminderNotification,
            questManager: questManager,
            careLedger: careLedger,
            reminderScheduling: reminderScheduling,
            oasisRewards: oasisRewards
        )
        revisions.publishPetHealthRecord(result, type: input.type.rawValue, note: note)
        return result
    }

    @discardableResult
    func recordSymptom(
        pet: Pet,
        input: PetSymptomCommandInput,
        note: String,
        emptyNote: String = "pet.symptom.empty"
    ) -> PetSymptomCommandResult? {
        guard let result = PetSymptomCommandService.recordSymptom(pet: pet, input: input, context: context, careLedger: careLedger) else {
            revisions.publish(
                DomainMutationResult(
                    command: .petHealthRecord(petID: pet.id, type: "symptom"),
                    affectedEntityIDs: [pet.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisions.publishPetSymptom(result, note: note)
        return result
    }

    @discardableResult
    func recordHeatCycle(
        pet: Pet,
        input: PetHeatCycleCommandInput,
        note: String
    ) -> PetHeatCycleCommandResult {
        let result = PetHeatCycleCommandService.recordHeatCycle(pet: pet, input: input, context: context)
        revisions.publishPetHeatCycle(result, note: note)
        return result
    }

    @discardableResult
    func deleteHealthLog(_ log: PetHealthLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteHealthLog(log, pet: pet, context: context)
        revisions.publishPetHealthDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteSymptomLog(_ log: SymptomLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteSymptomLog(log, pet: pet, context: context)
        revisions.publishPetHealthDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteHeatCycleLog(_ log: HeatCycleLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteHeatCycleLog(log, pet: pet, context: context)
        revisions.publishPetHealthDelete(result, note: note)
        return result
    }
}
