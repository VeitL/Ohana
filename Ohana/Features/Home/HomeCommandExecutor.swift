//
//  HomeCommandExecutor.swift
//  Ohana
//
//  Side-effect boundary for home commands that need ModelContext.
//

import Foundation
import SwiftData
import UIKit

@MainActor
private func fetchHomeCommandModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "HomeCommandExecutor failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

@MainActor
struct HomeCommandExecutor {
    let modelContext: ModelContext
    let careEvents: CareEventRecording
    let coconutExchange: CoconutExchangeManaging
    let revisions: DomainRevisionPublishing
    let derivations: CareDerivationExecutor
    let questManager: QuestManager
    let medicationReminders: MedicationReminderManaging
    let todayFocus: TodayFocusManaging
    let plantReminderControls: PlantReminderControlling

    init(modelContext: ModelContext) {
        self.init(
            modelContext: modelContext,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager(),
            plantReminderControls: StaticPlantReminderController()
        )
    }

    init(modelContext: ModelContext, careEvents: CareEventRecording) {
        self.init(
            modelContext: modelContext,
            careEvents: careEvents,
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager(),
            plantReminderControls: StaticPlantReminderController()
        )
    }

    init(modelContext: ModelContext, services: AppServices) {
        self.init(
            modelContext: modelContext,
            careEvents: services.careEvents,
            coconutExchange: services.coconutExchange,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            medicationReminders: services.medicationReminders,
            todayFocus: services.todayFocus,
            plantReminderControls: services.plantReminderControls
        )
    }

    init(
        modelContext: ModelContext,
        careEvents: CareEventRecording,
        coconutExchange: CoconutExchangeManaging,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging,
        todayFocus: TodayFocusManaging
    ) {
        self.init(
            modelContext: modelContext,
            careEvents: careEvents,
            coconutExchange: coconutExchange,
            revisions: revisions,
            questManager: questManager,
            medicationReminders: medicationReminders,
            todayFocus: todayFocus,
            plantReminderControls: StaticPlantReminderController()
        )
    }

    init(
        modelContext: ModelContext,
        careEvents: CareEventRecording,
        coconutExchange: CoconutExchangeManaging,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging,
        todayFocus: TodayFocusManaging,
        plantReminderControls: PlantReminderControlling
    ) {
        self.modelContext = modelContext
        self.careEvents = careEvents
        self.coconutExchange = coconutExchange
        self.revisions = revisions
        self.derivations = CareDerivationExecutor(revisions: revisions)
        self.questManager = questManager
        self.medicationReminders = medicationReminders
        self.todayFocus = todayFocus
        self.plantReminderControls = plantReminderControls
    }

