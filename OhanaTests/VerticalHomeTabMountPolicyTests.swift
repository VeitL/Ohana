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

    @Test func mountedTabsKeepPreparedCalendarMountedForWarmupOnly() {
        let mounted = VerticalHomeTabMountPolicy.mountedTabs(
            active: .home,
            outgoing: nil,
            prepared: Set([.calendar, .oasis])
        )

        #expect(mounted == Set([.home, .calendar]))
        #expect(mounted.contains(.calendar))
        #expect(!mounted.contains(.oasis))
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

    @Test func preparedHiddenCalendarMountsOffscreenForWarmupWithoutBecomingLive() {
        let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
            for: .calendar,
            active: .home,
            outgoing: nil,
            selected: .home,
            prepared: Set([.calendar])
        )
        let mounted = VerticalHomeTabMountPolicy.mountedTabs(
            active: .home,
            outgoing: nil,
            prepared: Set([.calendar])
        )

        #expect(lifecycle.isPrepared)
        #expect(!lifecycle.isVisible)
        #expect(!lifecycle.isLive)
        #expect(mounted.contains(.calendar))
    }

    @Test func calendarContentHandoffStateIgnoresFilterChanges() {
        let listState = CalendarContentHandoffState(viewModeRaw: CalendarViewMode.list.rawValue)
        let sameListState = CalendarContentHandoffState(viewModeRaw: CalendarViewMode.list.rawValue)
        let monthState = CalendarContentHandoffState(viewModeRaw: CalendarViewMode.month.rawValue)

        #expect(listState == sameListState)
        #expect(listState != monthState)
    }

    @Test func calendarInitialPositioningAvoidsProxyScrollToDuringFingerWindow() throws {
        let listSource = try source("Ohana/Features/Calendar/Views/CalendarView+List.swift")

        #expect(listSource.contains("func scheduleInitialTimelineScrollIfNeeded(proxy _: ScrollViewProxy)"))
        #expect(listSource.contains("cancelInitialTimelinePositioningForUserInteraction()"))
        #expect(!listSource.contains("scrollTimeline(proxy, to: targetID"))
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

    @Test func embeddedQuickActionsMountWhenPreloadedForHeroTail() {
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            isExpandedInteractionMounted: false
        ))

        #expect(FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            isExpandedInteractionMounted: true
        ))

        #expect(FocusHomeEmbeddedQuickActionThawPolicy.reveal(isMounted: false, postHeroReveal: 1) == 0)
        #expect(FocusHomeEmbeddedQuickActionThawPolicy.reveal(isMounted: true, postHeroReveal: 0) == 0)
        #expect(FocusHomeEmbeddedQuickActionThawPolicy.reveal(isMounted: true, postHeroReveal: 1) == 1)
    }

    @Test func embeddedQuickActionsRevealAndInteractBeforeHeroSettles() throws {
        let supportSource = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidSupport.swift")
        let sceneSource = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidScene.swift")

        #expect(FocusHomePostHeroControlRevealPolicy.fullMotionPreloadDelayMilliseconds <= 240)
        #expect(
            FocusHomePostHeroControlRevealPolicy.fullMotionPreloadDelayMilliseconds
                + UInt64(FocusHomePostHeroControlRevealPolicy.animationDuration * 1000)
                <= 420
        )
        #expect(FocusHomeExpandedInteractionPolicy.expandedControlReadyProgress < 0.25)
        #expect(FocusHomeExpandedInteractionPolicy.visibleControlInteractionProgress < 0.25)
        #expect(supportSource.contains("ZStack(alignment: .top)"))
        #expect(supportSource.contains(".opacity(Double(reveal))"))
        #expect(!sceneSource.contains("heroDirection == 0 && progress > 0.985"))
        #expect(!sceneSource.contains("reveal > 0.98"))
    }

    @Test func embeddedQuickActionsAvoidProgressThresholdMounts() throws {
        let sceneSource = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidScene.swift")

        #expect(!sceneSource.contains("openingMountProgress"))
        #expect(!sceneSource.contains("progress > 0.58"))
        #expect(sceneSource.contains("isExpandedInteractionReady"))
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

    @Test func embeddedQuickActionsBecomeInteractiveWhenMountedAndVisible() {
        #expect(!FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionMounted: false,
            reveal: 1
        ))

        #expect(!FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionMounted: true,
            reveal: 0.1
        ))

        #expect(FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionMounted: true,
            reveal: FocusHomeExpandedInteractionPolicy.visibleControlInteractionProgress
        ))
    }

    @Test func expandedCardInteractionsDoNotWaitForHeroCompletion() {
        let selectedCardId = UUID()

        #expect(FocusHomeExpandedInteractionPolicy.isExpandedControlReady(
            selectedCardId: selectedCardId,
            heroDirection: 1,
            progress: FocusHomeExpandedInteractionPolicy.expandedControlReadyProgress
        ))
        #expect(FocusHomeExpandedInteractionPolicy.isExpandedCollapseReady(
            selectedCardId: selectedCardId,
            progress: FocusHomeExpandedInteractionPolicy.expandedControlReadyProgress
        ))
        #expect(FocusHomeExpandedInteractionPolicy.canHitCollapsedCards(
            selectedCardId: selectedCardId,
            heroDirection: 1,
            progress: 0.8
        ))
        #expect(FocusHomeExpandedInteractionPolicy.canHitCollapsedCards(
            selectedCardId: selectedCardId,
            heroDirection: -1,
            progress: 0.8
        ))
        #expect(!FocusHomeExpandedInteractionPolicy.isExpandedControlReady(
            selectedCardId: selectedCardId,
            heroDirection: -1,
            progress: 1
        ))
    }

    @Test func collapsedHitLayerRedirectsDuringHeroWithoutCoveringSelectedCard() {
        let selectedCardId = UUID()
        let inactiveCardId = UUID()

        #expect(FocusHomeCollapsedHitLayerPolicy.includes(cardId: inactiveCardId, selectedCardId: selectedCardId))
        #expect(!FocusHomeCollapsedHitLayerPolicy.includes(cardId: selectedCardId, selectedCardId: selectedCardId))
        #expect(FocusHomeCollapsedHitLayerPolicy.includes(cardId: selectedCardId, selectedCardId: nil))
        #expect(FocusHomeCollapsedHitLayerPolicy.zIndex(selectedCardId: selectedCardId) < 24)
        #expect(FocusHomeCollapsedHitLayerPolicy.zIndex(selectedCardId: nil) == 80)
    }

    @Test func embeddedQuickActionsUnmountWhenPreloadIsNotMounted() {
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            isExpandedInteractionMounted: false
        ))
    }

    @Test func expandedCardCollapseHitLayerMountsBeforeQuickActionsAreReady() {
        #expect(FocusHomeEmbeddedCardCollapseHitPolicy.isMounted(
            isExpandedSurface: true,
            hasWalkTrackingCard: false
        ))
        #expect(!FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            isExpandedInteractionMounted: false
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

        let cardID = UUID()
        let petID = UUID()
        let runningIdentity = FocusHomeWalkCardIdentityPolicy.identity(
            cardID: cardID,
            walkPetID: petID,
            phase: .running,
            presentationRevision: 4
        )
        #expect(runningIdentity == FocusHomeWalkCardIdentityPolicy.identity(
            cardID: cardID,
            walkPetID: petID,
            phase: .paused,
            presentationRevision: 4
        ))
        #expect(runningIdentity != FocusHomeWalkCardIdentityPolicy.identity(
            cardID: cardID,
            walkPetID: petID,
            phase: .finished(elapsed: 12, poopCount: 1),
            presentationRevision: 4
        ))
        #expect(runningIdentity != FocusHomeWalkCardIdentityPolicy.identity(
            cardID: cardID,
            walkPetID: petID,
            phase: .running,
            presentationRevision: 5
        ))
        #expect(FocusHomeWalkCardIdentityPolicy.identity(
            cardID: cardID,
            walkPetID: nil,
            phase: .running,
            presentationRevision: 5
        ) == cardID.uuidString)
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
        #expect(VerticalSolidHomePlantWalletScrollPolicy.topContentInset == 0)
        #expect(
            VerticalSolidHomePlantWalletScrollPolicy.roomRailVisibleBottomInset
            < bottomChromeHeight
        )
        #expect(
            VerticalSolidHomePlantWalletScrollPolicy.roomRailCenterY(
                containerHeight: 798,
                topChromeHeight: topChromeHeight
            ) == 376
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
        #expect(routingSource.contains("resetCalendarBottomChromeForTabSelection()"))
        #expect(routingSource.contains("guard controller.outgoingTab == nil else { return }"))
        #expect(routeSource.contains("var onEmbeddedScrollOffsetChange: ((CGFloat) -> Void)?"))
        #expect(calendarSource.contains("@State var embeddedBottomChromeBaselineOffset: CGFloat?"))
        #expect(calendarListSource.contains("reportEmbeddedBottomChromeScrollOffset(offsetY, canEstablishBaseline: didScrollListToToday)"))
        #expect(calendarMonthSource.contains("reportEmbeddedBottomChromeScrollOffset(offsetY)"))
    }

    @Test func plantWalletQuickActionsUseSharedEditablePolicy() throws {
        let plantPageSource = try source("Ohana/Features/Home/Views/VerticalSolidHomePlantsPage.swift")
        let dashboardSource = try source("Ohana/Features/Plants/Views/PlantDashboardView+WalletDeck.swift")
        let policySource = try source("Ohana/Features/Plants/PlantDockQuickActionPolicy.swift")

        #expect(PlantDockQuickAction.defaultItems.map(\.id) == [
            "water",
            "fertilize",
            "photo",
            "detail"
        ])
        #expect(PlantDockQuickAction.editableItems.count == 14)
        #expect(PlantDockQuickAction.editableSections.map(\.category) == [
            .hydration,
            .nutrition,
            .maintenance,
            .health,
            .growth
        ])
        #expect(PlantDockQuickAction.maxVisibleItems == 8)
        #expect(policySource.contains("var detailFeatureDestination: PlantCareFeatureDestination?"))
        #expect(plantPageSource.contains("action.detailFeatureDestination"))
        #expect(plantPageSource.contains("PlantDockQuickActionsView("))
        #expect(plantPageSource.contains("overdueCareTypes: plantOverdueCareTypes(for: plant)"))
        #expect(dashboardSource.contains("PlantDockQuickActionsView("))
        #expect(dashboardSource.contains("overdueCareTypes: plantOverdueCareTypes(tasks: careTasks)"))
        #expect(dashboardSource.contains("focusedCareType: careType"))
        #expect(dashboardSource.contains("plantStoredDockActions(for: plant)"))
        #expect(dashboardSource.contains("plantDockActionAttentionLevel"))
    }

    @Test func plantBatchCareSheetUsesRouteSnapshotInsteadOfBodyAggregation() throws {
        let dashboardSource = try source("Ohana/Features/Plants/Views/PlantDashboardView.swift")
        let sheetSource = try source("Ohana/Features/Plants/Views/PlantBatchCareSheet.swift")
        let snapshotSource = try source("Ohana/Features/Plants/PlantBatchCareRouteSnapshot.swift")

        #expect(snapshotSource.contains("@ModelActor"))
        #expect(snapshotSource.contains("actor PlantBatchCareRouteSnapshotActor"))
        #expect(snapshotSource.contains("PlantBatchCareSheetSnapshot"))
        #expect(snapshotSource.contains("PlantBatchCareSheetRoomSection"))
        #expect(snapshotSource.contains("PlantBatchCareRouteSnapshotInput"))
        #expect(dashboardSource.contains("@State var batchCareSheetSnapshot: PlantBatchCareSheetSnapshot"))
        #expect(dashboardSource.contains("prepareBatchCareSheetSnapshot(careType: careType, roomID: roomID)"))
        #expect(dashboardSource.contains("PlantBatchCareRouteSnapshotActor(modelContainer: container)"))
        #expect(sheetSource.contains("let snapshot: PlantBatchCareSheetSnapshot"))
        #expect(sheetSource.contains("ForEach(snapshot.careTypeFilters)"))
        #expect(sheetSource.contains("ForEach(visibleRoomSections)"))
        #expect(!sheetSource.contains("Dictionary(grouping: visibleTasks"))
        #expect(!sheetSource.contains("Self.filteredTasks(tasks"))
    }

    @Test func plantBatchCareSheetKeepsExceptionActionsInFlow() throws {
        let sheetSource = try source("Ohana/Features/Plants/Views/PlantBatchCareSheet.swift")
        let dashboardSource = try source("Ohana/Features/Plants/Views/PlantDashboardView.swift")

        #expect(sheetSource.contains("PlantBatchCareActionRevealRow"))
        #expect(sheetSource.contains("@State private var resolvedTaskIDs"))
        #expect(sheetSource.contains("visibleRoomSections"))
        #expect(sheetSource.contains("resolveTask(task, using: onDeferTask)"))
        #expect(sheetSource.contains("resolveTask(task, using: onSkipTask)"))
        #expect(sheetSource.contains("全部处理完"))
        #expect(!sheetSource.contains("rowActionButton("))
        #expect(!sheetSource.contains("metricPill("))
        #expect(!sheetSource.contains("onDeferTask(task)\n                    dismiss()"))
        #expect(!sheetSource.contains("onSkipTask(task)\n                    dismiss()"))
        #expect(!dashboardSource.contains("func deferTaskFromBatchCare(_ task: PlantBatchCareSheetTask) {\n        showingBatchCareSheet = false"))
        #expect(!dashboardSource.contains("func skipTaskFromBatchCare(_ task: PlantBatchCareSheetTask) {\n        showingBatchCareSheet = false"))
    }

    @Test func plantWalletKeepsAllVisiblePlantsInOneScene() throws {
        let plantPageSource = try source("Ohana/Features/Home/Views/VerticalSolidHomePlantsPage.swift")

        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 0) == 0)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 1) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 2) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 3) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 4) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 5) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 6) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 7) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 12) == 1)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionCount(cardCount: 13) == 1)
        #expect(plantPageSource.contains("return [VerticalSolidHomePlantCardSection(cards: cards)]"))
        #expect(!plantPageSource.contains("stride(from: 0, to: cards.count"))
    }

    @Test func plantWalletCollapsedLayoutSpreadsSevenPlantsInOneBalancedCluster() {
        let offsets = FocusHomeVerticalSolidCollapsedLayoutPolicy.offsets(count: 7)
        let xValues = offsets.map(\.width)
        let yValues = offsets.map(\.height).sorted()
        let xSpan = (xValues.max() ?? 0) - (xValues.min() ?? 0)
        let ySpan = (yValues.max() ?? 0) - (yValues.min() ?? 0)
        let maxVerticalGap = zip(yValues.dropFirst(), yValues)
            .map { next, previous in next - previous }
            .max() ?? 0
        let leftCount = offsets.count { $0.width < 0 }
        let rightCount = offsets.count { $0.width > 0 }

        #expect(offsets.count == 7)
        #expect(offsets[5] != offsets[6])
        #expect(xSpan > 1.7)
        #expect(ySpan > 2.25)
        #expect(ySpan < 2.65)
        #expect(maxVerticalGap < 0.9)
        #expect(maximumCollapsedCardOverlapRatio(offsets: offsets) < 0.38)
        #expect(abs(leftCount - rightCount) <= 1)
    }

    @Test func plantWalletCollapsedLayoutAvoidsTallPilesForDenseCounts() {
        for count in [5, 6, 8, 9, 10, 13] {
            let offsets = FocusHomeVerticalSolidCollapsedLayoutPolicy.offsets(count: count)
            let xValues = offsets.map(\.width)
            let yValues = offsets.map(\.height)
            let xSpan = (xValues.max() ?? 0) - (xValues.min() ?? 0)
            let ySpan = (yValues.max() ?? 0) - (yValues.min() ?? 0)

            #expect(offsets.count == count)
            #expect(xSpan > 1.65)
            #expect(ySpan > 1.9)
            #expect(maximumCollapsedCardOverlapRatio(offsets: offsets) < 0.42)
        }
    }

    @Test func plantWalletScrollExtendedLayoutFlowsDensePlantsDownward() {
        let offsets = FocusHomeVerticalSolidCollapsedLayoutPolicy.offsets(count: 8, mode: .scrollExtended)
        let xValues = offsets.map(\.width)
        let yValues = offsets.map(\.height)
        let xSpan = (xValues.max() ?? 0) - (xValues.min() ?? 0)
        let ySpan = (yValues.max() ?? 0) - (yValues.min() ?? 0)
        let minimumSceneHeight = FocusHomeVerticalSolidCollapsedLayoutPolicy.scrollExtendedMinimumSceneHeight(cardCount: 8)
        let sectionHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 8,
            isExpanded: false,
            availableHeight: 520
        )
        let expandedHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 8,
            isExpanded: true,
            availableHeight: 520
        )

        #expect(offsets.count == 8)
        #expect(xSpan > 1.35)
        #expect(ySpan > 4.0)
        #expect(maximumCollapsedCardOverlapRatio(offsets: offsets) < 0.18)
        #expect(minimumSceneHeight > 840)
        #expect(sectionHeight == minimumSceneHeight)
        #expect(expandedHeight == sectionHeight)
    }

    @Test func plantDashboardWalletKeepsAllPlantsInOneScene() throws {
        let source = try source("Ohana/Features/Plants/Views/PlantDashboardView+WalletDeck.swift")

        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 0) == 0)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 1) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 6) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 7) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 12) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionCount(cardCount: 13) == 1)
        #expect(PlantDashboardWalletSectionPolicy.sectionHeight(cardCount: 1) == 420)
        #expect(PlantDashboardWalletSectionPolicy.sectionHeight(cardCount: 6) == 620)
        #expect(PlantDashboardWalletSectionPolicy.sectionHeight(cardCount: 8) > 840)
        #expect(source.contains("return [PlantDashboardWalletCardSection(ordinal: 0, cards: cards)]"))
        #expect(!source.contains("stride(from: 0, to: cards.count"))
        #expect(source.contains("collapsedLayoutMode: .scrollExtended"))
        #expect(source.contains("expandedVerticalPlacement: .sceneCenter"))
    }

    @Test func plantDashboardWalletUsesHomePlantCollapsedBias() throws {
        let source = try source("Ohana/Features/Plants/Views/PlantDashboardView+WalletDeck.swift")

        #expect(source.contains("collapsedVerticalBias: FocusHomeVerticalSolidCollapsedLayoutPolicy.bottomExtendedVerticalBias"))
    }

    @Test func homePlantRailFloatsAndCardsCenterBetweenChrome() throws {
        let homeSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView.swift")
        let plantPageSource = try source("Ohana/Features/Home/Views/VerticalSolidHomePlantsPage.swift")

        #expect(homeSource.contains("topChromeHeight: topChromeHeight"))
        #expect(plantPageSource.contains("roomRailCenterY("))
        #expect(plantPageSource.contains(".position("))
        #expect(plantPageSource.contains("roomRailTrailingCenterInset"))
        #expect(plantPageSource.contains("collapsedVerticalBias: FocusHomeVerticalSolidCollapsedLayoutPolicy.defaultVerticalBias"))
        #expect(!plantPageSource.contains(".padding(.top, 22)"))
        #expect(VerticalSolidHomePlantWalletScrollPolicy.expandedCardViewportTopInset == 36)

        #expect(VerticalSolidHomePlantWalletScrollPolicy.cardViewportHeight(
            containerHeight: 798,
            bottomChromeHeight: 104
        ) == 694)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.roomRailCenterY(
            containerHeight: 798,
            topChromeHeight: 46
        ) == 376)
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

        #expect(VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: 8,
            isExpanded: false,
            availableHeight: 694
        ) > 840)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.anchoredExpandedSceneHeight(
            baseHeight: 520,
            isExpanded: false,
            scrollOffsetY: 420
        ) == 520)
        #expect(VerticalSolidHomePlantWalletScrollPolicy.anchoredExpandedSceneHeight(
            baseHeight: 520,
            isExpanded: true,
            scrollOffsetY: 420
        ) > 1080)
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

    @Test func homePlantPageOwnsViewSwitcherAndListMode() throws {
        let plantPage = try source("Ohana/Features/Home/Views/VerticalSolidHomePlantsPage.swift")
        let models = try source("Ohana/Features/Home/VerticalSolidHomeModels.swift")
        let builder = try source("Ohana/Features/Home/VerticalSolidHomeSnapshotBuilder.swift")
        let uiTestSource = try source("OhanaUITests/PlantModuleUITests.swift")

        #expect(plantPage.contains("VerticalSolidHomePlantViewStyle"))
        #expect(plantPage.contains("@State private var selectedViewStyle"))
        #expect(plantPage.contains("home-plants-view-switcher-rail"))
        #expect(plantPage.contains("home-plants-view-deck"))
        #expect(plantPage.contains("home-plants-view-list"))
        #expect(plantPage.contains("home-plants-room-list-view"))
        #expect(plantPage.contains("selectedViewStyle == .deck &&"))
        #expect(plantPage.contains("viewSwitcherCenterY(roomRailCenterY: roomRailCenterY)"))
        #expect(plantPage.contains("collapsedLayoutMode: .scrollExtended"))
        #expect(plantPage.contains("expandedVerticalPlacement: .viewportTop("))
        #expect(plantPage.contains("deckScrollOffsetTracker.offsetY"))
        #expect(plantPage.contains("expandedDeckScrollOffsetY = frozenScrollOffsetY"))
        #expect(plantPage.contains("anchoredExpandedSceneHeight("))
        #expect(plantPage.contains(".scrollDisabled(selectedCardId != nil)"))
        #expect(!plantPage.contains("expandedVerticalPlacement: .collapsedCardCenter"))
        #expect(models.contains("let careDifficultyText: String"))
        #expect(models.contains("let attentionText: String"))
        #expect(models.contains("let todoText: String"))
        #expect(models.contains("let hasDueWatering: Bool"))
        #expect(models.contains("let hasDueFertilizing: Bool"))
        #expect(models.contains("let dueCareTypes: [PlantCareType]"))
        #expect(models.contains("let overdueCareTypes: [PlantCareType]"))
        #expect(models.contains("let dueCareCount: Int"))
        #expect(models.contains("let overdueCareCount: Int"))
        #expect(builder.contains("careDifficultyText:"))
        #expect(builder.contains("attentionText:"))
        #expect(builder.contains("todoText:"))
        #expect(builder.contains("hasDueWatering: hasDueWatering"))
        #expect(builder.contains("hasDueFertilizing: hasDueFertilizing"))
        #expect(builder.contains("dueCareTypes: dueCareTypes"))
        #expect(builder.contains("overdueCareTypes: overdueCareTypes"))
        #expect(builder.contains("dueCareCount: todayDueCareCount"))
        #expect(builder.contains("overdueCareCount: overdueCareCount"))
        #expect(uiTestSource.contains("testHomePlantViewSwitcherRailSwitchesToListMode"))
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

    @Test func homeFabUsesAddMemberAndAllFeatureRoots() throws {
        let sharedSource = try source("Ohana/Features/Home/Views/HomeFabSharedControls.swift")
        let modelsSource = try source("Ohana/Features/Home/FocusHomeModels.swift")
        let bottomBarSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeBottomBar.swift")
        let routingSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+TodayFocus.swift")

        #expect(modelsSource.contains("enum HomeFabFunctionShortcutAction"))
        #expect(modelsSource.contains("case addEntity(EntityType)"))
        #expect(modelsSource.contains("case destination(FMDest)"))
        #expect(modelsSource.contains("case submenu(HomeFabShortcutSubmenu)"))
        #expect(sharedSource.contains("primaryShortcuts(l:"))
        #expect(sharedSource.contains("action: .submenu(.addMember)"))
        #expect(sharedSource.contains("destination: .petFeatureCollection"))
        #expect(sharedSource.contains("addMemberShortcuts(l:"))
        #expect(sharedSource.contains("entityToAdd: .pet"))
        #expect(sharedSource.contains("entityToAdd: .human"))
        #expect(!sharedSource.contains("destination: .featureAggregate(.food)"))
        #expect(!sharedSource.contains("destination: .featureAggregate(.hygiene)"))
        #expect(!sharedSource.contains("destination: .featureAggregate(.health)"))
        #expect(bottomBarSource.contains("@State private var activeHomeSubmenu: HomeFabShortcutSubmenu?"))
        #expect(bottomBarSource.contains("@State private var submenuItemsVisible = false"))
        #expect(bottomBarSource.contains("HomeFabShortcutCatalog.addMemberShortcuts(l: l)"))
        #expect(bottomBarSource.contains("submenuItemsVisible && itemsVisible"))
        #expect(bottomBarSource.contains("case .submenu(.addMember):"))
        #expect(bottomBarSource.contains("isDimmed: activeHomeSubmenu == .addMember"))
        #expect(bottomBarSource.contains("isDimmed ? 0.42 : 1"))
        #expect(bottomBarSource.contains("return \"add-\\(type.rawValue)\""))
        #expect(bottomBarSource.contains("return \"pet-feature-collection\""))
        #expect(routingSource.contains("case let .addEntity(type):"))
        #expect(routingSource.contains("case let .destination(destination):"))
    }

    @Test func petFeatureCollectionRoutesToAggregateCards() throws {
        let modelSource = try source("Ohana/Features/FunctionMenu/FunctionMenuModels.swift")
        let routerSource = try source("Ohana/Features/FunctionMenu/Views/FunctionMenuDestinationRouter.swift")
        let routeDataSource = try source("Ohana/Features/FunctionMenu/FunctionMenuRouteContainer.swift")
        let collectionSource = try source("Ohana/Features/FunctionMenu/Views/PetFeatureCollectionView.swift")
        let sheetSource = try source("Ohana/Features/FunctionMenu/Views/FunctionMenuSheet.swift")

        #expect(modelSource.contains("case petFeatureCollection"))
        #expect(routerSource.contains("case .petFeatureCollection:"))
        #expect(routerSource.contains("PetFeatureCollectionView("))
        #expect(routerSource.contains("summary: petFeatureCollectionSummary"))
        #expect(routeDataSource.contains("var petFeatureCollectionSummary: PetFeatureCollectionSummary"))
        #expect(routeDataSource.contains("PetFeatureCollectionSummary.load("))
        #expect(
            collectionSource.contains("parentPath.append(.featureAggregate(item.feature))") ||
                collectionSource.contains("parentPath.append(FMDest.featureAggregate(item.feature))")
        )
        #expect(!collectionSource.contains("parentPath.append(.petFood"))
        #expect(!collectionSource.contains("parentPath.append(.petHealth"))
        #expect(!collectionSource.contains("FetchDescriptor<"))
        #expect(sheetSource.contains(".petFeatureCollection,"))
        #expect(sheetSource.contains("Alle Funktionen"))
    }

    @Test func plantFeatureCollectionRoutesToAggregateCards() throws {
        let modelSource = try source("Ohana/Features/FunctionMenu/FunctionMenuModels.swift")
        let routerSource = try source("Ohana/Features/FunctionMenu/Views/FunctionMenuDestinationRouter.swift")
        let routeDataSource = try source("Ohana/Features/FunctionMenu/FunctionMenuRouteContainer.swift")
        let collectionSource = try source("Ohana/Features/FunctionMenu/Views/PlantFeatureCollectionView.swift")
        let sheetSource = try source("Ohana/Features/FunctionMenu/Views/FunctionMenuSheet.swift")

        #expect(modelSource.contains("case plantFeatureCollection"))
        #expect(routerSource.contains("case .plantFeatureCollection:"))
        #expect(routerSource.contains("PlantFeatureCollectionView("))
        #expect(routerSource.contains("summary: plantFeatureCollectionSummary"))
        #expect(routeDataSource.contains("var plantFeatureCollectionSummary: PlantFeatureCollectionSummary"))
        #expect(routeDataSource.contains("PlantFeatureCollectionSummary.load("))
        #expect(routeDataSource.contains("var calendarPlanEnabledCount"))
        #expect(routeDataSource.contains("var systemReminderEnabledCount"))
        #expect(collectionSource.contains("commandCenterPanel"))
        #expect(collectionSource.contains("plant-feature-collection-command-center"))
        #expect(collectionSource.contains("summary.systemReminderEnabledCount"))
        #expect(collectionSource.contains("summary.maintenanceDueCount"))
        #expect(collectionSource.contains("summary.healthDueCount"))
        #expect(collectionSource.contains("summary.growthLogCount"))
        #expect(collectionSource.contains("parentPath.append(item.destination)"))
        #expect(collectionSource.contains(".plantsBatchCare"))
        #expect(collectionSource.contains(".plantsDashboard"))
        #expect(collectionSource.contains(".plantCareAggregate(.water)"))
        #expect(collectionSource.contains(".plantCareAggregate(.fertilize)"))
        #expect(collectionSource.contains(".plantCareAggregate(.maintenance)"))
        #expect(collectionSource.contains(".plantCareAggregate(.health)"))
        #expect(collectionSource.contains(".plantCareAggregate(.growth)"))
        #expect(!collectionSource.contains(".plantCareAggregate(.log)"))
        #expect(collectionSource.contains("title: l.tr(zh: \"植物管理\", en: \"Plant Management\""))
        #expect(!collectionSource.contains("FetchDescriptor<"))
        #expect(sheetSource.contains(".plantFeatureCollection,"))
        #expect(sheetSource.contains("Alle Pflanzenfunktionen"))
    }

    @Test func plantsTabFabOwnsPlantModuleShortcuts() throws {
        let sharedSource = try source("Ohana/Features/Home/Views/HomeFabSharedControls.swift")
        let bottomBarSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeBottomBar.swift")
        let routingSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+TodayFocus.swift")
        let functionRootSource = try source("Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift")

        #expect(sharedSource.contains("plantShortcuts(l:"))
        #expect(sharedSource.contains("entityToAdd: .plant"))
        #expect(sharedSource.contains("destination: .plantFeatureCollection"))
        #expect(!sharedSource.contains("destination: .featureGroup(.plants)"))
        #expect(bottomBarSource.contains("plantShortcuts: [HomeFabFunctionShortcut]"))
        #expect(bottomBarSource.contains("selectedTab == .plants"))
        #expect(bottomBarSource.contains("return \"add-\\(type.rawValue)\""))
        #expect(bottomBarSource.contains("return \"plant-feature-collection\""))
        #expect(routingSource.contains("case let .addEntity(type):"))
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

    @Test func cardHeroKeepsAmbientFloatOffTheTimelineBodyLoop() throws {
        let sceneSource = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidScene.swift")
        let policySource = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidScenePolicies.swift")

        #expect(!sceneSource.contains("TimelineView(.animation("))
        #expect(!sceneSource.contains("if canFloatCards {\n                    TimelineView"))
        #expect(sceneSource.contains("@State private var ambientFloatCycleTask: Task<Void, Never>?"))
        #expect(sceneSource.contains("Task.sleep(nanoseconds: FocusHomeAmbientFloatPolicy.phaseDurationNanoseconds)"))
        #expect(sceneSource.contains("withAnimation(FocusHomeAmbientFloatPolicy.phaseAnimation)"))
        #expect(policySource.contains("static let cycleDuration: TimeInterval = 8.7"))
        #expect(policySource.contains("static let phaseDuration: TimeInterval = cycleDuration / 2"))
        #expect(sceneSource.contains("FocusHomeWalkCardIdentityPolicy.identity("))
        #expect(!sceneSource.contains("appServices.walkingPresentationRevision"))
    }

    @Test func homeCardHeroAvoidsAnimatedLargeShadowRasterization() throws {
        let surfaceSource = try source("Ohana/Features/Home/Views/FocusHomeVerticalSolidCardSurface.swift")

        #expect(!surfaceSource.contains("radius: lerp(15, 24, p)"))
        #expect(surfaceSource.contains("stable home card depth without animating shadow rasterization"))
        #expect(surfaceSource.contains("collapse internal text/avatar shadows into one card surface before hero scaling"))
    }

    @Test func calendarRouteDataUsesWindowedFetchAndRevisionDebounce() throws {
        let routeSource = try source("Ohana/Features/Calendar/CalendarRouteContainer.swift")
        let policySource = try source("Ohana/Features/Calendar/Views/CalendarViewSupport.swift")

        #expect(routeSource.contains("scheduleRouteDataReloadAfterRevision()"))
        #expect(routeSource.contains("@ModelActor"))
        #expect(routeSource.contains("CalendarRouteDataActor"))
        #expect(routeSource.contains("try await actor.load(input: input)"))
        #expect(routeSource.contains("let events = fetchVisibleEvents()"))
        #expect(routeSource.contains("FetchDescriptor<Event>(\n                predicate: #Predicate<Event>"))
        #expect(routeSource.contains("event.startDate >= windowStart && event.startDate <= windowEnd"))
        #expect(routeSource.contains("event.recurrenceDays > 0 && event.startDate <= windowEnd"))
        #expect(routeSource.contains("recurringDescriptor.fetchLimit = Self.recurringEventFetchLimit"))
        #expect(!routeSource.contains("CalendarRouteData.load(from:"))
        #expect(!routeSource.contains("FetchDescriptor<Event>(sortBy: [SortDescriptor(\\.startDate"))
        #expect(!routeSource.contains("route-first-frame: allow deferred-fetch"))
        #expect(policySource.contains("revisionReloadDebounceMilliseconds"))
    }

    @Test func calendarViewRendersPreparedSnapshotInsteadOfBodyAggregation() throws {
        let calendarSource = try source("Ohana/Features/Calendar/Views/CalendarView.swift")
        let contentSource = try source("Ohana/Features/Calendar/Views/CalendarView+Content.swift")
        let headerSource = try source("Ohana/Features/Calendar/Views/CalendarView+Header.swift")
        let monthSource = try source("Ohana/Features/Calendar/Views/CalendarView+Month.swift")
        let supportSource = try source("Ohana/Features/Calendar/Views/CalendarViewSupport.swift")
        let routeSource = try source("Ohana/Features/Calendar/CalendarRouteContainer.swift")
        let snapshotSource = try source("Ohana/Features/Calendar/CalendarSnapshotBuilder.swift")

        #expect(calendarSource.contains("@State var preparedCalendarSnapshot = CalendarPreparedSnapshot.empty"))
        #expect(calendarSource.contains("@State var preparedCalendarSnapshotKey: CalendarPreparedSnapshotTriggerKey?"))
        #expect(calendarSource.contains("preparedCalendarSnapshotTriggerKey"))
        #expect(!calendarSource.contains("func buildFilteredEventsForPreparedSnapshot() -> [Event]"))
        #expect(!calendarSource.contains("func eventOccursOnDate(_ event: Event, date: Date) -> Bool"))
        #expect(!calendarSource.contains("preparedCalendarSnapshotInputKey"))
        #expect(!contentSource.contains(".onChange(of: preparedCalendarSnapshotInputKey)"))
        #expect(contentSource.contains(".onChange(of: preparedCalendarSnapshotTriggerKey)"))
        #expect(contentSource.contains("applyRoutePreparedSnapshotIfAvailable()"))
        #expect(contentSource.contains("CalendarPreparedSnapshotActor(modelContainer: modelContext.container)"))
        #expect(contentSource.contains("applyPreparedSnapshotReference"))
        #expect(!contentSource.contains("CalendarSnapshotBuilder.preparedSnapshot("))
        #expect(calendarSource.contains("routePreparedSnapshot: CalendarRoutePreparedSnapshot?"))
        #expect(calendarSource.contains("preparedCalendarSnapshot.timeline"))
        #expect(calendarSource.contains("preparedCalendarSnapshot.events(forDayID: timelineDateID(selectedDate))"))
        #expect(headerSource.contains("preparedCalendarSnapshot.weekEventsByDay"))
        #expect(monthSource.contains("preparedCalendarSnapshot.monthEventDayIDs"))
        #expect(!supportSource.contains("var selectedDay: Date"))
        #expect(routeSource.contains("actor CalendarPreparedSnapshotActor"))
        #expect(snapshotSource.contains("private nonisolated struct CalendarOccurrenceDayIndex"))
        #expect(snapshotSource.contains("let occurrencesByDay: [Date: [CalendarEventOccurrence]]"))
        #expect(snapshotSource.contains("private static func buildOccurrenceDayIndex("))
        #expect(snapshotSource.contains("let eventsByDay: [String: [Event]]"))
        #expect(!snapshotSource.contains("static func eventsForDate("))
        #expect(!snapshotSource.contains("private static func eventsForDate("))
        #expect(!snapshotSource.contains("eventOccursOnDate("))
        #expect(!snapshotSource.contains("selectedDateEvents"))
        #expect(!monthSource.contains("let hasEvents = filteredEvents.contains"))
    }

    private func maximumCollapsedCardOverlapRatio(offsets: [CGSize]) -> CGFloat {
        let cardWidth: CGFloat = 1
        let cardHeight: CGFloat = 1.58
        let cardArea = cardWidth * cardHeight
        let frames = offsets.map { offset in
            CGRect(
                x: offset.width - cardWidth / 2,
                y: offset.height - cardHeight / 2,
                width: cardWidth,
                height: cardHeight
            )
        }

        var maximumOverlap: CGFloat = 0
        for lhs in frames.indices {
            for rhs in frames.indices where rhs > lhs {
                let intersection = frames[lhs].intersection(frames[rhs])
                guard !intersection.isNull else { continue }
                maximumOverlap = max(maximumOverlap, intersection.width * intersection.height / cardArea)
            }
        }
        return maximumOverlap
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
