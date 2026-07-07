import Foundation
import Testing

struct PlantDetailLongLanguageLayoutTests {
    @Test func healthAndGrowthCardsUseAdaptiveMetricAndPhotoLayouts() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantDetailView+HealthGrowthSections.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("func plantDetailMetricGrid"))
        #expect(source.contains("GridItem(.adaptive(minimum: 96)"))
        #expect(source.contains("plantDetailPhotoPreviewWidth"))
        #expect(source.contains("plantDetailPhotoPreviewHeight"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(!source.contains("HStack(spacing: 8) {\n                healthReviewMetric("))
        #expect(!source.contains("HStack(spacing: 8) {\n                diaryStatPill("))
        #expect(!source.contains(".frame(width: 118, height: 92)"))
        #expect(!source.contains(".frame(width: 118, alignment: .leading)"))
    }

    @Test func detailRowsFallBackToStackedLayoutForLongLocalizedValues() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantDetailView+Support.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains("func detailRowTitle"))
        #expect(source.contains("func detailRowValue"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!source.contains("func detailRow(_ title: String, value: String) -> some View {\n        HStack(alignment: .top)"))
    }

    @Test func careSectionActionsUseAdaptiveGridInsteadOfFixedHorizontalRows() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantDetailView+CareSections.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("func plantDetailActionGrid"))
        #expect(source.contains("GridItem(.adaptive(minimum: 132)"))
        #expect(source.contains("func plantDetailTextActionButton"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(!source.contains("HStack(spacing: 8) {\n            diagnosisActionButton("))
        #expect(!source.contains("HStack(spacing: 10) {\n                        Button(l.tr(zh: \"完成\""))
        #expect(!source.contains(".frame(minHeight: 42)"))
    }

    @Test func plantCareLogSuggestionsAvoidFixedWidthCards() throws {
        let source = try source(
            "Ohana/Features/Plants/Views/PlantCareLogSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains(".frame(minWidth: 168, idealWidth: 220, maxWidth: 260"))
        #expect(!source.contains(".frame(width: 190, alignment: .leading)"))
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
