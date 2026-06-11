//
//  FeedAutoLogMaterializer.swift
//  Ohana
//

import Foundation
import SwiftData

enum FeedAutoLogMaterializer {
    @discardableResult
    @MainActor
    static func materializeDueLogs(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> Int {
        let careLedger = providedCareLedger ?? CareLedgerService()
        guard FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now, calendar: calendar) == .autoFeeder else {
            return 0
        }
        let autoEvents = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).autoFeederEvents
        guard !autoEvents.isEmpty else { return 0 }

        var existingKeys = Set(
            pet.careLogs.compactMap { FeedLogMetadata.autoDedupKey(for: $0) }
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
                    foodKind: event.foodKind,
                    autoFeedDedupKey: key,
                    pet: pet,
                    executorId: nil
                )
                context.insert(log)
                careLedger.recordPetCare(
                    log: log,
                    pet: pet,
                    source: .service,
                    sourceEventId: event.id.uuidString,
                    sourceReminderId: nil,
                    coconutDelta: 0,
                    metadataJSON: "",
                    context: context,
                    save: true
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
