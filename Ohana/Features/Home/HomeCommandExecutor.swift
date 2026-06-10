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
struct HomeCommandExecutor {
    let modelContext: ModelContext
    let careEvents: CareEventRecording
    let coconutExchange: CoconutExchangeManaging
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let medicationReminders: MedicationReminderManaging
    let todayFocus: TodayFocusManaging

    init(modelContext: ModelContext) {
        self.init(
            modelContext: modelContext,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager()
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
            todayFocus: StaticTodayFocusManager()
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
            todayFocus: services.todayFocus
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
        self.modelContext = modelContext
        self.careEvents = careEvents
        self.coconutExchange = coconutExchange
        self.revisions = revisions
        self.questManager = questManager
        self.medicationReminders = medicationReminders
        self.todayFocus = todayFocus
    }

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
    ) {
        let flowStartedAt = AppFlowPerformance.start(
            AppPerformanceFlows.quickCareCommand,
            note: ["action": actionType, "entry": "id"]
        )
        guard let pet = fetchPet(id: petID), !pet.hasPassedAway else {
            AppFlowPerformance.mark(
                AppPerformanceFlows.quickCareCommand,
                AppPerformancePhases.noop,
                startedAt: flowStartedAt,
                note: ["action": actionType, "reason": "missing_pet"]
            )
            publishNoop(QuickCareCommand.action(petID: petID, action: actionType), note: "home.quickCare.missingPet")
            return
        }

        let events = fetchQuickCareEvents(petID: petID, now: now)
        let feedLogs = fetchRecentCareLogs(petID: petID, now: now)
        let humans = fetchHumans()
        AppFlowPerformance.mark(
            AppPerformanceFlows.quickCareCommand,
            AppPerformancePhases.dataReady,
            startedAt: flowStartedAt,
            note: [
                "action": actionType,
                "events": "\(events.count)",
                "feedLogs": "\(feedLogs.count)",
                "humans": "\(humans.count)"
            ]
        )

        performActionType(
            actionType,
            pet: pet,
            executorId: executorId,
            allEvents: events,
            allFeedCareLogs: feedLogs,
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
                    feedLogs: feedLogs,
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
            AppPerformancePhases.writeSuccess,
            startedAt: flowStartedAt,
            note: ["action": actionType]
        )
    }

    func scheduleMedicationReminders(for pet: Pet) {
        medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
    }

