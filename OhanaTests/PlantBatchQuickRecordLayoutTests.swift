import Foundation
import Testing

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

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
