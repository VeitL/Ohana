//
//  VerticalSolidHomeView+QuickActions.swift
//  Ohana
//

import SwiftData
import SwiftUI

enum HomeWalkQuickActionPresentationPolicy {
    enum ExistingWalkDisposition: Equatable {
        case embeddedCurrentPet
        case floatingOtherPet
    }

    static func existingWalkDisposition(
        requestedPetID: UUID,
        currentPetID: UUID?,
        phase: WalkPhase
    ) -> ExistingWalkDisposition? {
        guard let currentPetID else { return nil }
        switch phase {
        case .running, .paused:
            return currentPetID == requestedPetID ? .embeddedCurrentPet : .floatingOtherPet
        case .idle, .finished:
            return nil
        }
    }
}

extension VerticalSolidHomeView {
    func openHeaderCoconutDestination() {
        if let card = headerContextCard {
            if card.isHuman, interaction.containsHuman(card.id) {
                routeCoordinator.openCoconutLog(.human(card.id))
                return
            }
            if interaction.pet(id: card.id) != nil {
                routeCoordinator.openCoconutLog(.pet(card.id))
                return
            }
        }
        routeCoordinator.openCoconutLog(nil)
    }

    func openQuickActionItem(_ item: QuickActionItem, card: FocusCard, usesPrimaryAction: Bool) {
        OhanaFeedback.light()
        if card.isHuman {
            guard card.isReal else {
                openCard(card)
                return
            }
            openHumanQuickActionItem(item, humanID: card.id, usesPrimaryAction: usesPrimaryAction)
            return
        }

        guard let pet = interaction.activePet(id: card.id) else {
            openCard(card)
            return
        }
        openPetQuickActionItem(item, pet: pet, usesPrimaryAction: usesPrimaryAction)
    }

    func openQuickActionOption(_ item: QuickActionItem, card: FocusCard, optionId: String) {
        guard !card.isHuman,
              interaction.activePet(id: card.id) != nil else {
            return
        }

        switch item.actionType {
        case "groom":
            performWithActionHuman(actionTitle: item.label) { executorID in
                OhanaFeedback.light()
                let petID = card.id
                enqueueHomeCommand(.quickCare(entityID: petID, action: "groom:\(optionId)")) {
                    commandExecutor.applyGroomCheckIn(
                        raw: optionId,
                        petID: petID,
                        executorId: executorID,
                        showSingleUseNotice: { title, message in
                            routeCoordinator.showSingleUseNotice(title: title, message: message)
                        },
                        feedback: applyQuickActionExecutorFeedback
                    )
                }
            }
        case "potty":
            performWithActionHuman(actionTitle: item.label) { executorID in
                OhanaFeedback.light()
                let petID = card.id
                enqueueHomeCommand(.quickCare(entityID: petID, action: "potty:\(optionId)")) {
                    commandExecutor.applyPottyCheckIn(
                        raw: optionId,
                        petID: petID,
                        executorId: executorID,
                        feedback: applyQuickActionExecutorFeedback
                    )
                }
            }
        case "health":
            performWithActionHuman(actionTitle: item.label) { executorID in
                OhanaFeedback.light()
                let petID = card.id
                enqueueHomeCommand(.quickCare(entityID: petID, action: "health:\(optionId)")) {
                    commandExecutor.applyHealthCheckIn(
                        raw: optionId,
                        petID: petID,
                        executorId: executorID,
                        openHealth: { routeCoordinator.openSheet(.petHealth($0, initialSection: nil)) },
                        feedback: applyQuickActionExecutorFeedback
                    )
                }
            }
        default:
            if let pet = interaction.activePet(id: card.id) {
                openPetQuickActionItem(item, pet: pet, usesPrimaryAction: true)
            }
        }
    }

