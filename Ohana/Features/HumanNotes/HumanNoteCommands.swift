//
//  HumanNoteCommands.swift
//  Ohana
//
//  Domain write boundaries for human notes and human care facts.
//

import Foundation
import SwiftData
import UIKit

struct HumanNoteFileAttachmentPayload: Equatable {
    let fileName: String
    let data: Data
    let isImage: Bool
}

struct HumanNoteCommandResult: Equatable {
    let subjectID: UUID
    let attachmentCount: Int
    let eventID: UUID?
    let reminderID: UUID?
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

struct HumanNoteDeleteResult: Equatable {
    let subjectID: UUID
    let didDelete: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

enum HumanNoteCommandService {
    @discardableResult
    @MainActor
    static func recordNote(
        human: Human,
        note: String,
        date: Date,
        imageAttachments: [UIImage],
        fileAttachments: [HumanNoteFileAttachmentPayload],
        reminderDate: Date?,
        appLanguage: String,
        context: ModelContext,
        scheduleNotification: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> HumanNoteCommandResult? {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNote.isEmpty || !imageAttachments.isEmpty || !fileAttachments.isEmpty || reminderDate != nil else {
            return nil
        }
        let disposition = MemberLifecycleGate.disposition(
            human: human,
            writeKind: reminderDate == nil ? .memorial : .memorialContentWithOptionalDerivations
        )
        guard disposition.writesContent else { return nil }

        let attachments = persistAttachments(
            images: imageAttachments,
            files: fileAttachments,
            humanID: human.id
        )
        let l = L10n(appLanguage)
        let effectiveReminderDate = disposition.allowsDerivedEffects ? reminderDate : nil
        let entry = noteEntry(
            note: cleanNote,
            date: date,
            attachments: attachments,
            reminderDate: effectiveReminderDate,
            l: l
        )
        human.notes = human.notes.isEmpty ? entry : human.notes + "\n\n" + entry
        CloudSyncMutationRecorder.markModified(human, context: context, modifiedAt: date)

        let reminderPair = effectiveReminderDate.flatMap {
            createReminder(
                human: human,
                note: cleanNote,
                reminderDate: $0,
                l: l,
                context: context
            )
        }

        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            HumanNoteAttachmentStore.deletePendingAttachments(attachments)
            context.rollback()
            return HumanNoteCommandResult(
                subjectID: human.id,
                attachmentCount: 0,
                eventID: nil,
                reminderID: nil,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }

        if scheduleNotification, let reminder = reminderPair?.reminder {
            let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
            Task { @MainActor in
                await reminderScheduling.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: .quickAction,
                    existingNotificationIds: nil,
                    operation: "schedule",
                    saveLedger: true
                )
            }
        }

        return HumanNoteCommandResult(
            subjectID: human.id,
            attachmentCount: attachments.count,
            eventID: reminderPair?.event.id,
            reminderID: reminderPair?.reminder.id,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func deleteNote(
        human: Human,
        rawString: String,
        context: ModelContext
    ) -> HumanNoteDeleteResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .memorial).writesContent else {
            return HumanNoteDeleteResult(
                subjectID: human.id,
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: nil
            )
        }
        let target = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, !human.notes.isEmpty else {
            return HumanNoteDeleteResult(
                subjectID: human.id,
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: nil
            )
        }

        let parts = human.notes.components(separatedBy: "\n\n")
        let remaining = parts.filter { part in
            part.trimmingCharacters(in: .whitespacesAndNewlines) != target
        }
        let didDelete = remaining.count != parts.count
        guard didDelete else {
            return HumanNoteDeleteResult(
                subjectID: human.id,
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: nil
            )
        }

        human.notes = remaining
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return HumanNoteDeleteResult(
                subjectID: human.id,
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return HumanNoteDeleteResult(
            subjectID: human.id,
            didDelete: true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private static func persistAttachments(
        images: [UIImage],
        files: [HumanNoteFileAttachmentPayload],
        humanID: UUID
    ) -> [HumanNoteAttachmentReference] {
        var references: [HumanNoteAttachmentReference] = []
        for (index, image) in images.enumerated() {
            if let ref = HumanNoteAttachmentStore.saveImage(image, humanId: humanID, index: index + 1) {
                references.append(ref)
            }
        }
        for file in files {
            if let ref = HumanNoteAttachmentStore.saveFile(
                data: file.data,
                originalFileName: file.fileName,
                isImage: file.isImage,
                humanId: humanID
            ) {
                references.append(ref)
            }
        }
        return references
    }

    private static func noteEntry(
        note: String,
        date: Date,
        attachments: [HumanNoteAttachmentReference],
        reminderDate: Date?,
        l: L10n
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "[\(formatter.string(from: date))] \(recordBody(note: note, attachments: attachments, reminderDate: reminderDate, l: l))\(HumanNoteAttachmentStore.marker(for: attachments))"
    }

    private static func recordBody(
        note: String,
        attachments: [HumanNoteAttachmentReference],
        reminderDate: Date?,
        l: L10n
    ) -> String {
        var parts: [String] = []
        if !note.isEmpty {
            parts.append(note)
        }
        let imageCount = attachments.filter(\.isImage).count
        let fileNames = attachments.filter { !$0.isImage }.map(\.fileName)
        if imageCount > 0 {
            parts.append(l.tr(zh: "照片 \(imageCount) 张", en: "\(imageCount) photo(s)", de: "\(imageCount) Foto(s)"))
        }
        if !fileNames.isEmpty {
            let names = fileNames.joined(separator: ", ")
            parts.append(l.tr(zh: "文件：\(names)", en: "Files: \(names)", de: "Dateien: \(names)"))
        }
        if let reminderDate {
            let formatted = reminderDate.formatted(date: .abbreviated, time: .shortened)
            parts.append(l.tr(zh: "提醒：\(formatted)", en: "Reminder: \(formatted)", de: "Erinnerung: \(formatted)"))
        }
        return parts.isEmpty ? l.tr(zh: "记录", en: "Record", de: "Eintrag") : parts.joined(separator: " · ")
    }

    @MainActor
    private static func createReminder(
        human: Human,
        note: String,
        reminderDate: Date,
        l: L10n,
        context: ModelContext
    ) -> (event: Event, reminder: Reminder)? {
        let title = note.isEmpty
            ? l.tr(zh: "\(human.name) 的记录提醒", en: "\(human.name)'s note reminder", de: "Notizerinnerung für \(human.name)")
            : note
        let intent = DomainScheduleCreateIntent(
            title: title,
            startDate: reminderDate,
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanNote,
            relatedEntityId: human.id.uuidString,
            reminderLeadMinutes: 0,
            assigneeId: human.id.uuidString,
            writeKind: .memorialContentWithOptionalDerivations,
            source: .userCommand
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else { return nil }
        let writeResult = DomainScheduleWriter.createEvent(plan: plan, context: context)
        let event = writeResult.event
        guard !writeResult.reminders.isEmpty else { return nil }
        let reminder = writeResult.reminders[0]
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: reminderDate)
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: reminderDate)
        return (event, reminder)
    }
}

@MainActor
struct HumanCareCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    private let derivations: CareDerivationExecutor
    let careLedger: CareLedgerRecording
    let reminderScheduling: ReminderSchedulingManaging
    let medicationReminders: MedicationReminderManaging

    init(context: ModelContext) {
        let careLedger = CareLedgerService()
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            careLedger: careLedger,
            reminderScheduling: ReminderSchedulingManager(careLedger: careLedger),
            medicationReminders: SharedMedicationReminderManager(careLedger: careLedger)
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        let careLedger = CareLedgerService()
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            careLedger: careLedger,
            reminderScheduling: ReminderSchedulingManager(careLedger: careLedger),
            medicationReminders: SharedMedicationReminderManager(careLedger: careLedger)
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            careLedger: services.careLedger,
            reminderScheduling: services.reminderScheduling,
            medicationReminders: services.medicationReminders
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        careLedger: CareLedgerRecording,
        reminderScheduling: ReminderSchedulingManaging,
        medicationReminders: MedicationReminderManaging
    ) {
        self.context = context
        self.revisions = revisions
        derivations = CareDerivationExecutor(revisions: revisions)
        self.careLedger = careLedger
        self.reminderScheduling = reminderScheduling
        self.medicationReminders = medicationReminders
    }

    @discardableResult
    func recordWorkout(
        human: Human,
        type: WorkoutType,
        durationMinutes: Int,
        date: Date,
        distanceKm: Double = 0,
        calories: Int = 0,
        steps: Int = 0,
        notes: String = "",
        sourceHealthKit: Bool = false,
        healthKitWorkoutUUID: String = "",
        healthKitSourceBundleID: String = "",
        healthKitSourceName: String = "",
        sourcePetWalkLogID: String = "",
        source: CareLedgerSource = .quickAction,
        command: DomainCommand,
        note: String
    ) -> WorkoutCommandResult {
        let result = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: type,
            durationMinutes: durationMinutes,
            date: date,
            context: context,
            distanceKm: distanceKm,
            calories: calories,
            steps: steps,
            notes: notes,
            sourceHealthKit: sourceHealthKit,
            healthKitWorkoutUUID: healthKitWorkoutUUID,
            healthKitSourceBundleID: healthKitSourceBundleID,
            healthKitSourceName: healthKitSourceName,
            sourcePetWalkLogID: sourcePetWalkLogID,
            source: source
        )
        guard result.didPersist, result.ledgerEventID != nil else { return result }
        revisions.publishHumanWorkout(result, command: command, note: note)
        return result
    }

