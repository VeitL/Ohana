//
//  FocusHomeWalkCardFlip.swift
//  Ohana
//
//  Stable flip scene between an expanded pet card and its walk tracker.
//

import SwiftUI

struct FocusHomeWalkCardFlip<Front: View>: View {
    let walkPet: Pet?
    var reduceMotion: Bool = false
    var walkCardPadding: CGFloat = 10
    var retainsWalkPetDuringClose: Bool = true
    private let front: () -> Front

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var retainedWalkPet: Pet?
    @State private var rotation: Double = 0
    @State private var generation = 0

    init(
        walkPet: Pet?,
        reduceMotion: Bool = false,
        walkCardPadding: CGFloat = 10,
        retainsWalkPetDuringClose: Bool = true,
        @ViewBuilder front: @escaping () -> Front
    ) {
        self.walkPet = walkPet
        self.reduceMotion = reduceMotion
        self.walkCardPadding = walkCardPadding
        self.retainsWalkPetDuringClose = retainsWalkPetDuringClose
        self.front = front
    }

    var body: some View {
        ZStack {
            front()
                .opacity(rotation < 90 ? 1 : 0)
                .allowsHitTesting(currentWalkPet == nil && rotation < 90)

            if let pet = currentWalkPet {
                WalkTrackingCardHost(
                    pet: pet,
                    onCloseSummaryToPetCard: closeWalkSummaryToPetCard
                )
                .padding(walkCardPadding)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(rotation >= 90 ? 1 : 0)
                .allowsHitTesting(rotation >= 90)
            }
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
        .onAppear {
            retainedWalkPet = walkPet
            if walkPet != nil {
                rotation = 0
                OhanaFrameScheduler.runAfterNextFrame {
                    syncWalkPet(animated: true)
                }
            }
        }
        .onChange(of: walkPet?.id) { _, _ in
            syncWalkPet(animated: true)
        }
        .onChange(of: retainsWalkPetDuringClose) { _, _ in
            syncWalkPet(animated: false)
        }
    }

    private var currentWalkPet: Pet? {
        retainsWalkPetDuringClose ? (walkPet ?? retainedWalkPet) : walkPet
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || accessibilityReduceMotion
    }

    private var flipAnimation: Animation {
        effectiveReduceMotion ? GoMotion.reduced : GoMotion.zStackHero
    }

    private var cleanupDelayMilliseconds: UInt64 {
        effectiveReduceMotion ? 120 : 540
    }

    private func syncWalkPet(animated: Bool) {
        generation += 1
        if let walkPet {
            retainedWalkPet = walkPet
            setRotation(180, animated: animated)
            return
        }

        if !retainsWalkPetDuringClose {
            retainedWalkPet = nil
            setRotation(0, animated: false)
            return
        }

        let targetGeneration = generation
        setRotation(0, animated: animated)
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: cleanupDelayMilliseconds) {
            guard targetGeneration == generation, walkPet == nil else { return }
            retainedWalkPet = nil
        }
    }

    private func closeWalkSummaryToPetCard() {
        generation += 1
        let targetGeneration = generation
        setRotation(0, animated: true)
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: cleanupDelayMilliseconds) {
            guard targetGeneration == generation else { return }
            PetWalkingManager.shared.reset()
            retainedWalkPet = nil
        }
    }

    private func setRotation(_ target: Double, animated: Bool) {
        guard rotation != target else { return }
        if animated {
            withAnimation(flipAnimation) {
                rotation = target
            }
        } else {
            rotation = target
        }
    }
}
