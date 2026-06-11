//
//  QuickFeedStockSnapshotStore.swift
//  Ohana
//
//  Cached stock read model for the heavier QuickFeed stock surfaces.
//

import Combine
import Foundation

struct QuickFeedStockSnapshot {
    let records: [PetFoodRecord]
    let dryRecords: [PetFoodRecord]
    let wetRecords: [PetFoodRecord]
    let dryPendingRecords: [PetFoodRecord]
    let wetPendingRecords: [PetFoodRecord]
    let dryOpenedHistoryRecords: [PetFoodRecord]
    let wetOpenedHistoryRecords: [PetFoodRecord]
    let dryActiveRecord: PetFoodRecord?
    let wetActiveRecord: PetFoodRecord?
    let dryStock: FeedStockSnapshot
    let wetStock: FeedStockSnapshot
    let totalGramsByRecordID: [UUID: Double]
    let activeCount: Int
    let pendingCount: Int

    static func build(
        pet: Pet,
        allEvents: [Event],
        careLogs: [PetCareLog],
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession] = [],
        now: Date,
        calendar: Calendar = .current
    ) -> QuickFeedStockSnapshot {
        let today = calendar.startOfDay(for: now)
        let records = foodRecords.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate > rhs.startDate }
            if (lhs.purchaseDate ?? .distantPast) != (rhs.purchaseDate ?? .distantPast) {
                return (lhs.purchaseDate ?? .distantPast) > (rhs.purchaseDate ?? .distantPast)
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        let dryRecords = records.filter { $0.foodKind == .dry }
        let wetRecords = records.filter { $0.foodKind == .wet }
        let dryActive = FeedStockCalculator.activeStockRecord(for: pet, foodKind: .dry, foodRecords: records, now: now)
        let wetActive = FeedStockCalculator.activeStockRecord(for: pet, foodKind: .wet, foodRecords: records, now: now)
        let dryActiveID = dryActive?.id
        let wetActiveID = wetActive?.id
        let dryStock = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .dry,
            events: allEvents,
            careLogs: careLogs,
            foodRecords: records,
            sharedCareSessions: sharedCareSessions,
            now: now,
            calendar: calendar
        )
        let wetStock = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .wet,
            events: allEvents,
            careLogs: careLogs,
            foodRecords: records,
            sharedCareSessions: sharedCareSessions,
            now: now,
            calendar: calendar
        )
        let dryPending = dryRecords
            .filter { FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) > today }
            .sorted { FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) < FeedStockCalculator.stockOpenDay(for: $1, calendar: calendar) }
        let wetPending = wetRecords
            .filter { FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) > today }
            .sorted { FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) < FeedStockCalculator.stockOpenDay(for: $1, calendar: calendar) }
        let dryHistory = dryRecords.filter {
            $0.id != dryActiveID && FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) <= today
        }
        let wetHistory = wetRecords.filter {
            $0.id != wetActiveID && FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) <= today
        }
        let totals = Dictionary(uniqueKeysWithValues: records.map { record in
            (record.id, FeedStockCalculator.activeStockTotalGrams(for: pet, record: record, foodKind: record.foodKind))
        })

        return QuickFeedStockSnapshot(
            records: records,
            dryRecords: dryRecords,
            wetRecords: wetRecords,
            dryPendingRecords: dryPending,
            wetPendingRecords: wetPending,
            dryOpenedHistoryRecords: dryHistory,
            wetOpenedHistoryRecords: wetHistory,
            dryActiveRecord: dryActive,
            wetActiveRecord: wetActive,
            dryStock: dryStock,
            wetStock: wetStock,
            totalGramsByRecordID: totals,
            activeCount: [dryActive, wetActive].compactMap(\.self).count,
            pendingCount: dryPending.count + wetPending.count
        )
    }

    func records(for foodKind: FeedFoodKind) -> [PetFoodRecord] {
        foodKind == .dry ? dryRecords : wetRecords
    }

    func pendingRecords(for foodKind: FeedFoodKind) -> [PetFoodRecord] {
        foodKind == .dry ? dryPendingRecords : wetPendingRecords
    }

    func openedHistoryRecords(for foodKind: FeedFoodKind) -> [PetFoodRecord] {
        foodKind == .dry ? dryOpenedHistoryRecords : wetOpenedHistoryRecords
    }

    func activeRecord(for foodKind: FeedFoodKind) -> PetFoodRecord? {
        foodKind == .dry ? dryActiveRecord : wetActiveRecord
    }

    func stock(for foodKind: FeedFoodKind) -> FeedStockSnapshot {
        foodKind == .dry ? dryStock : wetStock
    }

    func totalGrams(for record: PetFoodRecord) -> Double {
        totalGramsByRecordID[record.id] ?? max(0, record.totalGrams)
    }
}