    @discardableResult
    func deleteWorkout(
        _ log: HumanWorkoutLog,
        human: Human,
        command: DomainCommand,
        note: String
    ) -> WorkoutDeleteCommandResult {
        let result = WorkoutCommandService.deleteHumanWorkout(log, human: human, context: context)
        if result.didPersist && result.didChange {
            revisions.publishHumanWorkoutDelete(result, command: command, note: note)
        }
        return result
    }

    @discardableResult
    func createQuickMedication(
        human: Human,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        firstDoseTime: Date,
        startDate: Date,
        colorHex: String,
        notes: String,
        reminderEnabled: Bool,
        note: String,
        emptyNote: String = "quick.human.medication.noop"
    ) -> HumanMedicationCommandResult? {
        guard let result = HumanMedicationCommandService.createMedication(
            human: human,
            name: name,
            dosage: dosage,
            frequency: frequency,
            firstDoseTime: firstDoseTime,
            startDate: startDate,
            colorHex: colorHex,
            notes: notes,
            context: context,
            reminderEnabled: reminderEnabled,
            medicationReminders: medicationReminders
        ) else {
            derivations.derive(
                .noOp(
                    command: .quickHumanMedication(humanID: human.id),
                    affectedEntityIDs: [human.id],
                    note: emptyNote
                )
            )
            return nil
        }
        guard result.didPersist else { return result }
        revisions.publishQuickHumanMedication(result, note: note)
        return result
    }

