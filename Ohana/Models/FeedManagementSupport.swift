//
//  FeedManagementSupport.swift
//  Ohana
//
//  Shared feeding helpers for food stock, feed log source metadata, and auto feeder rules.
//

import Foundation
import SwiftData

enum FeedFoodKind: String, CaseIterable, Identifiable, Codable {
    case dry
    case wet

    var id: String { rawValue }

    var systemIconName: String {
        switch self {
        case .dry: return "circle.hexagongrid.fill"
        case .wet: return "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var assetName: String {
        switch self {
        case .dry: return "feed_dry_bowl"
        case .wet: return "feed_wet_tray"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .dry: return l.tr(zh: "干粮", en: "Dry food", de: "Trockenfutter")
        case .wet: return l.tr(zh: "湿粮", en: "Wet food", de: "Nassfutter")
        }
    }
}

enum FeedTreatKind: String, CaseIterable, Identifiable, Codable {
    case canned
    case lickable
    case freezeDried
    case dentalNeck
    case jerky
    case other

    var id: String { rawValue }

    var systemIconName: String {
        switch self {
        case .canned: return "cylinder.fill"
        case .lickable: return "waterbottle.fill"
        case .freezeDried: return "snowflake"
        case .dentalNeck: return "bone.fill"
        case .jerky: return "leaf.fill"
        case .other: return "birthday.cake.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .canned: return l.tr(zh: "罐头", en: "Can", de: "Dose")
        case .lickable: return l.tr(zh: "猫条", en: "Lickable", de: "Schlecksnack")
        case .freezeDried: return l.tr(zh: "冻干", en: "Freeze-dried", de: "Gefriergetrocknet")
        case .dentalNeck: return l.tr(zh: "磨牙鸡脖", en: "Dental neck", de: "Kau-Hals")
        case .jerky: return l.tr(zh: "肉干", en: "Jerky", de: "Trockenfleisch")
        case .other: return l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }
}

enum PetFoodBrandCatalog {
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

enum FeedLogMetadata {
    static let autoFeedNotePrefix = "ohana_auto_feed:"
    static let treatFeedNoteMarker = "ohana_treat_feed"

    static func source(for log: PetCareLog) -> FeedLogSource? {
        guard log.careType == .feeding else { return nil }
        if log.note.hasPrefix(PetCareLog.plannedFeedNotePrefix) { return .manualReminder }
        if log.note.hasPrefix(autoFeedNotePrefix) { return .autoMain }
        if log.note.hasPrefix(treatFeedNoteMarker) { return .treat }
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

    static func autoNote(eventId: UUID, scheduledAt: Date) -> String {
        "\(autoFeedNotePrefix)\(autoDedupKey(eventId: eventId, scheduledAt: scheduledAt))"
    }

    static func autoDedupKey(from note: String) -> String? {
        guard note.hasPrefix(autoFeedNotePrefix) else { return nil }
        return String(note.dropFirst(autoFeedNotePrefix.count))
    }
}

enum FeedRuleKind: String, CaseIterable {
    case manualReminder
    case autoFeeder

    var iconName: String {
        switch self {
        case .manualReminder: return "bell.badge.fill"
        case .autoFeeder: return "dot.radiowaves.left.and.right"
        }
    }
}

enum FeedOperatingMode: String, CaseIterable, Identifiable, Equatable {
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

enum FeedRuleMetadata {
    static let autoFeederEntityType = "pet_auto_feeder"

