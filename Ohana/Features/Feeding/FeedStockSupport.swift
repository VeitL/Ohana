//
//  FeedStockSupport.swift
//  Ohana
//

import Foundation
import SwiftData

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

nonisolated enum FeedStockCalculator {
    static func mainFoodLogs(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        since startDate: Date? = nil,
        careLogs: [PetCareLog] = []
    ) -> [PetCareLog] {
        careLogs.filter { log in
            log.pet?.id == pet.id &&
                log.careType == .feeding &&
                FeedLogMetadata.isMainFoodLog(log) &&
                (foodKind.map { log.foodKind == $0 } ?? true) &&
                (startDate.map { log.date >= $0 } ?? true)
        }
    }

    static func mainFoodEntries(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        since startDate: Date? = nil,
        feedingLedgerEntries: [QuickFeedLedgerEntry]
    ) -> [QuickFeedLedgerEntry] {
        feedingLedgerEntries.filter { entry in
            entry.petId == pet.id &&
                entry.source != .treat &&
                (foodKind.map { entry.foodKind == $0 } ?? true) &&
                (startDate.map { entry.date >= $0 } ?? true)
        }
    }

    static func treatLogs(for pet: Pet, since startDate: Date? = nil, careLogs: [PetCareLog] = []) -> [PetCareLog] {
        careLogs.filter { log in
            log.pet?.id == pet.id &&
                log.careType == .feeding &&
                FeedLogMetadata.isTreatLog(log) &&
                (startDate.map { log.date >= $0 } ?? true)
        }
    }

    static func mainConsumedSinceRestock(
        for pet: Pet,
        careLogs: [PetCareLog] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        sharedCareSessions: [SharedCareSession]? = nil,
        now: Date = Date()
    ) -> Double {
        FeedFoodKind.allCases.reduce(0) {
            $0 + mainConsumedSinceRestock(for: pet, foodKind: $1, careLogs: careLogs, feedingLedgerEntries: feedingLedgerEntries, foodRecords: foodRecords, sharedCareSessions: sharedCareSessions, now: now)
        }
    }

    static func mainConsumedSinceRestock(
        for pet: Pet,
        foodKind: FeedFoodKind,
        careLogs: [PetCareLog] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        sharedCareSessions: [SharedCareSession]? = nil,
        now: Date = Date(),
        calculationMode: FeedStockCalculationMode? = nil
    ) -> Double {
        let stock = activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords, now: now)
        let startDate = stock.map { stockOpenDay(for: $0) } ?? (foodKind == .dry ? pet.restockDate : nil)
        let mode = calculationMode ?? stock.map { FeedStockRecordMetadata.calculationMode(for: $0) }
        if let feedingLedgerEntries {
            return stockConsumptionEntries(
                for: pet,
                foodKind: foodKind,
                since: startDate,
                feedingLedgerEntries: feedingLedgerEntries,
                calculationMode: mode
            )
            .reduce(0) { total, entry in
                total + stockDeductionAmount(for: entry, pet: pet, sharedCareSessions: sharedCareSessions)
            }
        }
        return stockConsumptionLogs(for: pet, foodKind: foodKind, since: startDate, careLogs: careLogs, calculationMode: mode)
            .reduce(0) { total, log in
                total + stockDeductionAmount(for: log, pet: pet, sharedCareSessions: sharedCareSessions)
            }
    }

    static func effectiveMainFoodAmount(for log: PetCareLog, pet: Pet) -> Double {
        log.amountGrams > 0 ? log.amountGrams : pet.dailyPortionGrams
    }

    static func effectiveMainFoodAmount(for entry: QuickFeedLedgerEntry, pet: Pet) -> Double {
        entry.amountGrams > 0 ? entry.amountGrams : pet.dailyPortionGrams
    }

    static func stockDeductionAmount(
        for log: PetCareLog,
        pet: Pet,
        sharedCareSessions: [SharedCareSession]? = nil
    ) -> Double {
        if !log.sharedSessionId.isEmpty {
            if let session = sharedFeedingSession(for: log, sharedCareSessions: sharedCareSessions) {
                return session.stockOwnerPetId == pet.id.uuidString ? max(0, session.totalAmountGrams) : 0
            }
            if let sharedStockTotal = SharedCareMetadata.stockDeductionGrams(from: log.note) {
                return max(0, sharedStockTotal)
            }
            return 0
        }
        return effectiveMainFoodAmount(for: log, pet: pet)
    }

    static func stockDeductionAmount(
        for entry: QuickFeedLedgerEntry,
        pet: Pet,
        sharedCareSessions: [SharedCareSession]? = nil
    ) -> Double {
        if !entry.sharedSessionId.isEmpty {
            if let session = sharedFeedingSession(id: entry.sharedSessionId, sharedCareSessions: sharedCareSessions) {
                return session.stockOwnerPetId == pet.id.uuidString ? max(0, session.totalAmountGrams) : 0
            }
            if let sharedStockTotal = SharedCareMetadata.stockDeductionGrams(from: entry.note) {
                return max(0, sharedStockTotal)
            }
            return 0
        }
        return effectiveMainFoodAmount(for: entry, pet: pet)
    }

    static func recentDailyAverageGrams(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        careLogs: [PetCareLog] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current,
        calculationMode: FeedStockCalculationMode? = nil
    ) -> Double? {
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return nil }
        let activeRecord = foodKind.flatMap { activeStockRecord(for: pet, foodKind: $0, foodRecords: foodRecords, now: now) }
        let restockStart = activeRecord.map { stockOpenDay(for: $0, calendar: calendar) } ?? pet.restockDate
        let mode = calculationMode ?? activeRecord.map { FeedStockRecordMetadata.calculationMode(for: $0) }
        if let feedingLedgerEntries {
            let entries = stockConsumptionEntries(for: pet, foodKind: foodKind, since: maxDate(windowStart, restockStart), feedingLedgerEntries: feedingLedgerEntries, calculationMode: mode)
                .filter { $0.date <= now }
            let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            let dayTotals = grouped.values.map { entries in
                entries.reduce(0) { $0 + effectiveMainFoodAmount(for: $1, pet: pet) }
            }.filter { $0 > 0 }
            guard !dayTotals.isEmpty else { return nil }
            return dayTotals.reduce(0, +) / Double(dayTotals.count)
        }
        let logs = stockConsumptionLogs(for: pet, foodKind: foodKind, since: maxDate(windowStart, restockStart), careLogs: careLogs, calculationMode: mode)
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
        dailyTotalGrams(
            for: events.filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) },
            foodKind: foodKind
        )
    }

    static func planRuleDailyTotalGrams(for pet: Pet, events: [Event], foodKind: FeedFoodKind?) -> Double {
        dailyTotalGrams(
            for: events.filter {
                FeedRuleMetadata.isManualReminderEvent($0, pet: pet) ||
                    FeedRuleMetadata.isAutoFeederEvent($0, pet: pet)
            },
            foodKind: foodKind
        )
    }

    static func activePlanRuleDailyTotalGrams(
        for pet: Pet,
        events: [Event],
        foodKind: FeedFoodKind?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let mode = FeedOperatingMode.resolved(pet: pet, allEvents: events, now: now, calendar: calendar)
        let activeEvents = events.filter { event in
            switch mode {
            case .manual:
                false
            case .manualReminder:
                FeedRuleMetadata.isManualReminderEvent(event, pet: pet)
            case .autoFeeder:
                FeedRuleMetadata.isAutoFeederEvent(event, pet: pet)
            }
        }
        return dailyTotalGrams(for: activeEvents, foodKind: foodKind)
    }

    private static func dailyTotalGrams(for events: [Event], foodKind: FeedFoodKind?) -> Double {
        events
            .filter { event in foodKind.map { $0 == event.foodKind } ?? true }
            .reduce(0) { total, event in
                total + max(0, FeedRuleMetadata.amountGrams(from: event))
            }
    }

    static func estimatedDailyMainFoodGrams(
        for pet: Pet,
        events: [Event] = [],
        foodKind: FeedFoodKind? = nil,
        careLogs: [PetCareLog] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current,
        calculationMode: FeedStockCalculationMode? = nil
    ) -> (Double, FeedStockDailyBasis) {
        if calculationMode == .autoFeeder {
            let planTotal = activePlanRuleDailyTotalGrams(for: pet, events: events, foodKind: foodKind, now: now, calendar: calendar)
            if planTotal > 0 { return (planTotal, .autoRules) }
            if let average = recentDailyAverageGrams(for: pet, foodKind: foodKind, careLogs: careLogs, feedingLedgerEntries: feedingLedgerEntries, foodRecords: foodRecords, now: now, calendar: calendar, calculationMode: calculationMode), average > 0 {
                return (average, .recentAverage)
            }
            return (0, .unavailable)
        }
        if let average = recentDailyAverageGrams(for: pet, foodKind: foodKind, careLogs: careLogs, feedingLedgerEntries: feedingLedgerEntries, foodRecords: foodRecords, now: now, calendar: calendar, calculationMode: calculationMode), average > 0 {
            return (average, .recentAverage)
        }
        if calculationMode == nil {
            let planTotal = activePlanRuleDailyTotalGrams(for: pet, events: events, foodKind: foodKind, now: now, calendar: calendar)
            if planTotal > 0 { return (planTotal, .autoRules) }
            if FeedOperatingMode.stored(for: pet.id) == nil {
                let autoTotal = autoRuleDailyTotalGrams(for: pet, events: events, foodKind: foodKind)
                if autoTotal > 0 { return (autoTotal, .autoRules) }
            }
        }
        if foodKind == nil || foodKind == .dry, pet.dailyPortionGrams > 0 { return (pet.dailyPortionGrams, .defaultPortion) }
        return (0, .unavailable)
    }

    static func snapshot(
        for pet: Pet,
        events: [Event] = [],
        careLogs: [PetCareLog] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        sharedCareSessions: [SharedCareSession]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedStockSnapshot {
        snapshot(for: pet, foodKind: .dry, events: events, careLogs: careLogs, feedingLedgerEntries: feedingLedgerEntries, foodRecords: foodRecords, sharedCareSessions: sharedCareSessions, now: now, calendar: calendar)
    }

    static func snapshot(
        for pet: Pet,
        foodKind: FeedFoodKind,
        events: [Event] = [],
        careLogs: [PetCareLog] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord]? = nil,
        sharedCareSessions: [SharedCareSession]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedStockSnapshot {
        let stockRecord = activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords, now: now)
        let calculationMode = stockRecord.map { FeedStockRecordMetadata.calculationMode(for: $0) }
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
            if let feedingLedgerEntries {
                consumed = stockConsumptionEntries(for: pet, foodKind: foodKind, since: correctionDate, feedingLedgerEntries: feedingLedgerEntries, calculationMode: calculationMode)
                    .filter { $0.date <= now }
                    .reduce(0) { $0 + stockDeductionAmount(for: $1, pet: pet, sharedCareSessions: sharedCareSessions) }
            } else {
                consumed = stockConsumptionLogs(for: pet, foodKind: foodKind, since: correctionDate, careLogs: careLogs, calculationMode: calculationMode)
                    .filter { $0.date <= now }
                    .reduce(0) { $0 + stockDeductionAmount(for: $1, pet: pet, sharedCareSessions: sharedCareSessions) }
            }
            remaining = max(0, correctionGrams - consumed)
        } else {
            consumed = mainConsumedSinceRestock(for: pet, foodKind: foodKind, careLogs: careLogs, feedingLedgerEntries: feedingLedgerEntries, foodRecords: foodRecords, sharedCareSessions: sharedCareSessions, now: now, calculationMode: calculationMode)
            remaining = max(0, total - consumed)
        }
        let estimate = estimatedDailyMainFoodGrams(for: pet, events: events, foodKind: foodKind, careLogs: careLogs, feedingLedgerEntries: feedingLedgerEntries, foodRecords: foodRecords, now: now, calendar: calendar, calculationMode: calculationMode)
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

    private static func stockConsumptionLogs(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        since startDate: Date? = nil,
        careLogs: [PetCareLog] = [],
        calculationMode: FeedStockCalculationMode?
    ) -> [PetCareLog] {
        let logs = mainFoodLogs(for: pet, foodKind: foodKind, since: startDate, careLogs: careLogs)
        guard let calculationMode else { return logs }
        return logs.filter { logMatchesStockCalculationMode($0, mode: calculationMode) }
    }

    private static func stockConsumptionEntries(
        for pet: Pet,
        foodKind: FeedFoodKind? = nil,
        since startDate: Date? = nil,
        feedingLedgerEntries: [QuickFeedLedgerEntry],
        calculationMode: FeedStockCalculationMode?
    ) -> [QuickFeedLedgerEntry] {
        let entries = mainFoodEntries(for: pet, foodKind: foodKind, since: startDate, feedingLedgerEntries: feedingLedgerEntries)
        guard let calculationMode else { return entries }
        return entries.filter { entryMatchesStockCalculationMode($0, mode: calculationMode) }
    }

    private static func logMatchesStockCalculationMode(_ log: PetCareLog, mode: FeedStockCalculationMode) -> Bool {
        switch mode {
        case .manualOrPlan:
            FeedLogMetadata.source(for: log) != .autoMain
        case .autoFeeder:
            FeedLogMetadata.source(for: log) == .autoMain
        }
    }

    private static func entryMatchesStockCalculationMode(_ entry: QuickFeedLedgerEntry, mode: FeedStockCalculationMode) -> Bool {
        switch mode {
        case .manualOrPlan:
            entry.source != .autoMain
        case .autoFeeder:
            entry.source == .autoMain
        }
    }

    private static func sharedFeedingSession(
        for log: PetCareLog,
        sharedCareSessions: [SharedCareSession]?
    ) -> SharedCareSession? {
        guard !log.sharedSessionId.isEmpty,
              let sharedCareSessions else { return nil }
        return sharedFeedingSession(id: log.sharedSessionId, sharedCareSessions: sharedCareSessions)
    }

    private static func sharedFeedingSession(
        id: String,
        sharedCareSessions: [SharedCareSession]?
    ) -> SharedCareSession? {
        guard !id.isEmpty, let sharedCareSessions else { return nil }
        return sharedCareSessions.first { session in
            session.id.uuidString == id &&
                session.actionKind == .feeding
        }
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
