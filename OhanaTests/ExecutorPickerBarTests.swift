import Foundation
import SwiftUI
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ExecutorPickerBarTests {
    @Test func emptyHumansRenderNoPickerChrome() {
        UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")

        let host = UIHostingController(rootView: ExecutorPickerBar(humans: []))
        let size = host.sizeThatFits(in: CGSize(width: 320, height: 80))

        #expect(size.width == 0)
        #expect(size.height == 0)
    }

    @Test func multipleHumansRenderPickerChrome() {
        UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")

        let host = UIHostingController(
            rootView: ExecutorPickerBar(
                humans: [
                    Human(name: "Guan"),
                    Human(name: "Li")
                ],
                tint: .goYellow
            )
            .frame(width: 180)
        )
        let size = host.sizeThatFits(in: CGSize(width: 220, height: 80))

        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func highReuseAvatarComponentsUseMediaBlobLoader() throws {
        let rootURL = repositoryRootURL()
        let executorSource = try source("Ohana/Shared/Components/ExecutorPickerBar.swift", rootURL: rootURL)
        let pipelineSource = try source("Ohana/Shared/Components/HumanAvatarPipelineView.swift", rootURL: rootURL)
        let petPortraitSource = try source("Ohana/Shared/Components/PetAvatarPortraitView.swift", rootURL: rootURL)
        let featureHubSource = try source("Ohana/Shared/Components/FeatureHubComponents.swift", rootURL: rootURL)

        #expect(executorSource.contains("SwiftDataMediaBlobLoader(modelContainer: modelContext.container)"))
        #expect(executorSource.contains("humanAvatarImageData(modelID: modelID)"))
        #expect(!executorSource.contains("human.avatarImageData"))

        #expect(pipelineSource.contains("SwiftDataMediaBlobLoader(modelContainer: modelContext.container)"))
        #expect(pipelineSource.contains("humanAvatarImageData(modelID: modelID)"))
        #expect(!pipelineSource.contains("human.avatarImageData"))

        #expect(petPortraitSource.contains("SwiftDataMediaBlobLoader(modelContainer: container)"))
        #expect(petPortraitSource.contains("petAvatarImageData(modelID: petModelID)"))
        #expect(!petPortraitSource.contains("pet.avatarImageData"))

        #expect(featureHubSource.contains("FeatureHubAvatarBlobSource"))
        #expect(featureHubSource.contains("petAvatarImageData(modelID: modelID)"))
        #expect(featureHubSource.contains("humanAvatarImageData(modelID: modelID)"))
        #expect(featureHubSource.contains("plantAvatarImageData(modelID: modelID)"))
        #expect(!featureHubSource.contains("pet.avatarImageData"))
        #expect(!featureHubSource.contains("human.avatarImageData"))
        #expect(!featureHubSource.contains("plant.avatarImageData"))

        for path in featureHubAvatarCallerPaths {
            let callerSource = try source(path, rootURL: rootURL)
            #expect(!callerSource.contains("pet.hasAvatarImageAttachment ? pet.avatarImageData : nil"))
            #expect(!callerSource.contains("human.hasAvatarImageAttachment ? human.avatarImageData : nil"))
            #expect(!callerSource.contains("plant.hasAvatarImageAttachment ? plant.avatarImageData : nil"))
        }
    }

    private var featureHubAvatarCallerPaths: [String] {
        [
            "Ohana/Shared/Components/HumanModuleV4Components.swift",
            "Ohana/Features/DashboardRecords/Views/PetRetentionHubView.swift",
            "Ohana/Features/Economy/Views/PetBondVaultView.swift",
            "Ohana/Features/Moments/Views/PetMomentsHubView.swift",
            "Ohana/Features/Moments/Views/QuickMomentSheet.swift",
            "Ohana/Features/Medication/Views/PetMedicationDetailSheet.swift",
            "Ohana/Features/Medication/Views/PetMedicationView.swift",
            "Ohana/Features/Expenses/Views/HumanWeightDashboardContent.swift",
            "Ohana/Features/Expenses/Views/PetWeightDashboardContent.swift",
            "Ohana/Features/Expenses/Views/HumanExpenseDashboardContent.swift",
            "Ohana/Features/Expenses/Views/PetExpenseDashboardContent.swift",
            "Ohana/Features/Members/Views/PetAllFeaturesSheet.swift",
            "Ohana/Features/Plants/Views/PlantAllFeaturesSheet.swift"
        ]
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
