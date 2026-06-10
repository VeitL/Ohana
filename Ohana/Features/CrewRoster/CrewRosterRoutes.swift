//
//  CrewRosterRoutes.swift
//  Ohana
//
//  Typed presentation routes for the Ohana members surface.
//

import Foundation

enum CrewRosterMode: String, Hashable {
    case collaboration
    case members
}

enum CrewRosterFullScreenRoute: Identifiable, Equatable {
    case coconutLog
    case addEntity(EntityType)

    var id: String {
        switch self {
        case .coconutLog:
            "coconut-log"
        case let .addEntity(type):
            "add-\(type.id)"
        }
    }
}

enum CrewRosterSheetRoute: Identifiable, Equatable {
    case familyActivity(UUID)
    case familyWeeklyReport

    var id: String {
        switch self {
        case let .familyActivity(id):
            "family-activity-\(id.uuidString)"
        case .familyWeeklyReport:
            "family-weekly-report"
        }
    }
}