    static func isManualReminderEvent(_ event: Event, pet: Pet) -> Bool {
        (event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet") &&
        event.relatedEntityId == pet.id.uuidString &&
        event.eventType == EventType.foodChange.rawValue
    }

    static func isAutoFeederEvent(_ event: Event, pet: Pet) -> Bool {
        event.relatedEntityType == autoFeederEntityType &&
        event.relatedEntityId == pet.id.uuidString &&
        event.eventType == EventType.foodChange.rawValue
    }

    static func amountGrams(from event: Event, fallback: Double = 0) -> Double {
        if event.feedAmountGrams > 0 {
            return event.feedAmountGrams
        }
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*g"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(event.title.startIndex..<event.title.endIndex, in: event.title)
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

    static func mealName(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<10: return "早餐"
        case 10..<14: return "午餐"
        case 14..<17: return "下午餐"
        case 17..<21: return "晚餐"
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
        while cursor <= end && guardCount < 500 {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return dates
    }
}

struct FeedStockSnapshot {
    let totalGrams: Double
    let consumedGrams: Double
    let remainingGrams: Double
    let estimatedDailyGrams: Double
    let estimatedDailyBasis: FeedStockDailyBasis
    let remainingDays: Int
    let runOutDate: Date?
}

enum FeedStockDailyBasis {
    case recentAverage
    case autoRules
    case defaultPortion
    case unavailable
}

enum FeedStockCalculator {
    static func mainFoodLogs(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        since startDate: Date? = nil,
        careLogs: [PetCareLog]? = nil
    ) -> [PetCareLog] {
        let source = careLogs ?? pet.careLogs
        return source.filter { log in
            (careLogs == nil || log.pet?.id == pet.id) &&
            log.careType == .feeding &&
            FeedLogMetadata.isMainFoodLog(log) &&
            (foodKind.map { log.foodKind == $0 } ?? true) &&
            (startDate.map { log.date >= $0 } ?? true)
        }
    }

    static func treatLogs(for pet: Pet, since startDate: Date? = nil, careLogs: [PetCareLog]? = nil) -> [PetCareLog] {
        let source = careLogs ?? pet.careLogs
        return source.filter { log in
            (careLogs == nil || log.pet?.id == pet.id) &&
            log.careType == .feeding &&
            FeedLogMetadata.isTreatLog(log) &&
            (startDate.map { log.date >= $0 } ?? true)
        }
    }

    static func mainConsumedSinceRestock(
        for pet: Pet,
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date()
    ) -> Double {
        FeedFoodKind.allCases.reduce(0) {
            $0 + mainConsumedSinceRestock(for: pet, foodKind: $1, careLogs: careLogs, foodRecords: foodRecords, now: now)
        }
    }

    static func mainConsumedSinceRestock(
        for pet: Pet,
        foodKind: FeedFoodKind,
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date()
    ) -> Double {
        let stock = activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords, now: now)
        let startDate = stock.map { stockOpenDay(for: $0) } ?? (foodKind == .dry ? pet.restockDate : nil)
        return mainFoodLogs(for: pet, foodKind: foodKind, since: startDate, careLogs: careLogs)
            .reduce(0) { total, log in
                total + stockDeductionAmount(for: log, pet: pet)
            }
    }

    static func effectiveMainFoodAmount(for log: PetCareLog, pet: Pet) -> Double {
        log.amountGrams > 0 ? log.amountGrams : pet.dailyPortionGrams
    }

    static func stockDeductionAmount(for log: PetCareLog, pet: Pet) -> Double {
        if let sharedStockTotal = SharedCareMetadata.stockDeductionGrams(from: log.note) {
            return max(0, sharedStockTotal)
        }
        if !log.sharedSessionId.isEmpty,
           log.note.hasPrefix(SharedCareMetadata.sharedFeedNotePrefix) {
            return 0
        }
        return effectiveMainFoodAmount(for: log, pet: pet)
    }

    static func recentDailyAverageGrams(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return nil }
        let restockStart = foodKind
            .flatMap { activeStockRecord(for: pet, foodKind: $0, foodRecords: foodRecords, now: now) }
            .map { stockOpenDay(for: $0, calendar: calendar) } ?? pet.restockDate
        let logs = mainFoodLogs(for: pet, foodKind: foodKind, since: maxDate(windowStart, restockStart), careLogs: careLogs)
            .filter { $0.date <= now }
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
        let dayTotals = grouped.values.map { logs in
            logs.reduce(0) { $0 + effectiveMainFoodAmount(for: $1, pet: pet) }
        }.filter { $0 > 0 }
        guard !dayTotals.isEmpty else { return nil }
        return dayTotals.reduce(0, +) / Double(dayTotals.count)
    }

    static func autoRuleDailyTotalGrams(for pet: Pet, events: [Event]) -> Double {
        autoRuleDailyTotalGrams(for: pet, events: events, foodKind: nil)
    }

    static func autoRuleDailyTotalGrams(for pet: Pet, events: [Event], foodKind: FeedFoodKind?) -> Double {
        events
            .filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }
            .filter { event in foodKind.map { $0 == event.foodKind } ?? true }
            .reduce(0) { total, event in
                total + max(0, FeedRuleMetadata.amountGrams(from: event))
            }
    }

    static func planRuleDailyTotalGrams(for pet: Pet, events: [Event], foodKind: FeedFoodKind?) -> Double {
        events
            .filter {
                FeedRuleMetadata.isManualReminderEvent($0, pet: pet) ||
                FeedRuleMetadata.isAutoFeederEvent($0, pet: pet)
            }
            .filter { event in foodKind.map { $0 == event.foodKind } ?? true }
            .reduce(0) { total, event in
                total + max(0, FeedRuleMetadata.amountGrams(from: event))
            }
    }

