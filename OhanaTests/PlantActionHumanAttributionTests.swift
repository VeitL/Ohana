import Foundation
import Testing
@testable import Ohana

@MainActor
struct PlantActionHumanAttributionTests {
    @Test func plantCareSheetsKeepActorSelectionInsideTheActionDraft() throws {
        let rootURL = repositoryRootURL()
        let careLog = try source("Ohana/Features/Plants/Views/PlantCareLogSheet.swift", rootURL: rootURL)
        let dueBatch = try source("Ohana/Features/Plants/Views/PlantBatchCareSheet.swift", rootURL: rootURL)
        let quickBatch = try source("Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift", rootURL: rootURL)

        for sheet in [careLog, dueBatch, quickBatch] {
            #expect(sheet.contains("QuickCareActionHumanPickerContainer("))
            #expect(sheet.contains("@State private var selectedExecutorID: UUID?"))
            #expect(!sheet.contains("@AppStorage(\"currentActiveHumanId\")"))
        }

        #expect(careLog.contains("selectedPhotoData, selectedExecutorID"))
        #expect(dueBatch.contains("onComplete(selections, selectedExecutorID)"))
        #expect(quickBatch.contains("onRecord(selections, selectedExecutorID)"))
        #expect(careLog.contains("requiresExecutorSelection"))
        #expect(dueBatch.contains("requiresExecutorSelection"))
        #expect(quickBatch.contains("requiresExecutorSelection"))
    }

    @Test func sheetlessPlantCareOnlyAddsConfirmationForMultipleEligibleHumans() throws {
        let rootURL = repositoryRootURL()
        let confirmation = try source(
            "Ohana/Features/Plants/Views/PlantQuickCareActorConfirmationSheet.swift",
            rootURL: rootURL
        )
        let dashboardActions = try source(
            "Ohana/Features/Plants/Views/PlantDashboardView+WalletDeck.swift",
            rootURL: rootURL
        )
        let feature = try source(
            "Ohana/Features/Plants/Views/PlantCareFeatureDetailView.swift",
            rootURL: rootURL
        )

        #expect(confirmation.contains("var needsConfirmation: Bool { eligibleHumanCount > 1 }"))
        #expect(confirmation.contains("QuickCareActionHumanPickerContainer("))
        #expect(dashboardActions.contains("if humanContext.needsConfirmation"))
        #expect(feature.contains("if humanContext.needsConfirmation"))
        #expect(dashboardActions.contains("executorId: humanContext.defaultHumanID?.uuidString"))
        #expect(feature.contains("executorID: humanContext.defaultHumanID"))
    }

    @Test func plantCommandCallsitesUseTheSelectedDraftActor() throws {
        let rootURL = repositoryRootURL()
        let dashboard = try source("Ohana/Features/Plants/Views/PlantDashboardView.swift", rootURL: rootURL)
        let detail = try source("Ohana/Features/Plants/Views/PlantDetailView+Actions.swift", rootURL: rootURL)
        let homeRoute = try source("Ohana/Features/Home/HomePlantCareLogRouteContainer.swift", rootURL: rootURL)

        #expect(dashboard.contains("let executorId = executorID?.uuidString"))
        #expect(dashboard.contains("executorId: executorId"))
        #expect(detail.contains("executorId: executorID?.uuidString"))
        #expect(detail.contains("batchQuickRecordInitialExecutorID = quickCareExecutorID"))
        #expect(!detail.contains("appServices.activeHumanSelection.currentHumanId"))
        #expect(!detail.contains("executorId: currentExecutorId()\n            )"))
        #expect(homeRoute.contains("photoData, executorID in"))
        #expect(homeRoute.contains("executorId: executorID?.uuidString"))
        #expect(!homeRoute.contains("@AppStorage(\"currentActiveHumanId\")"))
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
