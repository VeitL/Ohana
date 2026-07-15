import Foundation
import Testing

@MainActor
struct QuickCareActionHumanAttributionTests {
    @Test func quickCareSheetsUseDraftScopedActorSelection() throws {
        let rootURL = repositoryRootURL()
        let play = try source(
            "Ohana/Features/QuickCare/Views/QuickPlayDetailSheet.swift",
            rootURL: rootURL
        )
        let water = try source(
            "Ohana/Features/QuickCare/Views/QuickWaterDetailSheet.swift",
            rootURL: rootURL
        )
        let waterLogic = try source(
            "Ohana/Features/QuickCare/Views/QuickWaterDetailSheet+Logic.swift",
            rootURL: rootURL
        )
        let feed = try source(
            "Ohana/Features/Feeding/Views/QuickFeedDetailSheet.swift",
            rootURL: rootURL
        )
        let feedActions = try source(
            "Ohana/Features/Feeding/Views/QuickFeedDetailContent+FeedingCommandActions.swift",
            rootURL: rootURL
        )

        #expect(play.contains("QuickCareActionHumanPickerContainer("))
        #expect(!play.contains("QuickCareExecutorPickerBarContainer("))
        #expect(play.contains("let executorId = selectedActionExecutorId"))

        #expect(water.contains("QuickCareActionHumanPickerContainer("))
        #expect(waterLogic.contains("let executorId = selectedActionExecutorId"))
        #expect(!waterLogic.contains("commandExecutor.activeExecutorId()"))

        #expect(feed.contains("ActionHumanPicker("))
        #expect(feedActions.contains("let executorId = selectedActionExecutorId"))
        #expect(!feedActions.contains("executorId: currentUserId"))
    }

    @Test func pottyAndHygieneActionsDoNotRereadTheGlobalHumanWhenSaving() throws {
        let rootURL = repositoryRootURL()
        let quickPotty = try source(
            "Ohana/Features/QuickCare/Views/QuickPottySheet.swift",
            rootURL: rootURL
        )
        let pottyDetail = try source(
            "Ohana/Features/QuickCare/Views/QuickPottyDetailSheet.swift",
            rootURL: rootURL
        )
        let pottyActions = try source(
            "Ohana/Features/QuickCare/Views/QuickPottyDetailSheet+ActionHuman.swift",
            rootURL: rootURL
        )
        let pottyLogic = try source(
            "Ohana/Features/QuickCare/Views/QuickPottyDetailSheet+Logic.swift",
            rootURL: rootURL
        )
        let hygiene = try source(
            "Ohana/Features/Hygiene/Views/PetHygieneDetailView.swift",
            rootURL: rootURL
        )
        let hygieneConfirmation = try source(
            "Ohana/Features/Hygiene/Views/PetHygieneActionHumanConfirmationSheet.swift",
            rootURL: rootURL
        )

        #expect(quickPotty.contains("QuickCareActionHumanPickerContainer("))
        #expect(quickPotty.contains("@State private var selectedActionHumanID: UUID?"))
        #expect(quickPotty.contains("let executorId = selectedActionHumanID?.uuidString"))
        #expect(!quickPotty.contains("@AppStorage(\"currentActiveHumanId\")"))
        #expect(!quickPotty.contains("QuickCareExecutorPickerBarContainer("))

        #expect(pottyDetail.contains("@State var selectedActionHumanID: UUID?"))
        #expect(pottyActions.contains("QuickCareActionHumanPickerContainer("))
        #expect(pottyLogic.contains("let executorId = selectedActionHumanID?.uuidString"))
        #expect(!pottyLogic.contains("activeExecutorId()"))

        #expect(hygiene.contains(".sheet(item: $pendingHygieneAction)"))
        #expect(hygiene.contains("commitHygiene(draft.type, executorID: executorID)"))
        #expect(!hygiene.contains("let executorId = appServices.activeHumanSelection.currentHumanId"))
        #expect(hygieneConfirmation.contains("ActionHumanPicker("))
    }

    @Test func stockFormUsesItsDraftRecorderAndKeepsExpensePayerSeparate() throws {
        let rootURL = repositoryRootURL()
        let stockSheet = try source(
            "Ohana/Features/Feeding/Views/QuickFeedDetailContent+StockSheets.swift",
            rootURL: rootURL
        )
        let stockActions = try source(
            "Ohana/Features/Feeding/Views/QuickFeedDetailContent+StockCommandActions.swift",
            rootURL: rootURL
        )
        let stockCommands = try source(
            "Ohana/Features/Feeding/FeedPlanAndStockCommands.swift",
            rootURL: rootURL
        )

        #expect(stockSheet.contains("role: .recorder"))
        #expect(stockActions.contains("guard validateActionHumanSelection() else { return }"))
        #expect(stockActions.contains("executorId: selectedActionExecutorId"))
        #expect(stockCommands.contains("recordedByHumanId: recordedByHumanId"))
        #expect(stockCommands.contains("payerId: actor.effectiveExecutorId"))
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(
            contentsOf: rootURL.appending(path: path),
            encoding: .utf8
        )
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
