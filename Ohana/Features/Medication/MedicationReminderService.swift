//
//  MedicationReminderService.swift
//  Ohana
//
//  P0: 用药提醒服务 — 按频次注册每日定时推送，并跟踪今日服药进度
//

import Foundation
import SwiftData
import UserNotifications

private final class MedicationReminderContextBox: @unchecked Sendable {
    let context: ModelContext?

    init(_ context: ModelContext?) {
        self.context = context
    }
}

@MainActor
protocol MedicationLocalNotificationCenterScheduling: AnyObject {
    var medicationNotificationMutationDomain: String { get }
    func pendingRequests() async -> [UNNotificationRequest]
    func deliveredRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
    func removeDeliveredRequests(withIdentifiers identifiers: [String])
}

extension MedicationLocalNotificationCenterScheduling {
    var medicationNotificationMutationDomain: String {
        "instance:\(ObjectIdentifier(self))"
    }
}

@MainActor
final class SystemMedicationLocalNotificationCenter: MedicationLocalNotificationCenterScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var medicationNotificationMutationDomain: String { "system.medication.notifications" }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func deliveredRequests() async -> [UNNotificationRequest] {
        await center.deliveredNotifications().map(\.request)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredRequests(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

// MARK: - 今日服药进度追踪 Key

extension MedicationReminderService {
    /// UserDefaults key for today's dose log: "med_doses_YYYY-MM-dd_<medicationId>"
    static func dosesKey(medicationId: UUID) -> String {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return "med_doses_\(today)_\(medicationId.uuidString)"
    }

    /// 今日已服次数
    static func dosesTakenToday(for medicationId: UUID) -> Int {
        UserDefaults.standard.integer(forKey: dosesKey(medicationId: medicationId))
    }

    /// 记录一次服药
    static func recordDose(for medicationId: UUID) {
        let key = dosesKey(medicationId: medicationId)
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }

    /// 撤销最后一次服药（undo）
    static func undoDose(for medicationId: UUID) {
        let key = dosesKey(medicationId: medicationId)
        let current = UserDefaults.standard.integer(forKey: key)
        if current > 0 {
            UserDefaults.standard.set(current - 1, forKey: key)
        }
    }
}

/// One process-wide ordering boundary for every medication notification
/// mutation. Foreground services and BG refreshes use different service
/// instances, so instance-local generations cannot protect privacy changes.
@MainActor
private enum MedicationNotificationMutationCoordinator {
    private struct State {
        var generation = 0
        var tail: Task<Void, Never>?
    }

    private static var states: [String: State] = [:]

    static func generation(for domain: String) -> Int {
        states[domain]?.generation ?? 0
    }

    static func tail(for domain: String) -> Task<Void, Never>? {
        states[domain]?.tail
    }

    static func setTail(_ tail: Task<Void, Never>, for domain: String) {
        var state = states[domain] ?? State()
        state.tail = tail
        states[domain] = state
    }

    @discardableResult
    static func invalidate(_ domain: String) -> Int {
        var state = states[domain] ?? State()
        state.generation &+= 1
        states[domain] = state
        return state.generation
    }
}

private struct MedicationNotificationRequestPlan {
    let request: UNNotificationRequest
    let scheduledAt: Date
    let subjectKind: CareLedgerSubjectKind
    let subjectID: String
    let medicationID: String
    let medicationName: String
    let scheduledActionType: String
    let ownerHumanID: UUID?
}

private struct MedicationNotificationScheduleBatchResult {
    let scheduledCount: Int
    let failureDescriptions: [String]
}

// MARK: - Reminder Service

@MainActor
final class MedicationReminderService {
    static let humanRollingWindowDayCount = 14

    private let notificationCenter: MedicationLocalNotificationCenterScheduling
    private let careLedger: CareLedgerRecording
    private let privacyDefaults: UserDefaults
    private var knownScheduledPetIDs: Set<UUID> = []
    private var knownScheduledHumanIDs: Set<UUID> = []

    private var mutationDomain: String {
        notificationCenter.medicationNotificationMutationDomain
    }

    init(
        careLedger: CareLedgerRecording = CareLedgerService(),
        notificationCenter: MedicationLocalNotificationCenterScheduling? = nil,
        privacyDefaults: UserDefaults = .standard
    ) {
        self.careLedger = careLedger
        self.notificationCenter = notificationCenter ?? SystemMedicationLocalNotificationCenter()
        self.privacyDefaults = privacyDefaults
    }

    /// Synchronously supersedes any in-flight plan built with older privacy
    /// state. The follow-up reconciliation can then safely run asynchronously.
    func invalidateNotificationMutations() {
        MedicationNotificationMutationCoordinator.invalidate(mutationDomain)
    }
}

@MainActor
extension MedicationReminderService {
    // MARK: - 调度单个宠物的用药通知（覆盖替换）

    func scheduleMedicationReminders(for pet: Pet, context: ModelContext? = nil) {
        let write = context.flatMap { context in
            DomainEffectWriteAuthorizer.authorizePetEffect(
                pet: pet,
                writeKind: .care,
                source: .domainService,
                context: context,
                logPrefix: "MedicationReminderService"
            )
        }
        guard context == nil || write != nil else {
            cancelMedicationReminders(for: pet.id)
            return
        }
        let hidesDetails = MedicationNotificationPrivacyStore.hidesMedicationDetails(defaults: privacyDefaults)
        let plans = petNotificationPlans(for: pet, hidesDetails: hidesDetails)
        knownScheduledPetIDs.insert(pet.id)
        enqueueNotificationReplacement { generation in
            await self.replacePendingMedicationNotifications(
                matching: MedicationNotificationIdentifierPolicy.petReminderPrefixes(for: pet.id),
                with: plans,
                write: write,
                context: context,
                expectedGeneration: generation
            )
        }
    }

    private func petNotificationPlans(
        for pet: Pet,
        hidesDetails: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MedicationNotificationRequestPlan] {
        pet.medications
            .filter { $0.isActive(on: now) }
            .flatMap { medication in
                petNotificationPlans(
                    for: medication,
                    pet: pet,
                    hidesDetails: hidesDetails,
                    now: now,
                    calendar: calendar
                )
            }
    }

    private func petNotificationPlans(
        for medication: PetMedication,
        pet: Pet,
        hidesDetails: Bool,
        now: Date,
        calendar: Calendar
    ) -> [MedicationNotificationRequestPlan] {
        let dosesPerDay = medication.frequency.dosesPerDay
        guard dosesPerDay > 0 else { return [] }

        var baseComponents = calendar.dateComponents([.year, .month, .day], from: now)
        baseComponents.hour = 0
        baseComponents.minute = 0
        baseComponents.second = 0
        guard let baseTime = calendar.date(from: baseComponents) else { return [] }

        let doseMinutes = PetMedicationSchedulePlan.doseMinutes(for: medication, required: dosesPerDay)
        let l = L10n.current
        let genericBody = l.tr(
            zh: "请打开 Ohana 查看用药详情。",
            en: "Open Ohana to view medication details.",
            de: "Öffne Ohana, um Medikamentendetails anzusehen."
        )
        var plans: [MedicationNotificationRequestPlan] = []

        outerLoop: for day in 0 ..< 14 {
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: baseTime) else { continue }
            if medication.frequency == .everyOtherDay {
                let daysSinceStart = calendar.dateComponents([.day], from: medication.startDate, to: dayDate).day ?? 0
                if daysSinceStart % 2 != 0 { continue }
            }

            for doseIndex in 0 ..< dosesPerDay {
                let minute = doseMinutes.indices.contains(doseIndex) ? doseMinutes[doseIndex] : 8 * 60
                let fireDate = dayDate.addingTimeInterval(Double(minute) * 60)
                guard fireDate > now else { continue }
                if let endDate = medication.endDate, fireDate > endDate { break outerLoop }

                let content = UNMutableNotificationContent()
                content.title = l.tr(zh: "宠物用药提醒", en: "Pet medication reminder", de: "Medikamentenerinnerung")
                content.body = MedicationNotificationContentPolicy.body(
                    hidesDetails: hidesDetails,
                    generic: genericBody,
                    detailed: "\(pet.name) · \(medication.name) · \(medication.dosage)"
                )
                content.sound = .default
                let classification = NotificationDeliveryClassification(
                    tier: .healthCritical,
                    category: .medication,
                    mergeAllowed: false
                )
                content.userInfo = [
                    "medicationId": medication.id.uuidString,
                    "petId": pet.id.uuidString,
                    "scheduledAt": fireDate.timeIntervalSince1970,
                    "doseIndex": doseIndex,
                    "eventType": EventType.petMedication.rawValue,
                    "relatedEntityType": DomainEntityLinkRegistry.petMedicationPlan,
                    "relatedEntityId": medication.id.uuidString
                ]
                .merging(MedicationNotificationPrivacyMarker.userInfo(hidesDetails: hidesDetails)) { _, new in new }
                .merging(NotificationDeliveryPolicy.userInfo(for: classification)) { _, new in new }
                content.categoryIdentifier = "MED_REMINDER"

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "medreminder_\(pet.id.uuidString)_\(medication.id.uuidString)_d\(day)_i\(doseIndex)"
                plans.append(MedicationNotificationRequestPlan(
                    request: UNNotificationRequest(identifier: identifier, content: content, trigger: trigger),
                    scheduledAt: fireDate,
                    subjectKind: .pet,
                    subjectID: pet.id.uuidString,
                    medicationID: medication.id.uuidString,
                    medicationName: medication.name,
                    scheduledActionType: "medicationScheduleSuccess",
                    ownerHumanID: nil
                ))
            }
        }

        if let endPlan = petMedicationEndNotificationPlan(
            for: medication,
            pet: pet,
            hidesDetails: hidesDetails,
            genericBody: genericBody,
            now: now,
            calendar: calendar
        ) {
            plans.append(endPlan)
        }
        return plans
    }

    private func petMedicationEndNotificationPlan(
        for medication: PetMedication,
        pet: Pet,
        hidesDetails: Bool,
        genericBody: String,
        now: Date,
        calendar: Calendar
    ) -> MedicationNotificationRequestPlan? {
        guard let endDate = medication.endDate,
              let alertDate = calendar.date(byAdding: .day, value: -3, to: endDate),
              alertDate > now else { return nil }

        let l = L10n.current
        let content = UNMutableNotificationContent()
        content.title = l.tr(zh: "用药即将结束", en: "Medication ending soon", de: "Medikation endet bald")
        content.body = MedicationNotificationContentPolicy.body(
            hidesDetails: hidesDetails,
            generic: genericBody,
            detailed: l.tr(
                zh: "\(pet.name) · \(medication.name) 疗程还剩 3 天，请确认是否续药",
                en: "\(pet.name) · \(medication.name) has 3 days left. Check whether to renew.",
                de: "\(pet.name) · \(medication.name) endet in 3 Tagen. Bitte Verlängerung prüfen."
            )
        )
        content.sound = .default
        let classification = NotificationDeliveryClassification(
            tier: .healthCritical,
            category: .medication,
            mergeAllowed: false
        )
        content.userInfo = [
            "medicationId": medication.id.uuidString,
            "petId": pet.id.uuidString,
            "eventType": EventType.petMedication.rawValue,
            "relatedEntityType": DomainEntityLinkRegistry.petMedicationPlan,
            "relatedEntityId": medication.id.uuidString
        ]
        .merging(MedicationNotificationPrivacyMarker.userInfo(hidesDetails: hidesDetails)) { _, new in new }
        .merging(NotificationDeliveryPolicy.userInfo(for: classification)) { _, new in new }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "medend_\(pet.id.uuidString)_\(medication.id.uuidString)"
        return MedicationNotificationRequestPlan(
            request: UNNotificationRequest(identifier: identifier, content: content, trigger: trigger),
            scheduledAt: alertDate,
            subjectKind: .pet,
            subjectID: pet.id.uuidString,
            medicationID: medication.id.uuidString,
            medicationName: medication.name,
            scheduledActionType: "medicationEndScheduleSuccess",
            ownerHumanID: nil
        )
    }

    // MARK: - 取消某只宠物所有用药通知

    func cancelMedicationReminders(for petId: UUID) {
        knownScheduledPetIDs.remove(petId)
        let prefixes = MedicationNotificationIdentifierPolicy.petReminderPrefixes(for: petId)
        enqueueNotificationCancellation(matching: prefixes)
    }
}

@MainActor
extension MedicationReminderService {
    // MARK: - 调度单个人的用药通知

    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication], context: ModelContext? = nil) {
        let write = context.flatMap { context in
            DomainEffectWriteAuthorizer.authorizeHumanEffect(
                human: human,
                writeKind: .care,
                source: .domainService,
                context: context,
                logPrefix: "MedicationReminderService"
            )
        }
        guard context == nil || write != nil else {
            cancelHumanMedicationReminders(for: human.id)
            return
        }
        let globallyHidden = MedicationNotificationPrivacyStore.hidesMedicationDetails(defaults: privacyDefaults)
        let plans = humanNotificationPlans(
            for: human,
            medications: meds,
            globallyHidden: globallyHidden
        )
        knownScheduledHumanIDs.insert(human.id)
        enqueueNotificationReplacement { generation in
            await self.replacePendingMedicationNotifications(
                matching: [MedicationNotificationIdentifierPolicy.humanReminderPrefix(for: human.id)],
                with: plans,
                write: write,
                context: context,
                expectedGeneration: generation
            )
        }
    }

    /// Reconciles a bounded batch of Human reminder owners against the next
    /// rolling window. Existing matching requests are preserved, so startup,
    /// foreground, and background triggers can safely repeat this operation.
    func reconcileHumanMedicationRollingWindow(
        context: ModelContext,
        budget: OhanaBackgroundWorkBudget,
        now: Date = Date()
    ) async -> HumanMedicationReminderRollingRefreshResult {
        guard budget.hasWorkCapacity else { return .deferred }

        let generation = MedicationNotificationMutationCoordinator.invalidate(mutationDomain)
        let previous = MedicationNotificationMutationCoordinator.tail(for: mutationDomain)
        let refreshTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return HumanMedicationReminderRollingRefreshResult.deferred }
            return await self.performHumanMedicationRollingReconciliation(
                context: context,
                budget: budget,
                now: now,
                expectedGeneration: generation
            )
        }
        MedicationNotificationMutationCoordinator.setTail(Task { @MainActor in
            _ = await refreshTask.value
        }, for: mutationDomain)
        return await refreshTask.value
    }

    private func performHumanMedicationRollingReconciliation(
        context: ModelContext,
        budget: OhanaBackgroundWorkBudget,
        now: Date,
        expectedGeneration: Int
    ) async -> HumanMedicationReminderRollingRefreshResult {
        let startedAt = Date()
        let pendingRequests = await notificationCenter.pendingRequests()
        guard expectedGeneration == MedicationNotificationMutationCoordinator.generation(for: mutationDomain) else {
            return HumanMedicationReminderRollingRefreshResult(
                removedNotificationCount: 0,
                scheduledNotificationCount: 0,
                hasMoreWork: true,
                wasDeferred: false,
                failureDescriptions: ["Human medication reminder refresh was superseded."]
            )
        }

        let batchLimit = max(1, budget.maximumItemCount)
        let previousOffset = HumanMedicationReminderRollingCursorStore.offset(defaults: privacyDefaults)
        let medications: [HumanMedication]
        do {
            medications = try fetchHumanMedicationRollingBatch(
                context: context,
                offset: previousOffset,
                limit: batchLimit
            )
        } catch {
            HumanMedicationReminderRollingCursorStore.record(
                nextOffset: previousOffset > 0 ? previousOffset : nil,
                needsRetry: true,
                defaults: privacyDefaults
            )
            return HumanMedicationReminderRollingRefreshResult(
                removedNotificationCount: 0,
                scheduledNotificationCount: 0,
                hasMoreWork: true,
                wasDeferred: false,
                failureDescriptions: [error.localizedDescription]
            )
        }

        let globallyHidden = MedicationNotificationPrivacyStore.hidesMedicationDetails(
            defaults: privacyDefaults
        )
        let desiredState = humanMedicationRollingDesiredState(
            medications: medications,
            context: context,
            globallyHidden: globallyHidden,
            now: now,
            budget: budget,
            startedAt: startedAt
        )
        let desiredPlans = desiredState.plans

        let pendingIDs = Set(pendingRequests.map(\.identifier))
        let pendingByID = Dictionary(uniqueKeysWithValues: pendingRequests.map { ($0.identifier, $0) })
        let pendingHumanIDs = Set(pendingIDs.filter {
            MedicationNotificationIdentifierPolicy.isHumanReminder($0)
        })
        let desiredIDs = Set(desiredPlans.map(\.request.identifier))
        let managedExistingIDs = managedHumanMedicationNotificationIDs(
            pendingHumanIDs,
            processedMedicationIDs: desiredState.processedMedicationIDs,
            context: context,
            now: now
        )
        let stalePrivacyMarkerIDs = Set(desiredPlans.compactMap { plan -> String? in
            guard let pending = pendingByID[plan.request.identifier],
                  !MedicationNotificationPrivacyMarker.matches(
                      pending.content,
                      desired: plan.request.content
                  ) else { return nil }
            return plan.request.identifier
        })
        let identifiersToRemove = Set(managedExistingIDs)
            .subtracting(desiredIDs)
            .union(stalePrivacyMarkerIDs)
        if !identifiersToRemove.isEmpty {
            notificationCenter.removePendingRequests(withIdentifiers: identifiersToRemove.sorted())
        }

        let remainingPendingIDs = pendingIDs.subtracting(identifiersToRemove)
        let allMissingPlans = desiredPlans.filter {
            !remainingPendingIDs.contains($0.request.identifier)
        }
        let availableNotificationSlots = max(
            0,
            NotificationPendingBudget.managedPendingRequestLimit - remainingPendingIDs.count
        )
        let notificationWorkLimit = min(budget.maximumItemCount, availableNotificationSlots)
        let missingPlans = Array(allMissingPlans.prefix(notificationWorkLimit))
        let truncatedByWorkBudget = allMissingPlans.count > missingPlans.count
            && notificationWorkLimit == budget.maximumItemCount
            && availableNotificationSlots > budget.maximumItemCount
        let batch = await scheduleNotificationPlans(
            missingPlans,
            existingNotificationIDs: remainingPendingIDs,
            write: nil,
            context: nil,
            expectedGeneration: expectedGeneration
        )

        let continuation = humanMedicationRollingContinuation(
            previousOffset: previousOffset,
            processedMedicationCount: desiredState.processedMedicationIDs.count,
            fetchedMedicationCount: medications.count,
            batchLimit: batchLimit,
            truncatedByWorkBudget: truncatedByWorkBudget,
            hasSchedulingFailures: !batch.failureDescriptions.isEmpty
        )
        HumanMedicationReminderRollingCursorStore.record(
            nextOffset: continuation.nextOffset,
            needsRetry: continuation.needsRetry,
            defaults: privacyDefaults
        )

        return HumanMedicationReminderRollingRefreshResult(
            removedNotificationCount: identifiersToRemove.count,
            scheduledNotificationCount: batch.scheduledCount,
            hasMoreWork: continuation.nextOffset != nil || continuation.needsRetry,
            wasDeferred: false,
            failureDescriptions: batch.failureDescriptions
        )
    }

    private func fetchHumanMedicationRollingBatch(
        context: ModelContext,
        offset: Int,
        limit: Int
    ) throws -> [HumanMedication] {
        var descriptor = FetchDescriptor<HumanMedication>(
            sortBy: [SortDescriptor(\HumanMedication.createdAt)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    private func humanMedicationRollingDesiredState(
        medications: [HumanMedication],
        context: ModelContext,
        globallyHidden: Bool,
        now: Date,
        budget: OhanaBackgroundWorkBudget,
        startedAt: Date
    ) -> (
        processedMedicationIDs: Set<UUID>,
        plans: [MedicationNotificationRequestPlan]
    ) {
        var processedMedicationIDs: Set<UUID> = []
        var plans: [MedicationNotificationRequestPlan] = []
        for medication in medications {
            guard budget.hasTimeRemaining(since: startedAt), !Task.isCancelled else { break }
            processedMedicationIDs.insert(medication.id)
            guard let humanID = UUID(
                uuidString: medication.humanId.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
                let human = try? fetchHuman(id: humanID, context: context),
                MemberWritePolicy.disposition(
                    human: human,
                    intent: .activeOnly
                ).allowsDerivedEffects else {
                continue
            }
            plans.append(contentsOf: humanNotificationPlans(
                for: medication,
                human: human,
                globallyHidden: globallyHidden,
                now: now
            ))
        }
        plans.sort { lhs, rhs in
            if lhs.scheduledAt != rhs.scheduledAt {
                return lhs.scheduledAt < rhs.scheduledAt
            }
            return lhs.request.identifier < rhs.request.identifier
        }
        return (processedMedicationIDs, plans)
    }

    private func managedHumanMedicationNotificationIDs(
        _ pendingHumanIDs: Set<String>,
        processedMedicationIDs: Set<UUID>,
        context: ModelContext,
        now: Date
    ) -> Set<String> {
        var managedExistingIDs: Set<String> = []
        for identifier in pendingHumanIDs {
            guard let ownerID = MedicationNotificationIdentifierPolicy.humanReminderOwnerID(
                in: identifier
            ),
                let medicationID = MedicationNotificationIdentifierPolicy.humanReminderMedicationID(
                    in: identifier
                ) else {
                managedExistingIDs.insert(identifier)
                continue
            }
            if processedMedicationIDs.contains(medicationID) {
                managedExistingIDs.insert(identifier)
                continue
            }

            guard let medication = try? fetchMedication(id: medicationID, context: context),
                  UUID(uuidString: medication.humanId.trimmingCharacters(in: .whitespacesAndNewlines)) == ownerID,
                  medication.isActive,
                  !medication.frequency.isManualEntry,
                  !HumanMedicationSchedulePlan.futureDoses(
                      for: medication,
                      from: now,
                      days: Self.humanRollingWindowDayCount
                  ).isEmpty,
                  let human = try? fetchHuman(id: ownerID, context: context),
                  MemberWritePolicy.disposition(
                      human: human,
                      intent: .activeOnly
                  ).allowsDerivedEffects else {
                managedExistingIDs.insert(identifier)
                continue
            }
        }
        return managedExistingIDs
    }

    private func humanMedicationRollingContinuation(
        previousOffset: Int,
        processedMedicationCount: Int,
        fetchedMedicationCount: Int,
        batchLimit: Int,
        truncatedByWorkBudget: Bool,
        hasSchedulingFailures: Bool
    ) -> (nextOffset: Int?, needsRetry: Bool) {
        let stoppedBeforeCompletingBatch = processedMedicationCount < fetchedMedicationCount
        let exhaustedBatch = processedMedicationCount == fetchedMedicationCount
            && fetchedMedicationCount == batchLimit
        let mustRetryCurrentBatch = truncatedByWorkBudget || hasSchedulingFailures
        let nextOffset: Int? = if mustRetryCurrentBatch {
            previousOffset > 0 ? previousOffset : nil
        } else if stoppedBeforeCompletingBatch || exhaustedBatch {
            previousOffset + processedMedicationCount
        } else {
            nil
        }
        return (
            nextOffset: nextOffset,
            needsRetry: stoppedBeforeCompletingBatch || mustRetryCurrentBatch
        )
    }

    private func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchMedication(id: UUID, context: ModelContext) throws -> HumanMedication? {
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func humanNotificationPlans(
        for human: Human,
        medications: [HumanMedication],
        globallyHidden: Bool,
        now: Date = Date()
    ) -> [MedicationNotificationRequestPlan] {
        medications
            .flatMap { medication in
                humanNotificationPlans(
                    for: medication,
                    human: human,
                    globallyHidden: globallyHidden,
                    now: now
                )
            }
            .sorted { lhs, rhs in
                if lhs.scheduledAt != rhs.scheduledAt {
                    return lhs.scheduledAt < rhs.scheduledAt
                }
                return lhs.request.identifier < rhs.request.identifier
            }
    }

    private func humanNotificationPlans(
        for medication: HumanMedication,
        human: Human,
        globallyHidden: Bool,
        now: Date
    ) -> [MedicationNotificationRequestPlan] {
        let doses = HumanMedicationSchedulePlan.futureDoses(
            for: medication,
            from: now,
            days: Self.humanRollingWindowDayCount
        )
        guard !doses.isEmpty else { return [] }

        let l = L10n.current
        // Lock-screen content honors the persisted field even when the wider
        // multi-member privacy UI is disabled for the local-first release.
        let memberMedicationIsPrivate = human.privateFields
            .contains(HumanPrivateField.medication.rawValue)
        let hidesMedicationDetails = MedicationNotificationContentPolicy.hidesHumanDetails(
            globalPreference: globallyHidden,
            memberMedicationIsPrivate: memberMedicationIsPrivate
        )
        let genericBody = l.tr(
            zh: "请打开 Ohana 查看用药详情。",
            en: "Open Ohana to view medication details.",
            de: "Öffne Ohana, um Medikamentendetails anzusehen."
        )

        return doses.map { dose in
            let fireDate = dose.scheduledTime
            let content = UNMutableNotificationContent()
            content.title = l.tr(zh: "吃药提醒", en: "Medication reminder", de: "Medikamentenerinnerung")
            content.body = MedicationNotificationContentPolicy.body(
                hidesDetails: hidesMedicationDetails,
                generic: genericBody,
                detailed: "\(medication.name) · \(medication.dosage)"
            )
            content.sound = .default
            let classification = NotificationDeliveryClassification(tier: .healthCritical, category: .medication, mergeAllowed: false)
            content.userInfo = [
                "humanMedicationId": medication.id.uuidString,
                "humanId": human.id.uuidString,
                "scheduledAt": fireDate.timeIntervalSince1970,
                "doseIndex": dose.doseIndex,
                "eventType": EventType.medication.rawValue,
                "relatedEntityType": DomainEntityLinkRegistry.humanMedicationPlan,
                "relatedEntityId": medication.id.uuidString
            ]
            .merging(MedicationNotificationPrivacyMarker.userInfo(hidesDetails: hidesMedicationDetails)) { _, new in new }
            .merging(NotificationDeliveryPolicy.userInfo(for: classification)) { _, new in new }
            content.categoryIdentifier = "HUMAN_MED_REMINDER"

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let minuteKey = Int(fireDate.timeIntervalSince1970 / 60)
            let identifier = "humanmedreminder_\(human.id.uuidString)_\(medication.id.uuidString)_m\(minuteKey)_i\(dose.doseIndex)"
            let medicationName = hidesMedicationDetails
                ? l.tr(zh: "隐私用药", en: "Private medication", de: "Privates Medikament")
                : medication.name
            return MedicationNotificationRequestPlan(
                request: UNNotificationRequest(identifier: identifier, content: content, trigger: trigger),
                scheduledAt: fireDate,
                subjectKind: .human,
                subjectID: human.id.uuidString,
                medicationID: medication.id.uuidString,
                medicationName: medicationName,
                scheduledActionType: "medicationScheduleSuccess",
                ownerHumanID: human.id
            )
        }
    }
}

@MainActor
extension MedicationReminderService {
    private func replacePendingMedicationNotifications(
        matching prefixes: [String],
        with plans: [MedicationNotificationRequestPlan],
        write: AuthorizedDomainEffectWrite?,
        context: ModelContext?,
        expectedGeneration: Int
    ) async {
        let requests = await notificationCenter.pendingRequests()
        guard expectedGeneration == MedicationNotificationMutationCoordinator.generation(for: mutationDomain) else { return }
        let identifiersToRemove = requests
            .map(\.identifier)
            .filter { identifier in prefixes.contains { identifier.hasPrefix($0) } }
        notificationCenter.removePendingRequests(withIdentifiers: identifiersToRemove)
        let knownNotificationIDs = Set(requests.map(\.identifier)).subtracting(identifiersToRemove)
        _ = await scheduleNotificationPlans(
            plans,
            existingNotificationIDs: knownNotificationIDs,
            write: write,
            context: context,
            expectedGeneration: expectedGeneration
        )
    }

    private func enqueueNotificationReplacement(
        _ operation: @escaping @MainActor (Int) async -> Void
    ) {
        let generation = MedicationNotificationMutationCoordinator.generation(for: mutationDomain)
        let previous = MedicationNotificationMutationCoordinator.tail(for: mutationDomain)
        let task = Task { @MainActor [weak self] in
            await previous?.value
            guard let self,
                  generation == MedicationNotificationMutationCoordinator.generation(for: self.mutationDomain) else { return }
            await operation(generation)
        }
        MedicationNotificationMutationCoordinator.setTail(task, for: mutationDomain)
    }

    private func enqueueNotificationCancellation(matching prefixes: [String]) {
        let previous = MedicationNotificationMutationCoordinator.tail(for: mutationDomain)
        let task = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            let requests = await self.notificationCenter.pendingRequests()
            let identifiers = requests
                .map(\.identifier)
                .filter { identifier in prefixes.contains { identifier.hasPrefix($0) } }
            self.notificationCenter.removePendingRequests(withIdentifiers: identifiers)
        }
        MedicationNotificationMutationCoordinator.setTail(task, for: mutationDomain)
    }

    private func scheduleNotificationPlans(
        _ plans: [MedicationNotificationRequestPlan],
        existingNotificationIDs: Set<String>,
        write: AuthorizedDomainEffectWrite?,
        context: ModelContext?,
        expectedGeneration: Int
    ) async -> MedicationNotificationScheduleBatchResult {
        var knownNotificationIDs = existingNotificationIDs
        var scheduledCount = 0
        var failureDescriptions: [String] = []

        for plan in plans {
            guard expectedGeneration == MedicationNotificationMutationCoordinator.generation(for: mutationDomain) else {
                failureDescriptions.append("Medication notification refresh was superseded.")
                break
            }
            let notificationID = plan.request.identifier
            guard MedicationNotificationMutationFence.allowsHuman(plan.ownerHumanID) else {
                notificationCenter.removePendingRequests(withIdentifiers: [notificationID])
                failureDescriptions.append("\(notificationID): deletedHuman")
                continue
            }
            let reservation = MedicationNotificationBudget.reserve(
                notificationId: notificationID,
                existingNotificationIds: &knownNotificationIDs
            )
            guard reservation == .scheduled else {
                failureDescriptions.append("\(notificationID): \(reservation.ledgerActionType)")
                if context != nil, write != nil {
                    recordMedicationScheduleResult(
                        contextBox: MedicationReminderContextBox(context),
                        write: write,
                        subjectKind: plan.subjectKind,
                        subjectId: plan.subjectID,
                        medicationId: plan.medicationID,
                        medicationName: plan.medicationName,
                        actionType: MedicationNotificationBudget.skippedActionType(
                            for: reservation,
                            scheduledActionType: plan.scheduledActionType
                        ),
                        metadataJSON: MedicationNotificationBudget.metadataJSON(
                            for: reservation,
                            notificationId: notificationID,
                            scheduledAt: plan.scheduledAt
                        )
                    )
                }
                continue
            }

            let result: ReminderNotificationScheduleResult
            do {
                try await notificationCenter.add(plan.request)
                guard expectedGeneration == MedicationNotificationMutationCoordinator.generation(for: mutationDomain),
                      MedicationNotificationMutationFence.allowsHuman(plan.ownerHumanID) else {
                    notificationCenter.removePendingRequests(withIdentifiers: [notificationID])
                    failureDescriptions.append("Medication notification refresh was superseded.")
                    break
                }
                scheduledCount += 1
                result = .scheduled
            } catch {
                knownNotificationIDs.remove(notificationID)
                failureDescriptions.append("\(notificationID): \(error.localizedDescription)")
                result = .failed(error.localizedDescription)
            }

            if context != nil, write != nil {
                recordMedicationScheduleResult(
                    contextBox: MedicationReminderContextBox(context),
                    write: write,
                    subjectKind: plan.subjectKind,
                    subjectId: plan.subjectID,
                    medicationId: plan.medicationID,
                    medicationName: plan.medicationName,
                    actionType: MedicationNotificationBudget.skippedActionType(
                        for: result,
                        scheduledActionType: plan.scheduledActionType
                    ),
                    metadataJSON: MedicationNotificationBudget.metadataJSON(
                        for: result,
                        notificationId: notificationID,
                        scheduledAt: plan.scheduledAt
                    )
                )
            }
        }

        return MedicationNotificationScheduleBatchResult(
            scheduledCount: scheduledCount,
            failureDescriptions: failureDescriptions
        )
    }
}

@MainActor
extension MedicationReminderService {
    func refreshScheduledMedicationReminders(
        context: ModelContext,
        hidingDetails: Bool
    ) async -> MedicationNotificationPrivacyRefreshResult {
        let generation = MedicationNotificationMutationCoordinator.invalidate(mutationDomain)
        let previous = MedicationNotificationMutationCoordinator.tail(for: mutationDomain)
        let refreshTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return MedicationNotificationPrivacyRefreshResult.unavailable }
            return await self.performPrivacyRefresh(
                context: context,
                hidingDetails: hidingDetails,
                expectedGeneration: generation
            )
        }
        MedicationNotificationMutationCoordinator.setTail(Task { @MainActor in
            _ = await refreshTask.value
        }, for: mutationDomain)
        return await refreshTask.value
    }

    /// Repairs a privacy replacement that was interrupted after the setting or
    /// member profile was persisted. This is intentionally cheap when every
    /// pending request already carries the expected versioned marker.
    func recoverMedicationNotificationPrivacyIfNeeded(
        context: ModelContext
    ) async -> MedicationNotificationPrivacyRefreshResult {
        let generation = MedicationNotificationMutationCoordinator.invalidate(mutationDomain)
        let previous = MedicationNotificationMutationCoordinator.tail(for: mutationDomain)
        let recoveryTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return MedicationNotificationPrivacyRefreshResult.unavailable }
            let hidingDetails = MedicationNotificationPrivacyStore.hidesMedicationDetails(
                defaults: self.privacyDefaults
            )
            guard await self.requiresPrivacyRecovery(
                context: context,
                globallyHidden: hidingDetails,
                expectedGeneration: generation
            ) else {
                return MedicationNotificationPrivacyRefreshResult(
                    replacedNotificationCount: 0,
                    scheduledNotificationCount: 0,
                    didFailSafeCancel: false,
                    failureDescriptions: []
                )
            }
            return await self.performPrivacyRefresh(
                context: context,
                hidingDetails: hidingDetails,
                expectedGeneration: generation
            )
        }
        MedicationNotificationMutationCoordinator.setTail(Task { @MainActor in
            _ = await recoveryTask.value
        }, for: mutationDomain)
        return await recoveryTask.value
    }

    private func requiresPrivacyRecovery(
        context: ModelContext,
        globallyHidden: Bool,
        expectedGeneration: Int
    ) async -> Bool {
        if MedicationNotificationRefreshScopeStore.load(defaults: privacyDefaults) != nil {
            return true
        }

        let pendingRequests = await notificationCenter.pendingRequests()
        let deliveredRequests = await notificationCenter.deliveredRequests()
        guard expectedGeneration == MedicationNotificationMutationCoordinator.generation(for: mutationDomain) else {
            return false
        }
        let requests = pendingRequests + deliveredRequests
        let medicationIDs = MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(requests.map(\.identifier))
        )
        var memberPrivacyCache: [UUID: Bool] = [:]

        for request in requests where medicationIDs.contains(request.identifier) {
            if MedicationNotificationIdentifierPolicy.isHumanReminder(request.identifier) {
                guard let humanID = MedicationNotificationIdentifierPolicy.humanReminderOwnerID(
                    in: request.identifier
                ) else { return true }
                let memberIsPrivate: Bool
                if let cached = memberPrivacyCache[humanID] {
                    memberIsPrivate = cached
                } else {
                    guard let human = try? fetchHuman(id: humanID, context: context) else { return true }
                    memberIsPrivate = human.privateFields
                        .contains(HumanPrivateField.medication.rawValue)
                    memberPrivacyCache[humanID] = memberIsPrivate
                }
                let shouldHide = MedicationNotificationContentPolicy.hidesHumanDetails(
                    globalPreference: globallyHidden,
                    memberMedicationIsPrivate: memberIsPrivate
                )
                if !MedicationNotificationPrivacyMarker.isCurrent(
                    request.content,
                    hidesDetails: shouldHide
                ) {
                    return true
                }
            } else if !MedicationNotificationPrivacyMarker.isCurrent(
                request.content,
                hidesDetails: globallyHidden
            ) {
                return true
            }
        }
        return false
    }

    private func performPrivacyRefresh(
        context: ModelContext,
        hidingDetails: Bool,
        expectedGeneration: Int
    ) async -> MedicationNotificationPrivacyRefreshResult {
        let pendingRequests = await notificationCenter.pendingRequests()
        let deliveredRequests = await notificationCenter.deliveredRequests()
        guard expectedGeneration == MedicationNotificationMutationCoordinator.generation(for: mutationDomain) else {
            return MedicationNotificationPrivacyRefreshResult(
                replacedNotificationCount: 0,
                scheduledNotificationCount: 0,
                didFailSafeCancel: false,
                failureDescriptions: ["Medication notification refresh was superseded."]
            )
        }
        let pendingIDs = Set(pendingRequests.map(\.identifier))
        let deliveredIDs = Set(deliveredRequests.map(\.identifier))
        let refreshPlan = MedicationNotificationIdentifierPolicy.refreshPlan(
            pendingNotificationIDs: pendingIDs.union(deliveredIDs)
        )
        let targets = medicationPrivacyRefreshTargets(for: refreshPlan)
        let targetPetIDs = targets.petIDs
        let targetHumanIDs = targets.humanIDs
        guard !refreshPlan.notificationIDs.isEmpty || !targetPetIDs.isEmpty || !targetHumanIDs.isEmpty else {
            return MedicationNotificationPrivacyRefreshResult(
                replacedNotificationCount: 0,
                scheduledNotificationCount: 0,
                didFailSafeCancel: false,
                failureDescriptions: []
            )
        }
        MedicationNotificationRefreshScopeStore.save(
            petIDs: targetPetIDs,
            humanIDs: targetHumanIDs,
            defaults: privacyDefaults
        )

        // Remove every old medication request before rebuilding so sensitive
        // content can never survive a failed privacy refresh. Delivered banners
        // must also leave Notification Center because their bodies cannot be
        // edited after delivery.
        notificationCenter.removePendingRequests(
            withIdentifiers: refreshPlan.notificationIDs.sorted()
        )
        notificationCenter.removeDeliveredRequests(
            withIdentifiers: refreshPlan.notificationIDs.sorted()
        )

        let entities: (
            pets: [Pet],
            humans: [Human],
            humanMedications: [HumanMedication]
        )
        do {
            entities = try medicationPrivacyRefreshEntities(
                context: context,
                targetPetIDs: targetPetIDs,
                targetHumanIDs: targetHumanIDs
            )
        } catch {
            if hidingDetails {
                await cancelAllMedicationNotifications()
            }
            return MedicationNotificationPrivacyRefreshResult(
                replacedNotificationCount: refreshPlan.notificationIDs.count,
                scheduledNotificationCount: 0,
                didFailSafeCancel: hidingDetails,
                failureDescriptions: [error.localizedDescription]
            )
        }

        let replacementState = medicationPrivacyRefreshReplacementState(
            entities: entities,
            targetPetIDs: targetPetIDs,
            targetHumanIDs: targetHumanIDs,
            unresolvedNotificationIDs: refreshPlan.unresolvedNotificationIDs,
            hidingDetails: hidingDetails
        )
        var failureDescriptions = replacementState.failureDescriptions
        // Capacity is an expected scheduling boundary, not a privacy failure.
        // Every retained request is removed first, then the globally earliest
        // privacy-safe requests are restored up to the managed iOS budget.
        let boundedState = capacityBoundedPrivacyRefreshPlans(
            replacementState.plans,
            pendingNotificationIDs: pendingIDs,
            removedNotificationIDs: refreshPlan.notificationIDs
        )
        let batch = await scheduleNotificationPlans(
            boundedState.plans,
            existingNotificationIDs: boundedState.remainingNotificationIDs,
            write: nil,
            context: nil,
            expectedGeneration: expectedGeneration
        )
        failureDescriptions.append(contentsOf: batch.failureDescriptions)

        let requiresFailSafeCancellation = hidingDetails && !failureDescriptions.isEmpty
        if requiresFailSafeCancellation {
            await cancelAllMedicationNotifications()
        } else if failureDescriptions.isEmpty, !boundedState.wasTruncatedByCapacity {
            MedicationNotificationRefreshScopeStore.clear(defaults: privacyDefaults)
        }
        return MedicationNotificationPrivacyRefreshResult(
            replacedNotificationCount: refreshPlan.notificationIDs.count,
            scheduledNotificationCount: requiresFailSafeCancellation ? 0 : batch.scheduledCount,
            didFailSafeCancel: requiresFailSafeCancellation,
            failureDescriptions: failureDescriptions
        )
    }

    private func medicationPrivacyRefreshTargets(
        for refreshPlan: MedicationNotificationRefreshPlan
    ) -> (petIDs: Set<UUID>, humanIDs: Set<UUID>) {
        let savedScope = MedicationNotificationRefreshScopeStore.load(defaults: privacyDefaults)
        return (
            refreshPlan.petIDs
                .union(savedScope?.petIDs ?? [])
                .union(knownScheduledPetIDs),
            refreshPlan.humanIDs
                .union(savedScope?.humanIDs ?? [])
                .union(knownScheduledHumanIDs)
        )
    }

    private func medicationPrivacyRefreshEntities(
        context: ModelContext,
        targetPetIDs: Set<UUID>,
        targetHumanIDs: Set<UUID>
    ) throws -> (
        pets: [Pet],
        humans: [Human],
        humanMedications: [HumanMedication]
    ) {
        let pets = targetPetIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<Pet>())
        let humans = targetHumanIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<Human>())
        let humanMedications = targetHumanIDs.isEmpty
            ? []
            : try context.fetch(FetchDescriptor<HumanMedication>())
        return (pets, humans, humanMedications)
    }

    private func medicationPrivacyRefreshReplacementState(
        entities: (
            pets: [Pet],
            humans: [Human],
            humanMedications: [HumanMedication]
        ),
        targetPetIDs: Set<UUID>,
        targetHumanIDs: Set<UUID>,
        unresolvedNotificationIDs: Set<String>,
        hidingDetails: Bool
    ) -> (
        plans: [MedicationNotificationRequestPlan],
        failureDescriptions: [String]
    ) {
        let petByID = Dictionary(uniqueKeysWithValues: entities.pets.map { ($0.id, $0) })
        let humanByID = Dictionary(uniqueKeysWithValues: entities.humans.map { ($0.id, $0) })
        var requestPlans: [MedicationNotificationRequestPlan] = []
        let failureDescriptions = unresolvedNotificationIDs
            .sorted()
            .map { "Unable to resolve medication notification owner for \($0)." }
        let now = Date()

        for petID in targetPetIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let pet = petByID[petID] else { continue }
            guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else { continue }
            requestPlans.append(contentsOf: petNotificationPlans(
                for: pet,
                hidesDetails: hidingDetails,
                now: now
            ))
        }

        for humanID in targetHumanIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let human = humanByID[humanID] else { continue }
            guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else { continue }
            let medications = entities.humanMedications.filter {
                UUID(uuidString: $0.humanId.trimmingCharacters(in: .whitespacesAndNewlines)) == humanID
            }
            requestPlans.append(contentsOf: humanNotificationPlans(
                for: human,
                medications: medications,
                globallyHidden: hidingDetails,
                now: now
            ))
        }

        requestPlans.sort { lhs, rhs in
            if lhs.scheduledAt != rhs.scheduledAt {
                return lhs.scheduledAt < rhs.scheduledAt
            }
            return lhs.request.identifier < rhs.request.identifier
        }
        return (requestPlans, failureDescriptions)
    }

    private func capacityBoundedPrivacyRefreshPlans(
        _ requestPlans: [MedicationNotificationRequestPlan],
        pendingNotificationIDs: Set<String>,
        removedNotificationIDs: Set<String>
    ) -> (
        plans: [MedicationNotificationRequestPlan],
        remainingNotificationIDs: Set<String>,
        wasTruncatedByCapacity: Bool
    ) {
        let remainingNotificationIDs = pendingNotificationIDs.subtracting(removedNotificationIDs)
        let availableNotificationSlots = max(
            0,
            NotificationPendingBudget.managedPendingRequestLimit - remainingNotificationIDs.count
        )
        var plannedNotificationIDs = remainingNotificationIDs
        let uniqueMissingPlans = requestPlans.filter { plan in
            plannedNotificationIDs.insert(plan.request.identifier).inserted
        }
        let plans = Array(uniqueMissingPlans.prefix(availableNotificationSlots))
        return (
            plans,
            remainingNotificationIDs,
            plans.count < uniqueMissingPlans.count
        )
    }

    private func cancelAllMedicationNotifications() async {
        let requests = await notificationCenter.pendingRequests()
        let identifiers = MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(requests.map(\.identifier))
        )
        notificationCenter.removePendingRequests(withIdentifiers: identifiers.sorted())
    }

    private nonisolated func recordMedicationScheduleResult(
        contextBox: MedicationReminderContextBox,
        write: AuthorizedDomainEffectWrite?,
        subjectKind: CareLedgerSubjectKind,
        subjectId: String,
        medicationId: String,
        medicationName: String,
        actionType: String,
        metadataJSON: String
    ) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let context = contextBox.context, let write else { return }
                DomainEffectDispatcher.run(plan: write) { _ in
                    _ = self.careLedger.record(
                        occurredAt: Date(),
                        actorKind: .unknown,
                        actorId: nil,
                        subjectKind: subjectKind,
                        subjectId: subjectId,
                        eventKind: .reminder,
                        actionType: actionType,
                        amountValue: 0,
                        amountUnit: "",
                        note: medicationName,
                        source: .notification,
                        sourceEventId: nil,
                        sourceReminderId: nil,
                        legacyModelName: "MedicationReminder",
                        legacyModelId: medicationId,
                        coconutDelta: 0,
                        rewardLogId: nil,
                        privacyFieldRaw: nil,
                        metadataJSON: metadataJSON,
                        context: context,
                        save: true
                    )
                }
            }
        }
    }

    // MARK: - 取消某个人的所有用药通知

    func cancelHumanMedicationReminders(for humanId: UUID) {
        knownScheduledHumanIDs.remove(humanId)
        let prefix = MedicationNotificationIdentifierPolicy.humanReminderPrefix(for: humanId)
        enqueueNotificationCancellation(matching: [prefix])
    }
}

// MARK: - DateFormatter helper

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
