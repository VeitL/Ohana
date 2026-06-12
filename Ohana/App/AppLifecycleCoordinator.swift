//
//  AppLifecycleCoordinator.swift
//  Ohana
//
//  Central lifecycle handoff for runtime policy, walk delivery, and background work.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

enum AppLifecycleEvent: Equatable {
    case rootAppeared(scenePhase: ScenePhase)
    case scenePhaseChanged(ScenePhase)
    case didEnterBackground
    case willResignActive
    case didBecomeActive
    case willTerminate
}

enum AppLifecycleCommand: Equatable {
    case allowSystemAutoLock
    case updateWorkloadPhase(ScenePhase)
    case refreshWorkload(reason: String)
    case walkBackground
    case walkInactive
    case walkForeground
    case pauseWalkingForTermination
    case scheduleReminderRefill
    case runAutomaticBackupIfDue(reason: String)
}

@MainActor
protocol AppLifecycleHandling {
    func handle(_ event: AppLifecycleEvent)
}

struct AppLifecycleReducer {
    private(set) var appliedPhase: ScenePhase?

    mutating func reduce(_ event: AppLifecycleEvent) -> [AppLifecycleCommand] {
        switch event {
        case let .rootAppeared(scenePhase):
            [.allowSystemAutoLock]
                + transitionCommands(to: scenePhase)
                + [
                    .refreshWorkload(reason: "contentAppear"),
                    .runAutomaticBackupIfDue(reason: "rootAppeared")
                ]
        case let .scenePhaseChanged(phase):
            activeCommandsIfNeeded(for: phase) + transitionCommands(to: phase)
        case .didEnterBackground:
            transitionCommands(to: .background) + [
                .scheduleReminderRefill,
                .runAutomaticBackupIfDue(reason: "didEnterBackground")
            ]
        case .willResignActive:
            transitionCommands(to: .inactive)
        case .didBecomeActive:
            [.allowSystemAutoLock] + transitionCommands(to: .active)
        case .willTerminate:
            [.pauseWalkingForTermination]
        }
    }

    private func activeCommandsIfNeeded(for phase: ScenePhase) -> [AppLifecycleCommand] {
        phase == .active ? [.allowSystemAutoLock] : []
    }

    private mutating func transitionCommands(to phase: ScenePhase) -> [AppLifecycleCommand] {
        guard appliedPhase != phase else { return [] }
        appliedPhase = phase

        var commands: [AppLifecycleCommand] = [.updateWorkloadPhase(phase)]
        switch phase {
        case .active:
            commands.append(.walkForeground)
        case .inactive:
            commands.append(.walkInactive)
        case .background:
            commands.append(.walkBackground)
        @unknown default:
            commands.append(.walkInactive)
        }
        return commands
    }
}

@MainActor
final class AppLifecycleCoordinator: AppLifecycleHandling {
    struct Dependencies {
        var allowSystemAutoLock: () -> Void
        var updateWorkloadPhase: (ScenePhase) -> Void
        var refreshWorkload: (String) -> Void
        var handleWalkBackground: () -> Void
        var handleWalkInactive: () -> Void
        var handleWalkForeground: () -> Void
        var pauseWalkForTermination: () -> Void
        var scheduleReminderRefill: () -> Void
        var runAutomaticBackupIfDue: (String) -> Void

        static func live(
            walkingManager: PetWalkingManager,
            automaticBackups: AutomaticBackupManaging? = nil,
            modelContainer: ModelContainer? = nil
        ) -> Dependencies {
            Dependencies(
                allowSystemAutoLock: {
                    UIApplication.shared.isIdleTimerDisabled = false
                },
                updateWorkloadPhase: { phase in
                    AppWorkloadPolicy.shared.updateScenePhase(phase)
                },
                refreshWorkload: { reason in
                    AppWorkloadPolicy.shared.refresh(reason: reason)
                },
                handleWalkBackground: {
                    walkingManager.handleAppBackgroundTransition()
                },
                handleWalkInactive: {
                    walkingManager.handleAppInactiveTransition()
                },
                handleWalkForeground: {
                    walkingManager.handleAppForegroundTransition()
                },
                pauseWalkForTermination: {
                    walkingManager.pauseForAppBackground()
                },
                scheduleReminderRefill: {
                    BackgroundTaskCoordinator.scheduleReminderRefill()
                },
                runAutomaticBackupIfDue: { reason in
                    guard let automaticBackups, let modelContainer else { return }
                    Task { @MainActor in
                        await automaticBackups.runIfDue(
                            container: modelContainer,
                            trigger: .lifecycle(reason)
                        )
                    }
                }
            )
        }
    }

    private var reducer = AppLifecycleReducer()
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func handle(_ event: AppLifecycleEvent) {
        let commands = reducer.reduce(event)
        execute(commands)
    }

    private func execute(_ commands: [AppLifecycleCommand]) {
        for command in commands {
            switch command {
            case .allowSystemAutoLock:
                dependencies.allowSystemAutoLock()
            case let .updateWorkloadPhase(phase):
                dependencies.updateWorkloadPhase(phase)
            case let .refreshWorkload(reason):
                dependencies.refreshWorkload(reason)
            case .walkBackground:
                dependencies.handleWalkBackground()
            case .walkInactive:
                dependencies.handleWalkInactive()
            case .walkForeground:
                dependencies.handleWalkForeground()
            case .pauseWalkingForTermination:
                dependencies.pauseWalkForTermination()
            case .scheduleReminderRefill:
                dependencies.scheduleReminderRefill()
            case let .runAutomaticBackupIfDue(reason):
                dependencies.runAutomaticBackupIfDue(reason)
            }
        }
    }
}