    static func estimatedDailyMainFoodGrams(
        for pet: Pet,
        events: [Event] = [],
        foodKind: FeedFoodKind? = nil,
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (Double, FeedStockDailyBasis) {
        if let average = recentDailyAverageGrams(for: pet, foodKind: foodKind, careLogs: careLogs, foodRecords: foodRecords, now: now, calendar: calendar), average > 0 {
            return (average, .recentAverage)
        }
        let planTotal = planRuleDailyTotalGrams(for: pet, events: events, foodKind: foodKind)
        if planTotal > 0 { return (planTotal, .autoRules) }
        if foodKind == nil || foodKind == .dry, pet.dailyPortionGrams > 0 { return (pet.dailyPortionGrams, .defaultPortion) }
        return (0, .unavailable)
    }

    static func snapshot(
        for pet: Pet,
        events: [Event] = [],
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedStockSnapshot {
        snapshot(for: pet, foodKind: .dry, events: events, careLogs: careLogs, foodRecords: foodRecords, now: now, calendar: calendar)
    }

    static func snapshot(
        for pet: Pet,
        foodKind: FeedFoodKind,
        events: [Event] = [],
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedStockSnapshot {
        let stockRecord = activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords, now: now)
        let sourceRecords = foodRecords ?? pet.foodRecords
        let hasModernRecord = sourceRecords.contains { record in
            (foodRecords == nil || record.pet?.id == pet.id) &&
            record.foodKind == foodKind
        }
        let total = stockRecord == nil && hasModernRecord ? 0 : activeStockTotalGrams(for: pet, record: stockRecord, foodKind: foodKind)
        let consumed: Double
        let remaining: Double
        if let stockRecord,
           let correctionGrams = stockRecord.remainingCorrectionGrams,
           let correctionDate = stockRecord.remainingCorrectionDate {
            consumed = mainFoodLogs(for: pet, foodKind: foodKind, since: correctionDate, careLogs: careLogs)
                .filter { $0.date <= now }
                .reduce(0) { $0 + stockDeductionAmount(for: $1, pet: pet) }
            remaining = max(0, correctionGrams - consumed)
        } else {
            consumed = mainConsumedSinceRestock(for: pet, foodKind: foodKind, careLogs: careLogs, foodRecords: foodRecords, now: now)
            remaining = max(0, total - consumed)
        }
        let estimate = estimatedDailyMainFoodGrams(for: pet, events: events, foodKind: foodKind, careLogs: careLogs, foodRecords: foodRecords, now: now, calendar: calendar)
        let days = estimate.0 > 0 ? Int(remaining / estimate.0) : 0
        let runOut = days > 0 ? calendar.date(byAdding: .day, value: days, to: now) : nil
        return FeedStockSnapshot(
            totalGrams: total,
            consumedGrams: consumed,
            remainingGrams: remaining,
            estimatedDailyGrams: estimate.0,
            estimatedDailyBasis: estimate.1,
            remainingDays: days,
            runOutDate: runOut
        )
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date?) -> Date {
        guard let rhs else { return lhs }
        return max(lhs, rhs)
    }

    static func activeStockRecord(
        for pet: Pet,
        foodKind: FeedFoodKind,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date()
    ) -> PetFoodRecord? {
        let source = foodRecords ?? pet.foodRecords
        let today = Calendar.current.startOfDay(for: now)
        return source
            .filter { record in
                (foodRecords == nil || record.pet?.id == pet.id) &&
                record.foodKind == foodKind &&
                stockOpenDay(for: record) <= today
            }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate > $1.startDate }
                if ($0.purchaseDate ?? .distantPast) != ($1.purchaseDate ?? .distantPast) {
                    return ($0.purchaseDate ?? .distantPast) > ($1.purchaseDate ?? .distantPast)
                }
                return $0.id.uuidString > $1.id.uuidString
            }
            .first
    }

    static func activeStockTotalGrams(for pet: Pet, record: PetFoodRecord?, foodKind: FeedFoodKind) -> Double {
        if let total = record?.totalGrams, total > 0 {
            return total
        }
        guard foodKind == .dry else { return 0 }
        return max(0, pet.restockWeight * 1000)
    }

    static func stockOpenDay(for record: PetFoodRecord, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: record.startDate)
    }
}

struct FeedRuleState {
    let pet: Pet
    let allEvents: [Event]
    let now: Date
    let calendar: Calendar

    init(pet: Pet, allEvents: [Event], now: Date = Date(), calendar: Calendar = .current) {
        self.pet = pet
        self.allEvents = allEvents
        self.now = now
        self.calendar = calendar
    }

    var manualReminderEvents: [Event] {
        allEvents
            .filter { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    var autoFeederEvents: [Event] {
        allEvents
            .filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    var todayManualReminders: [Reminder] {
        manualReminderEvents
            .flatMap(\.reminders)
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isPending || $0.isFailed }
    }

    var missedTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isFailed || ($0.isPending && $0.scheduledAt < now) }
    }

    var completedTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isCompleted }
    }

    var nextPendingManualReminder: Reminder? {
        pendingTodayManualReminders.first
    }

    var autoDailyTotalGrams: Double {
        FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents)
    }

    var operatingMode: FeedOperatingMode {
        FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
    }
}

enum FeedAutoLogMaterializer {
    @discardableResult
    @MainActor
    static func materializeDueLogs(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now, calendar: calendar) == .autoFeeder else {
            return 0
        }
        let autoEvents = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).autoFeederEvents
        guard !autoEvents.isEmpty else { return 0 }

        var existingKeys = Set(
            pet.careLogs.compactMap { FeedLogMetadata.autoDedupKey(from: $0.note) }
        )
        var inserted = 0

