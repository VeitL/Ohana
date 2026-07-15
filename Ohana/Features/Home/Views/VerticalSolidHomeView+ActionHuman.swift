//
//  VerticalSolidHomeView+ActionHuman.swift
//  Ohana
//
//  Draft-scoped attribution for Home actions that otherwise have no form.
//

import Foundation

extension VerticalSolidHomeView {
    func performWithActionHuman(
        actionTitle: String,
        perform: @escaping (String?) -> Void
    ) {
        let humans = interaction.humansByID.values.map {
            ActionHumanOption(
                id: $0.id,
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                isDeceased: $0.hasPassedAway
            )
        }
        let eligible = ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans)
        let preferredID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: activeHumanID,
            humans: humans
        )
        guard eligible.count > 1 else {
            perform(preferredID?.uuidString)
            return
        }
        pendingActionHumanConfirmation = ActionHumanConfirmationDraft(
            actionTitle: actionTitle,
            humans: eligible,
            preferredHumanID: preferredID,
            perform: perform
        )
    }
}
