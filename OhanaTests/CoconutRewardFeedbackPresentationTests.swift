import Foundation
import Testing

struct CoconutRewardFeedbackPresentationTests {
    @Test func globalRewardOverlayIsMountedAboveRoutePresentations() throws {
        let rootURL = repositoryRootURL()
        let contentSource = try source("Ohana/App/ContentView.swift", rootURL: rootURL)
        let appRouteSource = try source("Ohana/App/RouteContainers/AppRouteDestinationContainers.swift", rootURL: rootURL)
        let homeRouteSource = try source("Ohana/Features/Home/FocusHomeRouteSheetModifier.swift", rootURL: rootURL)
        let feedbackSource = try source("Ohana/Features/TodayFocus/Views/CheckInRewardFeedback.swift", rootURL: rootURL)

        #expect(feedbackSource.contains("struct GlobalCoconutRewardFeedbackLayer"))
        #expect(feedbackSource.contains("func globalCoconutRewardFeedbackOverlay() -> some View"))
        #expect(contentSource.contains("GlobalCoconutRewardFeedbackLayer()"))
        #expect(appRouteSource.components(separatedBy: ".globalCoconutRewardFeedbackOverlay()").count >= 4)
        #expect(homeRouteSource.components(separatedBy: ".globalCoconutRewardFeedbackOverlay()").count >= 4)
    }

    @Test func plantDetailDoesNotManuallyDuplicateRewardFeedbackEvents() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantDetailView+Actions.swift",
            rootURL: repositoryRootURL()
        )

        #expect(!source.contains("publishPlantCareVisualReward"))
        #expect(!source.contains("publishCoconutRewardFeedback("))
    }

    @Test func rewardProducingMilestoneExecutorUsesInjectedQuestManager() throws {
        let source = try source(
            "Ohana/Features/Milestones/PetMilestoneCommands.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("let questManager: QuestManager"))
        #expect(source.contains("questManager: services.questManager"))
        #expect(source.contains("questManager: questManager"))
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