        for event in autoEvents {
            let grams = FeedRuleMetadata.amountGrams(from: event, fallback: pet.dailyPortionGrams)
            guard grams > 0 else { continue }
            for dueDate in FeedRuleMetadata.dueOccurrences(for: event, through: now, calendar: calendar) {
                let key = FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: dueDate)
                guard !existingKeys.contains(key) else { continue }
                let log = PetCareLog(
                    date: dueDate,
                    type: .feeding,
                    amountGrams: grams,
                    note: FeedLogMetadata.autoNote(eventId: event.id, scheduledAt: dueDate),
                    foodKind: event.foodKind,
                    pet: pet,
                    executorId: nil
                )
                context.insert(log)
                CareLedgerService.recordPetCare(
                    log: log,
                    pet: pet,
                    source: .service,
                    sourceEventId: event.id.uuidString,
                    coconutDelta: 0,
                    context: context
                )
                existingKeys.insert(key)
                inserted += 1
            }
        }

        if inserted > 0 {
            context.safeSave()
        }
        return inserted
    }
}

struct FeedingDashboardState {
    let pet: Pet
    let allEvents: [Event]
    let manualGoalCount: Int
    let careLogs: [PetCareLog]?
    let foodRecords: [PetFoodRecord]?
    let now: Date
    let calendar: Calendar

    init(
        pet: Pet,
        allEvents: [Event],
        manualGoalCount: Int = 1,
        careLogs: [PetCareLog]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.pet = pet
        self.allEvents = allEvents
        self.manualGoalCount = max(1, manualGoalCount)
        self.careLogs = careLogs
        self.foodRecords = foodRecords
        self.now = now
        self.calendar = calendar
    }

    var today: FeedTodayState {
        FeedTodayState(pet: pet, allEvents: allEvents, manualGoalCount: manualGoalCount, careLogs: careLogs, now: now, calendar: calendar)
    }

    var rules: FeedRuleState {
        FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
    }

    var stock: FeedStockSnapshot {
        FeedStockCalculator.snapshot(for: pet, events: allEvents, careLogs: careLogs, foodRecords: foodRecords, now: now, calendar: calendar)
    }

    func stock(foodKind: FeedFoodKind) -> FeedStockSnapshot {
        FeedStockCalculator.snapshot(for: pet, foodKind: foodKind, events: allEvents, careLogs: careLogs, foodRecords: foodRecords, now: now, calendar: calendar)
    }

    var manualPlanEvents: [Event] { rules.manualReminderEvents }
    var autoFeederEvents: [Event] { rules.autoFeederEvents }
    var operatingMode: FeedOperatingMode { rules.operatingMode }
    var nextManualReminder: Reminder? { today.nextPendingReminder }
    var todayMainFoodGrams: Double { today.todayMainFoodGrams }
    var todayDryFoodGrams: Double { today.mainFoodTodayLogs.filter { $0.foodKind == .dry }.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) } }
    var todayWetFoodGrams: Double { today.mainFoodTodayLogs.filter { $0.foodKind == .wet }.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) } }
    var todayTreatGrams: Double { today.todayTreatGrams }
    var recentFeedLogs: [PetCareLog] { today.allTodayLogs }
    var todayAutoFeedLogs: [PetCareLog] {
        today.mainFoodTodayLogs.filter { FeedLogMetadata.source(for: $0) == .autoMain }
    }
    var todayAutoFeedCount: Int { todayAutoFeedLogs.count }
    var todayManualPlanTotalCount: Int {
        max(today.todayPlanReminders.count, manualPlanEvents.count, 1)
    }
    var todayManualPlanCompletedCount: Int {
        min(today.completedTodayPlanReminders.count, todayManualPlanTotalCount)
    }
    var todayManualPlanMissedCount: Int {
        today.missedTodayPlanReminders.count
    }
    var hasMissedManualPlan: Bool {
        todayManualPlanMissedCount > 0
    }
    var todayManualPlanCompletionText: String {
        "\(todayManualPlanCompletedCount)/\(todayManualPlanTotalCount)"
    }

    var autoDailyTotalGrams: Double {
        FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents)
    }
}

struct FeedPlanMealDraft: Equatable {
    var time: Date
    var foodKind: FeedFoodKind
    var grams: Double
}

struct FeedPlanDraft: Equatable {
    var kind: FeedRuleKind
    var dailyCount: Int
    var meals: [FeedPlanMealDraft]

    var gramsPerMeal: Double {
        meals.first?.grams ?? 0
    }

    var times: [Date]

    init(
        kind: FeedRuleKind,
        dailyCount: Int,
        gramsPerMeal: Double,
        times: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.kind = kind
        self.dailyCount = min(max(dailyCount, 1), 6)
        self.times = Self.normalizedTimes(times, count: self.dailyCount, now: now, calendar: calendar)
        self.meals = self.times.map {
            FeedPlanMealDraft(time: $0, foodKind: .dry, grams: max(0, gramsPerMeal))
        }
    }

