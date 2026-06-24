//
//  VerticalSolidHomeView+Routing.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension VerticalSolidHomeView {
    func bindHomeAppRouteSink() {
        routeCoordinator.bindAppRouteSink { route in
            switch route {
            case let .petProfile(id, initialTab):
                onOpenPet(id, initialTab)
            case let .humanProfile(id):
                onOpenHuman(id)
            }
        }
        routeCoordinator.bindAppSheetRouteSink { route in
            switch route {
            case .accountSwitcher:
                onPresentAccountSwitcher()
            case let .addEntity(type):
                onPresentAddEntity(type)
            case let .appSheet(route):
                onPresentAppSheet(route)
            case let .functionMenu(destination):
                onPresentFunctionMenu(destination)
            case .streakDetail:
                onPresentStreakDetail()
            }
        }
        routeCoordinator.bindAppFullScreenRouteSink { route in
            switch route {
            case .oasisReward:
                onPresentOasisReward()
            case let .walk(petID):
                onPresentWalk(petID)
            }
        }
        routeCoordinator.bindAppOverlayRouteSink { route in
            switch route {
            case let .quickMoment(petID):
                onPresentQuickMoment(petID)
            }
        }
    }

    func makeSnapshot() -> VerticalSolidHomeSnapshot {
        payload.snapshot
    }

    func requestHomeSnapshotRefresh() {
        guard let request = snapshotRefreshGate.dataDidChange(
            signature: dataSignature,
            isHeroAnimating: isHomeCardHeroAnimating
        ) else {
            return
        }
        scheduleHomeSnapshotRefresh(request)
    }

    func requestTodayFocusRefreshIfDayChanged(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let currentDayToken = TodayFocusSnapshot.dayToken(for: now, calendar: calendar)
        guard controller.snapshot.todayFocus.dayToken != currentDayToken else {
            return
        }
        requestHomeSnapshotRefresh()
    }

    func flushDeferredHomeSnapshotRefreshIfNeeded(isAnimating: Bool) {
        guard let request = snapshotRefreshGate.heroAnimationDidChange(isAnimating: isAnimating) else {
            return
        }
        scheduleHomeSnapshotRefresh(request)
    }

    func scheduleHomeSnapshotRefresh(_ request: HomeSnapshotRefreshRequest) {
        controller.scheduleSnapshotRefresh(
            signature: request.signature,
            delayMilliseconds: request.delayMilliseconds
        ) {
            makeSnapshot()
        }
    }

    func selectTab(_ tab: VerticalSolidHomeTab) {
        guard AppFeatureRouteGuard.allowsHomeTab(tab) else {
            AppFeatureRouteGuard.recordIntercept("homeTab:\(tab.rawValue)")
            return
        }
        guard controller.selectedTab != tab else { return }
        OhanaFeedback.selection()
        closeVerticalFabMenu(immediate: true)
        if tab == .oasis {
            starterOasisTabPromptPending = false
        }
        if tab == .calendar {
            prepareEmbeddedCalendarFilterForCurrentContext()
        }
        controller.select(tab)
    }

    func prepareEmbeddedCalendarFilterForCurrentContext() {
        guard let card = expandedBottomBarCard else {
            embeddedCalendarPreselectedPetId = nil
            embeddedCalendarPreselectedHumanId = nil
            return
        }

        if card.isHuman {
            embeddedCalendarPreselectedPetId = nil
            embeddedCalendarPreselectedHumanId = card.id.uuidString
        } else {
            embeddedCalendarPreselectedPetId = card.id.uuidString
            embeddedCalendarPreselectedHumanId = nil
        }
    }

    func openFunctionMenu(destination: FMDest?) {
        routeCoordinator.openFunctionMenu(
            destination: destination,
            currentLevel: appServices.oasisTree.treeLevel.rawValue
        )
    }

    func centerAction() {
        OhanaFeedback.light()
        switch controller.selectedTab {
        case .home:
            openFunctionMenu(destination: nil)
        case .calendar:
            openCalendarAddEvent()
        case .oasis:
            injectEmbeddedOasisEnergy()
        case .plants:
            routeCoordinator.openAddEntity(.plant)
        }
    }
}
