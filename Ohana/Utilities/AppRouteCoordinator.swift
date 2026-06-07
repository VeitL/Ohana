//
//  AppRouteCoordinator.swift
//  Ohana
//
//  Global typed route source of truth. Routes carry stable identifiers and
//  lightweight parameters; destination containers perform their own fetches.
//

import Combine
import Foundation
import SwiftUI

enum AppRoute: Hashable, Identifiable {
    case petProfile(id: UUID, initialTab: PetDetailTab)
    case humanProfile(id: UUID)
    case plantProfile(id: UUID)

    var id: String {
        switch self {
        case let .petProfile(id, tab):
            return "pet-profile-\(id.uuidString)-\(tab.rawValue)"
        case let .humanProfile(id):
            return "human-profile-\(id.uuidString)"
        case let .plantProfile(id):
            return "plant-profile-\(id.uuidString)"
        }
    }

    var sourceID: UUID {
        switch self {
        case let .petProfile(id, _),
             let .humanProfile(id),
             let .plantProfile(id):
            return id
        }
    }
}

enum AppSheetRoute: Hashable, Identifiable {
    case requiredAccountSwitch

    var id: String {
        switch self {
        case .requiredAccountSwitch:
            return "required-account-switch"
        }
    }
}

enum AppFullScreenRoute: Hashable, Identifiable {
    case requiredHumanProfile

    var id: String {
        switch self {
        case .requiredHumanProfile:
            return "required-human-profile"
        }
    }
}

enum AppOverlayRoute: Hashable, Identifiable {
    case none(UUID = UUID())

    var id: UUID {
        switch self {
        case let .none(id):
            return id
        }
    }
}

@MainActor
final class AppRouteCoordinator: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var sheet: AppSheetRoute?
    @Published var fullScreen: AppFullScreenRoute?
    @Published var overlay: AppOverlayRoute?

    func openPet(_ id: UUID, initialTab: PetDetailTab = .overview) {
        push(.petProfile(id: id, initialTab: initialTab))
    }

    func openHuman(_ id: UUID) {
        push(.humanProfile(id: id))
    }

    func openPlant(_ id: UUID) {
        push(.plantProfile(id: id))
    }

    func presentRequiredHumanProfile() {
        sheet = nil
        fullScreen = .requiredHumanProfile
    }

    func presentRequiredAccountSwitch() {
        fullScreen = nil
        sheet = .requiredAccountSwitch
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func dismissSheet(_ route: AppSheetRoute? = nil) {
        guard route == nil || sheet == route else { return }
        sheet = nil
    }

    func dismissFullScreen(_ route: AppFullScreenRoute? = nil) {
        guard route == nil || fullScreen == route else { return }
        fullScreen = nil
    }

    func resetToHome() {
        path.removeAll()
        sheet = nil
        fullScreen = nil
        overlay = nil
    }
}