    init(
        kind: FeedRuleKind,
        meals: [FeedPlanMealDraft],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.kind = kind
        self.dailyCount = min(max(meals.count, 1), 6)
        self.meals = Self.normalizedMeals(meals, count: self.dailyCount, now: now, calendar: calendar)
        self.times = self.meals.map(\.time)
    }

    static func suggestedTimes(for count: Int, on date: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let clamped = min(max(count, 1), 6)
        let hours: [Int]
        switch clamped {
        case 1: hours = [8]
        case 2: hours = [8, 18]
        case 3: hours = [8, 13, 19]
        case 4: hours = [7, 12, 17, 21]
        case 5: hours = [7, 11, 15, 19, 22]
        default: hours = [7, 10, 13, 16, 19, 22]
        }
        return hours.map {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: date) ?? date
        }
    }

    static func normalizedTimes(_ times: [Date], count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        var normalized = Array(times.prefix(count))
        if normalized.count < count {
            normalized += suggestedTimes(for: count, on: now, calendar: calendar).dropFirst(normalized.count)
        }
        return normalized
            .map { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                return calendar.date(
                    bySettingHour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: now
                ) ?? date
            }
            .sorted()
    }

    static func normalizedMeals(_ meals: [FeedPlanMealDraft], count: Int, now: Date = Date(), calendar: Calendar = .current) -> [FeedPlanMealDraft] {
        let clamped = min(max(count, 1), 6)
        let normalizedTimes = normalizedTimes(meals.map(\.time), count: clamped, now: now, calendar: calendar)
        return normalizedTimes.enumerated().map { index, time in
            let source = index < meals.count ? meals[index] : FeedPlanMealDraft(time: time, foodKind: .dry, grams: 50)
            return FeedPlanMealDraft(time: time, foodKind: source.foodKind, grams: max(0, source.grams))
        }
    }
}

struct FeedingPlanWriteResult {
    let events: [Event]
    let reminders: [Reminder]
}

enum FeedingPlanWriter {
    static let stockReminderEntityType = "pet_food_stock"
    private static let manualReminderWindowDays = 14

    @MainActor
    @discardableResult
    static func replacePlan(
        pet: Pet,
        draft: FeedPlanDraft,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedingPlanWriteResult {
        CarePlanCalendarSync.suppressDefaultPlan(kind: "feed", pet: pet, context: context)
        deletePlan(pet: pet, kind: draft.kind, allEvents: allEvents, context: context)

        let meals = FeedPlanDraft.normalizedMeals(draft.meals, count: draft.dailyCount, now: now, calendar: calendar)
        var createdEvents: [Event] = []
        var createdReminders: [Reminder] = []

        for meal in meals {
            let startDate = nextOccurrenceDate(forTimeOfDay: meal.time, after: now, calendar: calendar)
            let event = Event(
                title: FeedRuleMetadata.title(kind: draft.kind, date: startDate, amountGrams: meal.grams, foodKind: meal.foodKind),
                startDate: startDate,
                eventType: EventType.foodChange.rawValue,
                relatedEntityType: draft.kind == .autoFeeder ? FeedRuleMetadata.autoFeederEntityType : EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 1
            event.feedRuleKindRaw = draft.kind.rawValue
            event.foodKindRaw = meal.foodKind.rawValue
            event.feedAmountGrams = meal.grams
            context.insert(event)
            createdEvents.append(event)

            if draft.kind == .manualReminder {
                createdReminders.append(contentsOf: createUpcomingManualReminders(for: event, context: context, now: now, calendar: calendar))
            }
        }

        if let firstAmount = meals.first(where: { $0.grams > 0 })?.grams {
            pet.dailyPortionGrams = firstAmount
        }

        context.safeSave()
        return FeedingPlanWriteResult(events: createdEvents, reminders: createdReminders)
    }

    @MainActor
    static func deletePlan(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event],
        context: ModelContext
    ) {
        for event in planEvents(pet: pet, kind: kind, allEvents: allEvents) {
            deleteEvent(event, context: context)
        }
        context.safeSave()
    }

    @MainActor
    static func deactivateManualReminderOperations(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date()
    ) {
        var didChange = false
        for event in planEvents(pet: pet, kind: .manualReminder, allEvents: allEvents) {
            for reminder in event.reminders where reminder.isPending {
                NotificationManager.shared.cancel(notificationId: reminder.notificationId)
                if reminder.scheduledAt > now {
                    context.delete(reminder)
                    didChange = true
                }
            }
        }
        if didChange {
            context.safeSave()
        }
    }

    @MainActor
    static func clearFeedModePlans(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) {
        CarePlanCalendarSync.suppressDefaultPlan(kind: "feed", pet: pet, context: context)
        deletePlan(pet: pet, kind: .manualReminder, allEvents: allEvents, context: context)
        deletePlan(pet: pet, kind: .autoFeeder, allEvents: allEvents, context: context)
    }

    @MainActor
    @discardableResult
    static func ensureUpcomingManualReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        var created: [Reminder] = []
        for event in planEvents(pet: pet, kind: .manualReminder, allEvents: allEvents) {
            created.append(contentsOf: createUpcomingManualReminders(for: event, context: context, now: now, calendar: calendar))
        }
        if !created.isEmpty {
            context.safeSave()
        }
        return created
    }

