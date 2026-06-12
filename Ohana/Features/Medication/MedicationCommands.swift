//
//  MedicationCommands.swift
//  Ohana
//
//  Domain write boundaries for human and pet medication plans and doses.
//

import Foundation
import SwiftData

@MainActor
private func fetchMedicationCommandModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "MedicationCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

struct HumanMedicationCommandResult: Equatable {
    let medicationID: UUID
    let subjectID: UUID
    let scheduledReminderSync: Bool
}

struct HumanMedicationPlanCommandInput: Equatable {
    let name: String
    let dosage: String
    let frequency: MedicationFrequency
    let customFrequencyNote: String
    let doseMinutes: [Int]
    let weeklyWeekday: Int
    let startDate: Date
    let endDate: Date?
    let colorHex: String
    let visibleNotes: String
    let isActive: Bool
    let appLanguage: String

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanDosage: String {
        dosage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanCustomFrequencyNote: String {
        frequency == .custom ? customFrequencyNote.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    var normalizedDoseMinutes: [Int] {
        guard !frequency.isManualEntry else { return [] }
        let source = doseMinutes.isEmpty ? HumanMedicationSchedulePlan.defaultDoseMinutes(for: frequency) : doseMinutes
        return HumanMedicationScheduleMetadata.normalizedDoseMinutes(source)
    }

    var scheduleMetadata: HumanMedicationScheduleMetadata? {
        guard !frequency.isManualEntry else { return nil }
        return HumanMedicationScheduleMetadata(
            doseMinutes: normalizedDoseMinutes,
            weeklyWeekday: frequency == .weekly ? weeklyWeekday : nil
        )
    }

    var savedNotes: String {
        HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: visibleNotes,
            metadata: scheduleMetadata
        )
    }

    func firstDoseTime(calendar: Calendar = .current) -> Date {
        let firstMinute = normalizedDoseMinutes.first ?? 8 * 60
        return HumanMedicationSchedulePlan.date(on: Date(), minuteOfDay: firstMinute, calendar: calendar) ?? Date()
    }
}

struct HumanMedicationPlanCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let created: Bool
    let calendarEventIDs: [UUID]
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct HumanMedicationPlanDeleteCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct HumanMedicationPlanActivationCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let isActive: Bool
    let didChange: Bool
    let calendarEventIDs: [UUID]
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct HumanMedicationDoseCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let logID: UUID?
    let status: HumanMedicationStatus
    let didChange: Bool
    let recordedLedgerEvent: Bool
}

struct PetMedicationDoseCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let eventID: UUID
    let coconutDelta: Int
}

enum HumanMedicationCommandService {
    @discardableResult
    @MainActor
    static func createMedication(
        human: Human,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        firstDoseTime: Date,
        startDate: Date,
        colorHex: String,
        notes: String,
        context: ModelContext,
        reminderEnabled: Bool,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> HumanMedicationCommandResult? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: cleanName,
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            firstDoseTime: firstDoseTime,
            startDate: startDate,
            colorHex: colorHex,
            notes: notes
        )
        medication.isActive = true
        context.insert(medication)
        context.safeSave()

        if reminderEnabled {
            let meds = fetchHumanMedications(humanID: human.id.uuidString, context: context)
            let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
            medicationReminders.scheduleHumanMedicationReminders(
                for: human,
                meds: meds,
                context: context
            )
        }

        return HumanMedicationCommandResult(
            medicationID: medication.id,
            subjectID: human.id,
            scheduledReminderSync: reminderEnabled
        )
    }

    @MainActor
    private static func fetchHumanMedications(humanID: String, context: ModelContext) -> [HumanMedication] {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanID
            },
            sortBy: [SortDescriptor(\HumanMedication.createdAt)]
        )
        return fetchMedicationCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch quick human medications for reminder sync"
        )
    }
}

