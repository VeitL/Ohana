import Foundation
import Testing

struct SitterCardLongLanguageLayoutTests {
    @Test func sitterCardUsesAdaptiveMultilineRows() throws {
        let source = try source(
            "Ohana/Features/Members/Views/SitterCardPreviewSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("private var sitterHeaderTags: some View"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(source.contains(".lineLimit(4)"))
        #expect(!source.contains(".frame(width: 56, alignment: .leading)"))
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
