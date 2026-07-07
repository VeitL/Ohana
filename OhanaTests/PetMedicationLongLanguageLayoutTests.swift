import Foundation
import Testing

struct PetMedicationLongLanguageLayoutTests {
    @Test func medicationScreensUseAdaptiveLongLanguageLayouts() throws {
        let rootURL = repositoryRootURL()
        let listSource = try source(
            "Ohana/Features/Medication/Views/PetMedicationView.swift",
            rootURL: rootURL
        )
        let detailSource = try source(
            "Ohana/Features/Medication/Views/PetMedicationDetailSheet.swift",
            rootURL: rootURL
        )

        #expect(listSource.contains("func medicationMetricCell"))
        #expect(listSource.contains("func medicationCardHeader"))
        #expect(listSource.contains("func medicationCardActions"))
        #expect(listSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(listSource.contains(".lineLimit(2)"))
        #expect(!listSource.contains("func metricCell"))

        #expect(detailSource.contains("medicationDetailStatusStack"))
        #expect(detailSource.contains("medicationRemainingHeader"))
        #expect(detailSource.contains("medicationHistoryChips"))
        #expect(detailSource.contains("LazyVGrid(columns: [GridItem(.adaptive(minimum: 92)"))
        #expect(detailSource.contains(".lineLimit(3)"))
        #expect(!detailSource.contains("HStack(alignment: .top, spacing: 12) {\n                            bentoTodayStatus"))
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
