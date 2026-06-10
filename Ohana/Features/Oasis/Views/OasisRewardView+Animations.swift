//
//  OasisRewardView+Animations.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Animations

    func startAmbientMotionIfNeeded() {
        updateGlowMotion()
        startBreathing()
    }

    func stopAmbientMotion() {
        glowBreathing = false
        treeScale = 1.0
        treeGlow = 0.4
    }

    func updateGlowMotion() {
        glowBreathing = shouldRunAmbientMotion
    }

    func startBreathing() {
        guard shouldRunAmbientMotion else {
            treeScale = 1.0
            treeGlow = 0.4
            return
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { // ui-v4: allow AppWorkloadPolicy-gated Oasis ambient breathing; smoothness: allow visible-only ambient tree scale
            treeScale = 1.055
            treeGlow = 0.7
        }
    }

    func triggerLevelUpFeedback() {
        guard !levelUpPulse else { return }
        OhanaFeedback.success()
        spawnEnergyParticles(count: 22)
        withAnimation(GoMotion.rewardPop) {
            levelUpPulse = true
            levelUpBadgeVisible = true
        }
        levelUpFeedbackTask?.cancel()
        levelUpFeedbackTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 280) {
            withAnimation(GoMotion.stateChange) {
                levelUpPulse = false
            }
            levelUpFeedbackTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 920) {
                withAnimation(GoMotion.quick) {
                    levelUpBadgeVisible = false
                }
                levelUpFeedbackTask = nil
            }
        }
    }

    func spawnEnergyParticles(count: Int = 8) {
        energyParticles = (0 ..< count).map { _ in EnergyParticle() }
        for i in energyParticles.indices {
            withAnimation(.easeOut(duration: Double.random(in: 0.85 ... 1.55)).delay(Double(i) * 0.035)) { // ui-v4: allow short reward particle burst
                energyParticles[i].offsetY = CGFloat.random(in: -180 ... -80)
                energyParticles[i].opacity = 0
            }
        }
        particleCleanupTask?.cancel()
        particleCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1750) {
            energyParticles.removeAll()
            particleCleanupTask = nil
        }
    }
}