    func openPetQuickActionItem(
        _ item: QuickActionItem,
        pet: HomePetInteractionSnapshot,
        usesPrimaryAction: Bool
    ) {
        if usesPrimaryAction {
            switch item.actionType {
            case "feed", "walk", "play", "litter", "cageCleaning", "freeFlight", "misting", "substrateChange", "medication":
                performPetQuickAction(item.actionType, petID: pet.id)
            case "water":
                if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                    routeCoordinator.openSheet(.petWater(pet.id))
                } else {
                    performPetQuickAction("water", petID: pet.id)
                }
            case "waterChange", "filterClean":
                routeCoordinator.openSheet(.petWater(pet.id))
            case "weight":
                routeCoordinator.openPetWeightQuick(pet.id)
            case "expense":
                routeCoordinator.openSheet(.petExpenseQuick(pet.id))
            case "moment":
                routeCoordinator.openQuickMoment(pet.id)
            case "health":
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
            case "allFeatures":
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            default:
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
        case .allFeatures:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        case .none:
            routeCoordinator.openSheet(.petAllFeatures(pet.id))
        }
    }

    func performPetQuickAction(_ actionType: String, petID: UUID) {
        if actionType == "walk" {
            startWalkFromQuickAction(petID: petID)
            return
        }
        guard let action = HomePetQuickActionKind(rawValue: actionType) else { return }
        let now = Date()
        guard commandExecutor.quickActionWillImmediatelyWriteFact(
            action: action,
            petID: petID,
            now: now
        ) else {
            performPetQuickAction(actionType, petID: petID, executorID: nil, now: now)
            return
        }
        performWithActionHuman(actionTitle: l.quickActionLabel(for: actionType)) { executorID in
            performPetQuickAction(actionType, petID: petID, executorID: executorID, now: now)
        }
    }

