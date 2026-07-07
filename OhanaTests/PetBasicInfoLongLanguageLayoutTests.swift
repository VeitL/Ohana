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
        #expect(editSource.contains("func petProfileEditableRow"))
        #expect(!editSource.contains(".frame(width: 80, alignment: .leading)"))
        #expect(!editSource.contains(".frame(width: 70, alignment: .leading)"))

        #expect(healthSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(healthSource.contains("func compactSummaryLabel"))
        #expect(healthSource.contains("func compactSummaryValue"))
        #expect(!healthSource.contains(".frame(width: 58, alignment: .leading)"))
    }

    @Test func editPetSheetDailyPortionFallsBackForLongLabels() throws {
        let source = try source(
            "Ohana/Features/Members/Views/EditPetSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("dailyPortionLabel"))
        #expect(source.contains("dailyPortionInput"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains(".frame(minWidth: 104, idealWidth: 124, maxWidth: 150)"))
        #expect(!source.contains(".frame(width: 124)"))
    }

    @Test func memberCreationBottomNavigationAvoidsFixedWidthBackButton() throws {
        let source = try source(
            "Ohana/Features/Members/Views/MemberCardCreationContentView+Layout.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains(".frame(minWidth: 96, idealWidth: 112, maxWidth: 154, minHeight: 54)"))
        #expect(!source.contains(".frame(width: 104, height: 54)"))
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
