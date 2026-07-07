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

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
