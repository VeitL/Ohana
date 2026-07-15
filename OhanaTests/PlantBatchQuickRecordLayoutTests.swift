import Foundation
import Testing
@testable import Ohana

struct PlantBatchQuickRecordLayoutTests {
    @Test func quickRecordTypePickerUsesCareCategoriesInsteadOfFlatChips() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("@State private var selectedCareCategory"))
        #expect(source.contains("PlantCareCategory.allCases"))
        #expect(source.contains("private var categorySelector"))
        #expect(source.contains("private var careTypeGrid"))
        #expect(source.contains("private var visibleCareTypes: [PlantCareType]"))
        #expect(source.contains("quickCareTypes.filter { selectedCareCategory.contains($0) }"))
        #expect(!source.contains("ForEach(quickCareTypes) { type in"))
    }

    @Test func quickRecordPlantCardsAllowLongNamesAndRooms() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("HStack(alignment: .top, spacing: 10)"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!source.contains("Text(plant.name)\n                    .font(OhanaFont.caption(.black))\n                    .foregroundStyle(Color.ohanaPrimaryText)\n                    .lineLimit(1)"))
        #expect(!source.contains("Text(plant.roomName.isEmpty ? l.tr(zh: \"未分组\", en: \"No room\", de: \"Kein Raum\") : plant.roomName)\n                    .font(OhanaFont.caption2(.bold))\n                    .foregroundStyle(Color.ohanaSecondaryText)\n                    .lineLimit(1)"))
    }

    @Test func quickRecordCategoryChipsWrapLongLocalizedLabels() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains(".lineLimit(2)"))
        #expect(source.contains(".multilineTextAlignment(.center)"))
        #expect(source.contains(".frame(minWidth: 86, idealWidth: 104, maxWidth: 128, minHeight: 44)"))
        #expect(!source.contains(".frame(minWidth: 86)\n            .frame(minHeight: 44)"))
    }

    @Test func plantDetailSelectMorePrefillsCurrentPlantAndUsesBatchCommand() throws {
        let rootURL = repositoryRootURL()
        let sheetSource = try source(
            "Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift",
            rootURL: rootURL
        )
        let detailSource = try [
            "Ohana/Features/Plants/Views/PlantDetailView.swift",
            "Ohana/Features/Plants/Views/PlantDetailView+Actions.swift",
            "Ohana/Features/Plants/Views/PlantDetailView+CareSections.swift"
        ].map { try source($0, rootURL: rootURL) }.joined(separator: "\n")
        let containerSource = try source(
            "Ohana/Features/Plants/PlantDetailDataContainer.swift",
            rootURL: rootURL
        )

        #expect(sheetSource.contains("initialSelectedPlantIDs: Set<UUID> = []"))
        #expect(sheetSource.contains("initialSelectedPlantIDs.intersection(activePlantIDs)"))
        #expect(detailSource.contains("plant-detail-quick-care-select-more"))
        #expect(detailSource.contains("initialCareType: batchQuickRecordCareType"))
        #expect(detailSource.contains("initialSelectedPlantIDs: [plant.id]"))
        #expect(detailSource.contains("await OhanaFrameScheduler.waitAfterNextFrame()"))
        #expect(detailSource.contains("try await batchQuickRecordTargetLoader()"))
        #expect(!detailSource.contains("modelContext.fetch(descriptor)"))
        #expect(containerSource.contains("@ModelActor"))
        #expect(containerSource.contains("descriptor.fetchLimit = limit"))
        #expect(containerSource.contains("-> [PlantBatchQuickRecordTargetSnapshot]"))
        #expect(detailSource.contains("commandExecutor.recordPlantBatchQuickCare("))
        #expect(detailSource.contains("pendingBatchCareUndoToken = token"))
        #expect(detailSource.contains("undoPendingBatchCareFromDetail()"))
        #expect(!containerSource.contains("@Query(sort: \\Plant.name)"))
    }

    @Test func batchQuickRecordOnlyOffersActionsSupportedByTheAtomicCommand() throws {
        let expected: [PlantCareType] = [
            .watering,
            .fertilizing,
            .misting,
            .repotting,
            .pruning,
            .leafCleaning,
            .rotating,
            .pestCheck
        ]
        let unsupported: Set<PlantCareType> = [.newLeaf, .yellowLeaf, .pestFound, .customNote]
        let offered = PlantBatchCarePolicy.supportedQuickCareTypes
        let sheetSource = try source(
            "Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(offered == expected)
        #expect(Set(offered).isDisjoint(with: unsupported))
        #expect(sheetSource.contains("PlantBatchCarePolicy.supportedQuickCareTypes"))
    }

    @Test func batchQuickRecordWaitsForCommandSuccessBeforeFeedbackAndDismissal() throws {
        let rootURL = repositoryRootURL()
        let sheetSource = try source(
            "Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift",
            rootURL: rootURL
        )
        let dashboardSource = try source(
            "Ohana/Features/Plants/Views/PlantDashboardView.swift",
            rootURL: rootURL
        )
        let detailActionsSource = try source(
            "Ohana/Features/Plants/Views/PlantDetailView+Actions.swift",
            rootURL: rootURL
        )

        #expect(sheetSource.contains("@State private var isRecording = false"))
        #expect(sheetSource.contains("let didRecord = await onRecord(selections, resolvedExecutorID)\n        guard didRecord else { return }\n\n        UINotificationFeedbackGenerator().notificationOccurred(.success)\n        dismiss()"))
        #expect(sheetSource.contains(".disabled(selectedCount == 0 || isRecording || requiresExecutorSelection)"))
        #expect(dashboardSource.contains("func recordBatchQuickCare(_ selections: [PlantBatchCareSelection], executorID: UUID?) async -> Bool"))
        #expect(detailActionsSource.contains("func recordBatchQuickCareFromDetail("))
        #expect(detailActionsSource.contains("executorID: UUID?"))
    }

    @Test func fertilizingRowsShowLastDatePlannedCadenceAndLocalizedDueState() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantCareFeatureDetailView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("func fertilizingCadenceText(for plant: Plant) -> String"))
        #expect(source.contains("lastDate: plant.lastFertilizedDate"))
        #expect(source.contains("CareCycleStatus.make("))
        #expect(source.contains("status.compactDueText(l: l)"))
        #expect(source.contains("最近施肥：\\(fullDateText(lastDate))"))
        #expect(source.contains("计划每 \\(intervalDays) 天 · \\(statusText)"))
        #expect(source.contains("距下次施肥 \\(status.compactDueText(l: l))"))
        #expect(source.contains("plant-care-feature-fertilizing-status-\\(plant.id.uuidString)"))
        #expect(source.contains(".accessibilityElement(children: .contain)"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
