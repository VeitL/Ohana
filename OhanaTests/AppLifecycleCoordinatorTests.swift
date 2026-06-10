import SwiftUI
import Testing
@testable import Ohana

@MainActor
struct AppLifecycleCoordinatorTests {
    @Test func rootAppearAppliesInitialActivePhaseOnce() {
        var reducer = AppLifecycleReducer()

        let commands = reducer.reduce(.rootAppeared(scenePhase: .active))
        let duplicateScenePhase = reducer.reduce(.scenePhaseChanged(.active))

        #expect(commands == [
            .allowSystemAutoLock,
            .updateWorkloadPhase(.active),
            .walkForeground,
            .refreshWorkload(reason: "contentAppear")
        ])
        #expect(duplicateScenePhase == [.allowSystemAutoLock])
    }

    @Test func foregroundNotificationAndScenePhaseDoNotDuplicateWalkForeground() {
        var reducer = AppLifecycleReducer()

        let notificationCommands = reducer.reduce(.didBecomeActive)
        let scenePhaseCommands = reducer.reduce(.scenePhaseChanged(.active))

        #expect(notificationCommands == [
            .allowSystemAutoLock,
            .updateWorkloadPhase(.active),
            .walkForeground
        ])
        #expect(scenePhaseCommands == [.allowSystemAutoLock])
    }

    @Test func backgroundSchedulingIsSeparatedFromDuplicateScenePhaseWork() {
        var reducer = AppLifecycleReducer()

        let scenePhaseCommands = reducer.reduce(.scenePhaseChanged(.background))
        let notificationCommands = reducer.reduce(.didEnterBackground)

        #expect(scenePhaseCommands == [
            .updateWorkloadPhase(.background),
            .walkBackground
        ])
        #expect(notificationCommands == [.scheduleReminderRefill])
    }

    @Test func backgroundNotificationHandlesWorkWhenScenePhaseHasNotArrived() {
        var reducer = AppLifecycleReducer()

        let notificationCommands = reducer.reduce(.didEnterBackground)
        let duplicateScenePhase = reducer.reduce(.scenePhaseChanged(.background))

        #expect(notificationCommands == [
            .updateWorkloadPhase(.background),
            .walkBackground,
            .scheduleReminderRefill
        ])
        #expect(duplicateScenePhase.isEmpty)
    }

    @Test func terminationOnlyPausesWalkForUnavailableBackgroundDelivery() {
        var reducer = AppLifecycleReducer()

        let commands = reducer.reduce(.willTerminate)

        #expect(commands == [.pauseWalkingForTermination])
    }
}
