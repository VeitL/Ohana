//
//  CalendarTaskCompletionSyncService.swift
//  Ohana
//

import Foundation
import SwiftData

enum CalendarTaskCompletionSyncService {
    private static let calendarSource = CareLedgerSource.calendar.rawValue

    private struct GeneratedRewardTrace {
        let reward: (humanGot: Int, petGot: Int)
        let walletEntries: [CoconutLedgerEntry]
        let budgetEvents: [EconomyBudgetUsageEvent]
        let metadataJSON: String

        var coconutDelta: Int {
            max(0, reward.humanGot) + max(0, reward.petGot)
        }
    }

    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
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
    ) {
        let careLedger = providedCareLedger ?? CareLedgerService()
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet",
              let pet = pets.first(where: { $0.id.uuidString == event.relatedEntityId }) else { return }

        if !isCompleted {
            deleteCalendarGeneratedRecords(event: event, occurrenceDate: occurrenceDate, context: context)
            return
        }
        guard calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context).isEmpty else { return }

        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        if let careType = careType(for: event) {
            insertCareLog(
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                executorId: executorId,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger
            )
        } else if let pottyType = pottyType(for: event) {
            insertPottyLog(
                pet: pet,
                event: event,
                pottyType: pottyType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                executorId: executorId,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger
            )
        } else if let hygieneType = hygieneType(for: event) {
            insertHygieneLog(
                pet: pet,
                event: event,
                hygieneType: hygieneType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                rewardDate: operationDate,
                executorId: executorId,
                sourceReminderId: sourceReminderId,
                context: context,
                careLedger: careLedger
            )
        }
    }

    static func isPetTask(event: Event) -> Bool {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet" else { return false }
        return careType(for: event) != nil || pottyType(for: event) != nil || hygieneType(for: event) != nil
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
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
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
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: occurredAt)
        context.safeSave()
        let rewardTrace = awardGeneratedCare(
            action: rewardAction(for: careType, pet: pet),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            executorId: executorId,
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
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        let log = PetPottyLog(date: occurredAt, type: pottyType, pet: pet, executorId: executorId)
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: occurredAt)
        context.safeSave()
        let rewardTrace = awardGeneratedCare(
            action: .potty(isLitter: false),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            executorId: executorId,
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
        sourceReminderId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        let log = PetHygieneLog(date: occurredAt, type: hygieneType, pet: pet, executorId: executorId)
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: occurredAt)
        context.safeSave()
        let rewardTrace = awardGeneratedCare(
            action: .care(type: hygieneType),
            pet: pet,
            occurrenceDate: occurrenceDate,
            rewardDate: rewardDate,
            executorId: executorId,
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
    private static func awardGeneratedCare(
        action: QuestManager.OhanaActionType,
        pet: Pet,
        occurrenceDate: Date,
        rewardDate: Date,
        executorId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) -> GeneratedRewardTrace {
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

    private static func generatedMetadata(
        occurrenceDate: Date,
        rewardMetadata: String,
        walletEntries: [CoconutLedgerEntry],
        budgetEvents: [EconomyBudgetUsageEvent]
    ) -> String {
        var object = metadataDictionary(from: rewardMetadata)
        object["occurrence"] = occurrenceKey(for: occurrenceDate)
        object["walletEntryIds"] = walletEntries.map(\.id.uuidString)
        object["budgetUsageIds"] = budgetEvents.map(\.id.uuidString)
        object["generatedBy"] = "CalendarTaskCompletionSyncService"
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return occurrenceMetadata(for: occurrenceDate)
        }
        return json
    }

    private static func metadataDictionary(from json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func uuidArray(named key: String, in json: String) -> [UUID] {
        guard let values = metadataDictionary(from: json)[key] as? [String] else { return [] }
        return values.compactMap(UUID.init(uuidString:))
    }

    @MainActor
    private static func walletEntries(ids: [UUID], context: ModelContext) -> [CoconutLedgerEntry] {
        guard !ids.isEmpty else { return [] }
        let entries = fetchOrLog(FetchDescriptor<CoconutLedgerEntry>(), context: context, operation: "fetch generated wallet entries")
        let wanted = Set(ids)
        return entries.filter { wanted.contains($0.id) }
    }

    @MainActor
    private static func budgetUsageEvents(ids: [UUID], context: ModelContext) -> [EconomyBudgetUsageEvent] {
        guard !ids.isEmpty else { return [] }
        let events = fetchOrLog(FetchDescriptor<EconomyBudgetUsageEvent>(), context: context, operation: "fetch generated budget usage events")
        let wanted = Set(ids)
        return events.filter { wanted.contains($0.id) }
    }

    @MainActor
    private static func hasWalletEntry(transactionKey: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { $0.transactionKey == transactionKey }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch wallet reversal entry").isEmpty == false
    }

    @MainActor
    private static func human(idString: String, context: ModelContext) -> Human? {
        guard let id = UUID(uuidString: idString) else { return nil }
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch calendar reward human").first
    }

    @MainActor
    private static func pet(idString: String, context: ModelContext) -> Pet? {
        guard let id = UUID(uuidString: idString) else { return nil }
        return pet(id: id, context: context)
    }

    @MainActor
    private static func pet(id: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch calendar reward pet").first
    }

    private static func reversalMetadata(for entry: CoconutLedgerEntry) -> String {
        let object: [String: Any] = [
            "reason": "calendarCareUndo",
            "reversesWalletEntryId": entry.id.uuidString,
            "reversesTransactionKey": entry.transactionKey,
            "generatedBy": "CalendarTaskCompletionSyncService"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"reversesWalletEntryId\":\"\(entry.id.uuidString)\"}"
        }
        return json
    }

    private static func rewardAction(for careType: CareType, pet: Pet) -> QuestManager.OhanaActionType {
        rewardAction(for: careType, petName: pet.name)
    }

    private static func rewardAction(
        legacyModelName: String?,
        actionType: String,
        petName: String?
    ) -> QuestManager.OhanaActionType? {
        switch legacyModelName {
        case "PetCareLog":
            guard let careType = CareType(rawValue: actionType) else { return nil }
            return rewardAction(for: careType, petName: petName ?? "宠物")
        case "PetPottyLog":
            return .potty(isLitter: false)
        case "PetHygieneLog":
            guard let hygieneType = HygieneType(rawValue: actionType) else { return nil }
            return .care(type: hygieneType)
        default:
            return nil
        }
    }

    private static func rewardAction(for careType: CareType, petName: String) -> QuestManager.OhanaActionType {
        switch careType {
        case .feeding:
            .feed
        case .watering:
            .water
        case .litter:
            .potty(isLitter: true)
        case .play:
            .general(humanReward: 3, petReward: 2, emoji: careType.emoji, title: "\(petName) 互动奖励")
        case .filterClean:
            .general(humanReward: 25, petReward: 2, emoji: careType.emoji, title: "\(petName) 清理滤材报酬")
        case .cageCleaning:
            .general(humanReward: 10, petReward: 2, emoji: careType.emoji, title: "\(petName) 清理鸟笼奖励")
        case .freeFlight:
            .general(humanReward: 10, petReward: 2, emoji: careType.emoji, title: "\(petName) 放飞互动奖励")
        case .misting:
            .general(humanReward: 3, petReward: 2, emoji: careType.emoji, title: "\(petName) 保湿打卡奖励")
        case .substrateChange:
            .general(humanReward: 10, petReward: 2, emoji: careType.emoji, title: "\(petName) 环境清洁奖励")
        case .waterChange:
            .general(humanReward: 10, petReward: 2, emoji: careType.emoji, title: "\(petName) 换水奖励")
        }
    }

    private static func occurrenceTimestamp(for event: Event, occurrenceDate: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(occurrenceDate) { return Date() }
        if event.isAllDay { return calendar.startOfDay(for: occurrenceDate) }
        return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
    }

    private static func noteMarker(for event: Event, occurrenceDate: Date, careType: CareType) -> String {
        let key = occurrenceKey(for: occurrenceDate)
        if careType == .feeding {
            return "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString):calendar:\(key)"
        }
        return "ohana_calendar_event:\(event.id.uuidString):\(key)"
    }

    private static func feedAmount(from event: Event, fallback: Double) -> Double {
        if event.feedAmountGrams > 0 {
            return event.feedAmountGrams
        }
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }

    private static func occurrenceMetadata(for occurrenceDate: Date) -> String {
        "{\"occurrence\":\"\(occurrenceKey(for: occurrenceDate))\"}"
    }

    private static func occurrenceKey(for occurrenceDate: Date) -> String {
        Event.occurrenceStorageKey(for: occurrenceDate)
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func careType(for event: Event) -> CareType? {
        let text = normalizedText(for: event)
        if text.contains("换水") || text.contains("water change") { return .waterChange }
        if text.contains("滤") || text.contains("filter") { return .filterClean }
        if text.contains("猫砂") || text.contains("铲") || event.eventType == EventType.litterBox.rawValue { return .litter }
        if text.contains("喂水") || text.contains("喝水") || text.contains("饮水") || text.contains("drink") { return .watering }
        if event.eventType == EventType.foodChange.rawValue || text.contains("喂") || text.contains("feed") || text.contains("吃") { return .feeding }
        if text.contains("逗") || text.contains("陪玩") || text.contains("play") { return .play }
        return nil
    }

    private static func pottyType(for event: Event) -> PottyType? {
        let text = normalizedText(for: event)
        if text.contains("便") || text.contains("potty") || text.contains("poop") { return .perfectPoop }
        return nil
    }

    private static func hygieneType(for event: Event) -> HygieneType? {
        let text = normalizedText(for: event)
        guard event.eventType == EventType.grooming.rawValue
            || text.contains("洗") || text.contains("澡") || text.contains("刷牙")
            || text.contains("剪") || text.contains("梳") || text.contains("清耳")
            || text.contains("groom") || text.contains("bath") else { return nil }
        if text.contains("刷牙") || text.contains("teeth") { return .teeth }
        if text.contains("剪") || text.contains("nail") { return .nails }
        if text.contains("耳") || text.contains("ear") { return .ears }
        if text.contains("梳") || text.contains("brush") { return .brushing }
        return .bath
    }
}