    func performActionType(
        _ actionType: String,
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
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
    ) {
        let flowStartedAt = recordPerformance
            ? AppFlowPerformance.start(
                AppPerformanceFlows.quickCareCommand,
                note: ["action": actionType, "entry": "snapshot"]
            )
            : nil
        ExpandedQuickActionExecutor.performActionType(
            actionType,
            pet: pet,
            executorId: executorId,
            allEvents: allEvents,
            allFeedCareLogs: allFeedCareLogs,
            humans: humans,
            modelContext: modelContext,
            now: now,
            antiRepeatTitle: antiRepeatTitle,
            antiRepeatMessage: antiRepeatMessage,
            openFeedDetail: openFeedDetail,
            completePlannedFeed: completePlannedFeed,
            showAntiRepeat: showAntiRepeat,
            startWalk: startWalk,
            openWaterManagement: openWaterManagement,
            openMedication: openMedication,
            feedback: feedback,
            careEvents: careEvents,
            questManager: questManager,
            medicationReminders: medicationReminders
        )
        publishMutation(QuickCareCommand.action(petID: pet.id, action: actionType))
        if let flowStartedAt {
            AppFlowPerformance.mark(
                AppPerformanceFlows.quickCareCommand,
                AppPerformancePhases.writeSuccess,
                startedAt: flowStartedAt,
                note: ["action": actionType]
            )
        }
    }

    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)? {
        let reward = careEvents.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: modelContext,
            quality: .precise,
            executorId: executorId,
            date: Date()
        )
        if reward != nil {
            publishMutation(QuickCareCommand.plannedFeed(petID: pet.id, reminderID: reminder.id))
        }
        return reward
    }

    func applyPottyCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        ExpandedQuickActionExecutor.applyPottyCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            feedback: feedback,
            careEvents: careEvents
        )
        publishMutation(QuickCareCommand.potty(petID: pet.id, type: raw))
    }

    func applyPottyCheckIn(
        raw: String,
        petID: UUID,
        executorId: String?,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        guard let pet = fetchPet(id: petID), !pet.hasPassedAway else {
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
        ExpandedQuickActionExecutor.applyGroomCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            showSingleUseNotice: showSingleUseNotice,
            feedback: feedback,
            careEvents: careEvents
        )
        publishMutation(QuickCareCommand.grooming(petID: pet.id, type: raw))
    }

    func applyGroomCheckIn(
        raw: String,
        petID: UUID,
        executorId: String?,
        showSingleUseNotice: (String, String) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        guard let pet = fetchPet(id: petID), !pet.hasPassedAway else {
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
        ExpandedQuickActionExecutor.applyHealthCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            openHealth: openHealth,
            feedback: feedback,
            careEvents: careEvents
        )
        publishMutation(QuickCareCommand.health(petID: pet.id, type: raw))
    }

    func applyHealthCheckIn(
        raw: String,
        petID: UUID,
        executorId: String?,
        openHealth: (UUID) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        guard let pet = fetchPet(id: petID), !pet.hasPassedAway else {
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

    func recordMedicationDose(medication: PetMedication, pet: Pet) {
        PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true,
            questManager: questManager,
            medicationReminders: medicationReminders
        )
        scheduleMedicationReminders(for: pet)
        publishMutation(QuickCareCommand.medicationDose(petID: pet.id, medicationID: medication.id))
    }

    func recordMedicationDose(petID: UUID, medicationID: UUID) {
        guard let pet = fetchPet(id: petID),
              let medication = pet.medications.first(where: { $0.id == medicationID }) else {
            publishNoop(QuickCareCommand.medicationDose(petID: petID, medicationID: medicationID), note: "home.medicationDose.missingTarget")
            return
        }
        recordMedicationDose(medication: medication, pet: pet)
    }

    func completeTodayFocusEvent(_ event: Event, on date: Date = Date()) {
        let result = todayFocus.completeEvent(event, on: date, context: modelContext)
        publishMutation(
            .todayFocus(entityID: result.eventID, action: "eventComplete"),
            affected: [result.eventID],
            note: "home.todayFocusEvent"
        )
    }

    func completeTodayFocusEvent(eventID: UUID, on date: Date = Date()) {
        guard let event = fetchEvent(id: eventID) else {
            publishNoop(
                .todayFocus(entityID: eventID, action: "eventComplete"),
                note: "home.todayFocusEvent.missingEvent"
            )
            return
        }
        completeTodayFocusEvent(event, on: date)
    }

    func recordPlantCare(_ type: PlantCareType, plant: Plant, executorId: String?) {
        PlantCareCommandExecutor(context: modelContext, revisions: revisions).recordCare(
            type,
            plant: plant,
            executorId: executorId,
            note: "home.plantCare"
        )
    }

    func recordPlantCare(_ type: PlantCareType, plantID: UUID, executorId: String?) {
        guard let plant = fetchPlant(id: plantID) else {
            publishNoop(.plantCare(plantID: plantID, action: type.rawValue), note: "home.plantCare.missingPlant")
            return
        }
        recordPlantCare(type, plant: plant, executorId: executorId)
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
        feedLogs: [PetCareLog],
        executorId: String?,
        now: Date,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) -> Bool {
        guard let reminder = ExpandedQuickActionLogic.pendingFeedReminder(
            for: pet,
            allEvents: events,
            allFeedCareLogs: feedLogs,
            now: now
        ) else {
            return false
        }

        let reward = completePlannedFeed(
            pet: pet,
            reminder: reminder,
            executorId: executorId
        )
        guard let reward else { return false }
        let delta = reward.humanGot + reward.petGot
        feedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: pet.id,
                coconutDelta: delta,
                label: delta > 0 ? "喂食 +\(delta)🥥" : nil
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
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchPlant(id: UUID) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchEvent(id: UUID) -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchHuman(id: UUID) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchHumans() -> [Human] {
        (try? modelContext.fetch(FetchDescriptor<Human>())) ?? []
    }

    private func fetchCoconutExchangeRequest(id: UUID) -> CoconutExchangeRequest? {
        var descriptor = FetchDescriptor<CoconutExchangeRequest>(
            predicate: #Predicate<CoconutExchangeRequest> { request in
                request.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchQuickCareEvents(petID: UUID, now: Date) -> [Event] {
        let petKey = petID.uuidString
        let todayStart = Calendar.current.startOfDay(for: now)
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petKey || event.startDate >= todayStart
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        descriptor.fetchLimit = 400
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchRecentCareLogs(petID: UUID, now: Date) -> [PetCareLog] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let since = calendar.date(byAdding: .hour, value: -3, to: todayStart) ?? todayStart
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.date >= since
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 300
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.pet?.id == petID }
    }

    private func publishMutation(
        _ command: DomainCommand,
        affected: Set<UUID>,
        note: String
    ) {
        revisions.publishDomainMutation(
            command: command,
            affectedEntityIDs: affected,
            wroteBusinessFact: true,
            note: note
        )
    }

    private func publishMutation<C: FeatureDomainCommand>(
        _ command: C,
        affected: Set<UUID>,
        note: String
    ) {
        publishMutation(command.domainCommand, affected: affected, note: note)
    }

    private func publishMutation(_ command: QuickCareCommand) {
        publishMutation(
            command.domainCommand,
            affected: command.affectedEntityIDs,
            note: command.revisionNote
        )
    }

    private func publishNoop(_ command: DomainCommand, note: String) {
        revisions.publishDomainMutation(
            command: command,
            affectedEntityIDs: [],
            wroteBusinessFact: false,
            note: note
        )
    }

    private func publishNoop<C: FeatureDomainCommand>(_ command: C, note: String) {
        publishNoop(command.domainCommand, note: note)
    }
}

private enum HomeCommandExecutorError: LocalizedError {
    case missingTarget

    var errorDescription: String? {
        "Missing command target"
    }
}
