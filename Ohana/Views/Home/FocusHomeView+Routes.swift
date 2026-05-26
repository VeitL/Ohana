//
//  FocusHomeView+Routes.swift
//  Ohana
//
//  Split FocusHomeView responsibilities.
//

import SwiftUI

extension FocusHomeView {
    func handleMemberProfileDidChange(_ notification: Notification) {
        let id = (notification.userInfo?["id"] as? String).flatMap(UUID.init(uuidString:))
        snapshotController.invalidateMemberAppearance(cardId: id)
        requestSnapshotRefresh(force: true)
        if let id {
            snapshotController.seedAvatarData(
                cardId: id,
                data: FocusHomeCardDataSource.avatarDataForHomeCard(id: id, pets: pets, humans: humans)
            )
            snapshotController.seedPopoutData(
                cardId: id,
                data: FocusHomeCardDataSource.popoutDataForHomeCard(
                    id: id,
                    pets: pets,
                    equipFxPopoutCard: equipFxPopoutCard
                )
            )
        }
    }

    func routePendingReminderNotificationIfNeeded() {
        guard let userInfo = OhanaNotificationRouteCenter.shared.pendingRoute() else { return }
        _ = routeReminderNotification(userInfo)
    }

    func handleReminderRouteRequest(_ userInfo: [AnyHashable: Any]?) {
        _ = routeReminderNotification(userInfo)
    }

    @discardableResult
    func routeReminderNotification(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let payload = OhanaReminderRoutePayload(userInfo: userInfo) else { return false }
        return routeReminderNotification(payload)
    }

    @discardableResult
    func routeReminderNotification(_ userInfo: [String: Any]?) -> Bool {
        guard let payload = OhanaReminderRoutePayload(userInfo: userInfo) else { return false }
        return routeReminderNotification(payload)
    }

