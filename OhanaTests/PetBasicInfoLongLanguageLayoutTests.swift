import Foundation
import Testing

struct PetBasicInfoLongLanguageLayoutTests {
    @Test func petBasicInfoReadRowsAvoidFixedLabelColumns() throws {
        let rootURL = repositoryRootURL()
        let editSource = try source(
            "Ohana/Features/Members/Views/PetBasicInfoDetailView+Edit.swift",
            rootURL: rootURL
        )
        let healthSource = try source(
            "Ohana/Features/Members/Views/PetBasicInfoDetailView+HealthSummary.swift",
            rootURL: rootURL
        )

        #expect(editSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(editSource.contains("func infoRowLabel"))
        #expect(editSource.contains("func infoRowValue"))
        #expect(!editSource.contains(".frame(width: 80, alignment: .leading)"))

        #expect(healthSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(healthSource.contains("func compactSummaryLabel"))
        #expect(healthSource.contains("func compactSummaryValue"))
        #expect(!healthSource.contains(".frame(width: 58, alignment: .leading)"))
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
