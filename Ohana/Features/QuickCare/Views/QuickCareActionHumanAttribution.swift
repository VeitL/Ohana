//
//  QuickCareActionHumanAttribution.swift
//  Ohana
//
//  Shared, draft-scoped action attribution presentation for quick care sheets.
//

import SwiftUI

nonisolated struct QuickCareActionHumanSelection: Equatable, Sendable {
    let executorID: String?
    let requiresSelection: Bool
}

@MainActor
enum QuickCareActionHumanAttribution {
    static func selection(
        humans: [Human],
        currentLocalHumanIDRaw: String?,
        draftHumanID: UUID?
    ) -> QuickCareActionHumanSelection {
        let options = options(from: humans)
        let executorID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: draftHumanID,
            currentLocalHumanID: currentLocalHumanIDRaw.flatMap(UUID.init(uuidString:)),
            humans: options
        )
        return QuickCareActionHumanSelection(
            executorID: executorID?.uuidString,
            requiresSelection: ActionHumanDefaultSelectionPolicy.eligibleHumans(from: options).count > 1 &&
                executorID == nil
        )
    }

    static func options(from humans: [Human]) -> [ActionHumanOption] {
        humans.map { human in
            ActionHumanOption(
                id: human.id,
                name: human.name,
                avatarEmoji: human.avatarEmoji,
                isDeceased: human.hasPassedAway
            )
        }
    }
}

struct QuickCareActionHumanAttributionPicker: View {
    let humans: [Human]
    let currentLocalHumanIDRaw: String?
    let role: ActionHumanRole
    let tint: Color

    @Binding var selectedHumanID: UUID?

    init(
        humans: [Human],
        currentLocalHumanIDRaw: String?,
        selectedHumanID: Binding<UUID?>,
        role: ActionHumanRole,
        tint: Color
    ) {
        self.humans = humans
        self.currentLocalHumanIDRaw = currentLocalHumanIDRaw
        self.role = role
        self.tint = tint
        _selectedHumanID = selectedHumanID
    }

    var body: some View {
        ActionHumanPicker(
            humans: QuickCareActionHumanAttribution.options(from: humans),
            currentLocalHumanID: currentLocalHumanIDRaw.flatMap(UUID.init(uuidString:)),
            selectedHumanID: $selectedHumanID,
            role: role,
            tint: tint
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