    static func planEvents(pet: Pet, kind: FeedRuleKind, allEvents: [Event]) -> [Event] {
        allEvents
            .filter {
                switch kind {
                case .manualReminder:
                    return FeedRuleMetadata.isManualReminderEvent($0, pet: pet)
                case .autoFeeder:
                    return FeedRuleMetadata.isAutoFeederEvent($0, pet: pet)
                }
            }
            .sorted { $0.startDate < $1.startDate }
    }

    @MainActor
    @discardableResult
    static func saveFoodPurchase(
        pet: Pet,
        brand: String,
        totalGrams: Double,
        purchaseDate: Date?,
        openDate: Date? = nil,
        dailyGrams: Double?,
        foodKind: FeedFoodKind = .dry,
        reminderEnabled: Bool,
        reminderAdvanceDays: Int,
        executorId: String?,
        allEvents: [Event],
        context: ModelContext,
        recordToUpdate: PetFoodRecord? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PetFoodRecord {
        let sanitizedTotal = max(0, totalGrams)
        let sanitizedDaily = max(0, dailyGrams ?? pet.dailyPortionGrams)
        let finalBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPurchaseDate = purchaseDate.map { calendar.startOfDay(for: $0) }
        let openSourceDate = openDate ?? purchaseDate ?? now
        let openDay = calendar.startOfDay(for: openSourceDate)
        let finalOpenDate = calendar.isDate(openDay, inSameDayAs: now) ? now : openDay

        pet.foodTrackingMode = .precise
        if foodKind == .dry {
            pet.restockDate = finalOpenDate
            pet.casualOpenDate = finalOpenDate
            pet.restockWeight = sanitizedTotal / 1000
        }
        pet.foodReminderEnabled = reminderEnabled
        pet.foodReminderAdvanceDays = reminderAdvanceDays
        if !finalBrand.isEmpty { pet.foodBrand = finalBrand }

        let record = recordToUpdate ?? PetFoodRecord(pet: pet, executorId: executorId)
        record.brand = finalBrand.isEmpty ? pet.foodBrand : finalBrand
        record.dailyGrams = sanitizedDaily
        record.totalGrams = sanitizedTotal
        record.foodKindRaw = foodKind.rawValue
        record.purchaseDate = finalPurchaseDate
        record.startDate = finalOpenDate
        record.pet = pet
        record.executorId = executorId
        if recordToUpdate != nil {
            record.remainingCorrectionGrams = nil
            record.remainingCorrectionDate = nil
        }
        record.notes = "\(foodKind == .dry ? "干粮" : "湿粮")补粮 · \(Int(sanitizedTotal.rounded()))g"
        if recordToUpdate == nil {
            context.insert(record)
        }
        context.safeSave()

        _ = rebuildFoodStockReminder(
            pet: pet,
            allEvents: allEvents,
            context: context,
            now: now,
            calendar: calendar
        )
        return record
    }

    @MainActor
    @discardableResult
    static func correctFoodStock(
        record: PetFoodRecord,
        remainingGrams: Double,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Reminder? {
        record.remainingCorrectionGrams = max(0, remainingGrams)
        record.remainingCorrectionDate = now
        context.safeSave()
        guard let pet = record.pet else { return nil }
        return rebuildFoodStockReminder(pet: pet, allEvents: allEvents, context: context, now: now, calendar: calendar)
    }

    @MainActor
    @discardableResult
    static func rebuildFoodStockReminder(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Reminder? {
        rebuildFoodStockReminders(pet: pet, allEvents: allEvents, context: context, now: now, calendar: calendar).first
    }

    @MainActor
    @discardableResult
    static func rebuildFoodStockReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        for event in stockReminderEvents(pet: pet, allEvents: allEvents) {
            deleteEvent(event, context: context)
        }

        guard pet.foodReminderEnabled else {
            context.safeSave()
            return []
        }

        var reminders: [Reminder] = []
        for foodKind in FeedFoodKind.allCases {
            let snapshot = FeedStockCalculator.snapshot(for: pet, foodKind: foodKind, events: allEvents, now: now, calendar: calendar)
            guard snapshot.totalGrams > 0,
                  let reminderDate = foodReminderDate(pet: pet, snapshot: snapshot, calendar: calendar),
                  reminderDate > now else { continue }
            let kindTitle = foodKind == .dry ? "干粮" : "湿粮"
            let event = Event(
                title: "\(pet.name) \(kindTitle)快要断粮了，记得补充粮仓",
                startDate: reminderDate,
                eventType: EventType.shoppingList.rawValue,
                relatedEntityType: stockReminderEntityType,
                relatedEntityId: stockReminderEntityId(pet: pet, foodKind: foodKind)
            )
            event.foodKindRaw = foodKind.rawValue
            let reminder = Reminder(event: event, scheduledAt: reminderDate)
            context.insert(event)
            context.insert(reminder)
            reminders.append(reminder)
        }
        context.safeSave()
        return reminders
    }

    static func stockReminderEvents(pet: Pet, allEvents: [Event]) -> [Event] {
        allEvents.filter {
            $0.relatedEntityType == stockReminderEntityType &&
            ($0.relatedEntityId == pet.id.uuidString || $0.relatedEntityId.hasPrefix("\(pet.id.uuidString):"))
        }
    }

    static func stockReminderEntityId(pet: Pet, foodKind: FeedFoodKind) -> String {
        "\(pet.id.uuidString):\(foodKind.rawValue)"
    }

    static func foodReminderDate(
        pet: Pet,
        snapshot: FeedStockSnapshot,
        calendar: Calendar = .current
    ) -> Date? {
        guard let runOut = snapshot.runOutDate else { return nil }
        let raw = calendar.date(byAdding: .day, value: -pet.foodReminderAdvanceDays, to: runOut) ?? runOut
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: raw) ?? raw
    }

    @MainActor
    private static func deleteEvent(_ event: Event, context: ModelContext) {
        for reminder in event.reminders {
            NotificationManager.shared.cancel(notificationId: reminder.notificationId)
            context.delete(reminder)
        }
        context.delete(event)
    }

    @MainActor
    private static func createUpcomingManualReminders(
        for event: Event,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Reminder] {
        let existingKeys = Set(event.reminders.map { reminderKey(eventId: event.id, scheduledAt: $0.scheduledAt) })
        var created: [Reminder] = []

        for occurrence in upcomingOccurrences(for: event, now: now, daysAhead: manualReminderWindowDays, calendar: calendar) {
            let key = reminderKey(eventId: event.id, scheduledAt: occurrence)
            guard !existingKeys.contains(key) else { continue }
            let reminder = Reminder(event: event, scheduledAt: occurrence)
            context.insert(reminder)
            created.append(reminder)
        }
        return created
    }

    private static func upcomingOccurrences(
        for event: Event,
        now: Date,
        daysAhead: Int,
        calendar: Calendar
    ) -> [Date] {
        let intervalDays = max(event.recurrenceDays, 1)
        let end = calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now.addingTimeInterval(Double(daysAhead) * 86_400)
        var cursor = event.startDate
        var guardCount = 0

        while cursor < now && guardCount < 500 {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }

        var occurrences: [Date] = []
        while cursor <= end && guardCount < 1_000 {
            occurrences.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return occurrences
    }

    private static func nextOccurrenceDate(forTimeOfDay time: Date, after now: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var candidate = calendar.date(
            bySettingHour: components.hour ?? 8,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86_400)
        }
        return candidate
    }

    private static func reminderKey(eventId: UUID, scheduledAt: Date) -> String {
        "\(eventId.uuidString):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }
}

enum WaterOperatingMode: String, CaseIterable, Identifiable, Equatable {
    case manual
    case reminder

    var id: String { rawValue }

    static func stored(_ petId: UUID) -> WaterOperatingMode? {
        let raw = UserDefaults.standard.string(forKey: storageKey(petId))
        return raw.flatMap(WaterOperatingMode.init(rawValue:))
    }

    static func set(_ petId: UUID, mode: WaterOperatingMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: storageKey(petId))
    }

    private static func storageKey(_ petId: UUID) -> String {
        "water_operating_mode_\(petId.uuidString)"
    }
}

struct WaterRuleState {
    let pet: Pet
    let allEvents: [Event]
    let now: Date
    let calendar: Calendar

