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

        let reward = CareEventService.recordSharedLitterCare(
            sourcePet: first,
            targets: [first, second],
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 1000)
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
        #expect(FeedStockCalculator.stockDeductionAmount(for: ownerLog, pet: ownerLog.pet ?? first, sharedCareSessions: sessions) == 121)
        #expect(FeedStockCalculator.stockDeductionAmount(for: nonOwnerLog, pet: nonOwnerLog.pet ?? second, sharedCareSessions: sessions) == 0)
        #expect(FeedStockCalculator.stockDeductionAmount(for: ownerLog, pet: ownerLog.pet ?? first) == 0)
    }

    @Test func petFoodStockConveniencePropertiesReadStructuredSharedSession() throws {
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

        #expect(first.remainingFoodGrams == 880)
        #expect(first.foodConsumedSinceRestock == 120)
        #expect(second.remainingFoodGrams == 1000)
        #expect(second.foodConsumedSinceRestock == 0)
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
        let item = try #require(PetTimelineItemsBuilder.items(
            for: first,
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
        let remainingFeedLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        let remainingLog = try #require(remainingFeedLogs.first)
        let sessionState = try CloudSyncMetadataService.state(
            entityName: "SharedCareSession",
            localRecordId: session.id,
            context: context
        )

        #expect(sessions.count == 1)
        #expect(session.targetPetIds == [second.id.uuidString])
        #expect(session.stockOwnerPetId == second.id.uuidString)
        #expect(session.totalAmountGrams == remainingLog.amountGrams)
        #expect(remainingFeedLogs.count == 1)
        #expect(second.remainingFoodGrams == 940)
        #expect(sessionState?.hasPendingLocalChanges == true)
        #expect(sessionState?.isDeletionTombstone == false)
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
        #expect(result.ledgerEventIDs.count == 2)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
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

        let log = CareEventService.recordUnknownSharedPotty(
            sourcePet: first,
            targets: [first, second],
            type: .softPoop,
            context: context,
            date: Date(timeIntervalSince1970: 3000)
        )

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

        let log = CareEventService.recordUnknownSharedPotty(
            sourcePet: first,
            targets: [first, second],
            type: .softPoop,
            context: context,
            date: Date(timeIntervalSince1970: 3000)
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())

        #expect(sessions.count == 1)
        #expect(sessions.first?.actionKind == .pottyUnknown)
        #expect(pottyLogs.map(\.id) == [log.id])
        #expect(pottyLogs.first?.pet == nil)
        #expect(pottyLogs.first?.sharedSessionId == sessions.first?.id.uuidString)
        #expect(first.coconutBalance == 0)
        #expect(second.coconutBalance == 0)
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
            startDate: Date(timeIntervalSince1970: 5100)
        )

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: context)
        let data = try TestDataBackupManagerProjection.manager.encode(backup)
        let decoded = try JSONDecoder().decode(OhanaBackup.self, from: data)

        #expect(decoded.sharedCareSessions?.contains { $0.totalExpenseAmount == 30 && $0.expenseCategoryRaw == ExpenseCategory.food.rawValue } == true)
        #expect(decoded.petExpenseLogs.contains { $0.sharedSessionId?.isEmpty == false })
        #expect(decoded.petWalkLogs.contains { $0.sharedSessionId?.isEmpty == false })
        #expect(decoded.sharedCareSessions?.contains { $0.executorIdsRaw?.contains(coWalker.id.uuidString) == true } == true)
        #expect(decoded.petWalkLogs.contains { $0.executorIdsRaw?.contains(coWalker.id.uuidString) == true })
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV67.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
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