struct PetMedicationPlanCommandInput: Equatable {
    let name: String
    let dosage: String
    let frequency: PetMedicationFrequency
    let doseMinutes: [Int]
    let startDate: Date
    let endDate: Date?
    let colorHex: String
    let notes: String
    let isActive: Bool
    let remainingAmount: Double?

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanDosage: String {
        dosage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedDoseMinutes: [Int] {
        PetMedicationSchedulePlan.normalizedDoseMinutes(
            doseMinutes,
            count: PetMedicationSchedulePlan.dosesPerDay(for: frequency),
            frequency: frequency
        )
    }

    var savedCustomFrequencyNote: String {
        PetMedicationSchedulePlan.encodeDoseMinutes(normalizedDoseMinutes)
    }

    var cleanNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PetMedicationPlanCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let created: Bool
    let calendarEventIDs: [UUID]
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct PetMedicationPlanDeleteCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct PetMedicationPlanActivationCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let isActive: Bool
    let didChange: Bool
    let calendarEventIDs: [UUID]
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

enum PetMedicationPlanStorageKeys {
    static func remainingAmount(medicationID: UUID) -> String {
        "medication_remaining_\(medicationID.uuidString)"
    }

    static func remainingAmountValue(medicationID: UUID, defaults: UserDefaults = .standard) -> Double {
        defaults.double(forKey: remainingAmount(medicationID: medicationID))
    }

    static func remainingAmountValue(medication: PetMedication, defaults: UserDefaults = .standard) -> Double {
        medication.remainingAmount > 0
            ? medication.remainingAmount
            : remainingAmountValue(medicationID: medication.id, defaults: defaults)
    }

    static func decrementRemainingAmount(medicationID: UUID, by amount: Double = 1, defaults: UserDefaults = .standard) {
        let current = remainingAmountValue(medicationID: medicationID, defaults: defaults)
        guard current > 0, amount > 0 else { return }
        defaults.set(max(0, current - amount), forKey: remainingAmount(medicationID: medicationID))
    }

    static func decrementRemainingAmount(medication: PetMedication, by amount: Double = 1, defaults: UserDefaults = .standard) {
        guard amount > 0 else { return }
        let current = remainingAmountValue(medication: medication, defaults: defaults)
        guard current > 0 else { return }
        let next = max(0, current - amount)
        medication.remainingAmount = next
        defaults.set(next, forKey: remainingAmount(medicationID: medication.id))
    }
}

enum PetMedicationPlanCommandService {
    @discardableResult
    @MainActor
    static func savePlan(
        pet: Pet,
        editing existingMedication: PetMedication?,
        input: PetMedicationPlanCommandInput,
        context: ModelContext,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> PetMedicationPlanCommandResult? {
        guard !input.cleanName.isEmpty else { return nil }

        let medication: PetMedication
        let created: Bool
        if let existing = existingMedication {
            medication = existing
            created = false
        } else {
            medication = PetMedication(
                name: input.cleanName,
                dosage: input.cleanDosage,
                frequency: input.frequency,
                startDate: input.startDate,
                endDate: input.endDate,
                colorHex: input.colorHex,
                notes: input.cleanNotes,
                pet: pet
            )
            context.insert(medication)
            created = true
        }

        apply(input, to: medication, pet: pet)
        let calendarSync = syncCalendarEvents(
            for: medication,
            pet: pet,
            context: context
        )
        syncRemainingAmount(input.remainingAmount, medication: medication, userDefaults: userDefaults)
        context.safeSave()

        if scheduleReminders {
            let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
            medicationReminders.scheduleMedicationReminders(for: pet, context: context)
        }

        return PetMedicationPlanCommandResult(
            subjectID: pet.id,
            medicationID: medication.id,
            created: created,
            calendarEventIDs: calendarSync.createdEventIDs,
            removedCalendarEventIDs: calendarSync.removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func deletePlan(
        pet: Pet,
        medication: PetMedication,
        context: ModelContext,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> PetMedicationPlanDeleteCommandResult {
        let medicationID = medication.id
        let removedEventIDs = removeCalendarEvents(for: medicationID, context: context)
        CloudSyncMutationRecorder.markDeleted(medication, pet: pet, context: context)
        context.delete(medication)
        context.safeSave()
        userDefaults.removeObject(forKey: PetMedicationPlanStorageKeys.remainingAmount(medicationID: medicationID))

        if scheduleReminders {
            let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
            medicationReminders.scheduleMedicationReminders(for: pet, context: context)
        }

        return PetMedicationPlanDeleteCommandResult(
            subjectID: pet.id,
            medicationID: medicationID,
            removedCalendarEventIDs: removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func setPlanActive(
        pet: Pet,
        medication: PetMedication,
        isActive: Bool,
        context: ModelContext,
        scheduleReminders: Bool = true,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> PetMedicationPlanActivationCommandResult {
        let didChange = medication.isActive != isActive
        medication.isActive = isActive
        let calendarSync = syncCalendarEvents(
            for: medication,
            pet: pet,
            context: context
        )
        context.safeSave()

        if scheduleReminders {
            let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
            medicationReminders.scheduleMedicationReminders(for: pet, context: context)
        }

        return PetMedicationPlanActivationCommandResult(
            subjectID: pet.id,
            medicationID: medication.id,
            isActive: isActive,
            didChange: didChange,
            calendarEventIDs: calendarSync.createdEventIDs,
            removedCalendarEventIDs: calendarSync.removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @MainActor
    private static func apply(_ input: PetMedicationPlanCommandInput, to medication: PetMedication, pet: Pet) {
        medication.name = input.cleanName
        medication.dosage = input.cleanDosage
        medication.frequency = input.frequency
        medication.customFrequencyNote = input.savedCustomFrequencyNote
        medication.startDate = input.startDate
        medication.endDate = input.endDate
        medication.colorHex = input.colorHex
        medication.notes = input.cleanNotes
        medication.isActive = input.isActive
        medication.remainingAmount = max(0, input.remainingAmount ?? medication.remainingAmount)
        medication.pet = pet
    }

    private static func syncRemainingAmount(
        _ amount: Double?,
        medication: PetMedication,
        userDefaults: UserDefaults
    ) {
        let key = PetMedicationPlanStorageKeys.remainingAmount(medicationID: medication.id)
        guard let amount else {
            medication.remainingAmount = 0
            userDefaults.removeObject(forKey: key)
            return
        }
        let normalized = max(0, amount)
        medication.remainingAmount = normalized
        userDefaults.set(normalized, forKey: key)
    }

    @MainActor
    private static func syncCalendarEvents(
        for medication: PetMedication,
        pet: Pet,
        context: ModelContext
    ) -> (removedEventIDs: [UUID], createdEventIDs: [UUID]) {
        let removedEventIDs = removeCalendarEvents(for: medication.id, context: context)
        guard medication.isActive,
              PetMedicationSchedulePlan.dosesPerDay(for: medication.frequency) > 0 else {
            return (removedEventIDs, [])
        }

        let recurrenceDays = recurrenceDays(for: medication.frequency)
        let firstDay = firstScheduledDay(for: medication)
        let doseMinutes = PetMedicationSchedulePlan.doseMinutes(for: medication)
        var createdEventIDs: [UUID] = []

        for (index, minute) in doseMinutes.enumerated() {
            guard let start = HumanMedicationSchedulePlan.date(on: firstDay, minuteOfDay: minute) else {
                continue
            }
            let event = Event(
                title: calendarEventTitle(
                    for: medication,
                    pet: pet,
                    doseIndex: index,
                    totalDoses: doseMinutes.count
                ),
                startDate: start,
                eventType: EventType.petMedication.rawValue,
                relatedEntityType: MedicationEventLink.petMedicationPlan,
                relatedEntityId: medication.id.uuidString
            )
            event.recurrenceDays = recurrenceDays
            event.recurrenceEndDate = medication.endDate.map { Calendar.current.startOfDay(for: $0) }
            context.insert(event)
            createdEventIDs.append(event.id)
        }

        return (removedEventIDs, createdEventIDs)
    }

    private static func recurrenceDays(for frequency: PetMedicationFrequency) -> Int {
        switch frequency {
        case .everyOtherDay:
            2
        case .weekly:
            7
        default:
            1
        }
    }

    private static func firstScheduledDay(for medication: PetMedication, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: medication.startDate)
    }

    private static func calendarEventTitle(
        for medication: PetMedication,
        pet: Pet,
        doseIndex: Int,
        totalDoses: Int
    ) -> String {
        let doseSuffix = totalDoses > 1 ? " · \(doseIndex + 1)/\(totalDoses)" : ""
        let dosageSuffix = medication.dosage.isEmpty ? "" : " · \(medication.dosage)"
        return "💊 \(pet.name) · \(medication.name)\(dosageSuffix)\(doseSuffix)"
    }

    @MainActor
    private static func removeCalendarEvents(for medicationID: UUID, context: ModelContext) -> [UUID] {
        let medicationIDString = medicationID.uuidString
        let entityType = MedicationEventLink.petMedicationPlan
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == entityType && event.relatedEntityId == medicationIDString
            }
        )
        let events = fetchMedicationCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch pet medication calendar events"
        )
        let removedEventIDs = events.map(\.id)
        for event in events {
            for reminder in event.reminders {
                CloudSyncMutationRecorder.markDeleted(reminder, context: context)
            }
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        return removedEventIDs
    }
}

@MainActor
struct PetMedicationCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let medicationReminders: MedicationReminderManaging

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            medicationReminders: services.medicationReminders
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging
    ) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
        self.medicationReminders = medicationReminders
    }

    @discardableResult
    func savePlan(
        pet: Pet,
        editing existingMedication: PetMedication?,
        input: PetMedicationPlanCommandInput,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true,
        note: String,
        emptyNote: String = "pet.medication.plan.empty"
    ) -> PetMedicationPlanCommandResult? {
        guard let result = PetMedicationPlanCommandService.savePlan(
            pet: pet,
            editing: existingMedication,
            input: input,
            context: context,
            userDefaults: userDefaults,
            scheduleReminders: scheduleReminders,
            medicationReminders: medicationReminders
        ) else {
            revisions.publish(
                DomainMutationResult(
                    command: .petMedicationPlan(petID: pet.id, medicationID: existingMedication?.id),
                    affectedEntityIDs: [pet.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisions.publishPetMedicationPlan(result, note: note)
        return result
    }

    @discardableResult
    func deletePlan(
        pet: Pet,
        medication: PetMedication,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true,
        note: String
    ) -> PetMedicationPlanDeleteCommandResult {
        let result = PetMedicationPlanCommandService.deletePlan(
            pet: pet,
            medication: medication,
            context: context,
            userDefaults: userDefaults,
            scheduleReminders: scheduleReminders,
            medicationReminders: medicationReminders
        )
        revisions.publishPetMedicationPlanDelete(result, note: note)
        return result
    }

    @discardableResult
    func setPlanActive(
        pet: Pet,
        medication: PetMedication,
        isActive: Bool,
        scheduleReminders: Bool = true,
        note: String
    ) -> PetMedicationPlanActivationCommandResult {
        let result = PetMedicationPlanCommandService.setPlanActive(
            pet: pet,
            medication: medication,
            isActive: isActive,
            context: context,
            scheduleReminders: scheduleReminders,
            medicationReminders: medicationReminders
        )
        revisions.publishPetMedicationPlanActivation(result, note: note)
        return result
    }

    @discardableResult
    func recordDose(
        medication: PetMedication,
        pet: Pet,
        decrementRemaining: Bool = true,
        awardCoconut: Bool = true,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        note: String
    ) -> PetMedicationDoseCommandResult {
        let event = PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: context,
            decrementRemaining: decrementRemaining,
            awardCoconut: awardCoconut,
            questManager: questManager,
            activeHumanSelection: activeHumanSelection,
            medicationReminders: medicationReminders
        )
        let result = PetMedicationDoseCommandResult(
            subjectID: pet.id,
            medicationID: medication.id,
            eventID: event.id,
            coconutDelta: awardCoconut ? 1 : 0
        )
        revisions.publishPetMedicationDose(result, note: note)
        return result
    }
}

enum HumanMedicationPlanCommandService {
    private static let humanMedicationEntityType = MedicationEventLink.humanMedicationPlan

    @discardableResult
    @MainActor
    static func savePlan(
        human: Human,
        editing existingMedication: HumanMedication?,
        input: HumanMedicationPlanCommandInput,
        context: ModelContext,
        scheduleReminders: Bool = true,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> HumanMedicationPlanCommandResult? {
        guard !input.cleanName.isEmpty else { return nil }

        let medication: HumanMedication
        let created: Bool
        if let existing = existingMedication {
            medication = existing
            created = false
        } else {
            medication = HumanMedication(
                humanId: human.id.uuidString,
                name: input.cleanName,
                dosage: input.cleanDosage,
                frequency: input.frequency,
                firstDoseTime: input.firstDoseTime(),
                startDate: input.startDate,
                endDate: input.endDate,
                colorHex: input.colorHex,
                notes: input.savedNotes
            )
            context.insert(medication)
            created = true
        }

        apply(input, to: medication, human: human)
        let calendarSync = syncCalendarEvents(
            for: medication,
            human: human,
            appLanguage: input.appLanguage,
            context: context
        )
        context.safeSave()

        if scheduleReminders {
            scheduleHumanMedicationReminders(
                for: human,
                context: context,
                medicationReminders: providedMedicationReminders
            )
        }

        return HumanMedicationPlanCommandResult(
            subjectID: human.id,
            medicationID: medication.id,
            created: created,
            calendarEventIDs: calendarSync.createdEventIDs,
            removedCalendarEventIDs: calendarSync.removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func deletePlan(
        human: Human,
        medication: HumanMedication,
        context: ModelContext,
        scheduleReminders: Bool = true,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> HumanMedicationPlanDeleteCommandResult {
        let medicationID = medication.id
        let removedEventIDs = removeCalendarEvents(for: medicationID, context: context)
        CloudSyncMutationRecorder.markDeleted(medication, context: context)
        context.delete(medication)
        context.safeSave()

        if scheduleReminders {
            scheduleHumanMedicationReminders(
                for: human,
                context: context,
                medicationReminders: providedMedicationReminders
            )
        }

        return HumanMedicationPlanDeleteCommandResult(
            subjectID: human.id,
            medicationID: medicationID,
            removedCalendarEventIDs: removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func setPlanActive(
        human: Human,
        medication: HumanMedication,
        isActive: Bool,
        appLanguage: String,
        context: ModelContext,
        scheduleReminders: Bool = true,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> HumanMedicationPlanActivationCommandResult {
        let didChange = medication.isActive != isActive
        medication.isActive = isActive
        let calendarSync = syncCalendarEvents(
            for: medication,
            human: human,
            appLanguage: appLanguage,
            context: context
        )
        context.safeSave()

        if scheduleReminders {
            scheduleHumanMedicationReminders(
                for: human,
                context: context,
                medicationReminders: providedMedicationReminders
            )
        }

        return HumanMedicationPlanActivationCommandResult(
            subjectID: human.id,
            medicationID: medication.id,
            isActive: isActive,
            didChange: didChange,
            calendarEventIDs: calendarSync.createdEventIDs,
            removedCalendarEventIDs: calendarSync.removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @MainActor
    private static func apply(_ input: HumanMedicationPlanCommandInput, to medication: HumanMedication, human: Human) {
        medication.humanId = human.id.uuidString
        medication.name = input.cleanName
        medication.dosage = input.cleanDosage
        medication.frequency = input.frequency
        medication.customFrequencyNote = input.cleanCustomFrequencyNote
        medication.firstDoseTime = input.firstDoseTime()
        medication.startDate = input.startDate
        medication.endDate = input.endDate
        medication.colorHex = input.colorHex
        medication.notes = input.savedNotes
        medication.isActive = input.isActive
    }

    @MainActor
    private static func syncCalendarEvents(
        for medication: HumanMedication,
        human: Human,
        appLanguage: String,
        context: ModelContext
    ) -> (removedEventIDs: [UUID], createdEventIDs: [UUID]) {
        let removedEventIDs = removeCalendarEvents(for: medication.id, context: context)
        guard medication.isActive, !medication.frequency.isManualEntry else {
            return (removedEventIDs, [])
        }

        let calendar = Calendar.current
        let firstDay = firstScheduledDay(for: medication, calendar: calendar)
        let doseMinutes = HumanMedicationSchedulePlan.doseMinutes(for: medication, calendar: calendar)
        var createdEventIDs: [UUID] = []

        for (index, minute) in doseMinutes.enumerated() {
            guard let start = HumanMedicationSchedulePlan.date(on: firstDay, minuteOfDay: minute, calendar: calendar) else {
                continue
            }
            let event = Event(
                title: calendarEventTitle(
                    for: medication,
                    human: human,
                    doseIndex: index,
                    totalDoses: doseMinutes.count,
                    appLanguage: appLanguage
                ),
                startDate: start,
                eventType: EventType.medication.rawValue,
                relatedEntityType: humanMedicationEntityType,
                relatedEntityId: medication.id.uuidString
            )
            event.recurrenceDays = medication.frequency == .weekly ? 7 : 1
            event.recurrenceEndDate = medication.endDate.map { calendar.startOfDay(for: $0) }
            event.assigneeId = human.id.uuidString
            context.insert(event)
            createdEventIDs.append(event.id)
        }

        return (removedEventIDs, createdEventIDs)
    }

    private static func firstScheduledDay(for medication: HumanMedication, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: medication.startDate)
        guard medication.frequency == .weekly else { return start }
        let targetWeekday = HumanMedicationScheduleMetadata.parse(from: medication.notes)?.weeklyWeekday
            ?? calendar.component(.weekday, from: start)
        let startWeekday = calendar.component(.weekday, from: start)
        let delta = (targetWeekday - startWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: delta, to: start) ?? start
    }

    private static func calendarEventTitle(
        for medication: HumanMedication,
        human: Human,
        doseIndex: Int,
        totalDoses: Int,
        appLanguage: String
    ) -> String {
        let l = L10n(appLanguage)
        let doseSuffix = totalDoses > 1
            ? l.tr(zh: " · 第 \(doseIndex + 1) 次", en: " · Dose \(doseIndex + 1)", de: " · Dosis \(doseIndex + 1)")
            : ""
        let dosageSuffix = medication.dosage.isEmpty ? "" : " · \(medication.dosage)"
        return "💊 \(human.name) · \(medication.name)\(dosageSuffix)\(doseSuffix)"
    }

    @MainActor
    private static func removeCalendarEvents(for medicationID: UUID, context: ModelContext) -> [UUID] {
        let medicationIDString = medicationID.uuidString
        let entityType = humanMedicationEntityType
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == entityType && event.relatedEntityId == medicationIDString
            }
        )
        let events = fetchMedicationCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch human medication calendar events"
        )
        let removedEventIDs = events.map(\.id)
        for event in events {
            for reminder in event.reminders {
                CloudSyncMutationRecorder.markDeleted(reminder, context: context)
            }
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        return removedEventIDs
    }

    @MainActor
    private static func scheduleHumanMedicationReminders(
        for human: Human,
        context: ModelContext,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) {
        let meds = fetchHumanMedications(humanID: human.id.uuidString, context: context)
        let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
        medicationReminders.scheduleHumanMedicationReminders(
            for: human,
            meds: meds,
            context: context
        )
    }

    @MainActor
    private static func fetchHumanMedications(humanID: String, context: ModelContext) -> [HumanMedication] {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanID
            },
            sortBy: [SortDescriptor(\HumanMedication.createdAt)]
        )
        return fetchMedicationCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch human medication plans for reminder sync"
        )
    }
}

enum HumanMedicationDoseCommandService {
    @discardableResult
    @MainActor
    static func setDoseStatus(
        human: Human,
        medicationID: UUID,
        scheduledTime: Date,
        status: HumanMedicationStatus,
        context: ModelContext,
        source: CareLedgerSource = .detail,
        now: Date = Date(),
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> HumanMedicationDoseCommandResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let update = HumanMedicationLogStore.applyDoseStatus(
            humanId: human.id.uuidString,
            medicationId: medicationID.uuidString,
            scheduledTime: scheduledTime,
            status: status,
            existingLogs: [],
            context: context
        )

        var recordedLedgerEvent = false
        if update.shouldRecordLedgerEvent, let log = update.log {
            recordedLedgerEvent = true
            careLedger.record(
                occurredAt: log.recordedTime ?? now,
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                eventKind: .medication,
                actionType: status == .taken ? "humanMedicationTaken" : "humanMedicationSkipped",
                amountValue: 0,
                amountUnit: "",
                note: "",
                source: source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "HumanMedicationLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "{\"medicationId\":\"\(medicationID.uuidString)\"}",
                context: context,
                save: false
            )
        }

        if update.didChange {
            context.safeSave()
        }

        return HumanMedicationDoseCommandResult(
            subjectID: human.id,
            medicationID: medicationID,
            logID: update.log?.id,
            status: status,
            didChange: update.didChange,
            recordedLedgerEvent: recordedLedgerEvent
        )
    }
}
