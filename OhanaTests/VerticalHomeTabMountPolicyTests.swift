import CoreGraphics
import Foundation
import Testing
@testable import Ohana

struct VerticalHomeTabMountPolicyTests {
    @Test func mountedTabsKeepOnlyActiveTabWhenIdle() {
        let mounted = VerticalHomeTabMountPolicy.mountedTabs(active: .home, outgoing: nil)

        #expect(mounted == Set([.home]))
    }

    @Test func mountedTabsKeepOnlyActiveAndOutgoingDuringTransition() {
        let mounted = VerticalHomeTabMountPolicy.mountedTabs(active: .calendar, outgoing: .home)

        #expect(mounted == Set([.calendar, .home]))
        #expect(!mounted.contains(.oasis))
        #expect(!mounted.contains(.plants))
    }

    @Test func mountedTabsIncludePreparedTabsAfterWarmup() {
        let mounted = VerticalHomeTabMountPolicy.mountedTabs(
            active: .home,
            outgoing: nil,
            prepared: Set([.calendar, .oasis])
        )

        #expect(mounted == Set([.home, .calendar, .oasis]))
    }

    @Test func incomingTabIsPreparedButNotLiveDuringTransition() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .calendar,
            active: .calendar,
            outgoing: .home,
            selected: .calendar
        )

        #expect(lifecycle.isPrepared)
        #expect(!lifecycle.isPreparingForDisplay)
        #expect(lifecycle.isVisible)
        #expect(!lifecycle.isLive)
    }

    @Test func activeTabBecomesLiveAfterOutgoingTabIsRemoved() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .calendar,
            active: .calendar,
            outgoing: nil,
            selected: .calendar
        )

        #expect(lifecycle.isPrepared)
        #expect(!lifecycle.isPreparingForDisplay)
        #expect(lifecycle.isVisible)
        #expect(lifecycle.isLive)
    }

    @Test func preparedInactiveTabIsPreparedButNotLive() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .calendar,
            active: .home,
            outgoing: nil,
            selected: .home,
            prepared: Set([.calendar])
        )

        #expect(lifecycle.isPrepared)
        #expect(!lifecycle.isPreparingForDisplay)
        #expect(!lifecycle.isVisible)
        #expect(!lifecycle.isLive)
    }

    @Test func outgoingTabIsNeitherPreparedNorLive() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .home,
            active: .calendar,
            outgoing: .home,
            selected: .calendar
        )

        #expect(!lifecycle.isPrepared)
        #expect(!lifecycle.isPreparingForDisplay)
        #expect(lifecycle.isVisible)
        #expect(!lifecycle.isLive)
    }

    @Test func preparingTabIsPreparedBeforeItBecomesVisible() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .oasis,
            active: .home,
            outgoing: nil,
            selected: .oasis,
            preparing: .oasis
        )

        #expect(lifecycle.isPrepared)
        #expect(lifecycle.isPreparingForDisplay)
        #expect(!lifecycle.isVisible)
        #expect(!lifecycle.isLive)
    }

    @Test func selectedPreparingTabIsVisibleButNotLive() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .oasis,
            active: .oasis,
            outgoing: .home,
            selected: .oasis,
            preparing: .oasis
        )

        #expect(lifecycle.isPrepared)
        #expect(lifecycle.isPreparingForDisplay)
        #expect(lifecycle.isVisible)
        #expect(!lifecycle.isLive)
    }

    @Test func embeddedQuickActionsStayUnmountedUntilHeroSettles() {
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.9,
            heroDirection: 1,
            reduceMotion: false
        ))

        #expect(FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.99,
            heroDirection: 1,
            reduceMotion: false
        ))
    }

    @Test func embeddedQuickActionsUseShortReducedMotionThaw() {
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.49,
            heroDirection: 1,
            reduceMotion: true
        ))

        #expect(FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.5,
            heroDirection: 1,
            reduceMotion: true
        ))
    }

    @Test func embeddedQuickActionsRemainMountedDuringEarlyCollapseExit() {
        #expect(FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.9,
            heroDirection: -1,
            reduceMotion: false
        ))

        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.7,
            heroDirection: -1,
            reduceMotion: false
        ))
    }

    @Test func ambientFloatOnlyRunsForVisibleCollapsedHomeCards() {
        #expect(FocusHomeAmbientFloatPolicy.isSurfaceVisibleForAmbient(
            isVisible: true,
            selectedCardId: nil,
            progress: 0
        ))

        #expect(!FocusHomeAmbientFloatPolicy.isSurfaceVisibleForAmbient(
            isVisible: false,
            selectedCardId: nil,
            progress: 0
        ))

        #expect(!FocusHomeAmbientFloatPolicy.isSurfaceVisibleForAmbient(
            isVisible: true,
            selectedCardId: UUID(),
            progress: 0
        ))

        #expect(FocusHomeAmbientFloatPolicy.isSurfaceCovered(
            selectedCardId: nil,
            progress: 0.01
        ))
    }

    @Test func ambientFloatRequiresOptInAndRespectsReduceMotion() {
        #expect(FocusHomeAmbientFloatPolicy.allowsAmbientOptIn(
            isEnabled: true,
            reduceMotion: false
        ))

        #expect(!FocusHomeAmbientFloatPolicy.allowsAmbientOptIn(
            isEnabled: false,
            reduceMotion: false
        ))

        #expect(!FocusHomeAmbientFloatPolicy.allowsAmbientOptIn(
            isEnabled: true,
            reduceMotion: true
        ))
    }

    @Test func bottomNavigationKeepsLabelsThroughFourTabs() {
        let metrics = HomeBottomNavigationLayoutPolicy.metrics(tabCount: 4)

        #expect(metrics.showsTabLabels)
        #expect(metrics.actionHitSize >= 56)
        #expect(metrics.barHeight >= metrics.actionHitSize)
    }

    @Test func bottomNavigationSwitchesFiveTabsToIconOnlyDensity() {
        let metrics = HomeBottomNavigationLayoutPolicy.metrics(tabCount: 5)

        #expect(!metrics.showsTabLabels)
        #expect(metrics.actionHitSize >= 56)
        #expect(metrics.tabSpacing <= 2)
    }

    @Test func bottomNavigationReservesRoomForPrimaryAction() {
        let threeTabWidth = HomeBottomNavigationLayoutPolicy.estimatedTabSlotWidth(
            containerWidth: 390,
            tabCount: 3
        )
        let fiveTabWidth = HomeBottomNavigationLayoutPolicy.estimatedTabSlotWidth(
            containerWidth: 390,
            tabCount: 5
        )

        #expect(threeTabWidth > 70)
        #expect(fiveTabWidth >= 44)
    }
}
