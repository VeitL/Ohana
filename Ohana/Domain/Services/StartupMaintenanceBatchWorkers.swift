//
//  StartupMaintenanceBatchWorkers.swift
//  Ohana
//
//  Bounded, value-returning SwiftData maintenance workers used only after the
//  first visible frame. They deliberately keep normal user-facing services on
//  their existing paths while startup uses cancellable background batches.
//

import Foundation
import SwiftData

// MARK: - Member theme normalization

nonisolated enum MemberThemeColorNormalizationSource: String, Codable, Equatable, Sendable {
    case pet
    case human
    case complete
}

nonisolated struct MemberThemeColorNormalizationCursor: Codable, Equatable, Sendable {
    var source: MemberThemeColorNormalizationSource
    var offset: Int

    static let initial = MemberThemeColorNormalizationCursor(source: .pet, offset: 0)

    var isComplete: Bool {
        source == .complete
    }

    func normalized() -> MemberThemeColorNormalizationCursor {
        guard source != .complete else {
            return MemberThemeColorNormalizationCursor(source: .complete, offset: 0)
        }
        return MemberThemeColorNormalizationCursor(source: source, offset: max(0, offset))
    }
}

nonisolated struct MemberThemeColorNormalizationBatchResult: Equatable, Sendable {
    let nextCursor: MemberThemeColorNormalizationCursor
    let scannedRecordCount: Int
    let normalizedRecordCount: Int
    let didComplete: Bool
}

private nonisolated struct MemberThemeColorNormalizationPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

nonisolated enum MemberThemeColorStartupMaintenanceService {
    static func normalizeBatch(
        context: ModelContext,
        cursor: MemberThemeColorNormalizationCursor,
        maximumRecordCount: Int,
        deadline: Date
    ) throws -> MemberThemeColorNormalizationBatchResult {
        var nextCursor = cursor.normalized()
        var remainingRecordCount = max(1, maximumRecordCount)
        var scannedRecordCount = 0
        var normalizedRecordCount = 0
        var didChange = false

        do {
            maintenanceLoop: while remainingRecordCount > 0,
                                   !nextCursor.isComplete,
                                   Date() < deadline {
                try Task.checkCancellation()

                switch nextCursor.source {
                case .pet:
                    let pets = try pets(
                        context: context,
                        offset: nextCursor.offset,
                        limit: remainingRecordCount
                    )
                    guard !pets.isEmpty else {
                        nextCursor = MemberThemeColorNormalizationCursor(source: .human, offset: 0)
                        continue
                    }

                    for pet in pets {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        defer {
                            scannedRecordCount += 1
                            remainingRecordCount -= 1
                            nextCursor.offset += 1
                        }

                        let normalized = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                            pet.themeColorHex,
                            fallback: OhanaThemeColorPolicy.petFallbackHex
                        )
                        guard pet.themeColorHex.uppercased() != normalized else { continue }
                        pet.themeColorHex = normalized
                        didChange = true
                        normalizedRecordCount += 1
                    }

                    if pets.count < max(1, remainingRecordCount + pets.count) {
                        nextCursor = MemberThemeColorNormalizationCursor(source: .human, offset: 0)
                    }

                case .human:
                    let humans = try humans(
                        context: context,
                        offset: nextCursor.offset,
                        limit: remainingRecordCount
                    )
                    guard !humans.isEmpty else {
                        nextCursor = MemberThemeColorNormalizationCursor(source: .complete, offset: 0)
                        continue
                    }

                    for human in humans {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        defer {
                            scannedRecordCount += 1
                            remainingRecordCount -= 1
                            nextCursor.offset += 1
                        }

                        let normalized = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                            human.themeColorHex,
                            fallback: OhanaThemeColorPolicy.humanFallbackHex
                        )
                        guard human.themeColorHex.uppercased() != normalized else { continue }
                        human.themeColorHex = normalized
                        didChange = true
                        normalizedRecordCount += 1
                    }

                    if humans.count < max(1, remainingRecordCount + humans.count) {
                        nextCursor = MemberThemeColorNormalizationCursor(source: .complete, offset: 0)
                    }

                case .complete:
                    break maintenanceLoop
                }
            }

            try Task.checkCancellation()
            if didChange {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    throw MemberThemeColorNormalizationPersistenceFailure(errorDescription: saveResult.errorDescription)
                }
            }

            return MemberThemeColorNormalizationBatchResult(
                nextCursor: nextCursor,
                scannedRecordCount: scannedRecordCount,
                normalizedRecordCount: normalizedRecordCount,
                didComplete: nextCursor.isComplete
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func pets(
        context: ModelContext,
        offset: Int,
        limit: Int
    ) throws -> [Pet] {
        var descriptor = FetchDescriptor<Pet>(sortBy: [SortDescriptor(\Pet.createdAt)])
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        return try context.fetch(descriptor)
    }

    private static func humans(
        context: ModelContext,
        offset: Int,
        limit: Int
    ) throws -> [Human] {
        var descriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\Human.createdAt)])
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        return try context.fetch(descriptor)
    }
}

