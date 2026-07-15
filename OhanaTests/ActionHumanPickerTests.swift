import Foundation
import SwiftUI
import Testing
@testable import Ohana

@MainActor
struct ActionHumanPickerTests {
    @Test func defaultsToCurrentLocalHumanWithoutChangingAnExistingDraft() {
        let currentID = UUID()
        let otherID = UUID()
        let humans = [
            ActionHumanOption(id: currentID, name: "Current"),
            ActionHumanOption(id: otherID, name: "Other")
        ]

        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: currentID,
            humans: humans
        ) == currentID)
        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: otherID,
            currentLocalHumanID: currentID,
            humans: humans
        ) == otherID)
    }

    @Test func deceasedHumansAreNeverEligible() {
        let deceasedID = UUID()
        let activeID = UUID()
        let humans = [
            ActionHumanOption(id: deceasedID, name: "Remembered", isDeceased: true),
            ActionHumanOption(id: activeID, name: "Active")
        ]

        #expect(ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans).map(\.id) == [activeID])
        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: deceasedID,
            currentLocalHumanID: deceasedID,
            humans: humans
        ) == activeID)
    }

    @Test func invalidDraftDoesNotSilentlyFallBackWhenMultipleHumansRemain() {
        let invalidID = UUID()
        let currentID = UUID()
        let humans = [
            ActionHumanOption(id: currentID, name: "Current"),
            ActionHumanOption(id: UUID(), name: "Other")
        ]

        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: invalidID,
            currentLocalHumanID: currentID,
            humans: humans
        ) == nil)
    }

    @Test func missingOrInvalidCurrentHumanRequiresChoiceWhenMultipleHumansRemain() {
        let humans = [
            ActionHumanOption(id: UUID(), name: "One"),
            ActionHumanOption(id: UUID(), name: "Two")
        ]

        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: nil,
            humans: humans
        ) == nil)
        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: UUID(),
            humans: humans
        ) == nil)
    }

    @Test func onlyEligibleHumanIsSelectedWithoutRenderingPickerChrome() {
        let onlyID = UUID()
        let humans = [ActionHumanOption(id: onlyID, name: "Only")]

        #expect(ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: nil,
            humans: humans
        ) == onlyID)

        let host = UIHostingController(
            rootView: ActionHumanPicker(
                humans: humans,
                currentLocalHumanID: nil,
                selectedHumanID: .constant(nil)
            )
        )
        let size = host.sizeThatFits(in: CGSize(width: 320, height: 80))

        #expect(size.width == 0)
        #expect(size.height == 0)
    }

    @Test func multipleEligibleHumansRenderCompactNativePicker() {
        let currentID = UUID()
        let host = UIHostingController(
            rootView: ActionHumanPicker(
                humans: [
                    ActionHumanOption(id: currentID, name: "Current"),
                    ActionHumanOption(id: UUID(), name: "Other")
                ],
                currentLocalHumanID: currentID,
                selectedHumanID: .constant(currentID),
                role: .recorder
            )
            .frame(width: 190)
        )
        let size = host.sizeThatFits(in: CGSize(width: 220, height: 80))

        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func sharedPickerOwnsNoGlobalCurrentHumanState() throws {
        let source = try String(
            contentsOf: repositoryRootURL()
                .appending(path: "Ohana/Shared/Components/ActionHumanPicker.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("@AppStorage"))
        #expect(!source.contains("UserDefaults"))
        #expect(!source.contains("currentActiveHumanId"))
        #expect(source.contains("@Binding private var selectedHumanID"))
    }

    @Test func petMedicationDoseWriteUsesTheConfirmedActorSnapshot() throws {
        let source = try String(
            contentsOf: repositoryRootURL()
                .appending(path: "Ohana/Domain/Services/PetMedicationDoseLogging.swift"),
            encoding: .utf8
        )

        #expect(source.contains("executorId: String?"))
        #expect(source.contains("requestedExecutorId: executorId"))
        #expect(!source.contains("UserDefaultsActiveHumanSelection"))
        #expect(!source.contains("activeHumanSelection.currentHumanId"))
    }

    @Test func quickMomentUsesDraftScopedRecorderAttribution() throws {
        let source = try String(
            contentsOf: repositoryRootURL()
                .appending(path: "Ohana/Features/Moments/Views/QuickMomentSheet.swift"),
            encoding: .utf8
        )

        #expect(source.contains("@State private var selectedRecorderHumanID: UUID?"))
        #expect(source.contains("@State private var requiresRecorderSelection = false"))
        #expect(source.contains("QuickCareActionHumanPickerContainer("))
        #expect(source.contains("role: .recorder"))
        #expect(source.contains("let executorId = selectedRecorderHumanID?.uuidString"))
        #expect(source.contains("&& !requiresRecorderSelection"))
        #expect(!source.contains("@AppStorage(\"currentActiveHumanId\")"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
