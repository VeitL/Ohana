import Foundation
import SwiftData
import Testing
import UIKit
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PetRecordExperienceTests {
    @Test func backdatedFeedReceiptPointsToItsFactInsteadOfTheNewestRecord() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Alex")
        context.insert(pet)
        context.insert(human)
        pet.dailyPortionGrams = 35
        pet.mainFoodKind = .wet
        try context.save()
        let now = Date()
        let latest = record(pet: pet, human: human, context: context, date: now)
        let catchUpDate = now.addingTimeInterval(-86400)
        let catchUp = record(pet: pet, human: human, context: context, date: catchUpDate, note: "After our walk")
        let reference = try #require(catchUp.recordReference)
        #expect(catchUp.didPersist && catchUp.didRecord)
        #expect(reference.recordID != latest.recordReference?.recordID)
        #expect(reference.route.focusedRecordID == reference.recordID)
        #expect(reference.route.tab == .timeline)
        #expect(reference.route.filter == .care)
        let readback = ModelContext(container)
        let id = reference.recordID
        let log = try #require(readback.fetch(FetchDescriptor<PetCareLog>(predicate: #Predicate { $0.id == id })).first)
        #expect(log.pet?.id == pet.id)
        #expect(log.date == catchUpDate)
        #expect(log.note.contains("After our walk"))
        #expect(pet.dailyPortionGrams == 35)
        #expect(pet.mainFoodKind == .wet)
        var rows = PetTimelineSourceRows()
        rows.careLogs = [log]
        let timeline = PetTimelineItemsBuilder.archiveItems(for: pet, mode: .care, sourceRows: rows, l: L10n("en"))
        #expect(timeline.first?.subtitle.contains("50 g") == true)
        #expect(timeline.first?.subtitle.contains("After our walk") == true)
        #expect(timeline.first?.subtitle.contains(PetCareLog.manualFeedNoteMarker) == false)
    }

    @Test func sharedFeedReceiptUsesTheSourceChildAndSharedTimelineIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = Pet(name: "Momo", species: "猫")
        let companion = Pet(name: "Nori", species: "猫")
        let human = Human(name: "Alex")
        [source, companion].forEach { context.insert($0) }
        context.insert(human)
        try context.save()
        let result = ManualFeedCommand.recordManual(
            pet: source, targets: [companion, source], grams: 80, foodKind: .dry,
            saveAsDefault: false, foodRecords: [], allEvents: [], context: context,
            executorId: human.id.uuidString, note: "Together"
        )
        let reference = try #require(result.recordReference)
        let sessionID = try #require(reference.sharedSessionID)
        #expect(reference.route.focusedRecordID == sessionID)
        let log = try #require(context.fetch(FetchDescriptor<PetCareLog>()).first { $0.id == reference.recordID })
        #expect(log.pet?.id == source.id)
        #expect(log.sharedSessionId == sessionID.uuidString)
        #expect(log.note == "Together")
        #expect(result.targetCount == 2)
    }

    @Test func latestMemoryIsPetScopedAndChoosesTheNewestStoredDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let other = Pet(name: "Nori", species: "猫")
        context.insert(pet)
        context.insert(other)
        let now = Date()
        let photo = PetPhotoLog(imageData: Data([1]), date: now, note: "Sunny nap", pet: pet)
        let older = PetMilestone(date: now.addingTimeInterval(-86400), title: "First day", pet: pet)
        let unrelated = PetMilestone(date: now.addingTimeInterval(86400), title: "Other pet", pet: other)
        context.insert(photo)
        context.insert(older)
        context.insert(unrelated)
        try context.save()
        let snapshot = try #require(PetLatestMemorySnapshot.load(petID: pet.id, context: ModelContext(container)))
        #expect(snapshot.reference.recordID == photo.id)
        #expect(snapshot.reference.petID == pet.id)
        #expect(snapshot.title == "Sunny nap")
        #expect(snapshot.reference.route.filter == .memories)
        #expect(PetLatestMemorySnapshot.load(petID: UUID(), context: context) == nil)
    }

    @Test func failedMemoryCommitReturnsNoReceiptAndCanRetryWithoutDuplicateFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        // Memorial memories are writable and have no care/reward side effects.
        pet.passedAwayDate = Date().addingTimeInterval(-86400)
        context.insert(pet)
        try context.save()
        enum SaveFailure: Error { case injected }
        let failed = MomentCommandService.recordMoment(
            pet: pet, note: "A memory to keep", photoData: [], locationLatitude: 0,
            locationLongitude: 0, locationPlacename: "", context: context,
            persist: { _ in throw SaveFailure.injected }
        )
        #expect(failed.savedLogIDs.isEmpty)
        #expect(failed.coconutDelta == 0)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<PetPhotoLog>()) == 0)
        let retry = MomentCommandService.recordMoment(
            pet: pet, note: "A memory to keep", photoData: [], locationLatitude: 0,
            locationLongitude: 0, locationPlacename: "", context: context
        )
        #expect(retry.savedLogIDs.count == 1)
        #expect(retry.coconutDelta == 0)
        let logs = try ModelContext(container).fetch(FetchDescriptor<PetPhotoLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.note == "A memory to keep")
    }

    @Test func oldMomentsRoutesRemainCompatibleAndNewRoutesHaveDistinctIdentity() {
        let petID = UUID()
        #expect(AppSheetRoute.petMomentHistory(petID).id == "pet-moment-history-\(petID.uuidString)")
        #expect(AppSheetRoute.petMomentHistory(petID).id == AppSheetRoute.petMomentHistory(petID, initialRoute: .highlights).id)
        #expect(AppSheetRoute.petMomentHistory(petID, initialRoute: .timeline).id != AppSheetRoute.petMomentHistory(petID, initialRoute: .photos).id)
    }

    @Test func savedPhotoCanBeDecodedFromANewContextInMemorialMode() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.passedAwayDate = Date().addingTimeInterval(-86400)
        context.insert(pet)
        try context.save()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { canvas in
            UIColor.orange.setFill()
            canvas.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let payload = try #require(image.pngData())
        let result = try PetPhotoAlbumCommandService.createPhotos(data: [payload], pet: pet, context: context)
        let id = try #require(result.photoIDs.first)
        let readback = ModelContext(container)
        let log = try #require(readback.fetch(FetchDescriptor<PetPhotoLog>(predicate: #Predicate { $0.id == id })).first)
        let decoded = try #require(UIImage(data: log.imageData))
        #expect(decoded.size.width == 24 && decoded.size.height == 24)
        #expect(log.pet?.id == pet.id)
        #expect(try readback.fetchCount(FetchDescriptor<PetCareLog>()) == 0)
        #expect(try readback.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 0)
    }

    @Test func timelineKeepsRepeatedFactsAndLocatesEveryRecordInAPhotoGroup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Alex")
        context.insert(pet)
        context.insert(human)
        try context.save()
        let now = Date()
        _ = record(pet: pet, human: human, context: context, date: now.addingTimeInterval(-120))
        _ = record(pet: pet, human: human, context: context, date: now.addingTimeInterval(-60))
        let first = PetPhotoLog(imageData: Data([1]), date: now.addingTimeInterval(-1000), note: "Together", pet: pet)
        let second = PetPhotoLog(imageData: Data([1]), date: now.addingTimeInterval(-999), note: "Together", pet: pet)
        let later = PetPhotoLog(imageData: Data([1]), date: now.addingTimeInterval(-500), note: "Another memory", pet: pet)
        [first, second, later].forEach { context.insert($0) }
        try context.save()
        var rows = PetTimelineSourceRows()
        rows.careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        rows.photoLogs = [first, second, later]
        let data = PetMomentsHubRenderData.build(pet: pet, timelineRows: rows, sharedCareSessions: [], l: L10n("en"))
        #expect(data.sections(for: .care).flatMap(\.items).count == 2)
        let memories = data.sections(for: .memories).flatMap(\.items).filter { $0.type == "moment" }
        #expect(memories.count == 2)
        #expect(memories.contains { $0.containsRecord(second.id) && $0.containsRecord(first.id) })
        #expect(memories.contains { $0.containsRecord(later.id) })
    }

    @Test func failedFeedAndWaterCommitRemovePendingFactsBeforeRetry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()
        enum SaveFailure: Error { case injected }
        let feed = CareEventService.recordManualFeedFact(
            pet: pet, amountGrams: 30, context: context,
            persist: { _ in .failed(SaveFailure.injected) }
        )
        let water = CareEventService.recordCareFact(
            pet: pet, type: .watering, amountMl: 100, context: context, reward: .water,
            persist: { _ in .failed(SaveFailure.injected) }
        )
        #expect(!feed.result.didPersist && !water.result.didPersist)
        #expect(try context.fetchCount(FetchDescriptor<PetCareLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 0)
        let retry = CareEventService.recordManualFeedFact(pet: pet, amountGrams: 30, context: context)
        #expect(retry.result.didPersist)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<PetCareLog>()) == 1)
    }

    @Test func explicitFeedingDefaultCommitsWithTheFact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()
        let result = ManualFeedCommand.recordManual(
            pet: pet, targets: [pet], grams: 40, foodKind: .wet, saveAsDefault: true,
            foodRecords: [], allEvents: [], context: context, executorId: nil
        )
        #expect(result.didPersist && result.recordReference != nil)
        let id = pet.id
        let stored = try #require(ModelContext(container).fetch(FetchDescriptor<Pet>(predicate: #Predicate { $0.id == id })).first)
        #expect(stored.dailyPortionGrams == 40)
        #expect(stored.mainFoodKind == .wet)
    }

    private func record(pet: Pet, human: Human, context: ModelContext, date: Date, note: String = "") -> ManualFeedCommandResult {
        ManualFeedCommand.recordManual(
            pet: pet, targets: [pet], grams: 50, foodKind: .dry, saveAsDefault: false,
            foodRecords: [], allEvents: [], context: context, executorId: human.id.uuidString,
            date: date, note: note
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema(ArkSchemaV99.models), configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }
}