    @discardableResult
    func saveMedicationPlan(
        human: Human,
        editing existingMedication: HumanMedication?,
        input: HumanMedicationPlanCommandInput,
        scheduleReminders: Bool = true,
        note: String? = nil,
        emptyNote: String = "human.medication.plan.invalid"
    ) -> HumanMedicationPlanCommandResult? {
        guard let result = HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: existingMedication,
            input: input,
            context: context,
            scheduleReminders: scheduleReminders,
            medicationReminders: medicationReminders
        ) else {
            derivations.derive(
                .noOp(
                    command: .humanMedicationPlan(humanID: human.id, medicationID: existingMedication?.id),
                    affectedEntityIDs: [human.id],
                    note: emptyNote
                )
            )
            return nil
        }
        guard result.didPersist else { return result }
        revisions.publishHumanMedicationPlan(
            result,
            commandMedicationID: existingMedication?.id,
            note: note ?? (result.created ? "human.medication.plan.created" : "human.medication.plan.updated")
        )
        return result
    }

    @discardableResult
    func setMedicationPlanActive(
        human: Human,
        medication: HumanMedication,
        isActive: Bool,
        appLanguage: String,
        scheduleReminders: Bool = true,
        note: String? = nil
    ) -> HumanMedicationPlanActivationCommandResult {
        let result = HumanMedicationPlanCommandService.setPlanActive(
            human: human,
            medication: medication,
            isActive: isActive,
            appLanguage: appLanguage,
            context: context,
            scheduleReminders: scheduleReminders,
            medicationReminders: medicationReminders
        )
        let revisionNote = note
            ?? (result.scheduledReminderSync ? "human.medication.plan.activation.reminders" : "human.medication.plan.activation")
        if result.didChange || !result.calendarEventIDs.isEmpty || !result.removedCalendarEventIDs.isEmpty {
            revisions.publishHumanMedicationPlanActivation(result, note: revisionNote)
        }
        return result
    }

