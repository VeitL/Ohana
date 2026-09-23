//
//  VerticalSolidHomeView+Routing.swift
//  Ohana
//

import SwiftData
import SwiftUI

enum HomeToolbarPrimaryActionPolicy {
    static let homeIcon = "chart.bar.xaxis"

    static func homeDestination(currentLevel: Int, plan: OhanaPlanLevel = .free) -> FMDest? {
        guard isHouseholdInsightsAvailable(currentLevel: currentLevel, plan: plan) else {
            return nil
        }
        return .featureGroup(.householdHub)
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
    var homeToolbarQuickRecordTargets: [HomeToolbarQuickRecordTarget] {
        let quickActionsByCardID = controller.snapshot.cards.reduce(into: [UUID: [QuickActionItem]]()) { result, card in
            guard result[card.id] == nil else { return }
            result[card.id] = interaction.expandedActions(for: card.id).candidateItems
        }
        return HomeToolbarQuickRecordPolicy.targets(
            for: controller.selectedTab,
            cards: controller.snapshot.cards,
            plants: controller.snapshot.plants,
            quickActionsByCardID: quickActionsByCardID,
            localization: l
        )
    }

    func openHomeToolbarQuickRecord(
        _ target: HomeToolbarQuickRecordTarget,
        action: QuickActionItem?,
        optionID: String?
    ) {
        switch target.kind {
        case .plant:
            guard action == nil,
                  optionID == nil,
                  controller.snapshot.plants.contains(where: {
                $0.id == target.entityID && !$0.isArchived
            }) else { return }
            OhanaFeedback.light()
            routeCoordinator.openSheet(.plantCareLog(target.entityID, initialCareType: .customNote))
        case .human:
            guard interaction.activeHumanSnapshot(id: target.entityID) != nil,
                  let card = controller.snapshot.cards.first(where: {
                      $0.id == target.entityID && $0.isHuman && !$0.hasPassedAway
                  }),
                  let action,
                  optionID == nil else { return }
            if action.actionType == "humanMetrics" {
                guard let privacyProbe = interaction.expandedActions(for: target.entityID)
                    .candidateItems
                    .first(where: { $0.actionType == "humanWeight" }) else { return }
                guard !interaction.expandedActions(for: target.entityID).state(for: privacyProbe).isLocked else {
                    routeCoordinator.showHumanPrivacy()
                    return
                }
                OhanaFeedback.light()
                routeCoordinator.openSheet(.humanMetrics(target.entityID))
                return
            }
            openQuickActionItem(action, card: card, usesPrimaryAction: true)
        case .pet:
            guard interaction.activePet(id: target.entityID) != nil,
                  let card = controller.snapshot.cards.first(where: {
                      $0.id == target.entityID && !$0.isHuman && !$0.isElectronicPet && !$0.hasPassedAway
                  }),
                  let action else { return }
            if let optionID {
                guard HomeQuickActionOptionCatalog.options(
                    for: action.actionType,
                    localization: l
                ).contains(where: { $0.id == optionID }) else { return }
                openQuickActionOption(action, card: card, optionId: optionID)
                return
            }
            let state = interaction.expandedActions(for: target.entityID).state(for: action)
            let usesPrimaryAction = HomeToolbarQuickRecordPolicy.usesPetPrimaryAction(
                for: action,
                state: state
            )
            openQuickActionItem(action, card: card, usesPrimaryAction: usesPrimaryAction)
        }
    }

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
        // TabView owns the page transition. Keep custom motion scoped to the
        // app-owned selection indicator instead of animating the root tree.
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
            guard let destination = HomeToolbarPrimaryActionPolicy.homeDestination(
                currentLevel: appServices.oasisTree.treeLevel.rawValue,
                plan: appServices.commerce.ohanaPlanLevel
            ) else { return }
            openFunctionMenu(destination: destination)
        case .calendar, .oasis:
            performHomeBottomContextAction()
        case .plants:
            routeCoordinator.openAddEntity(.plant)
        }
    }

    func performHomeBottomContextAction() {
        switch controller.selectedTab {
        case .home, .plants:
            break
        case .calendar:
            openCalendarAddEvent(plants: embeddedCalendarPlants)
        case .oasis:
            guard homeBottomContextActionDisabledReason == nil else { return }
            injectEmbeddedOasisEnergy()
        }
    }

    var homeBottomContextActionDisabledReason: HomeBottomContextActionDisabledReason? {
        switch controller.selectedTab {
        case .home, .plants:
            return controller.snapshot.isReady ? nil : .loading
        case .calendar:
            return nil
        case .oasis:
            guard controller.snapshot.isReady else { return .loading }
            guard oasisEnergyInjectionTask == nil, pendingOasisEnergyInjectionCount == 0 else {
                return .inProgress
            }
            let cost = OasisTreeEnergyInjectionPolicy.starterPackageCost
            guard islandCoconutBalance >= cost else {
                return .insufficientCoconuts(required: cost)
            }
            guard treeManager.canUseInjectionPackage(cost: cost) else { return .unavailable }
            return nil
        }
    }

    var homeToolbarPrimaryActionIcon: String {
        switch controller.selectedTab {
        case .home:
            HomeToolbarPrimaryActionPolicy.homeIcon
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
            l.tr(zh: "查看家庭洞察", en: "View household insights", de: "Haushaltseinblicke anzeigen")
        case .calendar:
            l.tr(zh: "添加待办", en: "Add task", de: "Aufgabe hinzufügen")
        case .oasis:
            l.tr(zh: "注入能量", en: "Inject energy", de: "Energie einspeisen")
        case .plants:
            l.tr(zh: "植物操作", en: "Plant actions", de: "Pflanzenaktionen")
        }
    }

    var showsHomeToolbarPrimaryAction: Bool {
        HomeToolbarPrimaryActionPolicy.homeDestination(
            currentLevel: appServices.oasisTree.treeLevel.rawValue,
            plan: appServices.commerce.ohanaPlanLevel
        ) != nil
    }
}