    @discardableResult
    func performActionType(
        _ actionType: String,
        petID: UUID,
        executorId: String?,
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ petID: UUID, _ opensManualSheet: Bool) -> Void,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Void) -> Void,
        startWalk: (UUID) -> Void,
        openWaterManagement: (UUID) -> Void,
        openMedication: (UUID) -> Void,
        feedback: @escaping (ExpandedQuickActionExecutor.Feedback) -> Void
    ) -> Bool {
        let flowStartedAt = AppFlowPerformance.start(
            AppPerformanceFlows.quickCareCommand,
            note: ["action": actionType, "entry": "id"]
        )
        guard let pet = fetchPet(id: petID),
              MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsCareFactWrite else {
            AppFlowPerformance.mark(
                AppPerformanceFlows.quickCareCommand,
                AppPerformancePhases.noop,
                startedAt: flowStartedAt,
                note: ["action": actionType, "reason": "missing_pet"]
            )
            publishNoop(QuickCareCommand.action(petID: petID, action: actionType), note: "home.quickCare.missingPet")
            return false
        }

        let events = fetchQuickCareEvents(pet: pet, now: now)
        let foodRecords = fetchFoodRecords(petID: petID)
        let humans = fetchHumans()
        AppFlowPerformance.mark(
            AppPerformanceFlows.quickCareCommand,
            AppPerformancePhases.dataReady,
            startedAt: flowStartedAt,
            note: [
                "action": actionType,
                "events": "\(events.count)",
                "foodRecords": "\(foodRecords.count)",
                "humans": "\(humans.count)"
            ]
        )

        let didRecord = performActionType(
            actionType,
            pet: pet,
            executorId: executorId,
            allEvents: events,
            allFoodRecords: foodRecords,
            humans: humans,
            now: now,
            antiRepeatTitle: antiRepeatTitle,
            antiRepeatMessage: antiRepeatMessage,
            openFeedDetail: { opensManualSheet in
                openFeedDetail(petID, opensManualSheet)
            },
            completePlannedFeed: { plannedPet in
                completePlannedFeedFromFetchedState(
                    pet: plannedPet,
                    events: events,
                    foodRecords: foodRecords,
                    executorId: executorId,
                    now: now,
                    feedback: feedback
                )
            },
            showAntiRepeat: showAntiRepeat,
            startWalk: { startWalk($0.id) },
            openWaterManagement: { openWaterManagement($0.id) },
            openMedication: { openMedication($0.id) },
            feedback: feedback,
            recordPerformance: false
        )
        AppFlowPerformance.mark(
            AppPerformanceFlows.quickCareCommand,
            didRecord ? AppPerformancePhases.writeSuccess : AppPerformancePhases.noop,
            startedAt: flowStartedAt,
            note: ["action": actionType]
        )
        return didRecord
    }

    func scheduleMedicationReminders(for pet: Pet) {
        medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
    }

    @discardableResult
    func performActionType(
        _ actionType: String,
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFoodRecords: [PetFoodRecord],
        humans: [Human],
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ opensManualSheet: Bool) -> Void,
        completePlannedFeed: @escaping (Pet) -> Bool,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Void) -> Void,
        startWalk: (Pet) -> Void,
        openWaterManagement: (Pet) -> Void,
        openMedication: (Pet) -> Void,
        feedback: @escaping (ExpandedQuickActionExecutor.Feedback) -> Void,
        recordPerformance: Bool = true
    ) -> Bool {
        let flowStartedAt = recordPerformance
            ? AppFlowPerformance.start(
                AppPerformanceFlows.quickCareCommand,
                note: ["action": actionType, "entry": "snapshot"]
            )
            : nil
        let didRecord = ExpandedQuickActionExecutor.performActionType(
            actionType,
            pet: pet,
            executorId: executorId,
            allEvents: allEvents,
            allFoodRecords: allFoodRecords,
            humans: humans,
            modelContext: modelContext,
            now: now,
            antiRepeatTitle: antiRepeatTitle,
            antiRepeatMessage: antiRepeatMessage,
            openFeedDetail: openFeedDetail,
            completePlannedFeed: completePlannedFeed,
            showAntiRepeat: { title, message, pendingAction in
                showAntiRepeat(title, message) {
                    let confirmedDidRecord = pendingAction()
                    guard confirmedDidRecord,
                          shouldPublishConfirmedAntiRepeatMutation(
                              actionType: actionType,
                              pet: pet,
                              allEvents: allEvents,
                              now: now
                          )
                    else { return }
                    publishMutation(QuickCareCommand.action(petID: pet.id, action: actionType), pet: pet)
                }
            },
            startWalk: startWalk,
            openWaterManagement: openWaterManagement,
            openMedication: openMedication,
            feedback: feedback,
            careEvents: careEvents,
            questManager: questManager,
            medicationReminders: medicationReminders
        )
        guard didRecord else {
            publishNoop(QuickCareCommand.action(petID: pet.id, action: actionType), note: "home.quickCare.factNoop")
            if let flowStartedAt {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.quickCareCommand,
                    AppPerformancePhases.noop,
                    startedAt: flowStartedAt,
                    note: ["action": actionType]
                )
            }
            return false
        }
        publishMutation(QuickCareCommand.action(petID: pet.id, action: actionType), pet: pet)
        if let flowStartedAt {
            AppFlowPerformance.mark(
                AppPerformanceFlows.quickCareCommand,
                AppPerformancePhases.writeSuccess,
                startedAt: flowStartedAt,
                note: ["action": actionType]
            )
        }
        return true
    }

    private func shouldPublishConfirmedAntiRepeatMutation(
        actionType: String,
        pet: Pet,
        allEvents: [Event],
        now: Date
    ) -> Bool {
        guard actionType == "feed" else { return true }
        return ExpandedQuickActionLogic.feedDashboard(
            for: pet,
            allEvents: allEvents,
            now: now
        ).operatingMode == .manual
    }

    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        allEvents: [Event],
        foodRecords: [PetFoodRecord],
        executorId: String?,
        now: Date
    ) -> ManualFeedCommandResult {
        let result = ManualFeedCommand.completePlanned(
            pet: pet,
            reminder: reminder,
            foodRecords: foodRecords,
            allEvents: allEvents,
            context: modelContext,
            executorId: executorId,
            careEvents: careEvents,
            date: now
        )
        if result.didPersist && result.didRecord && result.allowsDerivedEffects {
            publishMutation(QuickCareCommand.plannedFeed(petID: pet.id, reminderID: reminder.id), pet: pet)
        }
        return result
    }

    func applyPottyCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        let didRecord = ExpandedQuickActionExecutor.applyPottyCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            feedback: feedback,
            careEvents: careEvents
        )
        if didRecord {
            publishMutation(QuickCareCommand.potty(petID: pet.id, type: raw), pet: pet)
        }
    }

    func applyPottyCheckIn(
        raw: String,
        petID: UUID,
        executorId: String?,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        guard let pet = fetchPet(id: petID),
              MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsCareFactWrite else {
            publishNoop(QuickCareCommand.potty(petID: petID, type: raw), note: "home.potty.missingPet")
            return
        }
        applyPottyCheckIn(raw: raw, pet: pet, executorId: executorId, feedback: feedback)
    }

    func applyGroomCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        showSingleUseNotice: (String, String) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        let didRecord = ExpandedQuickActionExecutor.applyGroomCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            showSingleUseNotice: showSingleUseNotice,
            feedback: feedback,
            careEvents: careEvents
        )
        if didRecord {
            publishMutation(QuickCareCommand.grooming(petID: pet.id, type: raw), pet: pet)
        }
    }

    func applyGroomCheckIn(
        raw: String,
        petID: UUID,
        executorId: String?,
        showSingleUseNotice: (String, String) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        guard let pet = fetchPet(id: petID),
              MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsCareFactWrite else {
            publishNoop(QuickCareCommand.grooming(petID: petID, type: raw), note: "home.groom.missingPet")
            return
        }
        applyGroomCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            showSingleUseNotice: showSingleUseNotice,
            feedback: feedback
        )
    }

    func applyHealthCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        openHealth: (Pet) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        let didRecord = ExpandedQuickActionExecutor.applyHealthCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            openHealth: openHealth,
            feedback: feedback,
            careEvents: careEvents
        )
        if didRecord {
            publishMutation(QuickCareCommand.health(petID: pet.id, type: raw), pet: pet)
        }
    }

    func applyHealthCheckIn(
        raw: String,
        petID: UUID,
        executorId: String?,
        openHealth: (UUID) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        guard let pet = fetchPet(id: petID),
              MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsCareFactWrite else {
            publishNoop(QuickCareCommand.health(petID: petID, type: raw), note: "home.health.missingPet")
            return
        }
        applyHealthCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            openHealth: { openHealth($0.id) },
            feedback: feedback
        )
    }

    @discardableResult
    func recordMedicationDose(medication: PetMedication, pet: Pet) -> Bool {
        let result = PetMedicationDoseLogging.recordDoseResult(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            medicationReminders: medicationReminders
        )
        guard result.didPersist, result.didRecord, result.allowsDerivedEffects else {
            publishNoop(QuickCareCommand.medicationDose(petID: pet.id, medicationID: medication.id), note: "home.medicationDose.noop")
            return false
        }
        scheduleMedicationReminders(for: pet)
        publishMutation(QuickCareCommand.medicationDose(petID: pet.id, medicationID: medication.id), pet: pet)
        return true
    }

    @discardableResult
    func recordMedicationDose(petID: UUID, medicationID: UUID) -> Bool {
        guard let pet = fetchPet(id: petID),
              let medication = pet.medications.first(where: { $0.id == medicationID }) else {
            publishNoop(QuickCareCommand.medicationDose(petID: petID, medicationID: medicationID), note: "home.medicationDose.missingTarget")
            return false
        }
        return recordMedicationDose(medication: medication, pet: pet)
    }

    @discardableResult
    func completeTodayFocusEvent(_ event: Event, on date: Date = Date(), executorId: String? = nil) -> Bool {
        let result = todayFocus.completeEvent(event, on: date, context: modelContext, executorId: resolvedExecutorId(executorId))
        guard result.didChange, result.allowsDerivedEffects else {
            publishNoop(
                .todayFocus(entityID: result.eventID, action: "eventComplete"),
                note: "home.todayFocusEvent.noop"
            )
            return false
        }
        publishMutation(
            .todayFocus(entityID: result.eventID, action: "eventComplete"),
            event: event,
            note: "home.todayFocusEvent"
        )
        return true
    }

    @discardableResult
    func completeTodayFocusEvent(eventID: UUID, on date: Date = Date(), executorId: String? = nil) -> Bool {
        guard let event = fetchEvent(id: eventID) else {
            publishNoop(
                .todayFocus(entityID: eventID, action: "eventComplete"),
                note: "home.todayFocusEvent.missingEvent"
            )
            return false
        }
        return completeTodayFocusEvent(event, on: date, executorId: executorId)
    }

    private func resolvedExecutorId(_ explicit: String?) -> String? {
        if let explicit, !explicit.isEmpty {
            return explicit
        }
        let stored = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        return stored.isEmpty ? nil : stored
    }

    @discardableResult
    func recordPlantCare(
        _ type: PlantCareType,
        plant: Plant,
        executorId: String?,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) -> PlantCareCommandResult {
        PlantCareCommandExecutor(context: modelContext, revisions: revisions).recordCare(
            type,
            plant: plant,
            executorId: executorId,
            note: "home.plantCare",
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus
        )
    }

    @discardableResult
    func recordPlantCare(
        _ type: PlantCareType,
        plantID: UUID,
        executorId: String?,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) -> PlantCareCommandResult? {
        guard let plant = fetchPlant(id: plantID) else {
            publishNoop(.plantCare(plantID: plantID, action: type.rawValue), note: "home.plantCare.missingPlant")
            return nil
        }
        return recordPlantCare(type, plant: plant, executorId: executorId, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
    }

    @discardableResult
    func recordPlantCare(
        _ type: PlantCareType,
        plantIDs: [UUID],
        executorId: String?,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) -> [UUID] {
        var recordedIDs: [UUID] = []
        for plantID in plantIDs {
            guard let plant = fetchPlant(id: plantID) else {
                publishNoop(.plantCare(plantID: plantID, action: type.rawValue), note: "home.plantCare.missingPlant")
                continue
            }
            let result = recordPlantCare(type, plant: plant, executorId: executorId, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
            if result.didPersist {
                recordedIDs.append(plantID)
            }
        }
        return recordedIDs
    }

    @discardableResult
    func completePlantBatchCare(
        selections: [PlantBatchCareSelection],
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantBatchCareCommandResult {
        PlantCareCommandExecutor(context: modelContext, revisions: revisions).completeBatchCare(
            selections: selections,
            executorId: resolvedExecutorId(executorId),
            note: "home.plantCare.batchCare",
            now: now,
            calendar: calendar
        )
    }

    @discardableResult
    func recordPlantBatchQuickCare(
        selections: [PlantBatchCareSelection],
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantBatchCareCommandResult {
        PlantCareCommandExecutor(context: modelContext, revisions: revisions).recordBatchQuickCare(
            selections: selections,
            executorId: resolvedExecutorId(executorId),
            note: "home.plantCare.batchQuickRecord",
            now: now,
            calendar: calendar
        )
    }

    @discardableResult
    func undoPlantBatchCare(
        _ token: PlantBatchCareUndoToken,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantBatchCareUndoResult {
        PlantCareCommandExecutor(context: modelContext, revisions: revisions).undoBatchCare(
            token,
            note: "home.plantCare.batchCareUndo",
            now: now,
            calendar: calendar
        )
    }

    @discardableResult
    func commitPlantBatchCareRewards(
        for token: PlantBatchCareUndoToken,
        now: Date = Date()
    ) -> PlantBatchCareRewardCommitResult {
        PlantCareCommandExecutor(context: modelContext, revisions: revisions).commitBatchCareRewards(
            for: token,
            note: "home.plantCare.batchCareRewardCommit",
            now: now
        )
    }

    @discardableResult
    func deferPlantDueTasksOneDay(
        plants: [Plant],
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantReminderBulkDeferResult {
        let command = DomainCommand.command(
            "plants",
            "deferDueTasksOneDay",
            ["plantCount": String(plants.count)]
        )
        let result = plantReminderControls.deferDueTasksOneDay(
            plants: plants,
            context: modelContext,
            executorId: resolvedExecutorId(executorId),
            now: now,
            calendar: calendar,
            scheduleNotifications: true,
            notifications: ReminderNotificationSchedulerRegistry.current,
            defaults: .standard
        )
        revisions.publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: Set(plants.map(\.id)),
                wroteBusinessFact: result.didPersist && result.deferredTaskCount > 0,
                note: "home.plantCare.deferDueTasks"
            )
        )
        return result
    }

    func confirmCoconutExchange(_ request: CoconutExchangeRequest, receiver: Human) throws {
        do {
            try coconutExchange.confirm(request, by: receiver, context: modelContext)
            publishMutation(
                EconomyCommand.coconutExchange(requestID: request.id),
                affected: [request.id, receiver.id],
                note: "home.coconutExchange"
            )
        } catch {
            revisions.publishFailure(
                command: EconomyCommand.coconutExchange(requestID: request.id).domainCommand,
                error: error
            )
            throw error
        }
    }

    func confirmCoconutExchange(requestID: UUID, receiverID: UUID) throws {
        guard let request = fetchCoconutExchangeRequest(id: requestID),
              let receiver = fetchHuman(id: receiverID) else {
            let command = EconomyCommand.coconutExchange(requestID: requestID).domainCommand
            revisions.publishFailure(
                command: command,
                error: HomeCommandExecutorError.missingTarget
            )
            throw HomeCommandExecutorError.missingTarget
        }
        try confirmCoconutExchange(request, receiver: receiver)
    }

    private func completePlannedFeedFromFetchedState(
        pet: Pet,
        events: [Event],
        foodRecords: [PetFoodRecord],
        executorId: String?,
        now: Date,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) -> Bool {
        guard let reminder = ExpandedQuickActionLogic.pendingFeedReminder(
            for: pet,
            allEvents: events,
            now: now
        ) else {
            return false
        }

        let result = completePlannedFeed(
            pet: pet,
            reminder: reminder,
            allEvents: events,
            foodRecords: foodRecords,
            executorId: executorId,
            now: now
        )
        guard result.didRecord, result.allowsDerivedEffects else { return false }
        let delta = result.coconutDelta
        feedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: pet.id,
                coconutDelta: delta,
                label: ExpandedQuickActionExecutor.rewardLabel(actionType: "feed", delta: delta)
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func fetchPet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchHomeCommandModelsOrLog(
            descriptor,
            context: modelContext,
            operation: "fetch pet"
        ).first
    }

    private func fetchPlant(id: UUID) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchHomeCommandModelsOrLog(
            descriptor,
            context: modelContext,
            operation: "fetch plant"
        ).first
    }

    private func fetchEvent(id: UUID) -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchHomeCommandModelsOrLog(
            descriptor,
            context: modelContext,
            operation: "fetch event"
        ).first
    }

    private func fetchHuman(id: UUID) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchHomeCommandModelsOrLog(
            descriptor,
            context: modelContext,
            operation: "fetch human"
        ).first
    }

    private func fetchHumans() -> [Human] {
        fetchHomeCommandModelsOrLog(
            FetchDescriptor<Human>(),
            context: modelContext,
            operation: "fetch humans"
        )
    }

    private func fetchCoconutExchangeRequest(id: UUID) -> CoconutExchangeRequest? {
        var descriptor = FetchDescriptor<CoconutExchangeRequest>(
            predicate: #Predicate<CoconutExchangeRequest> { request in
                request.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchHomeCommandModelsOrLog(
            descriptor,
            context: modelContext,
            operation: "fetch coconut exchange request"
        ).first
    }

    private func fetchQuickCareEvents(pet: Pet, now: Date) -> [Event] {
        let petIDRaw = pet.id.uuidString
        let petEvents = fetchHomeCommandModelsOrLog(
            FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.relatedEntityId == petIDRaw
                },
                sortBy: [SortDescriptor(\.startDate, order: .forward)]
            ),
            context: modelContext,
            operation: "fetch quick care pet events"
        )

        let medicationDoseEvents = fetchTodayMedicationDoseEvents(pet: pet, now: now)
        let uniqueEvents = Dictionary(
            grouping: petEvents + medicationDoseEvents,
            by: \.id
        ).compactMap(\.value.first)
        return uniqueEvents.sorted { $0.startDate < $1.startDate }
    }

    private func fetchTodayMedicationDoseEvents(pet: Pet, now: Date) -> [Event] {
        let medicationIDs = Set(pet.medications.map(\.id.uuidString))
        guard !medicationIDs.isEmpty else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let medicationDoseType = EventType.petMedicationDose.rawValue
        let doseEvents = fetchHomeCommandModelsOrLog(
            FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.eventType == medicationDoseType &&
                        event.startDate >= start &&
                        event.startDate < end
                },
                sortBy: [SortDescriptor(\.startDate, order: .forward)]
            ),
            context: modelContext,
            operation: "fetch quick care medication dose events"
        )
        return doseEvents.filter { medicationIDs.contains($0.relatedEntityId) }
    }

    private func fetchFoodRecords(petID: UUID) -> [PetFoodRecord] {
        var descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { record in
                record.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 120
        return fetchHomeCommandModelsOrLog(
            descriptor,
            context: modelContext,
            operation: "fetch food records"
        )
    }

    private func publishMutation(
        _ command: DomainCommand,
        affected: Set<UUID>,
        note: String
    ) {
        revisions.publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    private func publishMutation(
        _ command: DomainCommand,
        event: Event,
        note: String
    ) {
        let request = DomainSubjectResolutionRequest(event: event)
        let resolution = DomainSubjectResolver.resolve(request: request, context: modelContext)
        guard resolution.role.isMemberScoped else {
            publishMutation(command, affected: resolution.affectedEntityIDs, note: note)
            return
        }
        guard let effectPlan = DomainEffectWriteAuthorizer.authorizeSubjectEffect(
            subjectRequest: request,
            writeKind: .care,
            context: modelContext,
            logPrefix: "HomeCommandExecutor.eventMutation"
        ) else {
            publishNoop(command, note: "\(note).unauthorized")
            return
        }
        derivations.derive(
            .derivedMutation(
                command: command,
                effectPlan: effectPlan,
                note: note
            )
        )
    }

    private func publishMutation(
        _ command: some FeatureDomainCommand,
        affected: Set<UUID>,
        note: String
    ) {
        publishMutation(command.domainCommand, affected: affected, note: note)
    }

    private func publishMutation(_ command: QuickCareCommand, pet: Pet) {
        guard let effectPlan = DomainEffectWriteAuthorizer.authorizePetEffect(
            pet: pet,
            writeKind: .care,
            context: modelContext,
            logPrefix: "HomeCommandExecutor.quickCareMutation"
        ) else {
            publishNoop(command.domainCommand, note: "\(command.revisionNote).unauthorized")
            return
        }
        derivations.derive(
            .derivedMutation(
                command: command.domainCommand,
                effectPlan: effectPlan,
                note: command.revisionNote
            )
        )
    }

    private func publishNoop(_ command: DomainCommand, note: String) {
        derivations.derive(
            .noOp(
                command: command,
                affectedEntityIDs: [],
                note: note
            )
        )
    }

    private func publishNoop(_ command: some FeatureDomainCommand, note: String) {
        publishNoop(command.domainCommand, note: note)
    }
}

private enum HomeCommandExecutorError: LocalizedError {
    case missingTarget

    var errorDescription: String? {
        "Missing command target"
    }
}
