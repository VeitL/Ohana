import Foundation
import Testing

struct PlantDashboardLongLanguageLayoutTests {
    @Test func roomZoneCardsUseAdaptiveLayoutInsteadOfFixedWidth() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantDashboardView+DiscoverySections.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("func roomZoneTitle"))
        #expect(source.contains("func roomZoneStatusStack"))
        #expect(source.contains("func roomZoneCardFrame()"))
        #expect(source.contains("frame(minWidth: 150, idealWidth: 164, maxWidth: 190"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(!source.contains(".frame(width: 142, alignment: .topLeading)"))
    }

    @Test func batchCareRevealActionsAvoidFixedWidthLocalizedLabels() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantBatchCareSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("private let revealWidth: CGFloat = 198"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(source.contains(".multilineTextAlignment(.center)"))
        #expect(source.contains(".frame(minWidth: 82, idealWidth: 90, maxWidth: 96, minHeight: 56)"))
        #expect(!source.contains(".frame(width: 72)"))
    }

    @Test func overviewHeaderRailsUseAdaptiveGridsForDenseLocalizedText() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantDashboardView+Sections.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("var dashboardStatusColumns: [GridItem]"))
        #expect(source.contains("GridItem(.adaptive(minimum: 108)"))
        #expect(source.contains("LazyVGrid(columns: dashboardStatusColumns"))
        #expect(source.contains("var dashboardQuickActionColumns: [GridItem]"))
        #expect(source.contains("LazyVGrid(columns: dashboardQuickActionColumns"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(!source.contains("return HStack(spacing: 8) {\n            dashboardQuickActionButton("))
        #expect(!source.contains("HStack(spacing: 8) {\n            dashboardStatusChip("))
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
