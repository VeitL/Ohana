//
//  MemberThemeColorMaintenanceService.swift
//  Ohana
//

import Foundation
import SwiftData

enum MemberThemeColorMaintenanceService {
    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "MemberThemeColorMaintenanceService failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    static func normalizeReservedColors(context: ModelContext) {
        var didChange = false

        let pets = fetchOrLog(
            FetchDescriptor<Pet>(),
            context: context,
            operation: "fetch pets for theme color normalization"
        )
        for pet in pets {
            let normalized = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                pet.themeColorHex,
                fallback: OhanaThemeColorPolicy.petFallbackHex
            )
            if pet.themeColorHex.uppercased() != normalized {
                pet.themeColorHex = normalized
                didChange = true
            }
        }

        let humans = fetchOrLog(
            FetchDescriptor<Human>(),
            context: context,
            operation: "fetch humans for theme color normalization"
        )
        for human in humans {
            let normalized = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                human.themeColorHex,
                fallback: OhanaThemeColorPolicy.humanFallbackHex
            )
            if human.themeColorHex.uppercased() != normalized {
                human.themeColorHex = normalized
                didChange = true
            }
        }

        if didChange {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            if !saveResult.didSave {
                context.rollback()
            }
        }
    }
}
