//
//  SystemSurfaceRouteInbox.swift
//  Ohana
//
//  Buffers a typed system-surface route across cold app bootstrap.
//

import Foundation
import Observation

@MainActor
@Observable
final class SystemSurfaceRouteInbox {
    struct Request: Identifiable, Equatable {
        let id: UUID
        let route: OhanaExternalRoute

        init(id: UUID = UUID(), route: OhanaExternalRoute) {
            self.id = id
            self.route = route
        }
    }

    private(set) var pendingRequest: Request?

    @discardableResult
    func submit(_ url: URL) -> Bool {
        guard let route = OhanaExternalRoute.parse(url) else { return false }
        pendingRequest = Request(route: route)
        return true
    }

    func consume(_ requestID: UUID) {
        guard pendingRequest?.id == requestID else { return }
        pendingRequest = nil
    }
}