    @discardableResult
    func deleteMedicationPlan(
        human: Human,
        medication: HumanMedication,
        scheduleReminders: Bool = true,
        note: String
    ) -> HumanMedicationPlanDeleteCommandResult {
        let result = HumanMedicationPlanCommandService.deletePlan(
            human: human,
            medication: medication,
            context: context,
            scheduleReminders: scheduleReminders,
            medicationReminders: medicationReminders
        )
        if result.didChange {
            revisions.publishHumanMedicationPlanDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    func setMedicationDoseStatus(
        human: Human,
        medicationID: UUID,
        scheduledTime: Date,
        status: HumanMedicationStatus,
        source: CareLedgerSource = .detail,
        now: Date = Date(),
        note: String? = nil
    ) -> HumanMedicationDoseCommandResult {
        let result = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: medicationID,
            scheduledTime: scheduledTime,
            status: status,
            context: context,
            source: source,
            now: now,
            careLedger: careLedger
        )
        let scheduledMinute = Int(scheduledTime.timeIntervalSince1970 / 60)
        let revisionNote = note
            ?? (result.recordedLedgerEvent ? "human.medication.dose.ledger" : "human.medication.dose")
        if result.didChange {
            revisions.publishHumanMedicationDose(result, scheduledMinute: scheduledMinute, note: revisionNote)
        }
        return result
    }

    @discardableResult
    func recordHealthMetric(
        human: Human,
        metricKey: String,
        unitCode: String,
        value: Double,
        date: Date,
        notes: String,
        note: String,
        emptyNote: String = "human.health.metric.noop"
    ) -> HumanHealthMetricCommandResult? {
        guard let result = HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            date: date,
            notes: notes,
            context: context
        ) else {
            derivations.derive(
                .noOp(
                    command: .humanHealthMetric(humanID: human.id, metricKey: metricKey),
                    affectedEntityIDs: [human.id],
                    note: emptyNote
                )
            )
            return nil
        }
        revisions.publishHumanHealthMetric(result, note: note)
        return result
    }

    @discardableResult
    func deleteHealthMetric(
        _ log: HumanHealthMetricLog,
        human: Human,
        note: String
    ) -> HumanHealthMetricDeleteCommandResult {
        let result = HumanHealthMetricCommandService.deleteMetricLog(log, human: human, context: context)
        if result.didChange {
            revisions.publishHumanHealthMetricDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    func recordNote(
        human: Human,
        noteText: String,
        date: Date,
        imageAttachments: [UIImage],
        fileAttachments: [HumanNoteFileAttachmentPayload],
        reminderDate: Date?,
        appLanguage: String,
        scheduleNotification: Bool = true,
        note: String,
        emptyNote: String = "human.note.noop"
    ) -> HumanNoteCommandResult? {
        guard let result = HumanNoteCommandService.recordNote(
            human: human,
            note: noteText,
            date: date,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
            reminderDate: reminderDate,
            appLanguage: appLanguage,
            context: context,
            scheduleNotification: scheduleNotification,
            reminderScheduling: reminderScheduling
        ) else {
            derivations.derive(
                .noOp(
                    command: .humanNote(humanID: human.id),
                    affectedEntityIDs: [human.id],
                    note: emptyNote
                )
            )
            return nil
        }
        guard result.didPersist else { return result }
        revisions.publishHumanNote(result, note: note)
        return result
    }

    @discardableResult
    func deleteNote(
        human: Human,
        rawString: String,
        note: String? = nil
    ) -> HumanNoteDeleteResult {
        let result = HumanNoteCommandService.deleteNote(
            human: human,
            rawString: rawString,
            context: context
        )
        if result.didPersist {
            revisions.publishHumanNoteDelete(
                result,
                note: note ?? (result.didDelete ? "human.note.delete" : "human.note.delete.noop")
            )
        }
        return result
    }
}