    init(pet: Pet, allEvents: [Event], now: Date = Date(), calendar: Calendar = .current) {
        self.pet = pet
        self.allEvents = allEvents
        self.now = now
        self.calendar = calendar
    }

    var planEvents: [Event] {
        WaterPlanWriter.planEvents(pet: pet, allEvents: allEvents)
    }

    var operatingMode: WaterOperatingMode {
        if let stored = WaterOperatingMode.stored(pet.id) {
            return stored == .reminder && planEvents.isEmpty ? .manual : stored
        }
        return planEvents.isEmpty ? .manual : .reminder
    }

    var todayPlanReminders: [Reminder] {
        planEvents
            .flatMap(\.reminders)
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { $0.isPending || $0.isFailed }
    }

    var missedPlanReminders: [Reminder] {
        planEvents
            .flatMap(\.reminders)
            .filter { ($0.isPending || $0.isFailed) && $0.scheduledAt <= now }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var completedTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { $0.isCompleted }
    }

    var nextPendingReminder: Reminder? {
        missedPlanReminders.first ?? pendingTodayPlanReminders.first
    }

    var missedCount: Int {
        missedPlanReminders.count
    }

    var completionText: String {
        "\(completedTodayPlanReminders.count)/\(max(todayPlanReminders.count, planEvents.count, 1))"
    }
}

enum WaterPlanWriter {
    static let entityType = "pet_water_plan"
    private static let reminderWindowDays = 14

