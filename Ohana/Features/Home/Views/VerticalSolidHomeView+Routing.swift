//
//  VerticalSolidHomeView+Routing.swift
//  Ohana
//

import SwiftData
import SwiftUI

enum HomeToolbarPrimaryActionPolicy {
    static func homeDestination(currentLevel: Int, plan: OhanaPlanLevel = .free) -> FMDest {
        isHouseholdInsightsAvailable(currentLevel: currentLevel, plan: plan)
            ? .featureGroup(.householdHub)
            : .growthRoadmap
    }

    static func homeIcon(currentLevel: Int, plan: OhanaPlanLevel = .free) -> String {
        isHouseholdInsightsAvailable(currentLevel: currentLevel, plan: plan)
            ? "chart.bar.xaxis"
            : "tree.fill"
    }

    static func isHouseholdInsightsAvailable(
        currentLevel: Int,
        plan: OhanaPlanLevel = .free
    ) -> Bool {
        AppFeatureRouteGuard.isVisibleFunctionDestination(
            .featureGroup(.householdHub),
            currentLevel: currentLevel,
            plan: plan
        )
    }
}

extension VerticalSolidHomeView {
    func embeddedTaskCenterPage(lifecycle: VerticalSolidHomePageLifecycle) -> some View {
        TaskCenterRouteContainer(
            presentation: .embeddedHome,
            initialSurface: .tasks,
            routeContext: TaskCenterRouteContext(
                scope: .all,
                focusedItemID: taskCenterFocusedItemID,
                focusedFamilyTaskID: taskCenterFocusedFamilyTaskID,
                focusRequestID: taskCenterFocusRequestID
            ),
            preselectedPetId: embeddedCalendarPreselectedPetId,
            preselectedHumanId: embeddedCalendarPreselectedHumanId,
            addEventTrigger: calendarAddEventTrigger,
            isEmbeddedPrepared: lifecycle.isPrepared,
            isEmbeddedVisible: lifecycle.isVisible,
            isEmbeddedActive: lifecycle.isLive,
            onRequestAddEvent: openCalendarAddEvent,
            onPlantsLoaded: { plants in
                embeddedCalendarPlants = plants
            },
            onOpenEventDestination: openCalendarEventDestination,
            onOpenSystemDestination: { item in
                switch item.systemDestination {
                case .createFirstPet:
                    routeCoordinator.openAddEntity(.pet)
                case .claimStarterGift:
                    onRequestStarterGiftClaim()
                case .completeHumanProfile:
                    if let id = item.subject.id { routeCoordinator.openSheet(.humanBasicInfo(id)) }
                case .completeFirstPetProfile:
                    if let id = item.subject.id { routeCoordinator.openSheet(.petBasicInfo(id)) }
                case .confirmPetIdentityProtection:
                    if let id = item.subject.id { routeCoordinator.openSheet(.petDocuments(id)) }
                case .confirmPetPreventiveCare:
                    if let id = item.subject.id {
                        routeCoordinator.openSheet(.petHealth(id, initialSection: .preventive))
                    }
                case .configureFirstCarePlan:
                    if let id = item.subject.id { routeCoordinator.openSheet(.petFood(id)) }
                case .recordFirstCare:
                    if let id = item.subject.id {
                        routeCoordinator.openSheet(.petFeed(id, opensManualSheet: true))
                    }
                case nil:
                    break
                }
            },
            onPresentCoconutLog: onPresentCoconutLog,
            onBadgeChange: { badge in
                guard taskCenterBadge != badge else { return }
                taskCenterBadge = badge
            }
        )
        .padding(.top, 4)
    }

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

    func selectTab(
        _ tab: VerticalSolidHomeTab,
        preservesTaskFocus: Bool = false
    ) {
        guard AppFeatureRouteGuard.allowsHomeTab(tab, currentLevel: appServices.oasisTree.treeLevel.rawValue) else {
            AppFeatureRouteGuard.recordIntercept("homeTab:\(tab.rawValue)")
            return
        }
        if tab == .calendar, !preservesTaskFocus {
            taskCenterFocusedItemID = nil
            taskCenterFocusedFamilyTaskID = nil
            taskCenterFocusRequestID = nil
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
            currentLevel: appServices.oasisTree.treeLevel.rawValue,
            plan: appServices.commerce.ohanaPlanLevel
        )
    }

    func performHomeToolbarPrimaryAction() {
        switch controller.selectedTab {
        case .home:
            openFunctionMenu(destination: HomeToolbarPrimaryActionPolicy.homeDestination(
                currentLevel: appServices.oasisTree.treeLevel.rawValue,
                plan: appServices.commerce.ohanaPlanLevel
            ))
        case .calendar:
            calendarAddEventTrigger += 1
        case .oasis:
            injectEmbeddedOasisEnergy()
        case .plants:
            routeCoordinator.openAddEntity(.plant)
        }
    }

    var homeToolbarPrimaryActionIcon: String {
        switch controller.selectedTab {
        case .home:
            HomeToolbarPrimaryActionPolicy.homeIcon(
                currentLevel: appServices.oasisTree.treeLevel.rawValue,
                plan: appServices.commerce.ohanaPlanLevel
            )
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
            if HomeToolbarPrimaryActionPolicy.isHouseholdInsightsAvailable(
                currentLevel: appServices.oasisTree.treeLevel.rawValue,
                plan: appServices.commerce.ohanaPlanLevel
            ) {
                l.tr(zh: "查看家庭洞察", en: "View household insights", de: "Haushaltseinblicke anzeigen")
            } else {
                l.tr(zh: "查看成长路线", en: "View growth roadmap", de: "Wachstumsweg anzeigen")
            }
        case .calendar:
            l.tr(zh: "添加待办", en: "Add task", de: "Aufgabe hinzufügen")
        case .oasis:
            l.tr(zh: "注入能量", en: "Inject energy", de: "Energie einspeisen")
        case .plants:
            l.tr(zh: "植物操作", en: "Plant actions", de: "Pflanzenaktionen")
        }
    }
}
