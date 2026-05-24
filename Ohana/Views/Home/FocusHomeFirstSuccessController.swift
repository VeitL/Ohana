//
//  FocusHomeFirstSuccessController.swift
//  Ohana
//
//  First successful quick-action helper state for the expanded card.
//

import Combine
import Foundation
import UIKit

@MainActor
final class FocusHomeFirstSuccessController: ObservableObject {
    private var pendingMomentPetId: UUID?
    private var momentCoconutBefore: Int?

    func completeFeed(
        for pet: Pet,
        expand: (UUID) -> Void,
        performFeed: (Pet) -> Void
    ) {
        expand(pet.id)
        performFeed(pet)
    }

    func completePlay(
        for pet: Pet,
        expand: (UUID) -> Void,
        performPlay: (Pet) -> Void
    ) {
        expand(pet.id)
        performPlay(pet)
    }

    func startMoment(
        for pet: Pet,
        expand: (UUID) -> Void,
        presentMoment: (Pet) -> Void
    ) {
        expand(pet.id)
        pendingMomentPetId = pet.id
        momentCoconutBefore = QuestManager.shared.coconutCount
        presentMoment(pet)
    }

    func completeMomentIfNeeded(
        for pet: Pet,
        triggerFeedback: (_ coconutDelta: Int, _ label: String?) -> Void,
        markCompleted: () -> Void
    ) {
        guard pendingMomentPetId == pet.id else { return }
        let before = momentCoconutBefore ?? QuestManager.shared.coconutCount
        let coconutDelta = max(0, QuestManager.shared.coconutCount - before)
        pendingMomentPetId = nil
        momentCoconutBefore = nil

        triggerFeedback(
            coconutDelta,
            coconutDelta > 0 ? "照片记录 +\(coconutDelta)🥥" : nil
        )
        markCompleted()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
