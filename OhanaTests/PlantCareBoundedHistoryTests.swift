import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantCareBoundedHistoryTests {
    @Test func featureHistoryLoadsBoundedPagesAndReportsExactVisibleTotal() async throws {
        let fixture = try makeFixture()
        let actor = PlantCareFeatureRouteSnapshotActor(modelContainer: fixture.container)

        let firstPage = try await actor.load(
            request: PlantCareFeatureRouteSnapshotRequest(
                plantIDs: [fixture.plant.id],
                feature: .log,
                focusedCareType: nil,
                now: fixture.now
            )
        )
        let secondPage = try await actor.load(
            request: PlantCareFeatureRouteSnapshotRequest(
                plantIDs: [fixture.plant.id],
                feature: .log,
                focusedCareType: nil,
                historyLimit: 160,
                now: fixture.now
            )
        )

        #expect(firstPage.records.count == 80)
        #expect(firstPage.totalRecordCount == fixture.visibleLogCount)
        #expect(firstPage.hasMore)
        #expect(firstPage.requestKey.contains("limit:80"))
        #expect(secondPage.records.count == 160)
        #expect(secondPage.totalRecordCount == fixture.visibleLogCount)
        #expect(secondPage.hasMore)
        #expect(secondPage.requestKey.contains("limit:160"))
        #expect(firstPage.records.allSatisfy { !$0.note.hasPrefix("defer:") && !$0.note.hasPrefix("skip:") })
        #expect(secondPage.records.allSatisfy { !$0.note.hasPrefix("defer:") && !$0.note.hasPrefix("skip:") })
    }

    @Test func detailUsesBoundedTimelineAndGalleryWhileExportKeepsOnlyVisibleHistory() async throws {
        let fixture = try makeFixture()
        let actor = PlantDetailRenderDataActor(modelContainer: fixture.container)
        let renderData = try await actor.build(
            request: PlantDetailRenderDataRequest(
                plantModelID: fixture.plant.persistentModelID,
                revision: 1,
                languageCode: "en",
                now: fixture.now
            )
        )

        #expect(renderData.recentLogs.count == 80)
        #expect(renderData.logSummary.logCount == fixture.visibleLogCount)
        #expect(renderData.logSummary.firstLogDate == fixture.firstVisibleDate)
        #expect(renderData.logSummary.latestLogDate == fixture.latestVisibleDate)
        #expect(renderData.logSummary.latestLog?.date == fixture.latestVisibleDate)
        #expect(renderData.galleryPhotoItems.count == 120)
        #expect(renderData.growthDiaryPhotoCount == fixture.photoLogCount)
        #expect(renderData.recentLogs.allSatisfy { !$0.note.hasPrefix("defer:") && !$0.note.hasPrefix("skip:") })

        let payload = PlantGrowthDiaryExportService.makePayload(
            for: fixture.plant,
            exportedAt: fixture.now,
            includePhotos: false
        )
        #expect(payload.entries.count == fixture.visibleLogCount)
        #expect(payload.entries.allSatisfy { !$0.note.hasPrefix("defer:") && !$0.note.hasPrefix("skip:") })
    }

    @Test func highFrequencyPlanningUsesOnlyBoundedHistoryProjections() throws {
        let fixture = try makeFixture()
        let context = fixture.container.mainContext
        let calendar = Calendar.current
        let pruningDate = fixture.firstVisibleDate.addingTimeInterval(-86400)
        let pruning = PlantCareLog(
            date: pruningDate,
            careType: .pruning,
            note: "bounded-plan-anchor"
        )
        pruning.plant = fixture.plant
        context.insert(pruning)
        try context.save()

        var fetchCount = 0
        let history = try PlantCarePlanningHistoryQuery.build(plantID: fixture.plant.id) { descriptor in
            fetchCount += 1
            return try context.fetch(descriptor)
        }
        let tasks = PlantCarePlanService.tasks(
            for: fixture.plant,
            history: history,
            now: fixture.now,
            calendar: calendar
        )
        let pruningTask = try #require(tasks.first { $0.careType == .pruning })
        let expectedPruningDueDate = try #require(calendar.date(
            byAdding: .day,
            value: pruningTask.effectiveIntervalDays,
            to: calendar.startOfDay(for: pruningDate)
        ))

        #expect(history.recentWateringDates.count == 4)
        #expect(history.recentCustomNotes.count == 2)
        #expect(history.latestCareDates[.pruning] == pruningDate)
        #expect(pruningTask.dueDate == expectedPruningDueDate)
        #expect(fetchCount == 3)
    }

    @Test func planningBatchFusesSparseReadsAndFailsSoftPerPlant() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let firstPlant = Plant(name: "First", remindersEnabled: false)
        let failedPlant = Plant(name: "Failed", remindersEnabled: false)
        let finalPlant = Plant(name: "Final", remindersEnabled: false)
        [firstPlant, failedPlant, finalPlant].forEach(context.insert)

        let pruningDate = Date(timeIntervalSince1970: 1_735_689_600)
        let firstLog = PlantCareLog(date: pruningDate, careType: .pruning)
        firstLog.plant = firstPlant
        context.insert(firstLog)
        let finalLog = PlantCareLog(
            date: pruningDate.addingTimeInterval(3600),
            careType: .customNote,
            note: "sparse"
        )
        finalLog.plant = finalPlant
        context.insert(finalLog)
        try context.save()

        var fetchCounts: [UUID: Int] = [:]
        let batch = try PlantCarePlanningHistoryQuery.buildMany(
            plantIDs: [firstPlant.id, failedPlant.id, firstPlant.id, finalPlant.id]
        ) { plantID, descriptor in
            fetchCounts[plantID, default: 0] += 1
            if plantID == failedPlant.id {
                throw PlanningFetchProbeError.expected
            }
            return try context.fetch(descriptor)
        }

        #expect(batch.historiesByPlantID.count == 3)
        #expect(batch.historiesByPlantID[firstPlant.id]?.latestCareDates[.pruning] == pruningDate)
        #expect(batch.historiesByPlantID[failedPlant.id] == .empty)
        #expect(batch.historiesByPlantID[finalPlant.id]?.recentCustomNotes.map(\.note) == ["sparse"])
        #expect(batch.failedPlantIDs == [failedPlant.id])
        #expect(fetchCounts[firstPlant.id] == 1)
        #expect(fetchCounts[failedPlant.id] == 1)
        #expect(fetchCounts[finalPlant.id] == 1)
    }

    private func makeFixture(visibleLogCount: Int = 260) throws -> Fixture {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let plant = Plant(name: "Bounded Fern", healthStatus: .stable, remindersEnabled: false)
        let firstVisibleDate = Date(timeIntervalSince1970: 1_735_689_600)
        var latestVisibleDate = firstVisibleDate
        var photoLogCount = 0
        context.insert(plant)

        for index in 0 ..< visibleLogCount {
            let date = firstVisibleDate.addingTimeInterval(Double(index) * 3600)
            let careType: PlantCareType = index.isMultiple(of: 2) ? .photo : .watering
            let photoData = careType == .photo ? Data([UInt8(index % 251)]) : nil
            let log = PlantCareLog(
                date: date,
                careType: careType,
                note: "visible-\(index)",
                photoData: photoData
            )
            log.plant = plant
            context.insert(log)
            latestVisibleDate = date
            if photoData != nil { photoLogCount += 1 }
        }

        for (offset, note) in ["defer:watering:internal", "skip:watering:internal"].enumerated() {
            let log = PlantCareLog(
                date: latestVisibleDate.addingTimeInterval(Double(offset + 1) * 3600),
                careType: .customNote,
                note: note
            )
            log.plant = plant
            context.insert(log)
        }
        plant.lastWateredDate = latestVisibleDate
        try context.save()

        return Fixture(
            container: container,
            plant: plant,
            visibleLogCount: visibleLogCount,
            photoLogCount: photoLogCount,
            firstVisibleDate: firstVisibleDate,
            latestVisibleDate: latestVisibleDate,
            now: latestVisibleDate.addingTimeInterval(86400)
        )
    }
}

private enum PlanningFetchProbeError: Error {
    case expected
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let plant: Plant
    let visibleLogCount: Int
    let photoLogCount: Int
    let firstVisibleDate: Date
    let latestVisibleDate: Date
    let now: Date
}
