//
//  IslandNegativeSignal.swift
//  Ohana
//
//  Shared value model for island negative feedback surfaces.
//

import Foundation

nonisolated struct IslandNegativeSignal: Identifiable, Equatable, Sendable {
    let id: String
    let iconName: String
    let emoji: String
    let title: String
    let detail: String
    let severity: Severity
    let petId: UUID?
    let plantId: UUID?
    let healthAlertType: HealthAlert.AlertType?
    let routeHint: RouteHint?

    enum Severity: Sendable {
        case warning
        case critical

        var identityToken: String {
            switch self {
            case .warning: "warning"
            case .critical: "critical"
            }
        }
    }

    enum RouteHint: String, Sendable {
        case petOverview
        case feed
        case water
        case potty
        case walk
        case weight
        case medication
        case health
        case allFeatures
        case plant
    }

    init(
        id: String? = nil,
        iconName: String,
        emoji: String,
        title: String,
        detail: String,
        severity: Severity,
        petId: UUID? = nil,
        plantId: UUID? = nil,
        healthAlertType: HealthAlert.AlertType? = nil,
        routeHint: RouteHint? = nil
    ) {
        self.id = id ?? Self.identityKey(
            title: title,
            detail: detail,
            severity: severity,
            petId: petId,
            plantId: plantId,
            healthAlertType: healthAlertType,
            routeHint: routeHint
        )
        self.iconName = iconName
        self.emoji = emoji
        self.title = title
        self.detail = detail
        self.severity = severity
        self.petId = petId
        self.plantId = plantId
        self.healthAlertType = healthAlertType
        self.routeHint = routeHint
    }

    private static func identityKey(
        title: String,
        detail: String,
        severity: Severity,
        petId: UUID?,
        plantId: UUID?,
        healthAlertType: HealthAlert.AlertType?,
        routeHint: RouteHint?
    ) -> String {
        let subject = if let petId {
            "pet:\(petId.uuidString)"
        } else if let plantId {
            "plant:\(plantId.uuidString)"
        } else {
            "household"
        }
        let alert = healthAlertType.map { ":health:\($0.rawValue)" } ?? ""
        let route = routeHint.map { ":route:\($0.rawValue)" } ?? ""
        return [
            "negative" + route,
            subject + alert,
            severity.identityToken,
            stableHash(title),
            stableHash(detail)
        ].joined(separator: ":")
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 5381
        for scalar in value.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        return String(hash, radix: 16)
    }
}
