import Foundation
import Testing

struct FamilyReportAdaptiveLayoutTests {
    @Test func weeklyReportUsesAdaptiveSummaryAndStoryLayouts() throws {
        let source = try source(
            "Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("@Environment(\\.dynamicTypeSize) private var dynamicTypeSize"))
        #expect(source.contains("reportMetricColumns"))
        #expect(source.contains("GridItem(.adaptive(minimum: 96)"))
        #expect(source.contains("reportPillColumns"))
        #expect(source.contains("GridItem(.adaptive(minimum: 102)"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains("headerTitleBlock"))
        #expect(source.contains("headerShareControl"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!source.contains("HStack(spacing: 10) {\n                metric("))
        #expect(!source.contains("HStack(spacing: 8) {\n                storyPill("))
        #expect(!source.contains(".lineLimit(1)\n                .minimumScaleFactor(0.72)"))
    }

    @Test func plantFeatureCollectionCommandCenterUsesAdaptiveMetricAndPillGrids() throws {
        let source = try source(
            "Ohana/Features/FunctionMenu/Views/PlantFeatureCollectionView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("commandCenterMetricColumns"))
        #expect(source.contains("GridItem(.adaptive(minimum: 128)"))
        #expect(source.contains("commandCenterPillColumns"))
        #expect(source.contains("GridItem(.adaptive(minimum: 112)"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!source.contains("LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8)"))
        #expect(!source.contains(".lineLimit(1)\n                    .minimumScaleFactor(0.72)"))
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
