//
//  PetMedicationDoseLogging.swift
//  Ohana
//
//  宠物用药打卡写入 Event，避免改动 PetMedication Schema。
//

import CryptoKit
import Foundation
import SwiftData

nonisolated enum PetMedicationDoseLogging {
    static let relatedEntityTypeMedication = DomainEntityLinkRegistry.petMedicationDose

    struct ScheduledOccurrence: Sendable {
        let scheduledAt: Date
        let doseIndex: Int

        func eventID(medicationID: UUID) -> UUID {
            let minute = Int64((scheduledAt.timeIntervalSince1970 / 60).rounded(.down))
            let key = "pet-medication-dose:\(medicationID.uuidString):\(minute):\(doseIndex)"
            let bytes = Array(SHA256.hash(data: Data(key.utf8)))
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }

        func marker(calendar: Calendar = .current) -> String {
            let day = Int64(calendar.startOfDay(for: scheduledAt).timeIntervalSince1970)
            return "petMedicationScheduledDose:\(day):\(doseIndex)"
        }
    }

    static func doseMedicationId(for event: Event) -> UUID? {
        guard event.eventType == EventType.petMedicationDose.rawValue else { return nil }
        return DomainEntityLinkRegistry.resolvedId(
            for: DomainEntityLink(event: event),
            role: .petMedicationDose
        )
    }

    static func isDoseEvent(_ event: Event, medicationId: UUID) -> Bool {
        doseMedicationId(for: event) == medicationId
    }

    struct RecordDoseResult {
        let event: Event
        let didRecord: Bool
        let coconutDelta: Int
        let allowsDerivedEffects: Bool
        let didPersist: Bool
        let persistenceErrorDescription: String?
    }

    /// 某日该药应喂次数（`asNeeded` 为 0，不产生委托）
    static func requiredDoses(on date: Date, for med: PetMedication, calendar: Calendar = .current) -> Int {
        guard med.isActive else { return 0 }
        let d0 = calendar.startOfDay(for: date)
        if d0 < calendar.startOfDay(for: med.startDate) { return 0 }
        if let end = med.endDate, d0 > calendar.startOfDay(for: end) { return 0 }

        switch med.frequency {
        case .daily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .everyOtherDay:
            let start = calendar.startOfDay(for: med.startDate)
            let days = calendar.dateComponents([.day], from: start, to: d0).day ?? 0
            return days % 2 == 0 ? 1 : 0
        case .weekly:
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: med.startDate) ? 1 : 0
        case .asNeeded:
            return 0
        case .custom:
            return 1
        }
    }

    static func doseCount(on date: Date, events: [Event], medicationId: UUID, calendar: Calendar = .current) -> Int {
        events.count(where: { ev in
            isDoseEvent(ev, medicationId: medicationId)
                && calendar.isDate(ev.startDate, inSameDayAs: date)
        })
    }

    static func todayDoseCount(events: [Event], medicationId: UUID) -> Int {
        doseCount(on: Date(), events: events, medicationId: medicationId)
    }

    static func doseEventTitle(petName: String, medicationName: String, l: L10n = .current) -> String {
        l.tr(
            zh: "💊 \(petName) 服用 \(medicationName)",
            en: "💊 \(petName) took \(medicationName)",
            de: "💊 \(petName) hat \(medicationName) bekommen"
        )
    }

    static func doseRewardTitle(l: L10n = .current) -> String {
        l.tr(
            zh: "记录喂药 +1🥥",
            en: "Medication dose logged +1🥥",
            de: "Medikamentengabe erfasst +1🥥"
        )
    }

    @discardableResult
    @MainActor
    static func recordDose(
        medication: PetMedication,
        pet: Pet,
        modelContext: ModelContext,
        decrementRemaining: Bool = true,
        awardCoconut: Bool = false,
        economy: CareEventEconomyAwarding,
        executorId: String?,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil,
        scheduledOccurrence: ScheduledOccurrence? = nil
    ) -> Event {
        recordDoseResult(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            decrementRemaining: decrementRemaining,
            awardCoconut: awardCoconut,
            economy: economy,
            executorId: executorId,
            careLedger: providedCareLedger,
            medicationReminders: providedMedicationReminders,
            scheduledOccurrence: scheduledOccurrence
        ).event
    }

    @discardableResult
    @MainActor
    static func recordDoseResult(
        medication: PetMedication,
        pet: Pet,
        modelContext: ModelContext,
        decrementRemaining: Bool = true,
        awardCoconut: Bool = false,
        economy: CareEventEconomyAwarding,
        executorId: String?,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil,
        scheduledOccurrence: ScheduledOccurrence? = nil
    ) -> RecordDoseResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let medicationReminders = providedMedicationReminders ?? DomainServiceDependencyRegistry.medicationReminders(careLedger: careLedger)
        let now = Date()
        let doseDate = scheduledOccurrence?.scheduledAt ?? now
        let confirmedExecutorId = EconomyRewardOwnerResolver.normalizedExecutorId(executorId)
        let previewIntent = makeDoseIntent(medication: medication, pet: pet, date: doseDate, executorID: confirmedExecutorId)
        guard let actor = resolvedConfirmedExecutor(executorId: confirmedExecutorId, context: modelContext) else {
            return rejectedConfirmedExecutorResult(previewIntent: previewIntent)
        }
        let writeIntent = makeDoseIntent(medication: medication, pet: pet, date: doseDate, executorID: actor.effectiveExecutorId)
        if let scheduledOccurrence,
           let result = scheduledDosePreflight(
               scheduledOccurrence,
               medication: medication,
               now: now,
               intent: writeIntent,
               context: modelContext
           ) {
            return result
        }
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: writeIntent,
            context: modelContext
        ) else {
            let event = DomainScheduleWriter.makeUnpersistedEvent(intent: writeIntent)
            return RecordDoseResult(
                event: event,
                didRecord: false,
                coconutDelta: 0,
                allowsDerivedEffects: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let event = DomainScheduleWriter.createEvent(plan: plan, context: modelContext).event
        if let scheduledOccurrence {
            event.id = scheduledOccurrence.eventID(medicationID: medication.id)
            event.completedOccurrences = [scheduledOccurrence.marker()]
        }
        CloudSyncMutationRecorder.markModified(event, context: modelContext, modifiedAt: now)
        let effectsPlan = DomainEffectWriteAuthorizer.authorizePetEffect(
            pet: pet,
            occurredAt: doseDate,
            writeKind: .care,
            source: .domainService,
            executorId: actor.effectiveExecutorId,
            context: modelContext,
            logPrefix: "PetMedicationDoseLogging",
            actorOverride: actor
        )

        var coconutDelta = 0
        var pendingRemainingAmountWrite = PendingMedicationDoseStorageWrite.none
        if let effectsPlan {
            DomainEffectDispatcher.run(plan: effectsPlan) { actor in
                if awardCoconut, effectsPlan.allowsEconomyDerivation {
                    let reward = economy.awardCareAction(
                        type: .general(
                            humanReward: 1,
                            petReward: 0,
                            emoji: "💊",
                            title: doseRewardTitle()
                        ),
                        pet: pet,
                        context: modelContext,
                        quality: .none,
                        date: now,
                        executorId: actor.rewardExecutorId
                    )
                    coconutDelta = reward.humanGot + reward.petGot
                }

                careLedger.record(
                    occurredAt: event.startDate,
                    actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                    actorId: actor.effectiveExecutorId,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    eventKind: .medication,
                    actionType: "petMedicationDose",
                    amountValue: 0,
                    amountUnit: "",
                    note: event.title,
                    source: .detail,
                    sourceEventId: event.id.uuidString,
                    sourceReminderId: nil,
                    legacyModelName: "Event",
                    legacyModelId: event.id.uuidString,
                    coconutDelta: coconutDelta,
                    rewardLogId: nil,
                    privacyFieldRaw: nil,
                    metadataJSON: "{\"medicationId\":\"\(medication.id.uuidString)\"}",
                    context: modelContext,
                    save: false
                )
                if decrementRemaining {
                    pendingRemainingAmountWrite = prepareRemainingAmountDecrement(medication)
                }
            }
        }
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            modelContext.rollback()
            economy.refreshProjectionAfterRollback(context: modelContext)
            return RecordDoseResult(
                event: event,
                didRecord: false,
                coconutDelta: 0,
                allowsDerivedEffects: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        pendingRemainingAmountWrite.commit()
        if effectsPlan != nil {
            medicationReminders.recordDose(for: medication.id)
        }

        return RecordDoseResult(
            event: event,
            didRecord: true,
            coconutDelta: coconutDelta,
            allowsDerivedEffects: effectsPlan?.allowsDerivedEffects == true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private static func makeDoseIntent(
        medication: PetMedication,
        pet: Pet,
        date: Date,
        executorID: String?
    ) -> DomainScheduleCreateIntent {
        DomainScheduleCreateIntent(
            title: doseEventTitle(petName: pet.name, medicationName: medication.name),
            startDate: date,
            isAllDay: false,
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: relatedEntityTypeMedication,
            relatedEntityId: medication.id.uuidString,
            assigneeId: executorID,
            writeKind: .care,
            source: .domainService
        )
    }

    @MainActor
    private static func scheduledDosePreflight(
        _ occurrence: ScheduledOccurrence,
        medication: PetMedication,
        now: Date,
        intent: DomainScheduleCreateIntent,
        context: ModelContext
    ) -> RecordDoseResult? {
        guard occurrence.scheduledAt.timeIntervalSince1970.isFinite,
              occurrence.doseIndex >= 0,
              occurrence.doseIndex < requiredDoses(on: occurrence.scheduledAt, for: medication),
              occurrence.scheduledAt <= now.addingTimeInterval(5 * 60) else {
            return rejectedConfirmedExecutorResult(previewIntent: intent)
        }
        do {
            guard let existing = try alreadyRecordedOccurrence(occurrence, medication: medication, context: context) else {
                return nil
            }
            return RecordDoseResult(
                event: existing,
                didRecord: false,
                coconutDelta: 0,
                allowsDerivedEffects: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        } catch {
            return RecordDoseResult(
                event: DomainScheduleWriter.makeUnpersistedEvent(intent: intent),
                didRecord: false,
                coconutDelta: 0,
                allowsDerivedEffects: false,
                didPersist: false,
                persistenceErrorDescription: error.localizedDescription
            )
        }
    }

    @MainActor
    private static func alreadyRecordedOccurrence(
        _ occurrence: ScheduledOccurrence,
        medication: PetMedication,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Event? {
        let occurrenceID = occurrence.eventID(medicationID: medication.id)
        var identity = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == occurrenceID })
        identity.fetchLimit = 1
        if let existing = try context.fetch(identity).first { return existing }

        let dayStart = calendar.startOfDay(for: occurrence.scheduledAt)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        let eventType = EventType.petMedicationDose.rawValue
        let medicationID = medication.id.uuidString
        let dayEvents = try context.fetch(FetchDescriptor<Event>(predicate: #Predicate<Event> { event in
            event.eventType == eventType && event.relatedEntityId == medicationID &&
                event.startDate >= dayStart && event.startDate < dayEnd
        }))
        let markerPrefix = "petMedicationScheduledDose:\(Int64(dayStart.timeIntervalSince1970)):"
        let plannedIndices = Set(dayEvents.flatMap(\.completedOccurrences).compactMap { marker -> Int? in
            guard marker.hasPrefix(markerPrefix) else { return nil }
            return Int(marker.dropFirst(markerPrefix.count))
        })
        if plannedIndices.contains(occurrence.doseIndex) {
            return dayEvents.first { $0.completedOccurrences.contains(occurrence.marker(calendar: calendar)) }
        }
        let manualEvents = dayEvents.filter { event in
            !event.completedOccurrences.contains { $0.hasPrefix(markerPrefix) }
        }
        let unfilledThroughIndex = (0 ... occurrence.doseIndex).count(where: { !plannedIndices.contains($0) })
        return manualEvents.count >= unfilledThroughIndex ? manualEvents.first : nil
    }

    @MainActor
    private static func prepareRemainingAmountDecrement(_ medication: PetMedication) -> PendingMedicationDoseStorageWrite {
        let current = PetMedicationPlanStorageKeys.remainingAmountValue(medication: medication)
        guard current > 0 else { return .none }
        let next = max(0, current - 1)
        medication.remainingAmount = next
        return .setDouble(
            key: PetMedicationPlanStorageKeys.remainingAmount(medicationID: medication.id),
            value: next
        )
    }

    @MainActor
    private static func resolvedConfirmedExecutor(
        executorId: String?,
        context: ModelContext
    ) -> EconomyRewardOwnerResolution? {
        if let executorId,
           EconomyRewardOwnerResolver.explicitHuman(
               id: executorId,
               context: context,
               logPrefix: "PetMedicationDoseLogging.confirmedExecutor"
           ) == nil {
            return nil
        }
        return CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "PetMedicationDoseLogging"
        )
    }

    private static func rejectedConfirmedExecutorResult(
        previewIntent: DomainScheduleCreateIntent
    ) -> RecordDoseResult {
        RecordDoseResult(
            event: DomainScheduleWriter.makeUnpersistedEvent(intent: previewIntent),
            didRecord: false,
            coconutDelta: 0,
            allowsDerivedEffects: false,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }
}

private enum PendingMedicationDoseStorageWrite {
    case none
    case setDouble(key: String, value: Double)

    func commit(defaults: UserDefaults = .standard) {
        switch self {
        case .none:
            break
        case let .setDouble(key, value):
            defaults.set(value, forKey: key)
        }
    }
}
