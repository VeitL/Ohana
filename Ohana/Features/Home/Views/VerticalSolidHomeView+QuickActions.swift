//
//  VerticalSolidHomeView+QuickActions.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension VerticalSolidHomeView {
    func openHeaderCoconutDestination() {
        if let card = headerContextCard {
            if card.isHuman, humans.contains(where: { $0.id == card.id }) {
                routeCoordinator.openCoconutLog(.human(card.id))
                return
            }
            if pets.contains(where: { $0.id == card.id }) {
                routeCoordinator.openCoconutLog(.pet(card.id))
                return
            }
        }
        if let human = activeHuman {
            routeCoordinator.openCoconutLog(.human(human.id))
        }
    }

    func openQuickActionItem(_ item: QuickActionItem, card: FocusCard, usesPrimaryAction: Bool) {
        OhanaFeedback.light()
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            openHumanQuickActionItem(item, human: human, usesPrimaryAction: usesPrimaryAction)
            return
        }

        guard let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            openCard(card)
            return
        }
        openPetQuickActionItem(item, pet: pet, usesPrimaryAction: usesPrimaryAction)
    }

    func openQuickActionOption(_ item: QuickActionItem, card: FocusCard, optionId: String) {
        guard !card.isHuman,
              let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) else {
            return
        }

        switch item.actionType {
        case "groom":
            OhanaFeedback.light()
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "groom:\(optionId)")) {
                commandExecutor.applyGroomCheckIn(
                    raw: optionId,
                    petID: petID,
                    executorId: currentExecutorId(),
                    showSingleUseNotice: { title, message in
                        routeCoordinator.showSingleUseNotice(title: title, message: message)
                    },
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        case "potty":
            OhanaFeedback.light()
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "potty:\(optionId)")) {
                commandExecutor.applyPottyCheckIn(
                    raw: optionId,
                    petID: petID,
                    executorId: currentExecutorId(),
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        case "health":
            OhanaFeedback.light()
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "health:\(optionId)")) {
                commandExecutor.applyHealthCheckIn(
                    raw: optionId,
                    petID: petID,
                    executorId: currentExecutorId(),
                    openHealth: { routeCoordinator.openSheet(.petHealth($0, initialSection: nil)) },
                    feedback: applyQuickActionExecutorFeedback
                )
            }
        default:
            openPetQuickActionItem(item, pet: pet, usesPrimaryAction: true)
        }
    }

    func openPetQuickActionItem(_ item: QuickActionItem, pet: Pet, usesPrimaryAction: Bool) {
        if usesPrimaryAction {
            switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
            case let .perform(actionType):
                performPetQuickAction(actionType, petID: pet.id)
            case .waterManagement:
                routeCoordinator.openSheet(.petWater(pet.id))
            case .weight:
                routeCoordinator.openSheet(.petWeightQuick(pet.id))
            case .expense:
                routeCoordinator.openSheet(.petExpenseQuick(pet.id))
            case .moment:
                routeCoordinator.openQuickMoment(pet)
            case .health:
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
            case .none:
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            }
            return
        }

        switch ExpandedQuickActionLogic.petLongPressRoute(for: item) {
        case .feedDetail:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .waterManagement:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .walk:
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .playDetail:
            routeCoordinator.openSheet(.petPlay(pet.id))
        case .pottyDetail:
            routeCoordinator.openSheet(.petPotty(pet.id))
        case .hygiene:
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medication:
            routeCoordinator.openSheet(.petMedication(pet.id))
        case .weightDetail:
            routeCoordinator.openSheet(.petWeight(pet.id))
        case .expenseDetail:
            routeCoordinator.openSheet(.petExpense(pet.id))
        case .momentHistory:
            routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .none:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func performPetQuickAction(_ actionType: String, petID: UUID) {
        enqueueHomeCommand(.quickCare(entityID: petID, action: actionType)) {
            commandExecutor.performActionType(
                actionType,
                petID: petID,
                executorId: currentExecutorId(),
                now: Date(),
                antiRepeatTitle: l.tr(zh: "刚刚已经记录过", en: "Already logged", de: "Bereits erfasst"),
                antiRepeatMessage: { warning in
                    l.tr(
                        zh: "\(warning.executorName) \(warning.minutesAgo)分钟前刚记录过，确定再记一次吗？",
                        en: "\(warning.executorName) logged this \(warning.minutesAgo)m ago. Log again?",
                        de: "\(warning.executorName) hat das vor \(warning.minutesAgo) Min. erfasst. Erneut erfassen?"
                    )
                },
                openFeedDetail: { routeCoordinator.openSheet(.petFeed($0, opensManualSheet: $1)) },
                showAntiRepeat: { title, message, pendingAction in
                    routeCoordinator.showAntiRepeat(
                        title: title,
                        message: message,
                        pendingAction: pendingAction
                    )
                },
                startWalk: { routeCoordinator.openFullScreen(.walk($0)) },
                openWaterManagement: { routeCoordinator.openSheet(.petWater($0)) },
                openMedication: { routeCoordinator.openSheet(.petMedication($0)) },
                feedback: applyQuickActionExecutorFeedback
            )
        }
    }

    func applyQuickActionExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        refreshHeaderStreak()
        if feedback.coconutDelta > 0 {
            OhanaFeedback.success()
        }
        tryAwardTodayFocusDailyCompletion(afterCompleting: feedback.cardId)
    }

    func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    func openHumanQuickActionItem(_ item: QuickActionItem, human: Human, usesPrimaryAction: Bool) {
        let viewedBy = UUID(uuidString: activeHumanIdRaw)
        let isLocked = appServices.privacy.isHumanQuickActionLocked(item, human: human, viewedBy: viewedBy)
        let route = usesPrimaryAction
            ? ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: isLocked)
            : ExpandedQuickActionLogic.humanLongPressRoute(actionType: item.actionType, isLocked: isLocked)

        switch route {
        case .weightQuick:
            routeCoordinator.openSheet(.humanWeightQuick(human.id))
        case .weightDetail:
            routeCoordinator.openSheet(.humanWeight(human.id))
        case .workoutQuick:
            routeCoordinator.openSheet(.humanWorkoutQuick(human.id))
        case .workoutDetail:
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case .medicationAdd:
            routeCoordinator.openSheet(.humanMedicationQuick(human.id))
        case .medicationDetail:
            routeCoordinator.openSheet(.humanMedication(human.id))
        case .noteQuick:
            routeCoordinator.openSheet(.humanNoteQuick(human.id))
        case .noteDetail:
            routeCoordinator.openSheet(.humanNote(human.id))
        case .expenseQuick:
            routeCoordinator.openSheet(.humanExpenseQuick(human.id))
        case .expenseDetail:
            routeCoordinator.openSheet(.humanExpense(human.id))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        case .privacyAlert:
            routeCoordinator.showHumanPrivacy()
        case .none:
            break
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
                )
            ]
        }
        return FocusHomeFabShortcutPolicy.petShortcuts(
            for: pet,
            displayedItems: expandedQuickActionItems(for: pet),
            localization: l
        )
    }

    func expandedQuickActionItems(for pet: Pet) -> [QuickActionItem] {
        stableQuickActionItems(
            ExpandedQuickActionStore.petItems(
                raw: quickActionItemsRaw,
                pet: pet,
                localization: l,
                waterLabel: l.homeQAWater,
                managementLabel: waterManagementLabel
            ),
            entityID: pet.id,
            kind: .pet
        )
    }

    func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        stableQuickActionItems(
            ExpandedQuickActionStore.humanItems(
                raw: quickActionItemsRaw,
                human: human,
                localization: l
            ),
            entityID: human.id,
            kind: .human
        )
    }

    func stableQuickActionItems(_ items: [QuickActionItem], entityID: UUID, kind: EntityKind) -> [QuickActionItem] {
        items.map { item in
            var stableItem = item
            stableItem.id = "\(kind.rawValue)-\(entityID.uuidString)-\(item.actionType)"
            return stableItem
        }
    }

    var waterManagementLabel: String {
        l.tr(zh: "管理", en: "Manage", de: "Verwalten")
    }

    func openExpandedFabShortcut(_ shortcut: ExpandedCardFabShortcut, card: FocusCard) {
        closeVerticalFabMenu(immediate: true)
        switch shortcut.action {
        case let .quick(actionType):
            GrowthNewFeatureStore.markVisited(quickActionType: actionType)
        case let .detail(feature):
            GrowthNewFeatureStore.markVisited(feature: feature)
        case .allFeatures, .humanQuick, .humanAllFeatures:
            break
        }
        FocusHomeExpandedFabRouter.open(
            shortcut,
            card: card,
            pets: pets,
            humans: humans,
            activeHumanId: UUID(uuidString: activeHumanIdRaw),
            privacy: appServices.privacy,
            actions: FocusHomeExpandedFabRouter.Actions(
                showPetAllFeatures: { routeCoordinator.openSheet(.petAllFeatures($0.id)) },
                showHumanAllFeatures: { routeCoordinator.openSheet(.humanAllFeatures($0.id)) },
                openFeed: { routeCoordinator.openSheet(.petFeed($0.id, opensManualSheet: false)) },
                openWater: { routeCoordinator.openSheet(.petWater($0.id)) },
                openWalk: { routeCoordinator.openSheet(.petWalkSummary($0.id)) },
                openPotty: { routeCoordinator.openSheet(.petPotty($0.id)) },
                openPlay: { routeCoordinator.openSheet(.petPlay($0.id)) },
                openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) },
                openHygiene: { routeCoordinator.openSheet(.petHygiene($0.id)) },
                openMoment: { routeCoordinator.openQuickMoment($0) },
                openHealth: { routeCoordinator.openSheet(.petHealth($0.id, initialSection: nil)) },
                openWeight: { routeCoordinator.openSheet(.petWeight($0.id)) },
                openExpense: { routeCoordinator.openSheet(.petExpense($0.id)) },
                showHumanWeight: { routeCoordinator.openSheet(.humanWeight($0.id)) },
                showHumanWorkout: { routeCoordinator.openSheet(.humanWorkout($0.id)) },
                showHumanMedication: { routeCoordinator.openSheet(.humanMedication($0.id)) },
                showHumanNote: { routeCoordinator.openSheet(.humanNote($0.id)) },
                quickHumanExpense: { routeCoordinator.openSheet(.humanExpense($0.id)) },
                showPrivacyAlert: { routeCoordinator.showHumanPrivacy() }
            )
        )
    }

    func openPetQuickKey(_ key: String, pet: Pet) {
        GrowthNewFeatureStore.markVisited(quickActionType: key)
        switch key {
        case "feed":
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case "water", "waterChange", "filterClean":
            routeCoordinator.openSheet(.petWater(pet.id))
        case "potty":
            routeCoordinator.openSheet(.petPotty(pet.id))
        case "litter":
            routeCoordinator.openSheet(.petLitter(pet.id))
        case "walk":
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case "play":
            routeCoordinator.openSheet(.petPlay(pet.id))
        case "health":
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case "medication":
            routeCoordinator.openSheet(.petMedication(pet.id))
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case "weight":
            routeCoordinator.openSheet(.petWeight(pet.id))
        case "expense":
            routeCoordinator.openSheet(.petExpense(pet.id))
        case "moment":
            routeCoordinator.openQuickMoment(pet)
        default:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func openCalendarEventDestination(_ destination: FocusHomeReminderDestination) {
        routeCoordinator.dismissModal()
        openCalendarEventDestinationAfterDismiss(destination)
    }

    func openCalendarEventDestinationAfterDismiss(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            openPetQuickKey(key, pet: pet)
        case let .petFeature(feature, pet):
            openPetFeature(feature, pet: pet)
        case let .petHealth(pet, section):
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, human: human)
        case let .humanDetail(human):
            routeCoordinator.openSheet(.humanBasicInfo(human.id))
        case .plant:
            AppFeatureRouteGuard.recordIntercept("homeReminderPlant")
            openFunctionMenu(destination: .growthRoadmap)
        case let .functionMenu(destination):
            openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId):
            routeCoordinator.openCalendar(entityID: entityId, humanID: humanId)
        }
    }

    func openPetFeature(_ feature: PetFeature, pet: Pet) {
        GrowthNewFeatureStore.markVisited(feature: feature)
        switch feature {
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medications:
            routeCoordinator.openSheet(.petMedication(pet.id))
        case .food:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .hygiene:
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case .walks:
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .potty:
            routeCoordinator.openSheet(.petPotty(pet.id))
        case .basicInfo:
            routeCoordinator.openSheet(.petBasicInfo(pet.id))
        case .moments:
            routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .weight:
            routeCoordinator.openSheet(.petWeight(pet.id))
        case .expense:
            routeCoordinator.openSheet(.petExpense(pet.id))
        case .retention, .documents, .achievements:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func openHumanQuickKey(_ key: String, human: Human) {
        switch key {
        case "humanWeight":
            routeCoordinator.openSheet(.humanWeight(human.id))
        case "humanWorkout":
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case "humanMedication":
            routeCoordinator.openSheet(.humanMedication(human.id))
        case "humanExpense":
            routeCoordinator.openSheet(.humanExpense(human.id))
        case "humanNote":
            routeCoordinator.openSheet(.humanNote(human.id))
        default:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        }
    }
}
