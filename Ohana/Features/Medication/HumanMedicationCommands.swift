//
//  HumanMedicationCommands.swift
//  Ohana
//

import Foundation
import SwiftData

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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else { return nil }

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
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: input.startDate)
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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanMedicationPlanDeleteCommandResult(
                subjectID: human.id,
                medicationID: medicationID,
                removedCalendarEventIDs: [],
                scheduledReminderSync: false,
                didChange: false
            )
        }

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
            scheduledReminderSync: scheduleReminders,
            didChange: true
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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanMedicationPlanActivationCommandResult(
                subjectID: human.id,
                medicationID: medication.id,
                isActive: medication.isActive,
                didChange: false,
                calendarEventIDs: [],
                removedCalendarEventIDs: [],
                scheduledReminderSync: false
            )
        }

        let didChange = medication.isActive != isActive
        medication.isActive = isActive
        if didChange {
            CloudSyncMutationRecorder.markModified(medication, context: context)
        }
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
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: start)
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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanMedicationDoseCommandResult(
                subjectID: human.id,
                medicationID: medicationID,
                logID: nil,
                status: status,
                didChange: false,
                recordedLedgerEvent: false
            )
        }

        let careLedger = providedCareLedger ?? CareLedgerService()
        let update = HumanMedicationLogStore.applyDoseStatus(
            humanId: human.id.uuidString,
            medicationId: medicationID.uuidString,
            scheduledTime: scheduledTime,
            status: status,
            existingLogs: [],
            context: context,
            now: now
        )
        if update.didChange, let log = update.log {
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: now)
        }

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
