//
//  MemberThemeColorMaintenanceService.swift
//  Ohana
//

import SwiftData

enum MemberThemeColorMaintenanceService {
    @MainActor
    static func normalizeReservedColors(context: ModelContext) {
        var didChange = false

        let pets = (try? context.fetch(FetchDescriptor<Pet>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
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

        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
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
            context.safeSave()
        }
    }
}