    @discardableResult
    func routeReminderNotification(_ payload: OhanaReminderRoutePayload) -> Bool {
        guard let destination = FocusHomeReminderDeepLinkRouter.destination(
            for: payload,
            reminders: pendingReminders,
            events: allEvents,
            pets: pets,
            humans: humans,
            plants: plants,
            humanMedications: humanMedications
        ) else {
            return false
        }

        closeReminderNotificationSurfaces()
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 40 : 90) {
            openReminderNotificationDestination(destination)
        }
        OhanaNotificationRouteCenter.shared.clearPendingRoute(reminderId: payload.reminderId?.uuidString)
        return true
    }

    func closeReminderNotificationSurfaces() {
        selectedPet = nil
        selectedHuman = nil
        selectedPlant = nil
        selectedPetTab = .overview
        routeCoordinator.resetAllRoutes()
        fabExpanded = false
        fabMenuItemsVisible = false
    }

    func openReminderNotificationDestination(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            openPetQuickKey(key, card: FocusCard.from(pet, includeAvatarData: true))
        case let .petFeature(feature, pet):
            openPetFeature(feature, card: FocusCard.from(pet, includeAvatarData: true))
        case let .petHealth(pet, section):
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, card: FocusCard.from(human, includeAvatarData: true))
        case let .humanDetail(human):
            selectedHuman = human
        case let .plant(plant):
            selectedPlant = plant
        case let .functionMenu(destination):
            routeCoordinator.openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId):
            routeCoordinator.openCalendar(entityID: entityId, humanID: humanId)
        }
    }

    func handlePetSaved(_ pet: Pet) {
        handleHomeMemberSaved(
            FocusCard.from(pet, includeAvatarData: true),
            shouldArriveInHomeStack: HomeCardVisibility.isPetVisible(pet)
        )
    }

    func handleHumanSaved(_ human: Human) {
        handleHomeMemberSaved(
            FocusCard.from(human, includeAvatarData: true),
            shouldArriveInHomeStack: human.shouldShowOnHome
        )
    }

    private func handleHomeMemberSaved(_ card: FocusCard, shouldArriveInHomeStack: Bool) {
        snapshotController.seedAvatarData(cardId: card.id, data: card.avatarImageData)
        snapshotController.seedPopoutData(cardId: card.id, data: card.cardPopoutImageData)
        if shouldArriveInHomeStack {
            homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: card.id, currentRaw: homeCardOrderRaw)
            pendingHomeArrivalCardId = card.id
        } else {
            pendingHomeArrivalCardId = nil
        }
        refreshSnapshot(force: true)
    }

    func completePendingHomeArrival() {
        refreshSnapshot(force: true)
        guard let id = pendingHomeArrivalCardId else { return }
        pendingHomeArrivalCardId = nil
        beginHomeCardArrival(id: id)
    }

    private func beginHomeCardArrival(id: UUID) {
        arrivalClearTask?.cancel()
        let startDelay: UInt64 = shouldReduceWork ? 40 : 110
        arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: startDelay) {
            arrivingHomeCardId = id
            arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: shouldReduceWork ? 620 : 1_500) {
                guard arrivingHomeCardId == id else { return }
                arrivingHomeCardId = nil
                arrivalClearTask = nil
            }
        }
    }

    func openCard(_ card: FocusCard) {
        snapshotController.seedAvatarData(cardId: card.id, data: card.avatarImageData)
        snapshotController.seedPopoutData(cardId: card.id, data: card.cardPopoutImageData)
        routeCoordinator.dismissModal()
        if !displayCards.contains(where: { $0.id == card.id }) {
            homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: card.id, currentRaw: homeCardOrderRaw)
            refreshSnapshot(force: true)
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            expandWalletToCard(id: card.id)
        }
    }

    func openCardBasicInfo(_ card: FocusCard) {
        if card.isHuman {
            if let human = humans.first(where: { $0.id == card.id }) {
                routeCoordinator.openSheet(.humanBasicInfo(human.id))
            }
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            routeCoordinator.openSheet(.petBasicInfo(pet.id))
        }
    }

    func openAllFeatures(_ card: FocusCard) {
        if card.isHuman {
            if let human = humans.first(where: { $0.id == card.id }) {
                routeCoordinator.openSheet(.humanAllFeatures(human.id))
            }
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func openQuickModule(_ action: FocusHomeQuickAction, for card: FocusCard) {
        OhanaFeedback.light()
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            switch action {
            case .primary: routeCoordinator.openSheet(.humanWeight(human.id))
            case .secondary: routeCoordinator.openSheet(.humanExpense(human.id))
            case .tertiary: routeCoordinator.openSheet(.humanMedication(human.id))
            case .all: routeCoordinator.openSheet(.humanAllFeatures(human.id))
            }
            return
        }

        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch action {
        case .primary:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .secondary:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .tertiary:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .all:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func expandedFabShortcuts(for card: FocusCard) -> [ExpandedCardFabShortcut] {
        if card.isHuman {
            guard let human = humans.first(where: { $0.id == card.id }) else {
                return FocusHomeFabShortcutPolicy.humanShortcuts(localization: l)
            }
            return FocusHomeFabShortcutPolicy.humanShortcuts(
                for: human,
                displayedItems: expandedHumanQuickActionItems(for: human),
                localization: l
            )
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return [
                ExpandedCardFabShortcut(
                    label: l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"),
                    icon: "ellipsis.circle.fill",
                    action: .allFeatures
                ),
            ]
        }
        return FocusHomeFabShortcutPolicy.petShortcuts(
            for: pet,
            displayedItems: expandedQuickActionItems(for: pet),
            localization: l
        )
    }

    func openHomeFabShortcut(_ shortcut: HomeFabFunctionShortcut) {
        guard shortcut.isAvailable else { return }
        routeCoordinator.openFunctionMenu(destination: shortcut.destination)
    }

    func selectVerticalTab(_ tab: VerticalHomeTab) {
        guard verticalTabVisualState.selectedTab != tab else {
            closeVerticalFabMenu()
            return
        }
        guard !verticalSolidMotion.isTabMotionLocked, !isWalletHeroTransitioning else {
            OhanaFeedback.light()
            return
        }
        if wallet.isExpanded {
            selectVerticalTabFromExpandedWallet(tab)
            return
        }
        applyVerticalTabSelection(tab)
    }

    func selectVerticalTabFromExpandedWallet(_ tab: VerticalHomeTab) {
        guard verticalTabVisualState.selectedTab == .home else {
            collapseHiddenHomeWalletForDirectTabSelection()
            applyVerticalTabSelection(tab)
            return
        }

        applyVerticalTabSelection(tab)
        scheduleHiddenWalletCleanupAfterDirectTabSelection(to: tab)
    }

    func applyVerticalTabSelection(_ tab: VerticalHomeTab) {
        closeVerticalFabMenuForNavigation()
        verticalSolidMotion.lockForTabMotion()
        verticalTabVisualState.select(tab)
        let commitDelay: UInt64 = shouldReduceWork ? 140 : 520
        verticalTabVisualState.scheduleCommit(for: tab, milliseconds: commitDelay) {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedVerticalTab = tab
            }
        }
        verticalSolidMotion.unlockAfterTabMotion(milliseconds: shouldReduceWork ? 160 : 560)
    }

    func closeVerticalFabMenu() {
        guard fabExpanded || fabMenuItemsVisible else { return }
        withAnimation(HeroAnim.fabSpring) {
            fabMenuItemsVisible = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            guard !fabMenuItemsVisible else { return }
            withAnimation(HeroAnim.fabSpring) {
                fabExpanded = false
            }
        }
    }

    func closeVerticalFabMenuForNavigation() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            fabMenuItemsVisible = false
            fabExpanded = false
        }
    }

    func openExpandedFabShortcut(_ shortcut: ExpandedCardFabShortcut, card: FocusCard) {
        switch shortcut.action {
        case .allFeatures:
            openAllFeatures(card)
        case .humanAllFeatures:
            openAllFeatures(card)
        case let .detail(feature):
            openPetFeature(feature, card: card)
        case let .quick(key):
            openPetQuickKey(key, card: card)
        case let .humanQuick(key):
            openHumanQuickKey(key, card: card)
        }
    }

    func openPetFeature(_ feature: PetFeature, card: FocusCard) {
        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch feature {
        case .food: routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .hygiene: routeCoordinator.openSheet(.petHygiene(pet.id))
        case .health: routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medications: routeCoordinator.openSheet(.petMedication(pet.id))
        case .walks: routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .potty: routeCoordinator.openSheet(.petPotty(pet.id))
        case .weight: routeCoordinator.openSheet(.petWeight(pet.id))
        case .expense: routeCoordinator.openSheet(.petExpense(pet.id))
        case .moments: routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .basicInfo: routeCoordinator.openSheet(.petBasicInfo(pet.id))
        default: routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func openPetQuickKey(_ key: String, card: FocusCard) {
        guard let pet = pets.first(where: { $0.id == card.id }) else { return }
        switch key {
        case "feed": routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case "water", "waterChange", "filterClean": routeCoordinator.openSheet(.petWater(pet.id))
        case "potty": routeCoordinator.openSheet(.petPotty(pet.id))
        case "litter": routeCoordinator.openSheet(.petLitter(pet.id))
        case "walk": routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case "play": routeCoordinator.openSheet(.petPlay(pet.id))
        case "health": routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case "weight": routeCoordinator.openSheet(.petWeight(pet.id))
        case "expense": routeCoordinator.openSheet(.petExpense(pet.id))
        case "moment": routeCoordinator.openSheet(.petMomentHistory(pet.id))
        default: routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func openHumanQuickKey(_ key: String, card: FocusCard) {
        guard let human = humans.first(where: { $0.id == card.id }) else { return }
        switch key {
        case "humanWeight": routeCoordinator.openSheet(.humanWeight(human.id))
        case "humanExpense": routeCoordinator.openSheet(.humanExpense(human.id))
        case "humanMedication": routeCoordinator.openSheet(.humanMedication(human.id))
        case "humanWorkout": routeCoordinator.openSheet(.humanWorkout(human.id))
        case "humanNote": routeCoordinator.openSheet(.humanNote(human.id))
        default: routeCoordinator.openSheet(.humanAllFeatures(human.id))
        }
    }

    func showReward(amount: Int, label: String?, cardId _: UUID?) {
        expandedCoconutRewardAmount = amount
        expandedCoconutRewardLabel = label
        showExpandedCoconutReward = true
    }
}

enum FocusHomeQuickAction {
    case primary
    case secondary
    case tertiary
    case all
}
