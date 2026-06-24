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

        var existingKeys = existingAutoFeedDedupKeys(petID: pet.id, through: now, context: context)
        var inserted = 0

        for event in autoEvents {
            let grams = FeedRuleMetadata.amountGrams(from: event, fallback: pet.dailyPortionGrams)
            guard grams > 0 else { continue }
            for dueDate in FeedRuleMetadata.dueOccurrences(for: event, through: now, calendar: calendar) {
                let key = FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: dueDate)
                guard !existingKeys.contains(key) else { continue }
                let intent = DomainCareFactCreateIntent(
                    kind: .care(
                        type: .feeding,
                        amountGrams: grams,
                        amountMl: 0,
                        note: "",
                        foodKind: event.foodKind,
                        treatKind: nil,
                        autoFeedDedupKey: key,
                        sharedSessionId: ""
                    ),
                    occurredAt: dueDate,
                    source: .domainService
                )
                guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                    pet: pet,
                    intent: intent,
                    context: context,
                    logPrefix: "FeedAutoLogMaterializer.materializeDueLogs"
                ) else { continue }
                let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log
                DomainCareFactEffectsDispatcher.run(plan: write) { _ in
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
                }
                existingKeys.insert(key)
                inserted += 1
            }
        }

        if inserted > 0 {
            context.safeSave()
        }
        return inserted
    }

    @MainActor
    private static func existingAutoFeedDedupKeys(
        petID: UUID,
        through now: Date,
        context: ModelContext
    ) -> Set<String> {
        let petIDString = petID.uuidString
        let petKind = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingAction = CareType.feeding.rawValue
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petKind &&
                    event.subjectId == petIDString &&
                    event.eventKind == careKind &&
                    event.actionType == feedingAction &&
                    event.occurredAt <= now
            }
        )

        do {
            return Set(try context.fetch(descriptor).compactMap(autoFeedDedupKey(for:)))
        } catch {
            OhanaLog.warning(
                "FeedAutoLogMaterializer failed to fetch auto-feed ledger keys: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    private static func autoFeedDedupKey(for event: CareLedgerEvent) -> String? {
        if let key = CareLedgerMetadata.stringValue(named: CareLedgerMetadata.autoFeedDedupKey, in: event.metadataJSON) {
            return key
        }
        if let key = FeedLogMetadata.autoDedupKey(from: event.note) {
            return key
        }
        guard event.sourceReminderId == nil,
              event.sourceEnum == .service || event.sourceEnum == .backfill,
              let sourceEventId = event.sourceEventId,
              let eventId = UUID(uuidString: sourceEventId)
        else { return nil }
        return FeedLogMetadata.autoDedupKey(eventId: eventId, scheduledAt: event.occurredAt)
    }
}