/// Startup receives value-only progress from this actor; no live SwiftData
/// member models cross back to the visible coordinator.
@ModelActor
actor MemberThemeColorMaintenanceActor {
    func runBatch(
        cursor: MemberThemeColorNormalizationCursor,
        maximumRecordCount: Int,
        deadline: Date
    ) throws -> MemberThemeColorNormalizationBatchResult {
        try MemberThemeColorStartupMaintenanceService.normalizeBatch(
            context: modelContext,
            cursor: cursor,
            maximumRecordCount: maximumRecordCount,
            deadline: deadline
        )
    }
}

// MARK: - Auto feeder materialization

nonisolated struct StartupAutoFeederCursor: Codable, Equatable, Sendable {
    var petOffset: Int

    static let initial = StartupAutoFeederCursor(petOffset: 0)

    func normalized() -> StartupAutoFeederCursor {
        StartupAutoFeederCursor(petOffset: max(0, petOffset))
    }
}

nonisolated struct StartupAutoFeederBatchResult: Equatable, Sendable {
    let nextCursor: StartupAutoFeederCursor
    let processedPetCount: Int
    let insertedLogCount: Int
    let didComplete: Bool
}

private nonisolated struct StartupAutoFeederPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

nonisolated enum StartupAutoFeederMaintenanceService {
    static func materializeBatch(
        context: ModelContext,
        cursor: StartupAutoFeederCursor,
        maximumPetCount: Int,
        deadline: Date,
        now: Date,
        calendar: Calendar
    ) throws -> StartupAutoFeederBatchResult {
        var nextCursor = cursor.normalized()
        let maximumPetCount = max(1, maximumPetCount)
        var processedPetCount = 0
        var insertedLogCount = 0
        var didChange = false
        var reachedDeadline = false

        do {
            var descriptor = FetchDescriptor<Pet>(sortBy: [SortDescriptor(\Pet.createdAt)])
            descriptor.fetchOffset = nextCursor.petOffset
            descriptor.fetchLimit = maximumPetCount
            let pets = try context.fetch(descriptor)

            for pet in pets {
                try Task.checkCancellation()
                guard Date() < deadline else {
                    reachedDeadline = true
                    break
                }

                let result = try materializeDueLogs(
                    pet: pet,
                    context: context,
                    deadline: deadline,
                    now: now,
                    calendar: calendar
                )
                insertedLogCount += result.insertedLogCount
                didChange = didChange || result.insertedLogCount > 0

                guard !result.reachedDeadline else {
                    reachedDeadline = true
                    break
                }
                processedPetCount += 1
                nextCursor.petOffset += 1
            }

            try Task.checkCancellation()
            if didChange {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    throw StartupAutoFeederPersistenceFailure(errorDescription: saveResult.errorDescription)
                }
            }

            let didComplete = !reachedDeadline && pets.count < maximumPetCount
            return StartupAutoFeederBatchResult(
                nextCursor: didComplete ? .initial : nextCursor,
                processedPetCount: processedPetCount,
                insertedLogCount: insertedLogCount,
                didComplete: didComplete
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func materializeDueLogs(
        pet: Pet,
        context: ModelContext,
        deadline: Date,
        now: Date,
        calendar: Calendar
    ) throws -> (insertedLogCount: Int, reachedDeadline: Bool) {
        let events = try autoFeederEvents(for: pet, context: context)
        guard !events.isEmpty,
              FeedOperatingMode.resolved(pet: pet, allEvents: events, now: now, calendar: calendar) == .autoFeeder
        else {
            return (0, false)
        }

        var stagedKeys: Set<String> = []
        var insertedLogCount = 0

        for event in events where FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) {
            try Task.checkCancellation()
            guard Date() < deadline else { return (insertedLogCount, true) }

            let grams = FeedRuleMetadata.amountGrams(from: event, fallback: pet.dailyPortionGrams)
            guard grams > 0 else { continue }

            for dueDate in FeedRuleMetadata.dueOccurrences(for: event, through: now, calendar: calendar) {
                try Task.checkCancellation()
                guard Date() < deadline else { return (insertedLogCount, true) }

                let key = FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: dueDate)
                guard !stagedKeys.contains(key),
                      try !autoFeedDedupExists(
                          key: key,
                          petID: pet.id,
                          sourceEventID: event.id,
                          dueDate: dueDate,
                          context: context
                      )
                else {
                    continue
                }

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
                guard let write = DomainCareFactWriteAuthorizer.authorizeSystemPetFact(
                    pet: pet,
                    intent: intent,
                    context: context
                ) else {
                    continue
                }

                let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log
                if write.allowsDerivedEffects {
                    let feedMetadataJSON = CareLedgerMetadata.addingFeedingLogMetadata(from: log, to: "")
                    let metadataJSON = CareLedgerMetadata.addingString(
                        CareLedgerMetadata.autoFeedDedupKey,
                        value: log.autoFeedDedupKey,
                        to: feedMetadataJSON
                    )
                    DomainCareFactWriter.createCareLedgerEvent(
                        plan: write,
                        log: log,
                        sourceEventID: event.id,
                        metadataJSON: metadataJSON,
                        context: context
                    )
                }
                stagedKeys.insert(key)
                insertedLogCount += 1
            }
        }

        return (insertedLogCount, false)
    }

    private static func autoFeederEvents(for pet: Pet, context: ModelContext) throws -> [Event] {
        let petID = pet.id.uuidString
        let foodChangeType = EventType.foodChange.rawValue
        let autoKind = FeedRuleKind.autoFeeder.rawValue
        let legacyKind = ""
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petID &&
                    event.eventType == foodChangeType &&
                    (event.feedRuleKindRaw == autoKind || event.feedRuleKindRaw == legacyKind)
            },
            sortBy: [SortDescriptor(\Event.startDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Uses exact, finite lookups for each due occurrence. The legacy worker
    /// used to materialize every care-ledger row for a pet at launch; that
    /// makes a long-lived pet an unbounded startup read.
    private static func autoFeedDedupExists(
        key: String,
        petID: UUID,
        sourceEventID: UUID,
        dueDate: Date,
        context: ModelContext
    ) throws -> Bool {
        let petIDString = petID.uuidString
        let petKind = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingAction = CareType.feeding.rawValue
        let sourceEventIDString = sourceEventID.uuidString
        var ledgerDescriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petKind &&
                    event.subjectId == petIDString &&
                    event.eventKind == careKind &&
                    event.actionType == feedingAction &&
                    event.sourceEventId == sourceEventIDString &&
                    event.occurredAt == dueDate
            }
        )
        ledgerDescriptor.fetchLimit = 1
        if try !context.fetch(ledgerDescriptor).isEmpty {
            return true
        }

        var logDescriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.autoFeedDedupKey == key
            }
        )
        logDescriptor.fetchLimit = 1
        return try !context.fetch(logDescriptor).isEmpty
    }
}

