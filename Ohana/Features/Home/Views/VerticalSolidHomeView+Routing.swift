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
                onPresentAppSheet(.petMomentQuick(petID))
            case let .petWeightQuick(petID):
                onPresentAppSheet(.petWeightQuick(petID))
            case let .petExpenseQuick(petID):
                onPresentAppSheet(.petExpenseQuick(petID))
            case let .humanMedicationQuick(humanID):
                onPresentAppSheet(.humanMedicationQuick(humanID))
            case let .humanWeightQuick(humanID):
                onPresentAppSheet(.humanWeightQuick(humanID))
            case let .humanWorkoutQuick(humanID):
                onPresentAppSheet(.humanWorkoutQuick(humanID))
            case let .humanExpenseQuick(humanID):
                onPresentAppSheet(.humanExpenseQuick(humanID))
            case let .humanNoteQuick(humanID):
                onPresentAppSheet(.humanNoteQuick(humanID))
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
        guard AppFeatureRouteGuard.allowsHomeTab(tab, currentLevel: appServices.oasisTree.treeLevel.rawValue) else {
            AppFeatureRouteGuard.recordIntercept("homeTab:\(tab.rawValue)")
            return
        }
        guard controller.selectedTab != tab else { return }
        OhanaFeedback.selection()
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

    func performHomeToolbarPrimaryAction() {
        switch controller.selectedTab {
        case .home:
            openFunctionMenu(destination: .petFeatureCollection)
        case .calendar:
            openCalendarAddEvent(plants: embeddedCalendarPlants)
        case .oasis:
            injectEmbeddedOasisEnergy()
        case .plants:
            routeCoordinator.openAddEntity(.plant)
        }
    }

    var homeToolbarPrimaryActionIcon: String {
        switch controller.selectedTab {
        case .home:
            "chart.bar.xaxis"
        case .calendar:
            "plus"
        case .oasis:
            "bolt.fill"
        case .plants:
            "ellipsis.circle"
        }
    }

    var homeToolbarPrimaryActionAccessibilityLabel: String {
        switch controller.selectedTab {
        case .home:
            return l.tr(zh: "查看家庭数据", en: "View family data", de: "Familiendaten anzeigen")
        case .calendar:
            return l.tr(zh: "添加待办", en: "Add task", de: "Aufgabe hinzufügen")
        case .oasis:
            return l.tr(zh: "注入能量", en: "Inject energy", de: "Energie einspeisen")
        case .plants:
            return l.tr(zh: "植物操作", en: "Plant actions", de: "Pflanzenaktionen")
        }
    }
}
