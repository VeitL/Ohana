//
//  FeedManagementSupport.swift
//  Ohana
//
//  Shared feeding helpers for food stock, feed log source metadata, and auto feeder rules.
//

import Foundation
import SwiftData

nonisolated enum FeedFoodKind: String, CaseIterable, Identifiable, Codable {
    case dry
    case wet

    var id: String { rawValue }

    var systemIconName: String {
        switch self {
        case .dry: "circle.hexagongrid.fill"
        case .wet: "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var assetName: String {
        switch self {
        case .dry: "feed_dry_bowl"
        case .wet: "feed_wet_tray"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .dry: l.tr(zh: "干粮", en: "Dry food", de: "Trockenfutter")
        case .wet: l.tr(zh: "湿粮", en: "Wet food", de: "Nassfutter")
        }
    }
}

nonisolated enum FeedTreatKind: String, CaseIterable, Identifiable, Codable {
    case canned
    case lickable
    case freezeDried
    case dentalNeck
    case jerky
    case other

    var id: String { rawValue }

    var systemIconName: String {
        switch self {
        case .canned: "cylinder.fill"
        case .lickable: "waterbottle.fill"
        case .freezeDried: "snowflake"
        case .dentalNeck: "bone.fill"
        case .jerky: "leaf.fill"
        case .other: "birthday.cake.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .canned: l.tr(zh: "罐头", en: "Can", de: "Dose")
        case .lickable: l.tr(zh: "猫条", en: "Lickable", de: "Schlecksnack")
        case .freezeDried: l.tr(zh: "冻干", en: "Freeze-dried", de: "Gefriergetrocknet")
        case .dentalNeck: l.tr(zh: "磨牙鸡脖", en: "Dental neck", de: "Kau-Hals")
        case .jerky: l.tr(zh: "肉干", en: "Jerky", de: "Trockenfleisch")
        case .other: l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }
}

enum FeedGoalPreferences {
    private static func storageKey(for petId: UUID) -> String {
        "feedGoal_\(petId.uuidString)"
    }

    static func manualGoalCount(for petId: UUID, default defaultValue: Int) -> Int {
        let storedGoal = UserDefaults.standard.integer(forKey: storageKey(for: petId))
        return storedGoal > 0 ? storedGoal : defaultValue
    }
}

nonisolated enum PetFoodBrandCatalog {
    static func brands(countryCode: String = AppCountry.code, foodKind: FeedFoodKind) -> [String] {
        let country = AppCountry.normalize(countryCode)
        let regional = brandMap[country]?[foodKind] ?? []
        let global = brandMap["GLOBAL"]?[foodKind] ?? []
        return Array(Set(regional + global)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static let brandMap: [String: [FeedFoodKind: [String]]] = [
        "CN": [
            .dry: ["皇家", "冠能", "渴望", "爱肯拿", "纽顿", "素力高", "网易严选", "鲜朗", "伯纳天纯", "麦富迪", "高爷家", "蓝氏", "比瑞吉", "耐威克", "海洋之星"],
            .wet: ["巅峰", "K9 Natural", "希宝", "珍致", "麦富迪", "高爷家", "鲜朗", "尾巴生活", "网易严选", "小佩", "蓝氏", "喵达", "红狗"]
        ],
        "US": [
            .dry: ["Royal Canin", "Purina Pro Plan", "Hill's Science Diet", "Blue Buffalo", "Wellness", "Orijen", "Acana", "Taste of the Wild", "Instinct", "Iams", "Merrick", "Nutro", "Natural Balance"],
            .wet: ["Fancy Feast", "Friskies", "Sheba", "Weruva", "Tiki Cat", "Wellness", "Hill's Science Diet", "Royal Canin", "Blue Buffalo", "Purina Pro Plan", "Instinct", "Merrick"]
        ],
        "DE": [
            .dry: ["Royal Canin", "Purina Pro Plan", "Hill's Science Plan", "Josera", "Animonda", "Mera", "Wild Freedom", "Happy Cat", "Sanabelle", "Concept for Life", "Leonardo", "Bosch"],
            .wet: ["Animonda", "Mjamjam", "Feringa", "Wild Freedom", "Catz Finefood", "Leonardo", "Royal Canin", "Purina Gourmet", "Sheba", "Whiskas", "MAC's"]
        ],
        "GB": [
            .dry: ["Royal Canin", "Purina Pro Plan", "Hill's Science Plan", "James Wellbeloved", "Iams", "Lily's Kitchen", "Applaws", "Wellness CORE", "Scrumbles", "Harringtons", "Burns"],
            .wet: ["Felix", "Sheba", "Gourmet", "Whiskas", "Lily's Kitchen", "Applaws", "Encore", "Blink!", "Untamed", "Royal Canin", "Hill's Science Plan"]
        ],
        "JP": [
            .dry: ["Royal Canin", "Purina ONE", "Hill's Science Diet", "Unicharm", "Iams", "Medyfas", "Nisshin Petfood", "Aixia", "Kanematsu", "Orijen", "Acana"],
            .wet: ["CIAO", "Aixia", "MonPetit", "Sheba", "Kal Kan", "Royal Canin", "Hill's Science Diet", "Unicharm", "Medyfas", "Neko Genki"]
        ],
        "HK": [
            .dry: ["Royal Canin", "Hill's Science Diet", "Purina Pro Plan", "Orijen", "Acana", "Ziwi Peak", "Farmina", "Wellness", "Instinct", "Taste of the Wild"],
            .wet: ["Ziwi Peak", "Kakato", "Applaws", "Tiki Cat", "Weruva", "Sheba", "Fancy Feast", "Royal Canin", "Hill's Science Diet", "CIAO"]
        ],
        "TW": [
            .dry: ["皇家", "希爾思", "冠能", "渴望", "愛肯拿", "紐頓", "汪喵星球", "怪獸部落", "法米納", "耐吉斯", "莫比"],
            .wet: ["汪喵星球", "怪獸部落", "凱特鮮廚", "巔峰", "CIAO", "Sheba", "Fancy Feast", "皇家", "希爾思", "陪心寵糧"]
        ],
        "GLOBAL": [
            .dry: ["Royal Canin", "Purina Pro Plan", "Hill's Science Diet", "Orijen", "Acana", "Farmina", "Ziwi Peak", "Wellness"],
            .wet: ["Royal Canin", "Hill's Science Diet", "Sheba", "Fancy Feast", "Ziwi Peak", "Tiki Cat", "Weruva", "Applaws"]
        ]
    ]
}

enum FeedLogSource: String {
    case manualMain
    case manualReminder
    case autoMain
    case treat
}

enum FeedStockCalculationMode: String, CaseIterable, Identifiable {
    case manualOrPlan
    case autoFeeder

    var id: String { rawValue }
}

nonisolated enum FeedStockRecordMetadata {
    private static let calculationModePrefix = "stockCalculationMode:"

    static func calculationMode(from notes: String) -> FeedStockCalculationMode? {
        notes
            .components(separatedBy: "\n")
            .compactMap { line -> FeedStockCalculationMode? in
                guard line.hasPrefix(calculationModePrefix) else { return nil }
                return FeedStockCalculationMode(rawValue: String(line.dropFirst(calculationModePrefix.count)))
            }
            .first
    }

    static func calculationMode(for record: PetFoodRecord?) -> FeedStockCalculationMode {
        guard let record else { return .manualOrPlan }
        return FeedStockCalculationMode(rawValue: record.calculationModeRaw) ??
            calculationMode(from: record.notes) ??
            .manualOrPlan
    }

    static func applyCalculationMode(_ mode: FeedStockCalculationMode, to record: PetFoodRecord) {
        record.calculationModeRaw = mode.rawValue
        record.notes = notesScrubbingLegacyCalculationMode(record.notes)
    }

    static func notesScrubbingLegacyCalculationMode(_ notes: String) -> String {
        notes
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix(calculationModePrefix) }
            .joined(separator: "\n")
    }
}

nonisolated enum FeedLogMetadata {
    static let autoFeedNotePrefix = "ohana_auto_feed:"
    static let treatFeedNoteMarker = "ohana_treat_feed"

    static func source(for log: PetCareLog) -> FeedLogSource? {
        guard let source = source(
            actionType: log.careType.rawValue,
            note: log.note,
            ledgerSource: nil,
            sourceEventId: nil,
            sourceReminderId: nil
        ) else { return nil }
        if source == .manualMain, autoDedupKey(for: log) != nil { return .autoMain }
        return source
    }

    static func source(
        actionType: String,
        note: String,
        ledgerSource: CareLedgerSource?,
        sourceEventId: String?,
        sourceReminderId: String?
    ) -> FeedLogSource? {
        guard actionType == CareType.feeding.rawValue else { return nil }
        if note.hasPrefix(PetCareLog.plannedFeedNotePrefix) || ledgerSource == .reminder || sourceReminderId != nil {
            return .manualReminder
        }
        if autoDedupKey(from: note) != nil || (ledgerSource == .service && sourceEventId != nil) {
            return .autoMain
        }
        if note.hasPrefix(treatFeedNoteMarker) { return .treat }
        return .manualMain
    }

    static func isMainFoodLog(_ log: PetCareLog) -> Bool {
        guard let source = source(for: log) else { return false }
        return source != .treat
    }

    static func isTreatLog(_ log: PetCareLog) -> Bool {
        source(for: log) == .treat
    }

    static func autoDedupKey(eventId: UUID, scheduledAt: Date) -> String {
        "\(eventId.uuidString):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }

    static func applyAutoDedupKey(_ key: String, to log: PetCareLog) {
        log.autoFeedDedupKey = key
        log.note = visibleNoteWithoutAutoMetadata(log.note)
    }

    static func autoNote(eventId: UUID, scheduledAt: Date) -> String {
        "\(autoFeedNotePrefix)\(autoDedupKey(eventId: eventId, scheduledAt: scheduledAt))"
    }

    static func autoDedupKey(for log: PetCareLog) -> String? {
        if !log.autoFeedDedupKey.isEmpty {
            return log.autoFeedDedupKey
        }
        return autoDedupKey(from: log.note)
    }

    static func autoDedupKey(from note: String) -> String? {
        guard note.hasPrefix(autoFeedNotePrefix) else { return nil }
        return String(note.dropFirst(autoFeedNotePrefix.count))
    }

    private static func visibleNoteWithoutAutoMetadata(_ note: String) -> String {
        guard note.hasPrefix(autoFeedNotePrefix) else { return note }
        return ""
    }
}

enum FeedRuleKind: String, CaseIterable {
    case manualReminder
    case autoFeeder

    var iconName: String {
        switch self {
        case .manualReminder: "bell.badge.fill"
        case .autoFeeder: "dot.radiowaves.left.and.right"
        }
    }
}

nonisolated enum FeedPlanCatchUpPolicy {
    static let catchUpWindowHours = 6
    static let catchUpWindow: TimeInterval = .init(catchUpWindowHours * 60 * 60)

    static func isCatchUpEligible(scheduledAt: Date, now: Date) -> Bool {
        scheduledAt < now && now.timeIntervalSince(scheduledAt) <= catchUpWindow
    }

    static func isExpiredMiss(scheduledAt: Date, now: Date) -> Bool {
        scheduledAt < now && now.timeIntervalSince(scheduledAt) > catchUpWindow
    }

    static func isCatchUpEligible(_ reminder: Reminder, now: Date) -> Bool {
        guard !reminder.isCompleted, reminder.isPending || reminder.isFailed else { return false }
        return isCatchUpEligible(scheduledAt: reminder.scheduledAt, now: now)
    }

    static func isExpiredMiss(_ reminder: Reminder, now: Date) -> Bool {
        guard !reminder.isCompleted, reminder.isPending || reminder.isFailed else { return false }
        return isExpiredMiss(scheduledAt: reminder.scheduledAt, now: now)
    }
}

nonisolated enum FeedOperatingMode: String, CaseIterable, Identifiable, Equatable {
    case manual
    case manualReminder
    case autoFeeder

    var id: String { rawValue }

    private static func storageKey(petId: UUID) -> String {
        "feedOperatingMode_\(petId.uuidString)"
    }

    static func stored(for petId: UUID) -> FeedOperatingMode? {
        UserDefaults.standard.string(forKey: storageKey(petId: petId)).flatMap(FeedOperatingMode.init(rawValue:))
    }

    static func set(_ petId: UUID, mode: FeedOperatingMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: storageKey(petId: petId))
    }

    static func resolved(
        pet: Pet,
        allEvents: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedOperatingMode {
        let rules = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
        if let stored = stored(for: pet.id) {
            switch stored {
            case .manual:
                return .manual
            case .manualReminder:
                return rules.manualReminderEvents.isEmpty ? .manual : .manualReminder
            case .autoFeeder:
                return rules.autoFeederEvents.isEmpty ? .manual : .autoFeeder
            }
        }
        if !rules.autoFeederEvents.isEmpty { return .autoFeeder }
        if !rules.manualReminderEvents.isEmpty { return .manualReminder }
        return .manual
    }
}

nonisolated enum FeedRuleMetadata {
    static let autoFeederEntityType = "pet_auto_feeder"

    static func isManualReminderEvent(_ event: Event, pet: Pet) -> Bool {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet",
              event.relatedEntityId == pet.id.uuidString,
              event.eventType == EventType.foodChange.rawValue
        else { return false }
        if event.feedRuleKindRaw == FeedRuleKind.manualReminder.rawValue {
            return true
        }
        return event.feedRuleKindRaw.isEmpty && hasLegacyManualReminderTitle(event.title)
    }

    static func isAutoFeederEvent(_ event: Event, pet: Pet) -> Bool {
        (event.feedRuleKindRaw == FeedRuleKind.autoFeeder.rawValue || event.feedRuleKindRaw.isEmpty) &&
            event.relatedEntityType == autoFeederEntityType &&
            event.relatedEntityId == pet.id.uuidString &&
            event.eventType == EventType.foodChange.rawValue
    }

    private static func hasLegacyManualReminderTitle(_ title: String) -> Bool {
        let normalized = title.lowercased()
        let mealNames = ["早餐", "午餐", "下午餐", "晚餐", "夜宵"]
        if mealNames.contains(where: { title.contains($0) }) { return true }
        return ["feed", "food", "meal", "干粮", "湿粮"].contains { normalized.contains($0) }
    }

    static func amountGrams(from event: Event, fallback: Double = 0) -> Double {
        if event.feedAmountGrams > 0 {
            return event.feedAmountGrams
        }
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*g"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(event.title.startIndex ..< event.title.endIndex, in: event.title)
            if let match = regex.firstMatch(in: event.title, options: [], range: range),
               let capture = Range(match.range(at: 1), in: event.title) {
                let raw = String(event.title[capture]).replacingOccurrences(of: ",", with: ".")
                if let value = Double(raw) { return value }
            }
        }
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }

    static func title(kind: FeedRuleKind, date: Date, amountGrams: Double, foodKind: FeedFoodKind = .dry) -> String {
        let rounded = Int(amountGrams.rounded())
        let kindLabel = foodKind == .dry ? "干粮" : "湿粮"
        switch kind {
        case .manualReminder:
            return rounded > 0 ? "\(mealName(for: date)) \(kindLabel) \(rounded)g" : "\(mealName(for: date)) \(kindLabel)"
        case .autoFeeder:
            return rounded > 0 ? "自动喂食器 \(kindLabel) \(rounded)g" : "自动喂食器 \(kindLabel)"
        }
    }

    static func localizedTitle(
        for event: Event,
        l: L10n = L10n(),
        calendar: Calendar = .current
    ) -> String {
        if event.relatedEntityType == FeedingPlanWriter.stockReminderEntityType {
            return localizedStockReminderTitle(for: event, l: l)
        }

        guard event.eventType == EventType.foodChange.rawValue else {
            return event.title
        }

        if let kind = event.feedRuleKind {
            return localizedTitle(
                kind: kind,
                date: event.startDate,
                amountGrams: amountGrams(from: event),
                foodKind: event.foodKind,
                l: l,
                calendar: calendar
            )
        }

        if event.relatedEntityType == autoFeederEntityType {
            return localizedTitle(
                kind: .autoFeeder,
                date: event.startDate,
                amountGrams: amountGrams(from: event),
                foodKind: event.foodKind,
                l: l,
                calendar: calendar
            )
        }

        if event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet",
           hasLegacyManualReminderTitle(event.title) {
            return localizedTitle(
                kind: .manualReminder,
                date: event.startDate,
                amountGrams: amountGrams(from: event),
                foodKind: event.foodKind,
                l: l,
                calendar: calendar
            )
        }

        return event.title
    }

    static func localizedTitle(
        kind: FeedRuleKind,
        date: Date,
        amountGrams: Double,
        foodKind: FeedFoodKind = .dry,
        l: L10n = L10n(),
        calendar: Calendar = .current
    ) -> String {
        let rounded = Int(amountGrams.rounded())
        let kindLabel = foodKind.title(l)
        let amountSuffix = rounded > 0 ? " \(rounded)g" : ""
        switch kind {
        case .manualReminder:
            return "\(localizedMealName(for: date, l: l, calendar: calendar)) \(kindLabel)\(amountSuffix)"
        case .autoFeeder:
            return "\(l.tr(zh: "自动喂食器", en: "Auto feeder", de: "Futterautomat")) \(kindLabel)\(amountSuffix)"
        }
    }

    static func localizedMealName(for date: Date, l: L10n = L10n(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5 ..< 10:
            return l.tr(zh: "早餐", en: "Breakfast", de: "Frühstück")
        case 10 ..< 14:
            return l.tr(zh: "午餐", en: "Lunch", de: "Mittagessen")
        case 14 ..< 17:
            return l.tr(zh: "下午餐", en: "Afternoon meal", de: "Nachmittagsmahlzeit")
        case 17 ..< 21:
            return l.tr(zh: "晚餐", en: "Dinner", de: "Abendessen")
        default:
            return l.tr(zh: "夜宵", en: "Late snack", de: "Späte Mahlzeit")
        }
    }

    static func mealName(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5 ..< 10: return "早餐"
        case 10 ..< 14: return "午餐"
        case 14 ..< 17: return "下午餐"
        case 17 ..< 21: return "晚餐"
        default: return "夜宵"
        }
    }

    static func dueOccurrences(for event: Event, through now: Date, calendar: Calendar = .current, maxLookbackDays: Int = 45) -> [Date] {
        let intervalDays = max(event.recurrenceDays, 1)
        let end = min(event.recurrenceEndDate ?? now, now)
        guard event.startDate <= end else { return [] }

        let lookback = calendar.date(byAdding: .day, value: -maxLookbackDays, to: now) ?? event.startDate
        var cursor = event.startDate
        if cursor < lookback {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: event.startDate),
                to: calendar.startOfDay(for: lookback)
            ).day ?? 0
            let steps = max(0, days / intervalDays)
            cursor = calendar.date(byAdding: .day, value: steps * intervalDays, to: event.startDate) ?? event.startDate
            while cursor < lookback {
                guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
                cursor = next
            }
        }

        var dates: [Date] = []
        var guardCount = 0
        while cursor <= end, guardCount < 500 {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return dates
    }

    private static func localizedStockReminderTitle(for event: Event, l: L10n) -> String {
        let kindTitle = event.foodKind.title(l)
        if let petName = stockReminderPetName(from: event.title, foodKind: event.foodKind) {
            return l.tr(
                zh: "\(petName) \(kindTitle)快要断粮了，记得补充粮仓",
                en: "\(kindTitle) for \(petName) is running low. Refill the food stock.",
                de: "\(kindTitle) für \(petName) wird knapp. Vorrat auffüllen."
            )
        }
        return l.tr(
            zh: "\(kindTitle)快要断粮了，记得补充粮仓",
            en: "\(kindTitle) is running low. Refill the food stock.",
            de: "\(kindTitle) wird knapp. Vorrat auffüllen."
        )
    }

    private static func stockReminderPetName(from title: String, foodKind: FeedFoodKind) -> String? {
        let legacyKind = foodKind == .dry ? "干粮" : "湿粮"
        guard let range = title.range(of: " \(legacyKind)") else { return nil }
        let name = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