/// The actor owns all startup auto-feed reads and writes. Its result is a
/// value-only cursor so the main actor never receives SwiftData models.
@ModelActor
actor StartupAutoFeederMaintenanceActor {
    func runBatch(
        cursor: StartupAutoFeederCursor,
        maximumPetCount: Int,
        deadline: Date,
        now: Date,
        calendar: Calendar
    ) throws -> StartupAutoFeederBatchResult {
        try StartupAutoFeederMaintenanceService.materializeBatch(
            context: modelContext,
            cursor: cursor,
            maximumPetCount: maximumPetCount,
            deadline: deadline,
            now: now,
            calendar: calendar
        )
    }
}

// MARK: - Legacy shop ownership migration

nonisolated struct StartupShopPurchaseMigrationCursor: Codable, Equatable, Sendable {
    var itemOffset: Int

    static let initial = StartupShopPurchaseMigrationCursor(itemOffset: 0)

    func normalized() -> StartupShopPurchaseMigrationCursor {
        StartupShopPurchaseMigrationCursor(itemOffset: max(0, itemOffset))
    }
}

nonisolated struct StartupShopPurchaseMigrationBatchResult: Equatable, Sendable {
    let nextCursor: StartupShopPurchaseMigrationCursor
    let processedItemCount: Int
    let insertedRecordCount: Int
    let didComplete: Bool
}

private nonisolated struct StartupShopPurchaseMigrationPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

nonisolated enum StartupShopPurchaseMigrationService {
    static func runBatch(
        context: ModelContext,
        eligibleItemIDs: [String],
        cursor: StartupShopPurchaseMigrationCursor,
        maximumItemCount: Int,
        deadline: Date,
        now: Date
    ) throws -> StartupShopPurchaseMigrationBatchResult {
        var nextCursor = cursor.normalized()
        let maximumItemCount = max(1, maximumItemCount)
        let itemIDs = Array(eligibleItemIDs.dropFirst(nextCursor.itemOffset).prefix(maximumItemCount))
        var processedItemCount = 0
        var insertedRecordCount = 0
        var didChange = false
        var reachedDeadline = false

        do {
            for itemID in itemIDs {
                try Task.checkCancellation()
                guard Date() < deadline else {
                    reachedDeadline = true
                    break
                }
                defer {
                    processedItemCount += 1
                    nextCursor.itemOffset += 1
                }

                guard try !ShopPurchaseRecordStore.isOwned(itemID: itemID, context: context) else { continue }
                let record = ShopPurchaseRecord(
                    transactionKey: "legacy:\(itemID)",
                    itemId: itemID,
                    buyerHumanId: nil,
                    purchasedAt: now,
                    sourceRaw: "legacyDefaults",
                    isLegacyImport: true,
                    createdAt: now
                )
                context.insert(record)
                CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: now)
                insertedRecordCount += 1
                didChange = true
            }

            try Task.checkCancellation()
            if didChange {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    throw StartupShopPurchaseMigrationPersistenceFailure(errorDescription: saveResult.errorDescription)
                }
            }

            let didComplete = !reachedDeadline && nextCursor.itemOffset >= eligibleItemIDs.count
            return StartupShopPurchaseMigrationBatchResult(
                nextCursor: didComplete ? .initial : nextCursor,
                processedItemCount: processedItemCount,
                insertedRecordCount: insertedRecordCount,
                didComplete: didComplete
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}

/// Legacy defaults are read on the visible coordinator, reduced to a small
/// value list, and then persisted only inside this background SwiftData actor.
@ModelActor
actor StartupShopPurchaseMigrationActor {
    func runBatch(
        eligibleItemIDs: [String],
        cursor: StartupShopPurchaseMigrationCursor,
        maximumItemCount: Int,
        deadline: Date,
        now: Date
    ) throws -> StartupShopPurchaseMigrationBatchResult {
        try StartupShopPurchaseMigrationService.runBatch(
            context: modelContext,
            eligibleItemIDs: eligibleItemIDs,
            cursor: cursor,
            maximumItemCount: maximumItemCount,
            deadline: deadline,
            now: now
        )
    }
}
