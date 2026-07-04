import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct SharedPetActionRecorderTests {
    @Test func resolverKeepsSourceFirstAndFiltersSameSpeciesLiveTargets() {
        let source = Pet(name: "Milo", species: "cat")
        let sibling = Pet(name: "Luna", species: " 猫 ")
        let dog = Pet(name: "Biscuit", species: "狗")
        let owl = Pet(name: "Hoot", species: "猫头鹰")
        let memorial = Pet(name: "Star", species: "cat")
        source.createdAt = Date(timeIntervalSince1970: 10)
        sibling.createdAt = Date(timeIntervalSince1970: 1)
        owl.createdAt = Date(timeIntervalSince1970: 2)
        memorial.passedAwayDate = Date()

        let targets = SharedPetTargetResolver.sameSpeciesTargets(
            sourcePet: source,
            allPets: [sibling, owl, dog, memorial, source],
            explicitTargetIds: [sibling.id, owl.id]
        )

        #expect(targets.map(\.id) == [source.id, sibling.id])
        #expect(PetSpeciesKey.normalized("猫头鹰") == "bird")
    }

    @Test func sharedLitterWritesOneSessionTwoCareLogsAndNoPottyProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }
        let dependencies = CareEventServiceDependencies.live()

        let reward = CareEventService.recordSharedLitterCare(
            sourcePet: first,
            targets: [first, second],
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 1000),
            dependencies: dependencies
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())

        #expect(sessions.count == 1)
        #expect(sessions.first?.actionKind == .litterScoop)
        #expect(Set(sessions.first?.targetPetIds ?? []) == Set([first.id.uuidString, second.id.uuidString]))
        #expect(careLogs.count == 2)
        #expect(Set(careLogs.map(\.sharedSessionId)) == Set([sessions[0].id.uuidString]))
        #expect(careLogs.allSatisfy { $0.careType == .litter })
        #expect(pottyLogs.isEmpty)
        #expect(reward.humanGot == 2)
        #expect(reward.petGot == 2)
        #expect(human.coconutBalance == 2)
        #expect(first.coconutBalance == 1)
        #expect(second.coconutBalance == 1)
    }

    @Test func sharedHygieneWritesSessionIdAndCascadeFindsChildren() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "cat")
        let second = Pet(name: "Luna", species: "cat")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .hygiene,
                sourcePet: first,
                targets: [first, second],
                date: Date(timeIntervalSince1970: 2_100_000_000),
                executorId: human.id.uuidString,
                childLogStrategy: .hygiene(type: .bath)
            ),
            context: context
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())

        #expect(result.didWriteFact)
        #expect(result.hygieneLogIDs.count == 2)
        #expect(hygieneLogs.count == 2)
        #expect(Set(hygieneLogs.map(\.sharedSessionId)) == Set([session.id.uuidString]))

        let deleteResult = SharedCareSessionMaintenance.deleteCascade(session, context: context)
        let remainingHygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())

        #expect(Set(deleteResult.hygieneLogIDs) == Set(hygieneLogs.map(\.id)))
        #expect(remainingHygieneLogs.isEmpty)
    }

    @Test func sharedFeedAndWaterAllocateRemaindersToSourcePet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "cat")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2000)
        )
        _ = CareEventService.recordSharedWatering(
            sourcePet: first,
            targets: [second],
            totalMl: 301,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2100)
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let feedLogs = careLogs.filter { $0.careType == .feeding }.sorted { ($0.pet?.id == first.id ? 0 : 1) < ($1.pet?.id == first.id ? 0 : 1) }
        let waterLogs = careLogs.filter { $0.careType == .watering }.sorted { ($0.pet?.id == first.id ? 0 : 1) < ($1.pet?.id == first.id ? 0 : 1) }

        #expect(sessions.count == 2)
        #expect(feedLogs.map(\.amountGrams) == [61, 60])
        #expect(waterLogs.map(\.amountMl) == [151, 150])
        #expect(Set(feedLogs.map(\.sharedSessionId)).count == 1)
        #expect(Set(waterLogs.map(\.sharedSessionId)).count == 1)
        #expect(feedLogs.map(\.note) == ["", ""])
        #expect(waterLogs.map(\.note) == ["", ""])
        #expect(feedLogs.allSatisfy { !SharedCareMetadata.visibleNote($0.note).contains("stock") })
        #expect(feedLogs.allSatisfy { !$0.note.contains(SharedCareMetadata.stockOwnerKey) })
    }

    @Test func sharedFeedStockDeductionReadsStructuredSessionFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2200)
        )

        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let session = try #require(sessions.first)
        let ownerLog = try #require(feedLogs.first { $0.pet?.id.uuidString == session.stockOwnerPetId })
        let nonOwnerLog = try #require(feedLogs.first { $0.id != ownerLog.id })

        #expect(session.totalAmountGrams == 121)
        #expect(ownerLog.note.contains(SharedCareMetadata.stockTotalKey) == false)
        #expect(ownerLog.note.contains(SharedCareMetadata.stockOwnerKey) == false)
        #expect(feedLogs.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(FeedStockCalculator.stockDeductionAmount(for: ownerLog, pet: ownerLog.pet ?? first, sharedCareSessions: sessions) == 121)
        #expect(FeedStockCalculator.stockDeductionAmount(for: nonOwnerLog, pet: nonOwnerLog.pet ?? second, sharedCareSessions: sessions) == 0)
        #expect(FeedStockCalculator.stockDeductionAmount(for: ownerLog, pet: ownerLog.pet ?? first) == 0)
    }

    @Test func reconcileStripsLegacySharedNoteMetadataInsteadOfRewritingIt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2210)
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let allCareLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let feedLogs = allCareLogs.filter { $0.careType == .feeding }
        for log in feedLogs {
            log.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.feedNotePrefix,
                sessionId: session.id,
                stockTotalGrams: 121,
                isStockOwner: log.pet?.id.uuidString == session.stockOwnerPetId,
                targetCount: 2,
                visibleNote: "Dinner note"
            )
        }
        session.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.feedNotePrefix,
            sessionId: session.id,
            targetCount: 2,
            visibleNote: "Session note"
        )

        SharedCareSessionMaintenance.reconcile(
            session,
            context: context,
            reconciledAt: Date(timeIntervalSince1970: 2220)
        )

        #expect(session.note == "Session note")
        #expect(feedLogs.allSatisfy { $0.note == "Dinner note" })
        #expect(feedLogs.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(session.targetPetIds.count == 2)
        #expect(session.totalAmountGrams == 121)
    }

    @Test func legacyNoteCleanupRecoversStructuredFieldsAndMarksChangedFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2230)
        )
        _ = ExpenseCommandService.recordSharedPetExpense(
            sourcePet: first,
            targets: [first, second],
            amount: 40,
            date: Date(timeIntervalSince1970: 2240),
            category: .food,
            note: "Shared bag",
            context: context,
            executorId: human.id.uuidString
        )
        _ = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 900,
            endDate: Date(timeIntervalSince1970: 2260),
            context: context,
            executorId: human.id.uuidString,
            startDate: Date(timeIntervalSince1970: 2250),
            behaviorNotes: "Walk note"
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let feedSession = try #require(sessions.first { $0.actionKind == .feeding })
        let expenseSession = try #require(sessions.first { $0.actionKind == .expense })
        let walkSession = try #require(sessions.first { $0.actionKind == .walk })
        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>())
            .filter { $0.sharedSessionId == feedSession.id.uuidString }
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        feedSession.targetPetIdsRaw = ""
        feedSession.totalAmountGrams = 0
        feedSession.stockOwnerPetId = ""
        feedSession.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.feedNotePrefix,
            sessionId: feedSession.id,
            targetCount: 2,
            visibleNote: "Feed session"
        )
        expenseSession.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.expenseNotePrefix,
            sessionId: expenseSession.id,
            targetCount: 2,
            visibleNote: "Expense session"
        )
        walkSession.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.walkNotePrefix,
            sessionId: walkSession.id,
            targetCount: 2,
            visibleNote: "Walk session"
        )
        for log in feedLogs {
            log.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.feedNotePrefix,
                sessionId: feedSession.id,
                stockTotalGrams: 121,
                isStockOwner: log.pet?.id == second.id,
                targetCount: 2,
                visibleNote: "Dinner note"
            )
        }
        feedLogs.first?.sharedSessionId = ""
        for log in expenseLogs {
            log.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.expenseNotePrefix,
                sessionId: expenseSession.id,
                targetCount: 2,
                visibleNote: "Shared bag"
            )
        }
        expenseLogs.first?.sharedSessionId = ""
        for log in walkLogs {
            log.behaviorNotes = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.walkNotePrefix,
                sessionId: walkSession.id,
                targetCount: 2,
                visibleNote: "Walk note"
            )
        }
        walkLogs.first?.sharedSessionId = ""
        for event in ledgerEvents {
            event.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.careNotePrefix,
                sessionId: feedSession.id,
                targetCount: 2,
                visibleNote: "Ledger note"
            )
        }
        ledgerEvents.first?.legacyModelName = nil
        ledgerEvents.first?.legacyModelId = nil
        try context.save()

        let result = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            cleanedAt: Date(timeIntervalSince1970: 2270)
        )
        let secondResult = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            cleanedAt: Date(timeIntervalSince1970: 2280)
        )
        let feedSessionState = try CloudSyncMetadataService.state(
            entityName: "SharedCareSession",
            localRecordId: feedSession.id,
            context: context
        )
        let careLogState = try CloudSyncMetadataService.state(
            entityName: "PetCareLog",
            localRecordId: #require(result.careLogIDs.first),
            context: context
        )

        #expect(result.sessionIDs.count == 3)
        #expect(result.careLogIDs.count == feedLogs.count)
        #expect(result.expenseLogIDs.count == expenseLogs.count)
        #expect(result.walkLogIDs.count == walkLogs.count)
        #expect(result.ledgerEventIDs.count == ledgerEvents.count)
        #expect(result.missingSessionIDs.isEmpty)
        #expect(result.skippedOrphanCount == 0)
        #expect(secondResult.cleanedCount == 0)
        #expect(secondResult.skippedOrphanCount == 0)
        #expect(feedSession.note == "Feed session")
        #expect(expenseSession.note == "Expense session")
        #expect(walkSession.note == "Walk session")
        #expect(feedSession.targetPetIds.count == 2)
        #expect(feedSession.totalAmountGrams == 121)
        #expect(feedSession.stockOwnerPetId == second.id.uuidString)
        #expect(feedLogs.allSatisfy { $0.note == "Dinner note" })
        #expect(feedLogs.allSatisfy { $0.sharedSessionId == feedSession.id.uuidString })
        #expect(expenseLogs.allSatisfy { $0.note == "Shared bag" })
        #expect(expenseLogs.allSatisfy { $0.sharedSessionId == expenseSession.id.uuidString })
        #expect(walkLogs.allSatisfy { $0.behaviorNotes == "Walk note" })
        #expect(walkLogs.allSatisfy { $0.sharedSessionId == walkSession.id.uuidString })
        #expect(ledgerEvents.allSatisfy { $0.note == "Ledger note" })
        #expect(feedLogs.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(expenseLogs.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(walkLogs.allSatisfy { $0.behaviorNotes?.contains("ohana_shared_") != true })
        #expect(ledgerEvents.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(feedSessionState?.hasPendingLocalChanges == true)
        #expect(careLogState?.hasPendingLocalChanges == true)
    }

    @Test func legacyNoteCleanupLeavesOrphanMetadataWhenStructuredSessionIsMissing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Milo", species: "猫")
        let orphanSessionID = UUID()
        let orphanLog = PetCareLog(
            date: Date(timeIntervalSince1970: 2290),
            type: .feeding,
            amountGrams: 61,
            note: SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.feedNotePrefix,
                sessionId: orphanSessionID,
                stockTotalGrams: 121,
                isStockOwner: true,
                targetCount: 2,
                visibleNote: "Orphan dinner"
            ),
            pet: pet
        )
        let orphanEvent = CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 2291),
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: "feeding",
            amountValue: 61,
            amountUnit: "g",
            note: SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.careNotePrefix,
                sessionId: orphanSessionID,
                targetCount: 2,
                visibleNote: "Orphan ledger"
            ),
            legacyModelName: "PetCareLog",
            legacyModelId: orphanLog.id.uuidString
        )
        context.insert(pet)
        context.insert(orphanLog)
        context.insert(orphanEvent)
        try context.save()

        let result = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            cleanedAt: Date(timeIntervalSince1970: 2300)
        )

        #expect(result.cleanedCount == 0)
        #expect(result.missingSessionIDs == [orphanSessionID])
        #expect(result.skippedOrphanCareLogIDs == [orphanLog.id])
        #expect(result.skippedOrphanLedgerEventIDs == [orphanEvent.id])
        #expect(result.skippedOrphanCount == 2)
        #expect(orphanLog.note.contains("ohana_shared_"))
        #expect(orphanEvent.note.contains("ohana_shared_"))
        #expect(orphanLog.note.contains(SharedCareMetadata.stockTotalKey))
        #expect(orphanLog.note.contains(SharedCareMetadata.targetCountKey))

        let diagnostics = SharedCareSessionMaintenance.legacyOrphanNoteDiagnostics(context: context)
        let careDiagnostic = try #require(diagnostics.first { $0.sourceModelName == String(describing: PetCareLog.self) })
        let ledgerDiagnostic = try #require(diagnostics.first { $0.sourceModelName == String(describing: CareLedgerEvent.self) })

        #expect(diagnostics.count == 2)
        #expect(careDiagnostic.recordID == orphanLog.id)
        #expect(careDiagnostic.missingSessionID == orphanSessionID)
        #expect(careDiagnostic.targetCount == 2)
        #expect(careDiagnostic.stockTotalGrams == 121)
        #expect(careDiagnostic.isStockOwner)
        #expect(careDiagnostic.legacyModelName == nil)
        #expect(careDiagnostic.legacyModelId == nil)
        #expect(careDiagnostic.visibleNoteCharacterCount == "Orphan dinner".count)
        #expect(ledgerDiagnostic.recordID == orphanEvent.id)
        #expect(ledgerDiagnostic.missingSessionID == orphanSessionID)
        #expect(ledgerDiagnostic.legacyModelName == "PetCareLog")
        #expect(ledgerDiagnostic.legacyModelId == orphanLog.id.uuidString)
        #expect(ledgerDiagnostic.visibleNoteCharacterCount == "Orphan ledger".count)
    }

    @Test func backupImportCleansRecoverableLegacySharedCareNotes() throws {
        let source = try makeContainer()
        let sourceContext = source.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        sourceContext.insert(human)
        sourceContext.insert(first)
        sourceContext.insert(second)
        try sourceContext.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: sourceContext,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2310)
        )

        let feedSession = try #require(try sourceContext.fetch(FetchDescriptor<SharedCareSession>()).first)
        let feedLogs = try sourceContext.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try sourceContext.fetch(FetchDescriptor<CareLedgerEvent>())

        feedSession.targetPetIdsRaw = ""
        feedSession.totalAmountGrams = 0
        feedSession.stockOwnerPetId = ""
        feedSession.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.feedNotePrefix,
            sessionId: feedSession.id,
            targetCount: 2,
            visibleNote: "Feed session"
        )
        for log in feedLogs {
            log.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.feedNotePrefix,
                sessionId: feedSession.id,
                stockTotalGrams: 121,
                isStockOwner: log.pet?.id == second.id,
                targetCount: 2,
                visibleNote: "Dinner note"
            )
        }
        for event in ledgerEvents {
            event.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.careNotePrefix,
                sessionId: feedSession.id,
                targetCount: 2,
                visibleNote: "Ledger note"
            )
        }
        try sourceContext.save()

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: sourceContext)
        let target = try makeContainer()
        let targetContext = target.mainContext

        try TestDataBackupManagerProjection.manager.applyBackup(
            backup,
            context: targetContext,
            projectionManager: nil
        )

        let restoredSession = try #require(try targetContext.fetch(FetchDescriptor<SharedCareSession>()).first)
        let restoredLogs = try targetContext.fetch(FetchDescriptor<PetCareLog>())
        let restoredEvents = try targetContext.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(restoredSession.note == "Feed session")
        #expect(restoredSession.targetPetIds.count == 2)
        #expect(restoredSession.totalAmountGrams == 121)
        #expect(restoredSession.stockOwnerPetId == second.id.uuidString)
        #expect(restoredLogs.count == 2)
        #expect(restoredLogs.allSatisfy { $0.note == "Dinner note" })
        #expect(restoredLogs.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(restoredEvents.allSatisfy { $0.note == "Ledger note" })
        #expect(restoredEvents.allSatisfy { !$0.note.contains("ohana_shared_") })
    }

    @Test func legacyNoteMaintenanceRunsOnceAndStoresVersion() throws {
        let suiteName = "SharedCareLegacyNoteMaintenance-\(UUID().uuidString)"
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2320)
        )

        let feedSession = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        feedSession.targetPetIdsRaw = ""
        feedSession.totalAmountGrams = 0
        feedSession.stockOwnerPetId = ""
        feedSession.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.feedNotePrefix,
            sessionId: feedSession.id,
            targetCount: 2,
            visibleNote: "Feed session"
        )
        for log in feedLogs {
            log.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.feedNotePrefix,
                sessionId: feedSession.id,
                stockTotalGrams: 121,
                isStockOwner: log.pet?.id == second.id,
                targetCount: 2,
                visibleNote: "Dinner note"
            )
        }
        for event in ledgerEvents {
            event.note = SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.careNotePrefix,
                sessionId: feedSession.id,
                targetCount: 2,
                visibleNote: "Ledger note"
            )
        }
        try context.save()

        let firstRun = SharedCareLegacyNoteMaintenanceService.runIfNeeded(
            context: context,
            defaults: defaults,
            cleanedAt: Date(timeIntervalSince1970: 2330)
        )
        let secondRun = SharedCareLegacyNoteMaintenanceService.runIfNeeded(
            context: context,
            defaults: defaults,
            cleanedAt: Date(timeIntervalSince1970: 2340)
        )

        #expect(firstRun.didRun)
        #expect(firstRun.cleanup.cleanedCount > 0)
        #expect(defaults.integer(forKey: SharedCareLegacyNoteMaintenanceService.completedVersionKey) == SharedCareLegacyNoteMaintenanceService.currentVersion)
        #expect(secondRun.didRun == false)
        #expect(secondRun.cleanup.cleanedCount == 0)
        #expect(feedSession.note == "Feed session")
        #expect(feedSession.targetPetIds.count == 2)
        #expect(feedSession.totalAmountGrams == 121)
        #expect(feedSession.stockOwnerPetId == second.id.uuidString)
        #expect(feedLogs.allSatisfy { $0.note == "Dinner note" })
        #expect(ledgerEvents.allSatisfy { $0.note == "Ledger note" })
    }

    @Test func feedStockSnapshotReadsStructuredSharedSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        first.foodTrackingMode = .precise
        first.restockWeight = 1
        first.dailyPortionGrams = 60
        first.restockDate = Date(timeIntervalSince1970: 1000)
        second.foodTrackingMode = .precise
        second.restockWeight = 1
        second.dailyPortionGrams = 60
        second.restockDate = Date(timeIntervalSince1970: 1000)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 120,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2200)
        )
        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let firstSnapshot = FeedStockCalculator.snapshot(
            for: first,
            careLogs: feedLogs,
            sharedCareSessions: sessions,
            now: Date(timeIntervalSince1970: 2300)
        )
        let secondSnapshot = FeedStockCalculator.snapshot(
            for: second,
            careLogs: feedLogs,
            sharedCareSessions: sessions,
            now: Date(timeIntervalSince1970: 2300)
        )

        #expect(firstSnapshot.remainingGrams == 880)
        #expect(firstSnapshot.consumedGrams == 120)
        #expect(secondSnapshot.remainingGrams == 1000)
        #expect(secondSnapshot.consumedGrams == 0)
    }

    @Test func sharedSessionFactIsMarkedForCloudSyncAndTimelineUsesSessionTotals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "cat")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2250)
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let sessionState = try CloudSyncMetadataService.state(
            entityName: "SharedCareSession",
            localRecordId: session.id,
            context: context
        )
        let firstPetID = first.id
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.pet?.id == firstPetID
            }
        ))
        let item = try #require(PetTimelineItemsBuilder.items(
            for: first,
            sourceRows: PetTimelineSourceRows(careLogs: careLogs),
            sharedCareSessions: [session],
            l: L10n("en")
        ).first { $0.type == "care" })

        #expect(sessionState?.hasPendingLocalChanges == true)
        #expect(sessionState?.isDeletionTombstone == false)
        #expect(item.id == session.id)
        #expect(item.title == "Shared feeding · 2 pets")
        #expect(item.subtitle.contains("121 g"))
        #expect(item.subtitle.contains("Dry food"))
    }

    @Test func petPhotoAlbumRenderDataGroupsByMonthAndSortsPhotos() {
        let imageData = Data(repeating: 1, count: 12)
        let januaryEarly = PetPhotoLog(
            imageData: imageData,
            date: makeDate(year: 2026, month: 1, day: 2, hour: 10)
        )
        let januaryLate = PetPhotoLog(
            imageData: imageData,
            date: makeDate(year: 2026, month: 1, day: 20, hour: 18)
        )
        let february = PetPhotoLog(
            imageData: imageData,
            date: makeDate(year: 2026, month: 2, day: 3, hour: 9)
        )

        let renderData = PetPhotoAlbumRenderData.build(photoLogs: [januaryEarly, february, januaryLate])

        #expect(renderData.groups.count == 2)
        #expect(renderData.groups[0].photos.map(\.id) == [february.id])
        #expect(renderData.groups[1].photos.map(\.id) == [januaryLate.id, januaryEarly.id])
        #expect(renderData.groups[0].monthStart > renderData.groups[1].monthStart)
    }

    @Test func updatingSharedFeedLogReconcilesSessionAndRestagesCloudSync() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 120,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2260)
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let editedLog = try #require(feedLogs.first { $0.pet?.id == first.id })
        let otherLog = try #require(feedLogs.first { $0.id != editedLog.id })
        let sessionState = try #require(try CloudSyncMetadataService.state(
            entityName: "SharedCareSession",
            localRecordId: session.id,
            context: context
        ))
        let logState = try #require(try CloudSyncMetadataService.state(
            entityName: "PetCareLog",
            localRecordId: editedLog.id,
            context: context
        ))
        CloudSyncMetadataService.markSynced(
            sessionState,
            ckRecordName: "session-\(session.id.uuidString)",
            ckChangeTag: "1",
            ckZoneName: "zone",
            syncedAt: Date(timeIntervalSince1970: 2300)
        )
        CloudSyncMetadataService.markSynced(
            logState,
            ckRecordName: "log-\(editedLog.id.uuidString)",
            ckChangeTag: "1",
            ckZoneName: "zone",
            syncedAt: Date(timeIntervalSince1970: 2300)
        )
        try context.save()

        _ = FeedRecordCommand.updateLog(
            editedLog,
            grams: 80,
            date: Date(timeIntervalSince1970: 2400),
            pet: first,
            allEvents: [],
            context: context
        )

        let updatedSession = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let updatedSessionState = try #require(try CloudSyncMetadataService.state(
            entityName: "SharedCareSession",
            localRecordId: updatedSession.id,
            context: context
        ))
        let updatedLogState = try #require(try CloudSyncMetadataService.state(
            entityName: "PetCareLog",
            localRecordId: editedLog.id,
            context: context
        ))

        #expect(updatedSession.totalAmountGrams == 80 + otherLog.amountGrams)
        #expect(updatedSessionState.hasPendingLocalChanges)
        #expect(updatedSessionState.isDeletionTombstone == false)
        #expect(updatedLogState.hasPendingLocalChanges)
        #expect(editedLog.date == Date(timeIntervalSince1970: 2400))
    }

    @Test func deletingSharedFeedStockOwnerMigratesSessionDeductionToSurvivingLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 121,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2200)
        )

        let initialSession = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let ownerLog = try #require(feedLogs.first { $0.pet?.id.uuidString == initialSession.stockOwnerPetId })
        let survivor = try #require(feedLogs.first { $0.id != ownerLog.id })

        _ = PetCareTrackingCommandService.deleteCareLog(ownerLog, pet: ownerLog.pet ?? first, context: context)

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let remainingFeedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let remainingLog = try #require(remainingFeedLogs.first)

        #expect(sessions.count == 1)
        #expect(sessions.first?.totalAmountGrams == survivor.amountGrams)
        #expect(sessions.first?.targetPetIds == [survivor.pet?.id.uuidString ?? ""])
        #expect(remainingFeedLogs.count == 1)
        #expect(sessions.first?.stockOwnerPetId == survivor.pet?.id.uuidString)
        #expect(remainingLog.note.contains(SharedCareMetadata.stockOwnerKey) == false)
        #expect(FeedStockCalculator.stockDeductionAmount(for: remainingLog, pet: remainingLog.pet ?? second, sharedCareSessions: sessions) == survivor.amountGrams)
    }

    @Test func deletingPetReconcilesSurvivingSharedFeedSessionStockOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        first.foodTrackingMode = .precise
        first.restockWeight = 1
        first.dailyPortionGrams = 60
        first.restockDate = Date(timeIntervalSince1970: 1000)
        second.foodTrackingMode = .precise
        second.restockWeight = 1
        second.dailyPortionGrams = 60
        second.restockDate = Date(timeIntervalSince1970: 1000)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 120,
            foodKind: .dry,
            context: context,
            date: Date(timeIntervalSince1970: 2260)
        )

        _ = MemberDeletionCommandService.deletePet(first, context: context, userDefaults: UserDefaults.standard)

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let session = try #require(sessions.first)
        let feedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let visibleLog = try #require(feedLogs.first)
        let petState = try #require(try CloudSyncMetadataService.state(
            entityName: "Pet",
            localRecordId: first.id,
            context: context
        ))

        #expect(sessions.count == 1)
        #expect(session.targetPetIds == [second.id.uuidString])
        #expect(session.sourcePetId.isEmpty)
        #expect(session.stockOwnerPetId.isEmpty)
        #expect(session.totalAmountGrams == 60)
        #expect(feedLogs.count == 1)
        #expect(visibleLog.pet?.id == second.id)
        #expect(FeedStockCalculator.stockDeductionAmount(for: visibleLog, pet: second, sharedCareSessions: sessions) == 0)
        let secondSnapshot = FeedStockCalculator.snapshot(
            for: second,
            careLogs: feedLogs,
            sharedCareSessions: sessions,
            now: Date(timeIntervalSince1970: 2300)
        )
        #expect(secondSnapshot.remainingGrams == 1000)
        #expect(petState.hasPendingLocalChanges)
        #expect(petState.isDeletionTombstone)
    }

    @Test func deletingSharedSessionCascadeRemovesChildrenLedgerAndMarksTombstone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: first,
            targets: [first, second],
            totalGrams: 120,
            foodKind: .dry,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2260)
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let duplicatedLog = try #require(careLogs.first)
        let duplicateMatchingLedger = CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 2265),
            subjectKind: .pet,
            subjectId: duplicatedLog.pet?.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .service,
            legacyModelName: "PetCareLog",
            legacyModelId: duplicatedLog.id.uuidString
        )
        let unrelatedSameModelLedger = CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 2266),
            subjectKind: .pet,
            subjectId: first.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .service,
            legacyModelName: "PetCareLog",
            legacyModelId: "unrelated-care-log-id"
        )
        context.insert(duplicateMatchingLedger)
        context.insert(unrelatedSameModelLedger)
        try context.save()

        let result = SharedCareSessionMaintenance.deleteCascade(
            session,
            context: context,
            deletedByHumanId: human.id.uuidString,
            deletedAt: Date(timeIntervalSince1970: 2270)
        )
        let sessionState = try CloudSyncMetadataService.state(
            entityName: "SharedCareSession",
            localRecordId: session.id,
            context: context
        )
        #expect(result.sessionID == session.id)
        #expect(result.careLogIDs.count == 2)
        #expect(result.deletedChildCount == 2)
        #expect(result.ledgerEventIDs.count == 3)
        #expect(result.ledgerEventIDs.contains(duplicateMatchingLedger.id))
        #expect(!result.ledgerEventIDs.contains(unrelatedSameModelLedger.id))
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        let remainingLedger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(remainingLedger.map(\.id) == [unrelatedSameModelLedger.id])
        #expect(sessionState?.isDeletionTombstone == true)
        #expect(sessionState?.deletedByHumanId == CloudSyncRecordState.normalizedRecordId(human.id))
    }

    @Test func sharedExpenseDistributesCurrencyRemainderAndUsesCurrentCurrency() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        let third = Pet(name: "Nori", species: "猫")
        context.insert(first)
        context.insert(second)
        context.insert(third)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        _ = ExpenseCommandService.recordSharedPetExpense(
            sourcePet: first,
            targets: [first, second, third],
            amount: 100,
            date: Date(timeIntervalSince1970: 2300),
            category: .food,
            note: "Shared bag",
            context: context
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())

        #expect(sessions.first?.currencyCode == AppCurrency.code)
        #expect(expenseLogs.map(\.amount).sorted() == [33.33, 33.33, 33.34])
        #expect(expenseLogs.reduce(0) { $0 + $1.amount } == 100)
        #expect(expenseLogs.allSatisfy { $0.note == "Shared bag" })
        #expect(expenseLogs.allSatisfy { !$0.note.contains("ohana_shared_") })
    }

    @Test func unknownSharedPottyCanBeClaimedByPetAndLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        let log = try #require(CareEventService.recordUnknownSharedPotty(
            sourcePet: first,
            targets: [first, second],
            type: .softPoop,
            context: context,
            date: Date(timeIntervalSince1970: 3000)
        ))

        let result = PetPottyCommandService.claimUnknownPottyLog(log, pet: second, context: context)
        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(result.petID == second.id)
        #expect(log.pet?.id == second.id)
        #expect(sessions.first?.sourcePetId == second.id.uuidString)
        #expect(sessions.first?.targetPetIds == [second.id.uuidString])
        #expect(ledgerEvents.first?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(ledgerEvents.first?.subjectId == second.id.uuidString)
    }

    @Test func unknownSharedPottyWritesUnknownGroupFactWithoutRewardOrPetProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: nil)
        defer { cleanup() }

        let log = try #require(CareEventService.recordUnknownSharedPotty(
            sourcePet: first,
            targets: [first, second],
            type: .softPoop,
            context: context,
            date: Date(timeIntervalSince1970: 3000)
        ))

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let ledgerEvent = try #require(ledgerEvents.first)

        #expect(sessions.count == 1)
        #expect(sessions.first?.actionKind == .pottyUnknown)
        #expect(pottyLogs.map(\.id) == [log.id])
        #expect(pottyLogs.first?.pet == nil)
        #expect(pottyLogs.first?.sharedSessionId == sessions.first?.id.uuidString)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvent.note == "")
        #expect(ledgerEvents.allSatisfy { !$0.note.contains("ohana_shared_") })
        #expect(first.coconutBalance == 0)
        #expect(second.coconutBalance == 0)
    }

    @Test func unknownSharedPottyNoopReturnsNilWithoutDetachedFact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = Pet(name: "Milo", species: "猫")
        source.passedAwayDate = Date(timeIntervalSinceReferenceDate: 1)
        let target = Pet(name: "Luna", species: "猫")
        context.insert(source)
        context.insert(target)
        try context.save()

        let log = CareEventService.recordUnknownSharedPotty(
            sourcePet: source,
            targets: [target],
            type: .softPoop,
            context: context,
            date: Date(timeIntervalSinceReferenceDate: 3000)
        )

        #expect(log?.id == nil)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func sharedEnvironmentExpenseAndWalkUseUnifiedSessionProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let first = Pet(name: "Fin", species: "鱼")
        let second = Pet(name: "Glimmer", species: "fish")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: human.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedCare(
            sourcePet: first,
            targets: [first, second],
            type: .filterClean,
            actionKind: .filterClean,
            context: context,
            executorId: human.id.uuidString,
            reward: .general(humanReward: 25, petReward: 2, emoji: CareType.filterClean.emoji, title: "共同清理滤材"),
            rewardTitle: "共同清理滤材 · 2只",
            date: Date(timeIntervalSince1970: 4000)
        )
        _ = ExpenseCommandService.recordSharedPetExpense(
            sourcePet: first,
            targets: [first, second],
            amount: 40,
            date: Date(timeIntervalSince1970: 4100),
            category: .toys,
            note: "Shared tunnel",
            context: context,
            executorId: human.id.uuidString
        )
        _ = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 1200,
            endDate: Date(timeIntervalSince1970: 4300),
            context: context,
            executorId: human.id.uuidString,
            startDate: Date(timeIntervalSince1970: 4200)
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())

        #expect(Set(sessions.map(\.actionKind)) == Set([.filterClean, .expense, .walk]))
        #expect(careLogs.count(where: { $0.careType == .filterClean }) == 2)
        #expect(expenseLogs.map(\.amount).sorted() == [20, 20])
        #expect(Set(expenseLogs.map(\.sharedSessionId)).count == 1)
        #expect(walkLogs.map(\.distanceMeters).sorted() == [1200, 1200])
        #expect(Set(walkLogs.map(\.sharedSessionId)).count == 1)
    }

    @Test func sharedWalkStoresMultipleExecutorsOnSessionLogsAndLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let primary = Human(name: "Guan")
        let coWalker = Human(name: "Mia")
        let first = Pet(name: "Biscuit", species: "狗")
        let second = Pet(name: "Toast", species: "dog")
        context.insert(primary)
        context.insert(coWalker)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: primary.id.uuidString)
        defer { cleanup() }

        _ = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 1200,
            endDate: Date(timeIntervalSince1970: 6200),
            context: context,
            executorId: primary.id.uuidString,
            executorIds: [primary.id.uuidString, coWalker.id.uuidString],
            startDate: Date(timeIntervalSince1970: 6100)
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.eventKind == CareLedgerEventKind.walk.rawValue }
        let expectedExecutorIds = [primary.id.uuidString, coWalker.id.uuidString]

        #expect(sessions.count == 1)
        #expect(sessions.first?.executorId == primary.id.uuidString)
        #expect(sessions.first?.executorIds == expectedExecutorIds)
        #expect(walkLogs.count == 2)
        #expect(walkLogs.allSatisfy { $0.executorId == primary.id.uuidString })
        #expect(walkLogs.allSatisfy { $0.executorIds == expectedExecutorIds })
        #expect(Set(walkLogs.map(\.sharedSessionId)) == Set(sessions.map(\.id.uuidString)))
        #expect(ledgerEvents.count == 2)
        #expect(ledgerEvents.allSatisfy { $0.actorId == primary.id.uuidString })
        #expect(ledgerEvents.contains { $0.metadataJSON.contains(coWalker.id.uuidString) })
    }

    @Test func sharedWalkWritesFactWhenSecondaryExecutorHasPassedAway() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let primary = Human(name: "Guan")
        let coWalker = Human(name: "Mia")
        coWalker.passedAwayDate = Date(timeIntervalSince1970: 6000)
        let first = Pet(name: "Biscuit", species: "狗")
        let second = Pet(name: "Toast", species: "dog")
        context.insert(primary)
        context.insert(coWalker)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: primary.id.uuidString)
        defer { cleanup() }

        let result = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 1200,
            endDate: Date(timeIntervalSince1970: 6200),
            context: context,
            executorId: primary.id.uuidString,
            executorIds: [primary.id.uuidString, coWalker.id.uuidString],
            startDate: Date(timeIntervalSince1970: 6100)
        )

        #expect(result.didWriteFact)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains { $0.eventKind == CareLedgerEventKind.walk.rawValue })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains { $0.ownerId == primary.id.uuidString && $0.delta > 0 })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).allSatisfy { $0.ownerId != coWalker.id.uuidString })
    }

    @Test func sharedWalkWritesFactWhenSecondaryExecutorIsMissing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let primary = Human(name: "Guan")
        let first = Pet(name: "Biscuit", species: "狗")
        let second = Pet(name: "Toast", species: "dog")
        context.insert(primary)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: primary.id.uuidString)
        defer { cleanup() }
        let missingExecutorID = UUID().uuidString

        let result = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 1200,
            endDate: Date(timeIntervalSince1970: 6200),
            context: context,
            executorId: primary.id.uuidString,
            executorIds: [primary.id.uuidString, missingExecutorID],
            startDate: Date(timeIntervalSince1970: 6100)
        )

        #expect(result.didWriteFact)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains { $0.eventKind == CareLedgerEventKind.walk.rawValue })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains { $0.ownerId == primary.id.uuidString && $0.delta > 0 })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).allSatisfy { $0.ownerId != missingExecutorID })
    }

    @Test func backupRoundTripsSharedSessionExpenseAndWalkFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let primary = Human(name: "Guan")
        let coWalker = Human(name: "Mia")
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(primary)
        context.insert(coWalker)
        context.insert(first)
        context.insert(second)
        try context.save()

        let cleanup = isolateEconomy(activeHumanID: primary.id.uuidString)
        defer { cleanup() }

        _ = ExpenseCommandService.recordSharedPetExpense(
            sourcePet: first,
            targets: [first, second],
            amount: 30,
            date: Date(timeIntervalSince1970: 5000),
            category: .food,
            note: "Shared food bag",
            context: context
        )
        _ = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 900,
            endDate: Date(timeIntervalSince1970: 5200),
            context: context,
            executorId: primary.id.uuidString,
            executorIds: [primary.id.uuidString, coWalker.id.uuidString],
            startDate: Date(timeIntervalSince1970: 5100),
            behaviorNotes: "Park loop",
            moodRating: 5
        )

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: context)
        let data = try TestDataBackupManagerProjection.manager.encode(backup)
        let decoded = try JSONDecoder().decode(OhanaBackup.self, from: data)

        #expect(decoded.sharedCareSessions?.contains { $0.totalExpenseAmount == 30 && $0.expenseCategoryRaw == ExpenseCategory.food.rawValue } == true)
        #expect(decoded.petExpenseLogs.contains { $0.sharedSessionId?.isEmpty == false })
        #expect(decoded.petWalkLogs.contains { $0.sharedSessionId?.isEmpty == false })
        #expect(decoded.sharedCareSessions?.contains { $0.executorIdsRaw?.contains(coWalker.id.uuidString) == true } == true)
        #expect(decoded.petWalkLogs.contains { $0.executorIdsRaw?.contains(coWalker.id.uuidString) == true })
        #expect(decoded.petWalkLogs.contains { $0.behaviorNotes == "Park loop" && $0.moodRating == 5 })
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV82.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDefaults(suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? .distantPast
    }

    private func isolateEconomy(activeHumanID: String?) -> () -> Void {
        let defaults = UserDefaults.standard
        let oldActiveHuman = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldown = defaults.object(forKey: "quest_cooldownLogs")
        let oldBoost = defaults.object(forKey: "shop_boostDoubleActive")
        let oldFirstMeal = defaults.object(forKey: "quest_isFirstMealRecorded")
        let oldCoconutCount = TestQuestManagerProjection.manager.coconutCount
        let oldCoconutLogs = TestQuestManagerProjection.manager.coconutLogs
        let oldLastReward = TestQuestManagerProjection.manager.lastEconomyRewardResult
        let oldEconomyValues = defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("economyV2.dailyBudget.") }

        EconomyDailyBudgetStore.resetAll()
        defaults.removeObject(forKey: "quest_cooldownLogs")
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        if let activeHumanID {
            defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        } else {
            defaults.removeObject(forKey: "currentActiveHumanId")
        }
        TestQuestManagerProjection.manager.coconutCount = 0
        TestQuestManagerProjection.manager.coconutLogs = []
        TestQuestManagerProjection.manager.lastEconomyRewardResult = nil

        let dayKey = EconomyDailyBudgetStore.dayKey()
        defaults.set(EconomyDailyBudgetStore.luckyCoconutBudget, forKey: "economyV2.dailyBudget.household.household.local.\(dayKey).lucky")

        return {
            EconomyDailyBudgetStore.resetAll()
            for (key, value) in oldEconomyValues {
                defaults.set(value, forKey: key)
            }
            if let oldActiveHuman {
                defaults.set(oldActiveHuman, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldown {
                defaults.set(oldCooldown, forKey: "quest_cooldownLogs")
            } else {
                defaults.removeObject(forKey: "quest_cooldownLogs")
            }
            if let oldBoost {
                defaults.set(oldBoost, forKey: "shop_boostDoubleActive")
            } else {
                defaults.removeObject(forKey: "shop_boostDoubleActive")
            }
            if let oldFirstMeal {
                defaults.set(oldFirstMeal, forKey: "quest_isFirstMealRecorded")
            } else {
                defaults.removeObject(forKey: "quest_isFirstMealRecorded")
            }
            TestQuestManagerProjection.manager.coconutCount = oldCoconutCount
            TestQuestManagerProjection.manager.coconutLogs = oldCoconutLogs
            TestQuestManagerProjection.manager.lastEconomyRewardResult = oldLastReward
            TestQuestManagerProjection.manager.persistQuestFlags()
        }
    }
}
