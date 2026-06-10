//
//  FocusHomeWalkTransformController.swift
//  Ohana
//
//  Short-lived walk-card transform state.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class FocusHomeWalkTransformController: ObservableObject {
    @Published var burstCardId: UUID?
    private let walking: PetWalkingManaging

    init() {
        self.walking = SharedPetWalkingManager()
    }

    init(walking: PetWalkingManaging) {
        self.walking = walking
    }

    func trigger(
        for pet: Pet,
        expand: (UUID) -> Void,
        pulse: @escaping (UUID?) -> Void
    ) {
        walking.isWalkCardExpandedSurfaceVisible = true
        expand(pet.id)
        withAnimation(HeroAnim.fabSpring) {
            burstCardId = pet.id
            pulse(pet.id)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard burstCardId == pet.id else { return }
            withAnimation(GoMotion.quick) {
                burstCardId = nil
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 680_000_000)
            pulse(nil)
        }
    }
}