    func performPetQuickAction(
        _ actionType: String,
        petID: UUID,
        executorID: String?,
        now: Date
    ) {
        guard let action = HomePetQuickActionKind(rawValue: actionType) else { return }

        enqueueHomeCommand(.quickCare(entityID: petID, action: actionType)) {
            commandExecutor.performQuickAction(
                HomePetQuickActionRequest(
                    action: action,
                    petID: petID,
                    executorID: executorID,
                    now: now
                ),
                actions: HomePetQuickActionActions(
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
                        message: message
                    ) {
                        enqueueHomeCommand(.quickCare(entityID: petID, action: "\(actionType):confirmed")) {
                            pendingAction()
                        }
                    }
                },
                startWalk: { startWalkFromQuickAction(petID: $0) },
                openWaterManagement: { routeCoordinator.openSheet(.petWater($0)) },
                openMedication: { routeCoordinator.openSheet(.petMedication($0)) },
                feedback: applyQuickActionExecutorFeedback
                )
            )
        }
    }

    func applyQuickActionExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        if feedback.coconutDelta > 0 {
            OhanaFeedback.success()
        }
    }

    func openPlantCareFeature(_ destination: PlantCareFeatureDestination, plant: VerticalSolidHomePlantSnapshot) {
        guard isPlantCareUnlockedForHome else {
            AppFeatureRouteGuard.recordIntercept("plantGate:homePlantCareFeature")
            return
        }
        openFunctionMenu(destination: .plantCare(plant.id, destination))
    }

    func openPlantFeature(_ destination: PlantFeatureDestination, plant: VerticalSolidHomePlantSnapshot) {
        guard isPlantCareUnlockedForHome else {
            AppFeatureRouteGuard.recordIntercept("plantGate:homePlantFeature")
            return
        }
        openFunctionMenu(destination: .plantFeature(plant.id, destination))
    }

    func recordPlantQuickCare(_ type: PlantCareType, plantID: UUID) {
        let key = PlantQuickCareFeedbackKey.key(plantID: plantID, careType: type)
        guard !pendingPlantQuickCareKeys.contains(key) else { return }
        performWithActionHuman(actionTitle: type.displayName(l: l)) { executorID in
            performPlantQuickCare(type, plantID: plantID, executorID: executorID)
        }
    }

    private func performPlantQuickCare(_ type: PlantCareType, plantID: UUID, executorID: String?) {
        let key = PlantQuickCareFeedbackKey.key(plantID: plantID, careType: type)
        guard !pendingPlantQuickCareKeys.contains(key) else { return }

        OhanaFeedback.light()
        setPlantQuickCarePending(key)
        enqueueHomeCommand(.plantCare(plantID: plantID, action: type.rawValue)) {
            guard let result = commandExecutor.recordPlantCare(
                type,
                plantID: plantID,
                executorId: executorID
            ) else {
                setPlantQuickCareFailed(key)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            guard result.didPersist else {
                setPlantQuickCareFailed(key)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            setPlantQuickCareCompleted(key)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            applyPlantQuickCareRewardFeedback(result)
            applyTodayFocusMutationFeedback(entityId: plantID)
        }
    }

    func setPlantQuickCarePending(_ key: String) {
        plantQuickCareFeedbackClearTasks[key]?.cancel()
        plantQuickCareFeedbackClearTasks[key] = nil
        withAnimation(GoMotion.feedback) {
            pendingPlantQuickCareKeys.insert(key)
            completedPlantQuickCareKeys.remove(key)
            failedPlantQuickCareKeys.remove(key)
        }
    }

    func setPlantQuickCareCompleted(_ key: String) {
        withAnimation(GoMotion.feedback) {
            pendingPlantQuickCareKeys.remove(key)
            failedPlantQuickCareKeys.remove(key)
            completedPlantQuickCareKeys.insert(key)
        }
        schedulePlantQuickCareFeedbackClear(key)
    }

    func setPlantQuickCareFailed(_ key: String) {
        withAnimation(GoMotion.feedback) {
            pendingPlantQuickCareKeys.remove(key)
            completedPlantQuickCareKeys.remove(key)
            failedPlantQuickCareKeys.insert(key)
        }
        schedulePlantQuickCareFeedbackClear(key)
    }

    func schedulePlantQuickCareFeedbackClear(_ key: String) {
        plantQuickCareFeedbackClearTasks[key]?.cancel()
        plantQuickCareFeedbackClearTasks[key] = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1800) {
            withAnimation(GoMotion.selection) {
                completedPlantQuickCareKeys.remove(key)
                failedPlantQuickCareKeys.remove(key)
            }
            plantQuickCareFeedbackClearTasks[key] = nil
        }
    }

    func applyPlantQuickCareRewardFeedback(_ result: PlantCareCommandResult) {
        if result.coconutDelta > 0 {
            OhanaFeedback.success()
        }
    }

    func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    func openHumanQuickActionItem(_ item: QuickActionItem, humanID: UUID, usesPrimaryAction: Bool) {
        let isLocked = interaction.expandedActions(for: humanID).state(for: item).isLocked
        let route = usesPrimaryAction
            ? ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: isLocked)
            : ExpandedQuickActionLogic.humanLongPressRoute(actionType: item.actionType, isLocked: isLocked)

        switch route {
        case .weightQuick:
            routeCoordinator.openHumanWeightQuick(humanID)
        case .weightDetail:
            routeCoordinator.openSheet(.humanWeight(humanID))
        case .workoutQuick:
            routeCoordinator.openSheet(.humanWorkoutQuick(humanID))
        case .workoutDetail:
            routeCoordinator.openSheet(.humanWorkout(humanID))
        case .medicationAdd:
            routeCoordinator.openSheet(.humanMedicationQuick(humanID))
        case .medicationDetail:
            routeCoordinator.openSheet(.humanMedication(humanID))
        case .noteQuick:
            routeCoordinator.openSheet(.humanNoteQuick(humanID))
        case .noteDetail:
            routeCoordinator.openSheet(.humanNote(humanID))
        case .expenseQuick:
            routeCoordinator.openSheet(.humanExpenseQuick(humanID))
        case .expenseDetail:
            routeCoordinator.openSheet(.humanExpense(humanID))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(humanID))
        case .privacyAlert:
            routeCoordinator.showHumanPrivacy()
        case .none:
            break
        }
    }

    func startWalkFromQuickAction(petID: UUID) {
        guard let pet = fetchPetForHomeAction(id: petID), !pet.hasPassedAway else {
            routeCoordinator.openSheet(.petAllFeatures(petID))
            return
        }
        OhanaFeedback.medium()
        if presentExistingWalkFromQuickAction(requestedPetID: pet.id) {
            return
        }
        performWithActionHuman(actionTitle: l.quickActionLabel(for: "walk")) { executorID in
            beginWalkFromQuickAction(petID: petID, executorID: executorID)
        }
    }

    private func beginWalkFromQuickAction(petID: UUID, executorID: String?) {
        guard let pet = fetchPetForHomeAction(id: petID), !pet.hasPassedAway else { return }
        guard !presentExistingWalkFromQuickAction(requestedPetID: pet.id) else { return }
        appServices.walking.start(
            pet: pet,
            modelContext: modelContext,
            executorIds: executorID.map { [$0] } ?? []
        )
        if appServices.walking.currentPet?.id == pet.id {
            appServices.walking.isWalkCardExpandedSurfaceVisible = true
            appServices.publishWalkingPresentationChange()
            walkCardPresentationRevision &+= 1
        }
    }

    func presentExistingWalkFromQuickAction(requestedPetID: UUID) -> Bool {
        guard let disposition = HomeWalkQuickActionPresentationPolicy.existingWalkDisposition(
            requestedPetID: requestedPetID,
            currentPetID: appServices.walking.currentPet?.id,
            phase: appServices.walking.phase
        ) else {
            return false
        }

        switch disposition {
        case .embeddedCurrentPet:
            appServices.walking.isWalkCardExpandedSurfaceVisible = true
        case .floatingOtherPet:
            appServices.walking.isWalkCardExpandedSurfaceVisible = false
        }
        appServices.publishWalkingPresentationChange()
        walkCardPresentationRevision &+= 1
        return true
    }

    func minimizeWalkCardToFloatingControl() {
        appServices.walking.isWalkCardExpandedSurfaceVisible = false
        appServices.publishWalkingPresentationChange()
        walkCardPresentationRevision &+= 1
    }

    func fetchPetForHomeAction(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first // smoothness: allow action-time single-pet fetch after explicit walk quick action tap.
        } catch {
            OhanaLog.warning(
                "Home action pet fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return nil
        }
    }

    func openPetQuickKey(_ key: String, petID: UUID) {
        GrowthNewFeatureStore.markVisited(quickActionType: key)
        switch key {
        case "feed":
            routeCoordinator.openSheet(.petFeed(petID, opensManualSheet: false))
        case "water", "waterChange", "filterClean":
            routeCoordinator.openSheet(.petWater(petID))
        case "potty":
            routeCoordinator.openSheet(.petPotty(petID))
        case "litter":
            routeCoordinator.openSheet(.petLitter(petID))
        case "walk":
            routeCoordinator.openSheet(.petWalkSummary(petID))
        case "play":
            routeCoordinator.openSheet(.petPlay(petID))
        case "health":
            routeCoordinator.openSheet(.petHealth(petID, initialSection: nil))
        case "medication":
            routeCoordinator.openSheet(.petMedication(petID))
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            routeCoordinator.openSheet(.petHygiene(petID))
        case "weight":
            routeCoordinator.openSheet(.petWeight(petID))
        case "expense":
            routeCoordinator.openSheet(.petExpense(petID))
        case "moment":
            routeCoordinator.openQuickMoment(petID)
        default:
            routeCoordinator.openSheet(.petAllFeatures(petID))
        }
    }

    func openCalendarEventDestination(_ destination: FocusHomeReminderDestination) {
        routeCoordinator.dismissModal()
        openCalendarEventDestinationAfterDismiss(destination)
    }

    func openCalendarEventDestinationAfterDismiss(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            openPetReminderQuickKey(key, petID: pet.id)
        case let .petFeature(feature, pet):
            openPetFeature(feature, petID: pet.id)
        case let .petHealth(pet, section):
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, humanID: human.id)
        case let .humanDetail(human):
            routeCoordinator.openSheet(.humanBasicInfo(human.id))
        case let .plant(plant):
            openFunctionMenu(destination: .plantDetail(plant.id))
        case let .plantFeature(plant, destination):
            openFunctionMenu(destination: .plantFeature(plant.id, destination))
        case let .plantCare(plant, destination):
            openFunctionMenu(destination: .plantCare(plant.id, destination))
        case let .functionMenu(destination):
            openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId, plantId):
            routeCoordinator.openCalendar(entityID: entityId, humanID: humanId, plantID: plantId)
        }
    }

    func openCalendarEventDestinationAfterDismiss(_ destination: HomeReminderRouteSnapshot) {
        switch destination {
        case let .petQuick(key, petID):
            openPetReminderQuickKey(key, petID: petID)
        case let .petFeature(feature, petID):
            openPetFeature(feature, petID: petID)
        case let .petHealth(petID, section):
            routeCoordinator.openSheet(.petHealth(petID, initialSection: section))
        case let .humanQuick(key, humanID):
            openHumanQuickKey(key, humanID: humanID)
        case let .humanDetail(humanID):
            routeCoordinator.openSheet(.humanBasicInfo(humanID))
        case let .plant(plantID):
            openFunctionMenu(destination: .plantDetail(plantID))
        case let .plantFeature(plantID, destination):
            openFunctionMenu(destination: .plantFeature(plantID, destination))
        case let .plantCare(plantID, destination):
            openFunctionMenu(destination: .plantCare(plantID, destination))
        case let .functionMenu(destination):
            openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId, plantId):
            routeCoordinator.openCalendar(entityID: entityId, humanID: humanId, plantID: plantId)
        }
    }

    func openPetReminderQuickKey(_ key: String, petID: UUID) {
        if key == "walk" {
            routeCoordinator.openSheet(.petWalkSummary(petID))
        } else {
            openPetQuickKey(key, petID: petID)
        }
    }

    func openPetFeature(_ feature: PetFeature, petID: UUID) {
        GrowthNewFeatureStore.markVisited(feature: feature)
        switch feature {
        case .health:
            routeCoordinator.openSheet(.petHealth(petID, initialSection: nil))
        case .medications:
            routeCoordinator.openSheet(.petMedication(petID))
        case .food:
            routeCoordinator.openSheet(.petFeed(petID, opensManualSheet: false))
        case .hygiene:
            routeCoordinator.openSheet(.petHygiene(petID))
        case .walks:
            routeCoordinator.openSheet(.petWalkSummary(petID))
        case .potty:
            routeCoordinator.openSheet(.petPotty(petID))
        case .basicInfo:
            routeCoordinator.openSheet(.petBasicInfo(petID))
        case .moments:
            routeCoordinator.openSheet(.petMomentHistory(petID))
        case .weight:
            routeCoordinator.openSheet(.petWeight(petID))
        case .expense:
            routeCoordinator.openSheet(.petExpense(petID))
        case .retention, .documents, .achievements:
            routeCoordinator.openSheet(.petAllFeatures(petID))
        }
    }

    func openHumanQuickKey(_ key: String, humanID: UUID) {
        switch key {
        case "humanWeight":
            routeCoordinator.openHumanWeightQuick(humanID)
        case "humanWorkout":
            routeCoordinator.openSheet(.humanWorkoutQuick(humanID))
        case "humanMedication":
            routeCoordinator.openSheet(.humanMedicationQuick(humanID))
        case "humanExpense":
            routeCoordinator.openSheet(.humanExpenseQuick(humanID))
        case "humanNote":
            routeCoordinator.openSheet(.humanNoteQuick(humanID))
        default:
            routeCoordinator.openSheet(.humanAllFeatures(humanID))
        }
    }
}