struct QuickFeedStockSnapshotRevision: Equatable {
    let eventRevision: Int
    let careLogRevision: Int
    let foodRecordRevision: Int
    let sharedSessionRevision: Int
    let petRevision: Int
    let timeRevision: Int

    static func make(
        pet: Pet,
        allEvents: [Event],
        careLogs: [PetCareLog],
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession],
        now: Date
    ) -> QuickFeedStockSnapshotRevision {
        QuickFeedStockSnapshotRevision(
            eventRevision: revisionHash(allEvents.prefix(60)) { hasher, event in
                hasher.combine(event.id)
                hasher.combine(event.startDate.timeIntervalSince1970)
                hasher.combine(event.recurrenceDays)
                hasher.combine(event.feedRuleKindRaw)
                hasher.combine(event.foodKindRaw)
                hasher.combine(event.feedAmountGrams)
                hasher.combine(event.reminders.count)
            },
            careLogRevision: revisionHash(careLogs.prefix(180)) { hasher, log in
                hasher.combine(log.id)
                hasher.combine(log.date.timeIntervalSince1970)
                hasher.combine(log.amountGrams)
                hasher.combine(log.foodKindRaw)
                hasher.combine(log.note)
            },
            foodRecordRevision: revisionHash(foodRecords.prefix(90)) { hasher, record in
                hasher.combine(record.id)
                hasher.combine(record.startDate.timeIntervalSince1970)
                hasher.combine(record.purchaseDate?.timeIntervalSince1970 ?? 0)
                hasher.combine(record.totalGrams)
                hasher.combine(record.foodKindRaw)
                hasher.combine(record.notes)
                hasher.combine(record.remainingCorrectionGrams ?? -1)
                hasher.combine(record.remainingCorrectionDate?.timeIntervalSince1970 ?? 0)
            },
            sharedSessionRevision: revisionHash(sharedCareSessions.prefix(90)) { hasher, session in
                hasher.combine(session.id)
                hasher.combine(session.date.timeIntervalSince1970)
                hasher.combine(session.actionKindRaw)
                hasher.combine(session.stockOwnerPetId)
                hasher.combine(session.totalAmountGrams)
            },
            petRevision: revisionHash([pet]) { hasher, pet in
                hasher.combine(pet.id)
                hasher.combine(pet.restockWeight)
                hasher.combine(pet.restockDate?.timeIntervalSince1970 ?? 0)
                hasher.combine(pet.foodReminderEnabled)
                hasher.combine(pet.foodReminderAdvanceDays)
                hasher.combine(pet.dailyPortionGrams)
                hasher.combine(pet.mainFoodKindRaw)
            },
            timeRevision: Int(now.timeIntervalSince1970 / 60)
        )
    }

    private static func revisionHash<Element>(
        _ values: some Sequence<Element>,
        combine: (inout Hasher, Element) -> Void
    ) -> Int {
        var hasher = Hasher()
        var count = 0
        for value in values {
            combine(&hasher, value)
            count += 1
        }
        hasher.combine(count)
        return hasher.finalize()
    }
}

@MainActor
final class QuickFeedStockSnapshotStore: ObservableObject {
    @Published private(set) var snapshot: QuickFeedStockSnapshot
    private var revision: QuickFeedStockSnapshotRevision?

    init(initial: QuickFeedStockSnapshot) {
        snapshot = initial
    }

    func rebuild(
        pet: Pet,
        allEvents: [Event],
        careLogs: [PetCareLog],
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession],
        now: Date,
        force: Bool = false
    ) {
        let nextRevision = QuickFeedStockSnapshotRevision.make(
            pet: pet,
            allEvents: allEvents,
            careLogs: careLogs,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now
        )
        guard force || nextRevision != revision else { return }
        snapshot = QuickFeedStockSnapshot.build(
            pet: pet,
            allEvents: allEvents,
            careLogs: careLogs,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now
        )
        revision = nextRevision
    }
}
