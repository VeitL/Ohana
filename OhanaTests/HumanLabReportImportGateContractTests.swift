import Foundation
import Testing
@testable import Ohana

struct HumanLabReportImportGateContractTests {
    @Test func documentScanningIsGatedFromEntryToPersistence() throws {
        #expect(!PersonalFeatureAccessPolicy.allows(.documentScanning, level: .free))
        #expect(PersonalFeatureAccessPolicy.allows(.documentScanning, level: .personal))

        for path in [
            "Ohana/Features/Health/Views/HumanHealthCheckupView.swift",
            "Ohana/Features/HumanHealth/Views/HumanHealthReportView.swift"
        ] {
            let viewSource = normalized(try source(path))

            #expect(viewSource.contains(
                "sheetDestination = appServices.commerce.allows(.documentScanning) ? .labReportImport : .personalUpgrade"
            ))
            #expect(viewSource.contains(
                "case .labReportImport: HumanLabResultImportView(human: human)"
            ))
            #expect(viewSource.contains(
                "case .personalUpgrade: PersonalPlanView(prompt: PersonalUpgradePrompt(feature: .documentScanning))"
            ))
        }

        let commandSource = normalized(try source(
            "Ohana/Features/HumanHealth/HumanLabReportImportCommands.swift"
        ))
        #expect(commandSource.contains(
            "static func importReport( human: Human, input: HumanLabReportImportInput, personalAccessLevel: PersonalAccessLevel, context: ModelContext, saveChanges:"
        ))
        #expect(!commandSource.contains("personalAccessLevel: PersonalAccessLevel ="))
        #expect(commandSource.contains(
            "guard PersonalFeatureAccessPolicy.allows( .documentScanning, level: personalAccessLevel ) else"
        ))
        #expect(commandSource.contains("personal.documentScanning.required"))
        #expect(commandSource.contains(
            "personalAccessLevel: services.commerce.personalAccessLevel"
        ))
        #expect(commandSource.contains(
            "personalAccessLevel: personalAccessLevel, context: context"
        ))

        let importViewSource = normalized(try source(
            "Ohana/Features/HumanHealth/LabImport/HumanLabResultImportView.swift"
        ))
        #expect(importViewSource.contains(
            "HumanLabReportImportCommandExecutor( context: modelContext, services: appServices ).importReport("
        ))
    }

    private func normalized(_ source: String) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
