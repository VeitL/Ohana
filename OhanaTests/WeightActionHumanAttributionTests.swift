import Foundation
import Testing

@MainActor
struct WeightActionHumanAttributionTests {
    @Test func weightSheetsUseDraftScopedRecorderSelection() throws {
        let rootURL = repositoryRootURL()
        let genericSheet = try source(
            "Ohana/Features/DashboardRecords/Views/GenericWeightEntrySheet.swift",
            rootURL: rootURL
        )
        let quickSheet = try source(
            "Ohana/Features/DashboardRecords/Views/QuickWeightSheet.swift",
            rootURL: rootURL
        )
        let humanHistory = try source(
            "Ohana/Features/DashboardRecords/Views/HumanWeightHistoryView.swift",
            rootURL: rootURL
        )

        for sheet in [genericSheet, quickSheet] {
            #expect(sheet.contains("QuickCareActionHumanPickerContainer("))
            #expect(sheet.contains("role: .recorder"))
            #expect(sheet.contains("selectedRecorderHumanID?.uuidString"))
            #expect(!sheet.contains("@AppStorage(\"currentActiveHumanId\")"))
        }

        #expect(humanHistory.contains("QuickCareActionHumanPickerContainer("))
        #expect(humanHistory.contains("role: .recorder"))
        #expect(humanHistory.contains("selectedInlineRecorderHumanID?.uuidString"))
        #expect(!humanHistory.contains("let executorId = activeHumanIdStr.isEmpty"))
    }

    @Test func quickWeightRoutesPreserveTheirLedgerSource() throws {
        let rootURL = repositoryRootURL()
        let genericSheet = try source(
            "Ohana/Features/DashboardRecords/Views/GenericWeightEntrySheet.swift",
            rootURL: rootURL
        )
        let quickSheet = try source(
            "Ohana/Features/DashboardRecords/Views/QuickWeightSheet.swift",
            rootURL: rootURL
        )
        let hosts = try source(
            "Ohana/Features/Members/QuickWeightEntrySheetDataContainer.swift",
            rootURL: rootURL
        )

        #expect(genericSheet.contains("ledgerSource: petLedgerSource"))
        #expect(quickSheet.contains("ledgerSource: .quickAction"))
        #expect(hosts.contains("petLedgerSource: .quickAction"))
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
