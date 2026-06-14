//
//  CalendarTaskCompletionSyncService+Helpers.swift
//  Ohana
//

import Foundation
import SwiftData

extension CalendarTaskCompletionSyncService {
    static func generatedMetadata(
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

    static func metadataDictionary(from json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    static func uuidArray(named key: String, in json: String) -> [UUID] {
        guard let values = metadataDictionary(from: json)[key] as? [String] else { return [] }
        return values.compactMap(UUID.init(uuidString:))
    }

    @MainActor
    static func walletEntries(ids: [UUID], context: ModelContext) -> [CoconutLedgerEntry] {
        guard !ids.isEmpty else { return [] }
        let entries = fetchOrLog(FetchDescriptor<CoconutLedgerEntry>(), context: context, operation: "fetch generated wallet entries")
        let wanted = Set(ids)
        return entries.filter { wanted.contains($0.id) }
    }

    @MainActor
    static func budgetUsageEvents(ids: [UUID], context: ModelContext) -> [EconomyBudgetUsageEvent] {
        guard !ids.isEmpty else { return [] }
        let events = fetchOrLog(FetchDescriptor<EconomyBudgetUsageEvent>(), context: context, operation: "fetch generated budget usage events")
        let wanted = Set(ids)
        return events.filter { wanted.contains($0.id) }
    }

    @MainActor
    static func hasWalletEntry(transactionKey: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { $0.transactionKey == transactionKey }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch wallet reversal entry").isEmpty == false
    }

    @MainActor
    static func human(idString: String, context: ModelContext) -> Human? {
        guard let id = UUID(uuidString: idString) else { return nil }
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch calendar reward human").first
    }

    @MainActor
    static func pet(idString: String, context: ModelContext) -> Pet? {
        guard let id = UUID(uuidString: idString) else { return nil }
        return pet(id: id, context: context)
    }

    @MainActor
    static func pet(id: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch calendar reward pet").first
    }

    static func reversalMetadata(for entry: CoconutLedgerEntry) -> String {
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

    static func rewardAction(for careType: CareType, pet: Pet) -> QuestManager.OhanaActionType {
        rewardAction(for: careType, petName: pet.name)
    }

    static func rewardAction(
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

    static func rewardAction(for careType: CareType, petName: String) -> QuestManager.OhanaActionType {
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

    static func occurrenceTimestamp(for event: Event, occurrenceDate: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(occurrenceDate) { return Date() }
        if event.isAllDay { return calendar.startOfDay(for: occurrenceDate) }
        return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
    }

    static func noteMarker(for event: Event, occurrenceDate: Date, careType: CareType) -> String {
        let key = occurrenceKey(for: occurrenceDate)
        if careType == .feeding {
            return "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString):calendar:\(key)"
        }
        return "ohana_calendar_event:\(event.id.uuidString):\(key)"
    }

    static func calendarFactOnlySessionId(for event: Event, occurrenceDate: Date) -> String {
        "calendar:\(event.id.uuidString):\(occurrenceKey(for: occurrenceDate))"
    }

    static func sameTimestamp(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 0.001
    }

    static func feedAmount(from event: Event, fallback: Double) -> Double {
        if event.feedAmountGrams > 0 {
            return event.feedAmountGrams
        }
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }

    static func occurrenceMetadata(for occurrenceDate: Date) -> String {
        "{\"occurrence\":\"\(occurrenceKey(for: occurrenceDate))\"}"
    }

    static func occurrenceKey(for occurrenceDate: Date) -> String {
        Event.occurrenceStorageKey(for: occurrenceDate)
    }

    static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    static func careType(for event: Event) -> CareType? {
        let text = normalizedText(for: event)
        if text.contains("换水") || text.contains("water change") { return .waterChange }
        if text.contains("滤") || text.contains("filter") { return .filterClean }
        if text.contains("猫砂") || text.contains("铲") || event.eventType == EventType.litterBox.rawValue { return .litter }
        if text.contains("喂水") || text.contains("喝水") || text.contains("饮水") || text.contains("drink") { return .watering }
        if event.eventType == EventType.foodChange.rawValue || text.contains("喂") || text.contains("feed") || text.contains("吃") { return .feeding }
        if text.contains("逗") || text.contains("陪玩") || text.contains("play") { return .play }
        return nil
    }

    static func pottyType(for event: Event) -> PottyType? {
        let text = normalizedText(for: event)
        if text.contains("便") || text.contains("potty") || text.contains("poop") { return .perfectPoop }
        return nil
    }

    static func hygieneType(for event: Event) -> HygieneType? {
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
