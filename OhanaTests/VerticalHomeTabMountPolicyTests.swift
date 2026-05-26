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
}
