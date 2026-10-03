//
//  UITestHumanLabFixtureSeeder.swift
//  Ohana
//
//  DEBUG-only structured lab fixture for downgrade acceptance tests.
//

import Foundation
import SwiftData

#if DEBUG
@MainActor
enum UITestHumanLabFixtureSeeder {
    static func seedIfRequested(
        context: ModelContext,
        services: AppServices,
        human: Human
    ) {
        guard OhanaUITestLaunchOptions.requestsImportedLabFixture else { return }

        guard let reportID = UUID(uuidString: "D3400000-0000-4000-8000-000000000001"),
              let logID = UUID(uuidString: "D3400000-0000-4000-8000-000000000002") else {
            preconditionFailure("Imported lab UI-test fixture IDs are invalid.")
        }

        let measuredAt = Date(timeIntervalSince1970: 1_735_689_600)
        let input = HumanLabReportImportInput(
            reportID: reportID,
            reportType: .bloodTest,
            conclusion: .normal,
            hospitalName: "UI Test Imported Clinic",
            doctorName: "Dr. Fixture",
            reportDate: measuredAt,
            summary: "UI Test structured lab report",
            notes: "Created through the Personal import command boundary.",
            recordedByHumanId: human.id.uuidString,
            metrics: [
                HumanLabMetricImportInput(
                    logID: logID,
                    measuredAt: measuredAt,
                    metricKey: "tsh",
                    unitCode: "mIU_L",
                    value: 2.4,
                    sourceLabel: "TSH",
                    referenceLow: 0.4,
                    referenceHigh: 4.0,
                    referenceRangeText: "0.4 - 4.0 mIU/L",
                    reportedFlag: .normal,
                    notes: "UI Test imported metric"
                )
            ]
        )
        let result = HumanLabReportImportCommandExecutor(
            context: context,
            revisions: services.domainRevisions,
            personalAccessLevel: .personal
        ).importReport(
            human: human,
            input: input,
            note: "startup.humanLab.uiTestFixture"
        )

        guard result.didPersist else {
            preconditionFailure(
                "Imported lab UI-test fixture was rejected: \(result.persistenceErrorDescription ?? "unknown failure")"
            )
        }
    }
}
#endif
