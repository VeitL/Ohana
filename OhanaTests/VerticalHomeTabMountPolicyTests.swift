import CoreGraphics
import Foundation
import SwiftUI
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

    @Test func embeddedCalendarRendersMainContentDuringIncomingTransition() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .calendar,
            active: .calendar,
            outgoing: .home,
            selected: .calendar
        )

        #expect(CalendarEmbeddedContentMountPolicy.shouldRenderMainContent(
            hideToolbar: true,
            isEmbeddedPrepared: lifecycle.isPrepared,
            isEmbeddedVisible: lifecycle.isVisible,
            isEmbeddedActive: lifecycle.isLive,
            isContentMounted: false
        ))
        #expect(CalendarEmbeddedContentMountPolicy.shouldRenderMainContent(
            hideToolbar: true,
            isEmbeddedPrepared: lifecycle.isPrepared,
            isEmbeddedVisible: lifecycle.isVisible,
            isEmbeddedActive: lifecycle.isLive,
            isContentMounted: true
        ))
        #expect(
            CalendarEmbeddedContentMountPolicy.routeDataLoadDelayMilliseconds(
                hideToolbar: true,
                isEmbeddedVisible: lifecycle.isVisible,
                isEmbeddedActive: lifecycle.isLive
            ) == CalendarEmbeddedContentMountPolicy.visibleEmbeddedDataLoadDelayMilliseconds
        )
    }

    @Test func standaloneCalendarRendersMainContentImmediately() {
        #expect(CalendarEmbeddedContentMountPolicy.shouldRenderMainContent(
            hideToolbar: false,
            isEmbeddedPrepared: false,
            isEmbeddedVisible: false,
            isEmbeddedActive: false,
            isContentMounted: false
        ))
        #expect(
            CalendarEmbeddedContentMountPolicy.routeDataLoadDelayMilliseconds(
                hideToolbar: false,
                isEmbeddedVisible: false,
                isEmbeddedActive: false
            ) == CalendarEmbeddedContentMountPolicy.activeEmbeddedDataLoadDelayMilliseconds
        )
    }

    @Test func preparedHiddenCalendarPrewarmsOffscreenBeforeSelection() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .calendar,
            active: .home,
            outgoing: nil,
            selected: .home,
            prepared: Set([.calendar])
        )

        #expect(lifecycle.isPrepared)
        #expect(!lifecycle.isVisible)
        #expect(CalendarEmbeddedContentMountPolicy.shouldScheduleDeferredMount(
            hideToolbar: true,
            isEmbeddedPrepared: lifecycle.isPrepared,
            isEmbeddedVisible: lifecycle.isVisible,
            isEmbeddedActive: lifecycle.isLive,
            isContentMounted: false
        ))
        #expect(!CalendarEmbeddedContentMountPolicy.shouldRenderMainContent(
            hideToolbar: true,
            isEmbeddedPrepared: lifecycle.isPrepared,
            isEmbeddedVisible: lifecycle.isVisible,
            isEmbeddedActive: lifecycle.isLive,
            isContentMounted: false
        ))
        #expect(CalendarEmbeddedContentMountPolicy.shouldRenderMainContent(
            hideToolbar: true,
            isEmbeddedPrepared: lifecycle.isPrepared,
            isEmbeddedVisible: lifecycle.isVisible,
            isEmbeddedActive: lifecycle.isLive,
            isContentMounted: true
        ))
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

    @Test func oasisTabStaysFrozenAfterTransitionSettles() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .oasis,
            active: .oasis,
            outgoing: nil,
            selected: .oasis
        )

        #expect(OasisHomeTabContentPolicy.shouldRenderFrozenTree(for: lifecycle))
        #expect(!OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle))
        #expect(!OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle))
    }

    @Test func frozenOasisShopEntryUsesGlobalShopRouteWithoutMountingLiveTree() throws {
        let frozenStage = try source("Ohana/Features/Home/Views/VerticalSolidHomeComponents.swift")
        let host = try source("Ohana/Features/Oasis/Views/OasisHomeTabHost.swift")
        let home = try source("Ohana/Features/Home/Views/VerticalSolidHomeView.swift")

        #expect(frozenStage.contains("interactiveFeatures: [.shop]"))
        #expect(frozenStage.contains("onOpenShop(snapshot.shopInitialCategory)"))
        #expect(host.contains("VerticalSolidHomeOasisFrozenTreeStage("))
        #expect(host.contains("onOpenShop: onOpenShop"))
        #expect(home.contains("routeCoordinator.openCoconutShop(category, currentLevel: treeLevel)"))
        #expect(!OasisHomeTabContentPolicy.shouldRenderTreeContent(
            for: VerticalHomeTabMountPolicy.lifecycle(
                for: .oasis,
                active: .oasis,
                outgoing: nil,
                selected: .oasis
            )
        ))
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

        #expect(low.level == 0)
        #expect(low.progressToNextLevel == 0)
        #expect(high.level == 10)
        #expect(high.progressToNextLevel == 1)
        #expect(invalid.level == 4)
        #expect(invalid.progressToNextLevel == 0)
        #expect(invalid.totalEnergy == 0)
        #expect(invalid.nextLevelThreshold == 0)
        #expect(invalid.shopInitialCategory == .effect)

        let shopDecor = OasisTreeRenderSnapshot(
            level: 6,
            progressToNextLevel: 0.2,
            shopInitialCategory: .plantDecor
        )
        #expect(shopDecor.shopInitialCategory == .plantDecor)
    }

    @Test func beautifulCoconutTreeSupportsLevelZeroVisualState() {
        #expect(BeautifulCoconutTree.coconutCapacity(for: -4) == 0)
        #expect(BeautifulCoconutTree.coconutCapacity(for: 0) == 0)
        #expect(BeautifulCoconutTree.coconutCapacity(for: 1) == 0)
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

    @Test func embeddedQuickActionsThawDuringHeroExpansion() {
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.35,
            heroDirection: 1,
            reduceMotion: false
        ))

        #expect(FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.45,
            heroDirection: 1,
            reduceMotion: false
        ))

        let midReveal = FocusHomeEmbeddedQuickActionThawPolicy.reveal(
            progress: 0.55,
            heroDirection: 1,
            reduceMotion: false
        )
        #expect(midReveal > 0)
        #expect(midReveal < 1)

        #expect(FocusHomeEmbeddedQuickActionThawPolicy.reveal(
            progress: 0.74,
            heroDirection: 1,
            reduceMotion: false
        ) == 1)
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

    @Test func embeddedQuickActionsCanRenderBeforeExpandedInteractionSettles() {
        #expect(FocusHomeEmbeddedQuickActionPresentationPolicy.isVisible(
            embedsQuickActionsInCard: true,
            isExpandedSurface: true,
            hasWalkTrackingCard: false,
            isMounted: true
        ))

        #expect(!FocusHomeEmbeddedQuickActionPresentationPolicy.isVisible(
            embedsQuickActionsInCard: true,
            isExpandedSurface: true,
            hasWalkTrackingCard: true,
            isMounted: true
        ))
    }

    @Test func embeddedQuickActionsBecomeInteractiveOnlyAfterHeroSettles() {
        #expect(!FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionReady: false,
            reveal: 1
        ))

        #expect(!FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionReady: true,
            reveal: 0.8
        ))

        #expect(FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionReady: true,
            reveal: 1
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

    @Test func expandedCardCollapseHitLayerMountsBeforeQuickActionsAreReady() {
        #expect(FocusHomeEmbeddedCardCollapseHitPolicy.isMounted(
            isExpandedSurface: true,
            hasWalkTrackingCard: false
        ))
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: 0.2,
            heroDirection: 1,
            reduceMotion: false
        ))
        #expect(!FocusHomeEmbeddedCardCollapseHitPolicy.protectsQuickActionDock(
            quickActionsAreVisible: false
        ))
        #expect(FocusHomeEmbeddedCardCollapseHitPolicy.hitHeight(
            frameHeight: 500,
            quickActionDockHeight: 160,
            protectsQuickActionDock: false
        ) == 500)
    }

    @Test func expandedCardCollapseHitLayerProtectsQuickActionsOnlyAfterTheyAreVisible() {
        #expect(!FocusHomeEmbeddedCardCollapseHitPolicy.protectsQuickActionDock(
            quickActionsAreVisible: false
        ))
        #expect(FocusHomeEmbeddedCardCollapseHitPolicy.protectsQuickActionDock(
            quickActionsAreVisible: true
        ))
        #expect(FocusHomeEmbeddedCardCollapseHitPolicy.hitHeight(
            frameHeight: 500,
            quickActionDockHeight: 160,
            protectsQuickActionDock: true
        ) == 298)
    }

    @Test func expandedCardCollapseHitLayerStaysOffForWalkTrackingCard() {
        #expect(!FocusHomeEmbeddedCardCollapseHitPolicy.isMounted(
            isExpandedSurface: true,
            hasWalkTrackingCard: true
        ))
    }

    @Test func walkCardIdentityStaysStableWhenPausingActiveWalk() {
        #expect(FocusHomeWalkCardIdentityPolicy.phaseKey(.running) == FocusHomeWalkCardIdentityPolicy.phaseKey(.paused))
        #expect(FocusHomeWalkCardIdentityPolicy.phaseKey(.paused) != FocusHomeWalkCardIdentityPolicy.phaseKey(.finished(elapsed: 12, poopCount: 1)))
        #expect(FocusHomeWalkCardIdentityPolicy.phaseKey(.idle) != FocusHomeWalkCardIdentityPolicy.phaseKey(.running))
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

    @Test func bottomNavigationUsesIconOnlyDensityForFourTabs() {
        let metrics = HomeBottomNavigationLayoutPolicy.metrics(tabCount: 4)

        #expect(!metrics.showsSelectedLabel)
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

    @Test func bottomNavigationPlantsPrimaryActionUsesAddIcon() {
        #expect(HomeBottomNavigationPrimaryActionPresentation.icon(
            selectedTab: .plants,
            isFabExpanded: false,
            usesFabMenu: false
        ) == "plus")
        #expect(HomeBottomNavigationPrimaryActionPresentation.icon(
            selectedTab: .plants,
            isFabExpanded: true,
            usesFabMenu: false
        ) == "xmark")
    }

    @Test func plantsTabContentExtendsBehindFloatingBottomChrome() {
        let containerHeight: CGFloat = 844
        let topChromeHeight: CGFloat = 46
        let bottomChromeHeight: CGFloat = 104

        #expect(VerticalSolidHomePageContentHeightPolicy.height(
            selectedTab: .home,
            containerHeight: containerHeight,
            topChromeHeight: topChromeHeight,
            bottomChromeHeight: bottomChromeHeight
        ) == 694)
        #expect(VerticalSolidHomePageContentHeightPolicy.height(
            selectedTab: .plants,
            containerHeight: containerHeight,
            topChromeHeight: topChromeHeight,
            bottomChromeHeight: bottomChromeHeight
        ) == 798)
        #expect(VerticalSolidHomePageContentHeightPolicy.height(
            selectedTab: .calendar,
            containerHeight: containerHeight,
            topChromeHeight: topChromeHeight,
            bottomChromeHeight: bottomChromeHeight
        ) == 798)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.bottomContentInset <= 32)
        #expect(
            VerticalSolidHomePlantWalletScrollPolicy.roomRailVisibleBottomInset
            < bottomChromeHeight
        )
        #expect(FocusHomeVerticalSolidCollapsedLayoutPolicy.defaultVerticalBias == 0)
        #expect(
            FocusHomeVerticalSolidCollapsedLayoutPolicy.clampedVerticalBias(
                FocusHomeVerticalSolidCollapsedLayoutPolicy.bottomExtendedVerticalBias
            ) > 0
        )
    }

    @Test func calendarTabUsesPlantLikeBottomChromeHandoff() throws {
        let homeSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView.swift")
        let routingSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+Routing.swift")
        let routeSource = try source("Ohana/Features/Calendar/CalendarRouteContainer.swift")
        let calendarSource = try source("Ohana/Features/Calendar/Views/CalendarView.swift")
        let calendarListSource = try source("Ohana/Features/Calendar/Views/CalendarView+List.swift")
        let calendarMonthSource = try source("Ohana/Features/Calendar/Views/CalendarView+Month.swift")

        #expect(homeSource.contains("@State var calendarBottomChromeHidden = false"))
        #expect(homeSource.contains("onEmbeddedScrollOffsetChange: updateCalendarBottomChromeVisibility"))
        #expect(routingSource.contains("VerticalSolidHomeBottomChromeScrollPolicy.hidesBottomChrome"))
        #expect(routeSource.contains("var onEmbeddedScrollOffsetChange: ((CGFloat) -> Void)?"))
        #expect(calendarSource.contains("@State var embeddedBottomChromeBaselineOffset: CGFloat?"))
        #expect(calendarListSource.contains("reportEmbeddedBottomChromeScrollOffset(offsetY, canEstablishBaseline: didScrollListToToday)"))
        #expect(calendarMonthSource.contains("reportEmbeddedBottomChromeScrollOffset(offsetY)"))
    }

    @Test func plantWalletQuickActionsStaySimpleAndComplete() {
        #expect(VerticalSolidHomePlantQuickAction.allCases.map(\.id) == [
            "water",
            "fertilize",
            "log",
            "detail"
        ])
    }

    @Test func plantWalletKeepsFirstSixPlantsInOneScene() {
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 0) == 0)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 1) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 2) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 3) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 4) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 5) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 6) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 7) == 2)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 12) == 2)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 13) == 3)
    }

    @Test func plantDashboardWalletKeepsFirstSixPlantsInOneScene() {
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 0) == 0)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 1) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 6) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 7) == 2)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 12) == 2)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 13) == 3)
        #expect(PlantDashboardWalletSectionPolicy.sectionHeight(cardCount: 1) == 420)
        #expect(PlantDashboardWalletSectionPolicy.sectionHeight(cardCount: 6) == 620)
    }

    @Test func plantDashboardWalletUsesHomePlantCollapsedBias() throws {
        let source = try source("Ohana/Features/Plants/Views/PlantDashboardView+WalletDeck.swift")

        #expect(source.contains("collapsedVerticalBias: FocusHomeVerticalSolidCollapsedLayoutPolicy.bottomExtendedVerticalBias"))
    }

    @Test func plantWalletSectionHeightStaysStableDuringCardHeroMotion() {
        let collapsedHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 6,
            isExpanded: false,
            availableHeight: 520
        )
        let expandedHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 2,
            isExpanded: true,
            availableHeight: 520
        )
        let collapsedSceneHeight = VerticalSolidHomePlantWalletScrollPolicy.sceneHeight(
            cardCount: 6,
            isExpanded: false,
            availableHeight: 520
        )
        let expandedSceneHeight = VerticalSolidHomePlantWalletScrollPolicy.sceneHeight(
            cardCount: 2,
            isExpanded: true,
            availableHeight: 520
        )

        #expect(collapsedHeight == 520)
        #expect(expandedHeight == collapsedHeight)
        #expect(collapsedSceneHeight == 520)
        #expect(expandedSceneHeight == collapsedSceneHeight)

        let compactCollapsedHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 6,
            isExpanded: false,
            availableHeight: 280
        )
        let compactExpandedHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 6,
            isExpanded: true,
            availableHeight: 280
        )
        let compactCollapsedSceneHeight = VerticalSolidHomePlantWalletScrollPolicy.sceneHeight(
            cardCount: 6,
            isExpanded: false,
            availableHeight: 280
        )
        #expect(compactCollapsedHeight == VerticalSolidHomePlantWalletScrollPolicy.minimumSceneHeight)
        #expect(compactExpandedHeight == compactCollapsedHeight)
        #expect(compactCollapsedSceneHeight == VerticalSolidHomePlantWalletScrollPolicy.minimumSceneHeight)

        #expect(VerticalSolidHomePlantWalletScrollPolicy.cardViewportHeight(
            containerHeight: 798,
            bottomChromeHeight: 104
        ) == 694)
    }

    @Test func plantWalletInactiveCardGeometryCanBeFrozenDuringHeroMotion() {
        let stableFrame = CGRect(x: 0, y: 20, width: 120, height: 190)
        let preparedFrame = CGRect(x: 2, y: 24, width: 120, height: 190)
        let frozenFrame = CGRect(x: 7, y: 31, width: 120, height: 190)
        let selectedCardId = UUID()
        let inactiveCardId = UUID()

        #expect(FocusHomeInactiveHeroGeometryPolicy.collapsedFrame(
            stableFrame: stableFrame,
            preparedFrame: preparedFrame,
            frozenFrame: frozenFrame,
            freezesInactiveGeometry: true,
            selectedCardId: selectedCardId,
            cardId: inactiveCardId
        ) == frozenFrame)

        #expect(FocusHomeInactiveHeroGeometryPolicy.collapsedFrame(
            stableFrame: stableFrame,
            preparedFrame: preparedFrame,
            frozenFrame: frozenFrame,
            freezesInactiveGeometry: false,
            selectedCardId: selectedCardId,
            cardId: inactiveCardId
        ) == preparedFrame)

        #expect(FocusHomeInactiveHeroGeometryPolicy.collapsedFrame(
            stableFrame: stableFrame,
            preparedFrame: preparedFrame,
            frozenFrame: frozenFrame,
            freezesInactiveGeometry: true,
            selectedCardId: nil,
            cardId: inactiveCardId
        ) == stableFrame)
    }

    @Test func plantWalletExternalInactiveGeometryWinsDuringHeroMotion() {
        let selectedCardId = UUID()
        let inactiveCardId = UUID()
        let staleSelectionId = UUID()
        let localGeometry = FocusHomeInactiveHeroCollapsedGeometry(
            frame: CGRect(x: 0, y: 20, width: 120, height: 190),
            rotation: -8
        )
        let externalGeometry = FocusHomeInactiveHeroCollapsedGeometry(
            frame: CGRect(x: 12, y: 36, width: 120, height: 190),
            rotation: 5
        )

        #expect(FocusHomeInactiveHeroGeometrySourcePolicy.geometry(
            cardId: inactiveCardId,
            selectedCardId: selectedCardId,
            local: [inactiveCardId: localGeometry],
            localSelectionId: selectedCardId,
            external: [inactiveCardId: externalGeometry],
            externalSelectionId: selectedCardId,
            freezesInactiveGeometry: true
        ) == externalGeometry)

        #expect(FocusHomeInactiveHeroGeometrySourcePolicy.geometry(
            cardId: inactiveCardId,
            selectedCardId: selectedCardId,
            local: [inactiveCardId: localGeometry],
            localSelectionId: selectedCardId,
            external: [inactiveCardId: externalGeometry],
            externalSelectionId: staleSelectionId,
            freezesInactiveGeometry: true
        ) == localGeometry)

        #expect(FocusHomeInactiveHeroGeometrySourcePolicy.geometry(
            cardId: inactiveCardId,
            selectedCardId: selectedCardId,
            local: [inactiveCardId: localGeometry],
            localSelectionId: selectedCardId,
            external: [inactiveCardId: externalGeometry],
            externalSelectionId: selectedCardId,
            freezesInactiveGeometry: false
        ) == nil)
    }

    @Test func plantWalletInactiveCardsDoNotScaleWhileGeometryIsFrozen() {
        let selectedCardId = UUID()
        let inactiveCardId = UUID()

        #expect(FocusHomeInactiveHeroVisualPolicy.scale(
            selectedCardId: selectedCardId,
            cardId: inactiveCardId,
            progress: 0.5,
            reduceMotion: false,
            freezesInactiveGeometry: true
        ) == 1)

        let legacyScale = FocusHomeInactiveHeroVisualPolicy.scale(
            selectedCardId: selectedCardId,
            cardId: inactiveCardId,
            progress: 0.5,
            reduceMotion: false,
            freezesInactiveGeometry: false
        )
        #expect(legacyScale < 1)
        #expect(legacyScale > 0.9)

        #expect(FocusHomeInactiveHeroVisualPolicy.scale(
            selectedCardId: selectedCardId,
            cardId: selectedCardId,
            progress: 0.5,
            reduceMotion: false,
            freezesInactiveGeometry: true
        ) == 1)
    }

    @Test func plantWalletInactiveCardLayerDisablesImplicitAnimationWhileGeometryIsFrozen() {
        let selectedCardId = UUID()
        let inactiveCardId = UUID()

        #expect(FocusHomeInactiveHeroLayerPolicy.disablesImplicitAnimations(
            selectedCardId: selectedCardId,
            cardId: inactiveCardId,
            freezesInactiveGeometry: true
        ))

        #expect(!FocusHomeInactiveHeroLayerPolicy.disablesImplicitAnimations(
            selectedCardId: selectedCardId,
            cardId: selectedCardId,
            freezesInactiveGeometry: true
        ))

        #expect(!FocusHomeInactiveHeroLayerPolicy.disablesImplicitAnimations(
            selectedCardId: selectedCardId,
            cardId: inactiveCardId,
            freezesInactiveGeometry: false
        ))

        #expect(!FocusHomeInactiveHeroLayerPolicy.disablesImplicitAnimations(
            selectedCardId: nil,
            cardId: inactiveCardId,
            freezesInactiveGeometry: true
        ))
    }

    @Test func plantWalletSelectedCardMovesToFrontOnOpeningHeroFrame() throws {
        let source = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidScene.swift")

        #expect(source.contains("if embedsQuickActionsInCard, heroDirection > 0"))
        #expect(source.contains("return expandedCardZIndex()"))
        #expect(source.contains("if heroDirection < 0, progress < 0.035"))
        #expect(source.contains("return collapsedZIndex(index: index, count: cards.count)"))
    }

    @Test func plantWalletInactiveCardRotationCanBeFrozenDuringHeroMotion() {
        let selectedCardId = UUID()
        let inactiveCardId = UUID()
        let selectedRotation = FocusHomeInactiveHeroRotationPolicy.rotation(
            stableRotation: -8,
            frozenRotation: 4,
            freezesInactiveGeometry: true,
            selectedCardId: selectedCardId,
            cardId: selectedCardId
        )
        let frozenInactiveRotation = FocusHomeInactiveHeroRotationPolicy.rotation(
            stableRotation: -8,
            frozenRotation: 4,
            freezesInactiveGeometry: true,
            selectedCardId: selectedCardId,
            cardId: inactiveCardId
        )
        let liveInactiveRotation = FocusHomeInactiveHeroRotationPolicy.rotation(
            stableRotation: -8,
            frozenRotation: 4,
            freezesInactiveGeometry: false,
            selectedCardId: selectedCardId,
            cardId: inactiveCardId
        )
        let collapsedRotation = FocusHomeInactiveHeroRotationPolicy.rotation(
            stableRotation: -8,
            frozenRotation: 4,
            freezesInactiveGeometry: true,
            selectedCardId: nil,
            cardId: inactiveCardId
        )

        #expect(selectedRotation == -8)
        #expect(frozenInactiveRotation == 4)
        #expect(liveInactiveRotation == -8)
        #expect(collapsedRotation == -8)
    }

    @Test func plantWalletHeroSnapshotCarriesInactiveGeometryForFirstExpandedFrame() {
        let selectedCardId = UUID()
        let inactiveCardId = UUID()
        let inactiveGeometry = FocusHomeInactiveHeroCollapsedGeometry(
            frame: CGRect(x: 12, y: 36, width: 120, height: 190),
            rotation: 5
        )
        let card = FocusCard(
            id: selectedCardId,
            name: "Monstera",
            kind: "Plant",
            emoji: "leaf",
            color: Color(hex: "4FB6A3"),
            streak: 0,
            coconutBalance: 0,
            themeColorHex: "4FB6A3",
            isPlant: true,
            actions: []
        )

        let snapshot = FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: 0,
            avatarSource: .placeholder
        )
        .freezingCollapsedGeometry(
            frame: CGRect(x: 20, y: 40, width: 130, height: 205),
            rotation: -8,
            inactiveCollapsedGeometry: [inactiveCardId: inactiveGeometry]
        )

        #expect(snapshot.inactiveCollapsedGeometry[inactiveCardId] == inactiveGeometry)
    }

    @Test func plantDashboardWalletLegacyToggleUsesHeroStateMachine() throws {
        let source = try source("Ohana/Features/Plants/Views/PlantDashboardView.swift")

        #expect(source.contains("expandPlantWalletCard(snapshot)"))
        #expect(source.contains("collapsePlantWalletCard()"))
        #expect(!source.contains("withAnimation(GoMotion.page) {\n            expandedPlantCardID"))
    }

    @Test func plantDashboardWalletUsesSceneLocalInactiveFreezeWithoutExternalState() throws {
        let viewSource = try source("Ohana/Features/Plants/Views/PlantDashboardView.swift")
        let deckSource = try source("Ohana/Features/Plants/Views/PlantDashboardView+WalletDeck.swift")

        #expect(!viewSource.contains("plantFrozenInactiveGeometry"))
        #expect(!viewSource.contains("plantFrozenInactiveGeometrySelectionID"))
        #expect(!deckSource.contains("clearPlantInactiveGeometry"))
        #expect(!deckSource.contains("freezePlantInactiveGeometry"))
        #expect(deckSource.contains("freezesInactiveCollapsedGeometryDuringHero: true"))
        #expect(!deckSource.contains("externalInactiveCollapsedGeometry:"))
        #expect(!deckSource.contains("onInactiveCollapsedGeometryFrozen:"))
        #expect(!deckSource.contains("plantFrozenInactiveGeometry = snapshot.inactiveCollapsedGeometry"))
    }

    @Test func plantScrollChromeHidesOnlyAfterLeavingTopAndRestoresAtTop() {
        #expect(!VerticalSolidHomeBottomChromeScrollPolicy.hidesBottomChrome(
            scrollOffset: 0,
            currentHidden: false
        ))
        #expect(VerticalSolidHomeBottomChromeScrollPolicy.hidesBottomChrome(
            scrollOffset: 30,
            currentHidden: false
        ))
        #expect(VerticalSolidHomeBottomChromeScrollPolicy.hidesBottomChrome(
            scrollOffset: 12,
            currentHidden: true
        ))
        #expect(!VerticalSolidHomeBottomChromeScrollPolicy.hidesBottomChrome(
            scrollOffset: 2,
            currentHidden: true
        ))
        #expect(!VerticalSolidHomePlantScrollChromePolicy.hidesBottomChrome(
            scrollOffset: 0,
            currentHidden: false
        ))
        #expect(VerticalSolidHomePlantScrollChromePolicy.hidesBottomChrome(
            scrollOffset: 30,
            currentHidden: false
        ))
        #expect(VerticalSolidHomePlantScrollChromePolicy.hidesBottomChrome(
            scrollOffset: 12,
            currentHidden: true
        ))
        #expect(!VerticalSolidHomePlantScrollChromePolicy.hidesBottomChrome(
            scrollOffset: 2,
            currentHidden: true
        ))
    }

    @Test func plantRoomRailShowsWhenPlantPageHasPlants() {
        #expect(!VerticalSolidHomePlantRoomRailPolicy.shouldShow(plantCount: 0, selectedCardId: nil, heroDirection: 0))
        #expect(VerticalSolidHomePlantRoomRailPolicy.shouldShow(plantCount: 1, selectedCardId: nil, heroDirection: 0))
        #expect(VerticalSolidHomePlantRoomRailPolicy.shouldShow(plantCount: 8, selectedCardId: nil, heroDirection: 0))
        #expect(!VerticalSolidHomePlantRoomRailPolicy.shouldShow(plantCount: 8, selectedCardId: UUID(), heroDirection: 0))
        #expect(!VerticalSolidHomePlantRoomRailPolicy.shouldShow(plantCount: 8, selectedCardId: nil, heroDirection: 1))
    }

    @Test func homeQuickActionsAndFabShortcutsExposeMinimumHitAreas() {
        let minimumHitSize = VerticalHomeEmbeddedQuickActionHitAreaPolicy.minimumHitSize

        #expect(minimumHitSize >= 44)
        #expect(VerticalHomeEmbeddedQuickActionHitAreaPolicy.cellHeight >= minimumHitSize)
        #expect(VerticalHomeEmbeddedQuickActionHitAreaPolicy.addOptionCellHeight >= minimumHitSize)
        #expect(VerticalHomeEmbeddedQuickActionHitAreaPolicy.inlineMenuButtonWidth(buttonCount: 1) >= minimumHitSize)
        #expect(VerticalHomeEmbeddedQuickActionHitAreaPolicy.inlineMenuButtonWidth(buttonCount: 6) >= minimumHitSize)
        #expect(HomeFabShortcutHitAreaPolicy.minimumHitSize >= 44)
    }

    @Test func plantsTabFabOwnsPlantModuleShortcuts() throws {
        let sharedSource = try source("Ohana/Features/Home/Views/HomeFabSharedControls.swift")
        let bottomBarSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeBottomBar.swift")
        let routingSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+TodayFocus.swift")
        let functionRootSource = try source("Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift")

        #expect(sharedSource.contains("plantShortcuts(l:"))
        #expect(sharedSource.contains("entityToAdd: .plant"))
        #expect(sharedSource.contains("destination: .featureGroup(.plants)"))
        #expect(bottomBarSource.contains("plantShortcuts: [HomeFabFunctionShortcut]"))
        #expect(bottomBarSource.contains("selectedTab == .plants"))
        #expect(bottomBarSource.contains("return \"add-\\(entityToAdd.rawValue)\""))
        #expect(bottomBarSource.contains("return \"feature-group-\\(group.rawValue)\""))
        #expect(routingSource.contains("if let entityToAdd = shortcut.entityToAdd"))
        #expect(functionRootSource.contains("from: [.dailyCare, .healthBody, .archiveMemory, .householdHub]"))
        #expect(!functionRootSource.contains(".householdHub, .plants"))
    }

    @Test func bottomNavigationOasisUsesLevelText() {
        #expect(HomeBottomNavigationTreePresentation.levelText(8) == "Lv.8")
        #expect(HomeBottomNavigationTreePresentation.levelText(-1) == "Lv.0")
    }

    @Test func oasisTabIsHiddenUntilStarterGiftUnlocksTree() {
        let suiteName = "VerticalHomeTabMountPolicyTests.oasisTabIsHiddenUntilStarterGiftUnlocksTree.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(false, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(false, forKey: StarterGiftStorageKey.oasisTabPromptPending)
        #expect(!AppFeatureRouteGuard.allowsHomeTab(.oasis, starterGiftDefaults: defaults))
        #expect(!AppFeatureRouteGuard.visibleHomeTabs(starterGiftDefaults: defaults).contains(.oasis))

        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(true, forKey: StarterGiftStorageKey.oasisTabPromptPending)
        #expect(AppFeatureRouteGuard.allowsHomeTab(.oasis, starterGiftDefaults: defaults))
        #expect(AppFeatureRouteGuard.visibleHomeTabs(starterGiftDefaults: defaults).contains(.oasis))
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
        #expect(TestOasisTreeManagerProjection.manager.canUseInjectionPackage(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            date: date
        ))

        OasisTreePreferenceStore.markInjectionUsed(
            limitKey: OasisTreePreferenceStore.dailyInjectionDayKey,
            periodKey: EconomyDailyBudgetStore.dayKey(for: date)
        )
        #expect(TestOasisTreeManagerProjection.manager.canUseInjectionPackage(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            date: date
        ))
    }

    @Test func starterTreeInjectionNeedsFiveStarterPacksForLevelOne() {
        #expect(OasisTreeEnergyInjectionPolicy.starterPackageCost == 10)
        #expect(OasisTreeEnergyInjectionPolicy.starterPackageXP == 10)
        #expect(StarterGiftPolicy.giftAmount / OasisTreeEnergyInjectionPolicy.starterPackageCost == 5)
        #expect(OasisTreeManager.treeLevel(forTotalEnergy: 4 * OasisTreeEnergyInjectionPolicy.starterPackageXP) == .lv0)
        #expect(OasisTreeManager.treeLevel(forTotalEnergy: 5 * OasisTreeEnergyInjectionPolicy.starterPackageXP) == .lv1)
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }

    private func restore(_ defaults: UserDefaults, key: String, value: Any?) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
