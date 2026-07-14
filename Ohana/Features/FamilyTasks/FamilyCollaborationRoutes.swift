//
//  FamilyCollaborationRoutes.swift
//  Ohana
//
//  Stable typed routes for the family collaboration surface.
//

import Foundation

enum FamilyCollaborationSheetRoute: Identifiable, Equatable {
    case moreCollaboration

    var id: String {
        switch self {
        case .moreCollaboration:
            "more-collaboration"
        }
    }
}

enum FamilyCollaborationEditorRoute: Identifiable, Equatable {
    case assignReminder(UUID)
    case editTask(UUID)
    case create

    var id: String {
        switch self {
        case let .assignReminder(id):
            "assign-\(id.uuidString)"
        case let .editTask(id):
            "edit-\(id.uuidString)"
        case .create:
            "create"
        }
    }
}

enum FamilyCollaborationPostSheetAction: Equatable {
    case presentEditor(FamilyCollaborationEditorRoute)
    case openWeeklyReport
}

struct FamilyCollaborationEditorContext {
    let route: FamilyCollaborationEditorRoute
    let reminder: Reminder?
    let task: FamilyCollaborationTask?

    static func resolve(
        route: FamilyCollaborationEditorRoute,
        reminders: [Reminder],
        tasks: [FamilyCollaborationTask]
    ) -> FamilyCollaborationEditorContext? {
        switch route {
        case let .assignReminder(id):
            guard let reminder = reminders.first(where: { $0.id == id }) else { return nil }
            return FamilyCollaborationEditorContext(route: route, reminder: reminder, task: nil)
        case let .editTask(id):
            guard let task = tasks.first(where: { $0.id == id }) else { return nil }
            return FamilyCollaborationEditorContext(route: route, reminder: nil, task: task)
        case .create:
            return FamilyCollaborationEditorContext(route: route, reminder: nil, task: nil)
        }
    }
}
