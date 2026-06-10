//
//  VerticalSolidHomeView+Growth.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension VerticalSolidHomeView {
    func openGrowthDailyLoop(
        hasAnyMember: Bool,
        pendingFocusCount: Int,
        currentLevel: Int
    ) {
        closeVerticalFabMenu(immediate: true)
        guard hasAnyMember else {
            routeCoordinator.openAddEntity(.pet)
            return
        }

        let destination: FMDest = pendingFocusCount > 0
            ? .featureGroup(.dailyCare)
            : AppFeatureRouteGuard.recommendedDestination(
                for: AppFeatureRouteGuard.currentGrowthStep(currentLevel: currentLevel),
                currentLevel: currentLevel
            )
        openFunctionMenu(destination: destination)
    }

    func openHeaderTreeLevelDestination(hasAnyMember: Bool) {
        closeVerticalFabMenu(immediate: true)
        guard hasAnyMember else {
            OhanaFrameScheduler.runAfterNextFrame {
                routeCoordinator.openAddEntity(.pet)
            }
            return
        }

        OhanaFrameScheduler.runAfterNextFrame {
            AppPerformanceMonitor.shared.record("growth_roadmap_opened", valueMS: 0, note: "homeHeader")
            openFunctionMenu(destination: .growthRoadmap)
        }
    }

    func openCalendarAddEvent() {
        guard !isCalendarAddEventPresented else { return }
        closeVerticalFabMenu(immediate: true)
        calendarAddEventPresentationTask?.cancel()
        calendarAddEventContentMountTask?.cancel()
        isCalendarAddEventPresented = true
        calendarAddEventProgress = 0
        isCalendarAddEventContentMounted = false
        calendarAddEventPresentationTask = OhanaFrameScheduler.runAfterNextFrame {
            guard isCalendarAddEventPresented else {
                calendarAddEventPresentationTask = nil
                return
            }
            withAnimation(GoMotion.sheetEnter) {
                calendarAddEventProgress = 1
            }
            calendarAddEventPresentationTask = nil
        }
        calendarAddEventContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            guard isCalendarAddEventPresented else {
                calendarAddEventContentMountTask = nil
                return
            }
            withAnimation(GoMotion.quick) {
                isCalendarAddEventContentMounted = true
            }
            calendarAddEventContentMountTask = nil
        }
    }

    func closeCalendarAddEvent() {
        guard isCalendarAddEventPresented || calendarAddEventProgress > 0.001 else { return }
        calendarAddEventContentMountTask?.cancel()
        isCalendarAddEventContentMounted = false
        withAnimation(GoMotion.sheetEnter) {
            calendarAddEventProgress = 0
        }
        calendarAddEventPresentationTask?.cancel()
        calendarAddEventPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 340) {
            guard calendarAddEventProgress <= 0.02 else {
                calendarAddEventPresentationTask = nil
                return
            }
            isCalendarAddEventPresented = false
            isCalendarAddEventContentMounted = false
            calendarAddEventPresentationTask = nil
        }
    }

    func scheduleGrowthOnboardingIfNeeded() {
        guard !growthOnboardingCompleted,
              !showGrowthOnboarding,
              pets.isEmpty,
              humans.isEmpty else {
            return
        }
        growthOnboardingTask?.cancel()
        growthOnboardingTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 680) {
            guard !growthOnboardingCompleted,
                  pets.isEmpty,
                  humans.isEmpty else {
                growthOnboardingTask = nil
                return
            }
            withAnimation(GoMotion.feedback) {
                showGrowthOnboarding = true
            }
            growthOnboardingTask = nil
        }
    }

    func completeGrowthOnboarding() {
        growthOnboardingCompleted = true
        growthOnboardingTask?.cancel()
        growthOnboardingTask = nil
        withAnimation(GoMotion.feedback) {
            showGrowthOnboarding = false
        }
    }

    func scheduleGrowthUnlockFeedbackIfNeeded() {
        let currentLevel = treeManager.treeLevel.rawValue
        guard currentLevel > 0 else { return }

        guard growthLastSeenTreeLevel > 0 else {
            growthLastSeenTreeLevel = currentLevel
            return
        }

        guard currentLevel > growthLastSeenTreeLevel else {
            if currentLevel < growthLastSeenTreeLevel {
                growthLastSeenTreeLevel = currentLevel
            }
            return
        }

        let unlockedSteps = AppFeatureRouteGuard.newlyUnlockedStages(
            from: growthLastSeenTreeLevel,
            to: currentLevel
        )
        growthLastSeenTreeLevel = currentLevel
        guard let step = unlockedSteps.last else { return }

        growthUnlockToastPresentationTask?.cancel()
        growthUnlockToastDismissTask?.cancel()
        growthUnlockToastPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: showGrowthOnboarding ? 1_800 : 520) {
            guard !showGrowthOnboarding else {
                growthUnlockToastPresentationTask = nil
                return
            }
            withAnimation(GoMotion.sheetEnter) {
                growthUnlockToastStatus = GrowthUnlockStatus(step: step, currentLevel: currentLevel)
            }
            growthUnlockToastPresentationTask = nil
            growthUnlockToastDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3_800) {
                dismissGrowthUnlockToast()
            }
        }
    }

    func dismissGrowthUnlockToast() {
        growthUnlockToastPresentationTask?.cancel()
        growthUnlockToastDismissTask?.cancel()
        growthUnlockToastPresentationTask = nil
        growthUnlockToastDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            growthUnlockToastStatus = nil
        }
    }

    func openGrowthUnlockDestination(_ status: GrowthUnlockStatus) {
        OhanaFeedback.light()
        let destination = AppFeatureRouteGuard.recommendedDestination(
            for: status.step,
            currentLevel: status.currentLevel
        )
        dismissGrowthUnlockToast()
        OhanaFrameScheduler.runAfterNextFrame {
            openFunctionMenu(destination: destination)
        }
    }

    func scheduleGrowthLoopSync(after mutation: DomainMutationResult) {
        guard mutation.wroteBusinessFact else { return }
        appServices.onboardingJourney.markFirstCareCompleted()
        let previousLevel = treeManager.treeLevel.rawValue
        let previousEnergy = treeManager.totalEnergy
        let previousProgress = treeManager.progressToNextLevel

        growthLoopSyncTask?.cancel()
        growthLoopSyncTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            let startedAt = CFAbsoluteTimeGetCurrent()
            treeManager.refreshEnergy(
                modelContext: modelContext,
                pets: pets,
                humans: humans,
                plants: plants
            )
            let currentLevel = treeManager.treeLevel.rawValue
            let currentEnergy = treeManager.totalEnergy
            let currentProgress = treeManager.progressToNextLevel
            let energyDelta = max(0, currentEnergy - previousEnergy)

            AppPerformanceMonitor.shared.record(
                "growth_loop_energy_synced",
                startedAt: startedAt,
                note: "command=\(mutation.command), energyDelta=\(energyDelta), level=\(previousLevel)->\(currentLevel)"
            )

            if currentLevel > previousLevel {
                growthLoopPulseDismissTask?.cancel()
                growthLoopPulseDismissTask = nil
                growthLoopPulseStatus = nil
                scheduleGrowthUnlockFeedbackIfNeeded()
            } else if energyDelta > 0 || currentProgress > previousProgress {
                presentGrowthLoopPulse(
                    currentLevel: currentLevel,
                    energyDelta: max(energyDelta, 1),
                    progress: currentProgress
                )
            }
            growthLoopSyncTask = nil
        }
    }

    func presentGrowthLoopPulse(
        currentLevel: Int,
        energyDelta: Int,
        progress: Double
    ) {
        growthLoopPulseDismissTask?.cancel()
        let progressPercent = min(100, max(0, Int((progress * 100).rounded())))
        withAnimation(GoMotion.sheetEnter) {
            growthLoopPulseStatus = GrowthLoopPulseStatus(
                currentLevel: currentLevel,
                energyDelta: energyDelta,
                progressPercent: progressPercent
            )
        }
        growthLoopPulseDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 2_600) {
            dismissGrowthLoopPulse()
        }
    }

    func dismissGrowthLoopPulse() {
        growthLoopPulseDismissTask?.cancel()
        growthLoopPulseDismissTask = nil
        withAnimation(GoMotion.sheetEnter) {
            growthLoopPulseStatus = nil
        }
    }
}
