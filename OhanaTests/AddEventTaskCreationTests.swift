import Foundation
import Testing
@testable import Ohana

@MainActor
struct AddEventTaskCreationTests {
    @Test func typedPresetDerivesLockedCarePresentationWithoutLiveModels() {
        let subjectID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let preset = TaskCreationPreset(subjectID: subjectID, careKind: .plantWatering)
        let l = L10n("en")

        let state = AddEventTaskCreationState(
            preset: preset,
            subjectName: "  Fern  ",
            l: l
        )

        #expect(state.title == "\(preset.careKind.localizedTitle(l: l)) · Fern")
        #expect(state.eventType == .watering)
        #expect(state.relatedEntityType == EntityKind.plant.rawValue)
        #expect(state.relatedEntityId == subjectID.uuidString)
        #expect(state.taskCareKindRaw == preset.careKind.rawValue)
    }

    @Test func collaborationControlsAndRewardRequireTwoDistinctActiveHumans() {
        let creatorID = UUID()
        let assigneeID = UUID()

        #expect(!AddEventCollaborationPolicy.showsControls(activeHumanCount: 1))
        #expect(AddEventCollaborationPolicy.showsControls(activeHumanCount: 2))
        #expect(AddEventCollaborationPolicy.normalizedReward(
            25,
            activeHumanCount: 1,
            creatorHumanID: creatorID,
            assigneeHumanID: assigneeID
        ) == 0)
        #expect(AddEventCollaborationPolicy.normalizedReward(
            25,
            activeHumanCount: 2,
            creatorHumanID: creatorID,
            assigneeHumanID: creatorID
        ) == 0)
        #expect(AddEventCollaborationPolicy.normalizedReward(
            0,
            activeHumanCount: 2,
            creatorHumanID: creatorID,
            assigneeHumanID: assigneeID
        ) == 0)
        #expect(AddEventCollaborationPolicy.normalizedReward(
            FamilyTaskService.rewardCap + 1,
            activeHumanCount: 2,
            creatorHumanID: creatorID,
            assigneeHumanID: assigneeID
        ) == FamilyTaskService.rewardCap)
    }

    @Test func typedCreationWiringKeepsInternalReminderWhenNotificationPermissionIsDenied() throws {
        let rootURL = repositoryRootURL()
        let containerSource = try source(
            "Ohana/Features/Calendar/AddEventDataContainer.swift",
            rootURL: rootURL
        )
        let editorSource = try [
            "Ohana/Features/Calendar/Views/AddEventView.swift",
            "Ohana/Features/Calendar/Views/AddEventView+Actions.swift"
        ]
        .map { try source($0, rootURL: rootURL) }
        .joined(separator: "\n")

        #expect(containerSource.contains("var taskCreationPreset: TaskCreationPreset?"))
        #expect(containerSource.contains("taskCreationPreset: taskCreationPreset"))
        #expect(editorSource.contains("editingEvent == nil ? taskCreationPreset : nil"))
        #expect(editorSource.contains("add-event-locked-care-type"))
        #expect(editorSource.contains("add-event-locked-care-subject"))
        #expect(editorSource.contains("TaskCareAssignmentCommandExecutor("))
        #expect(editorSource.contains("let permissionGranted = await appServices.userNotifications.requestPermission()"))
        #expect(editorSource.contains("scheduleNotifications: permissionGranted"))
        #expect(editorSource.contains("scheduleNotifications: false"))
        #expect(editorSource.contains("CalendarCommandExecutor(context: modelContext, services: appServices)"))
        #expect(editorSource.contains("taskCareKindRaw: taskCreationPreset?.careKind.rawValue"))
        #expect(editorSource.contains("?? editingEvent?.taskCareKindRaw"))
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
