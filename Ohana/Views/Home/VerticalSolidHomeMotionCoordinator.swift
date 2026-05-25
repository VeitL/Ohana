//
//  VerticalSolidHomeMotionCoordinator.swift
//  Ohana
//
//  Freezes the portrait solid home render inputs while hero motion is active.
//

import Foundation
import Combine
import SwiftUI

struct VerticalSolidHomeRenderSnapshot {
    let cards: [FocusCard]
    let pets: [Pet]
    let activePets: [Pet]
    let plants: [Plant]
    let reminders: [Reminder]
    let humans: [Human]
    let events: [Event]
    let activePetId: UUID?
    let selectedTab: VerticalHomeTab

    var activePet: Pet? {
        guard let activePetId else { return activePets.first }
        return activePets.first(where: { $0.id == activePetId }) ?? activePets.first
    }
}

@MainActor
final class VerticalSolidHomeMotionCoordinator: ObservableObject {
    @Published private(set) var renderSnapshot: VerticalSolidHomeRenderSnapshot?
    @Published private(set) var isHeroMotionActive = false
    @Published private(set) var isTabMotionLocked = false

    private var generation = 0

    var cards: [FocusCard]? {
        renderSnapshot?.cards
    }

    func freeze(_ snapshot: VerticalSolidHomeRenderSnapshot) {
        generation += 1
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            renderSnapshot = snapshot
            isHeroMotionActive = true
            isTabMotionLocked = true
        }
    }

    func unlockStableExpandedState() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHeroMotionActive = false
            isTabMotionLocked = false
            renderSnapshot = nil
        }
    }

    func thawAfterCollapse() {
        generation += 1
        let token = generation
        OhanaFrameScheduler.runAfterNextFrame {
            guard token == self.generation else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.renderSnapshot = nil
                self.isHeroMotionActive = false
                self.isTabMotionLocked = false
            }
        }
    }

    func lockForTabMotion() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isTabMotionLocked = true
        }
    }

    func unlockAfterTabMotion(milliseconds: UInt64) {
        generation += 1
        let token = generation
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            guard token == self.generation else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.isTabMotionLocked = false
            }
        }
    }
}