    static func suggestedTimes(count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let clamped = min(max(count, 1), 6)
        let hours: [Int]
        switch clamped {
        case 1: hours = [10]
        case 2: hours = [10, 18]
        case 3: hours = [9, 14, 20]
        case 4: hours = [8, 12, 16, 21]
        case 5: hours = [7, 11, 15, 18, 22]
        default: hours = [7, 10, 13, 16, 19, 22]
        }
        return hours.prefix(clamped).map {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: now) ?? now
        }
    }

    static func normalizedTimes(_ times: [Date], count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let clamped = min(max(count, 1), 6)
        let fallback = suggestedTimes(count: clamped, now: now, calendar: calendar)
        return (0..<clamped).map { index in
            index < times.count ? times[index] : fallback[index]
        }
    }

    @MainActor
    @discardableResult
    static func replacePlan(
        pet: Pet,
        times: [Date],
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        CarePlanCalendarSync.suppressDefaultPlan(kind: "drink", pet: pet, context: context)
        deletePlan(pet: pet, allEvents: allEvents, context: context)

        var createdReminders: [Reminder] = []
        for time in normalizedTimes(times, count: times.count, now: now, calendar: calendar) {
            let startDate = nextOccurrenceDate(forTimeOfDay: time, after: now, calendar: calendar)
            let event = Event(
                title: "\(pet.name) 喂水",
                startDate: startDate,
                eventType: EventType.daily.rawValue,
                relatedEntityType: entityType,
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 1
            event.isAllDay = false
            context.insert(event)
            createdReminders.append(contentsOf: createUpcomingReminders(for: event, context: context, now: now, calendar: calendar))
        }

        context.safeSave()
        return createdReminders
    }

    @MainActor
    static func deletePlan(pet: Pet, allEvents: [Event], context: ModelContext) {
        for event in planEvents(pet: pet, allEvents: allEvents) {
            deleteEvent(event, context: context)
        }
        context.safeSave()
    }

    @MainActor
    @discardableResult
    static func ensureUpcomingReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        var created: [Reminder] = []
        for event in planEvents(pet: pet, allEvents: allEvents) {
            created.append(contentsOf: createUpcomingReminders(for: event, context: context, now: now, calendar: calendar))
        }
        if !created.isEmpty {
            context.safeSave()
        }
        return created
    }

    static func planEvents(pet: Pet, allEvents: [Event]) -> [Event] {
        allEvents
            .filter {
                $0.relatedEntityType == entityType &&
                $0.relatedEntityId == pet.id.uuidString &&
                $0.eventType == EventType.daily.rawValue
            }
            .sorted { $0.startDate < $1.startDate }
    }

    @MainActor
    private static func deleteEvent(_ event: Event, context: ModelContext) {
        for reminder in event.reminders {
            NotificationManager.shared.cancel(notificationId: reminder.notificationId)
            context.delete(reminder)
        }
        context.delete(event)
    }

    @MainActor
    private static func createUpcomingReminders(
        for event: Event,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Reminder] {
        let existingKeys = Set(event.reminders.map { reminderKey(eventId: event.id, scheduledAt: $0.scheduledAt) })
        var created: [Reminder] = []
        for occurrence in upcomingOccurrences(for: event, now: now, daysAhead: reminderWindowDays, calendar: calendar) {
            let key = reminderKey(eventId: event.id, scheduledAt: occurrence)
            guard !existingKeys.contains(key) else { continue }
            let reminder = Reminder(event: event, scheduledAt: occurrence)
            context.insert(reminder)
            created.append(reminder)
        }
        return created
    }

    private static func upcomingOccurrences(
        for event: Event,
        now: Date,
        daysAhead: Int,
        calendar: Calendar
    ) -> [Date] {
        let end = calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now.addingTimeInterval(Double(daysAhead) * 86_400)
        var cursor = event.startDate
        var guardCount = 0
        while cursor < now && guardCount < 500 {
            guard let next = calendar.date(byAdding: .day, value: max(event.recurrenceDays, 1), to: cursor) else { break }
            cursor = next
            guardCount += 1
        }

        var occurrences: [Date] = []
        while cursor <= end && guardCount < 1_000 {
            occurrences.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: max(event.recurrenceDays, 1), to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return occurrences
    }

    private static func nextOccurrenceDate(forTimeOfDay time: Date, after now: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var candidate = calendar.date(
            bySettingHour: components.hour ?? 9,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86_400)
        }
        return candidate
    }

    private static func reminderKey(eventId: UUID, scheduledAt: Date) -> String {
        "\(eventId.uuidString):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }
}
