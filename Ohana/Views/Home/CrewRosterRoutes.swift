//
//  CrewRosterRoutes.swift
//  Ohana
//
//  Typed presentation routes for the Ohana members surface.
//

import Foundation

enum CrewRosterMode: String, Equatable {
    case collaboration
    case members
}

enum CrewRosterFullScreenRoute: Identifiable, Equatable {
    case coconutLog
    case addEntity(EntityType)

    var id: String {
        switch self {
        case .coconutLog:
            return "coconut-log"
        case let .addEntity(type):
            return "add-\(type.id)"
        }
    }
}

enum CrewRosterSheetRoute: Identifiable, Equatable {
    case familyActivity(UUID)
    case familyWeeklyReport

    var id: String {
        switch self {
        case let .familyActivity(id):
            return "family-activity-\(id.uuidString)"
        case .familyWeeklyReport:
            return "family-weekly-report"
        }
    }
}
