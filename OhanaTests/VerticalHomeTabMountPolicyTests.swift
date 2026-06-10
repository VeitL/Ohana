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

    @Test func oasisTabUsesFrozenTreeDuringIncomingTransition() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .oasis,
            active: .oasis,
            outgoing: .home,
            selected: .oasis,
            preparing: .oasis
        )

        #expect(OasisHomeTabContentPolicy.shouldRenderFrozenTree(for: lifecycle))
        #expect(!OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle))
        #expect(!OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle))
    }

    @Test func oasisTabStartsActiveWorkOnlyAfterTransitionSettles() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .oasis,
            active: .oasis,
            outgoing: nil,
            selected: .oasis
        )

        #expect(OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle))
        #expect(OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle))
    }

    @Test func oasisTreeRenderSnapshotClampsUnsafeValues() {
        let low = OasisTreeRenderSnapshot(level: -4, progressToNextLevel: -0.2)
        let high = OasisTreeRenderSnapshot(level: 40, progressToNextLevel: 1.7)
        let invalid = OasisTreeRenderSnapshot(
            level: 4,
            progressToNextLevel: .nan,
            totalEnergy: -20,
            nextLevelThreshold: -100
        )

        #expect(low.level == 1)
        #expect(low.progressToNextLevel == 0)
        #expect(high.level == 10)
        #expect(high.progressToNextLevel == 1)
        #expect(invalid.level == 4)
        #expect(invalid.progressToNextLevel == 0)
        #expect(invalid.totalEnergy == 0)
        #expect(invalid.nextLevelThreshold == 0)
    }

    @Test func oasisEmbeddedLayoutFitsAvailableHeightWithoutVerticalScroll() {
        for height: CGFloat in [560, 620, 720] {
            let metrics = OasisEmbeddedLayoutPolicy.metrics(availableHeight: height)

            #expect(metrics.totalHeight <= height + 0.5)
            #expect(metrics.bentoGridHeight >= 100)
            #expect(metrics.treeCardHeight > metrics.bentoGridHeight)
            #expect(
                metrics.treeVisualHeight + OasisEmbeddedLayoutPolicy.compactTreeStageChromeHeight
                    <= metrics.treeCardHeight + 0.5
            )
        }
    }

    @Test func tabOutgoingCleanupWaitsForFullMotionSpringTail() {
        #expect(
            VerticalHomeTabTransitionPolicy.outgoingCleanupDelayMilliseconds(for: .full)
                >= UInt64(700)
        )
        #expect(
            VerticalHomeTabTransitionPolicy.outgoingCleanupDelayMilliseconds(for: .static)
                == VerticalHomeTabTransitionPolicy.reducedMotionOutgoingCleanupDelayMilliseconds
        )
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

    @Test func bottomNavigationKeepsSelectedLabelThroughFourTabs() {
        let metrics = HomeBottomNavigationLayoutPolicy.metrics(tabCount: 4)

        #expect(metrics.showsSelectedLabel)
        #expect(metrics.actionHitSize >= 52)
        #expect(metrics.barHeight >= metrics.actionHitSize)
    }

    @Test func bottomNavigationSwitchesFiveTabsToIconOnlyDensity() {
        let metrics = HomeBottomNavigationLayoutPolicy.metrics(tabCount: 5)

        #expect(!metrics.showsSelectedLabel)
        #expect(metrics.actionHitSize >= 52)
        #expect(metrics.tabSpacing <= 4)
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

    @Test func bottomNavigationOasisUsesLevelText() {
        #expect(HomeBottomNavigationTreePresentation.levelText(8) == "Lv.8")
        #expect(HomeBottomNavigationTreePresentation.levelText(-1) == "Lv.0")
    }

    @Test func bottomNavigationTreeProgressIsClamped() {
        #expect(HomeBottomNavigationTreePresentation.progressFill(-0.4) == CGFloat(0))
        #expect(HomeBottomNavigationTreePresentation.progressFill(0.42) == CGFloat(0.42))
        #expect(HomeBottomNavigationTreePresentation.progressFill(1.4) == CGFloat(1))
        #expect(HomeBottomNavigationTreePresentation.progressFill(.nan) == CGFloat(0))
        #expect(HomeBottomNavigationTreePresentation.progressFill(.infinity) == CGFloat(0))
    }

    @Test @MainActor func treeInjectionPackageStaysAvailableAfterUseWhenCoconutsRemain() {
        let defaults = UserDefaults.standard
        let oldPeriod = defaults.string(forKey: OasisTreePreferenceStore.dailyInjectionDayKey)
        defer {
            if let oldPeriod {
                defaults.set(oldPeriod, forKey: OasisTreePreferenceStore.dailyInjectionDayKey)
            } else {
                defaults.removeObject(forKey: OasisTreePreferenceStore.dailyInjectionDayKey)
            }
        }

        let date = Date(timeIntervalSince1970: 1_765_065_600)
        defaults.removeObject(forKey: OasisTreePreferenceStore.dailyInjectionDayKey)
        #expect(TestOasisTreeManagerProjection.manager.canUseInjectionPackage(cost: 80, date: date))

        OasisTreePreferenceStore.markInjectionUsed(
            limitKey: OasisTreePreferenceStore.dailyInjectionDayKey,
            periodKey: EconomyDailyBudgetStore.dayKey(for: date)
        )
        #expect(TestOasisTreeManagerProjection.manager.canUseInjectionPackage(cost: 80, date: date))
    }
}
