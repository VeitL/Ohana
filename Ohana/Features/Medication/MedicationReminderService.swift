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

nonisolated enum MedicationDoseProgressStore {
    static func dosesTakenToday(for medicationId: UUID) -> Int {
        let today = dayKey(for: Date())
        return UserDefaults.standard.integer(forKey: "med_doses_\(today)_\(medicationId.uuidString)")
    }

    private static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

nonisolated enum MedicationNotificationPrivacyStore {
    static let hidePetDetailsKey = "privacy_hide_pet_medication_notification_details"

    static func hidesPetMedicationDetails(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: hidePetDetailsKey)
    }
}

nonisolated enum MedicationNotificationBudget {
    @discardableResult
    static func reserve(
        notificationId: String,
        existingNotificationIds: inout Set<String>
    ) -> ReminderNotificationScheduleResult {
        guard !existingNotificationIds.contains(notificationId) else {
            return .skippedDuplicate
        }
        guard NotificationPendingBudget.hasCapacity(existingPendingCount: existingNotificationIds.count) else {
            return .skippedBudget(
                NotificationPendingBudget.skippedBudgetMetadataJSON(existingPendingCount: existingNotificationIds.count)
            )
        }
        existingNotificationIds.insert(notificationId)
        return .scheduled
    }

    static func metadataJSON(
        for result: ReminderNotificationScheduleResult,
        notificationId: String,
        scheduledAt: Date
    ) -> String {
        let base = "\"notificationId\":\"\(notificationId)\",\"scheduledAt\":\(scheduledAt.timeIntervalSince1970)"
        switch result {
        case .scheduled:
            return "{\(base)}"
        case .skippedDuplicate:
            return "{\(base),\"reason\":\"duplicate\"}"
        case let .skippedBudget(metadata):
            return "{\(base),\"reason\":\"budget\",\"budget\":\(metadata)}"
        case .skippedPastDue:
            return "{\(base),\"reason\":\"pastDue\"}"
        case .missingEvent:
            return "{\(base),\"reason\":\"missingEvent\"}"
        case let .failed(message):
            return "{\(base),\"error\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        case let .deferred(metadata),
             let .skippedMerged(metadata),
             let .skippedUserDisabled(metadata):
            return "{\(base),\"policy\":\(metadata)}"
        }
    }

    static func skippedActionType(
        for result: ReminderNotificationScheduleResult,
        scheduledActionType: String
    ) -> String {
        switch result {
        case .skippedDuplicate:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Duplicate")
        case .skippedBudget:
            scheduledActionType.replacingOccurrences(of: "Success", with: "SkippedBudget")
        case .skippedPastDue:
            scheduledActionType.replacingOccurrences(of: "Success", with: "SkippedPastDue")
        case .missingEvent:
            scheduledActionType.replacingOccurrences(of: "Success", with: "MissingEvent")
        case .failed:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Failed")
        case .deferred:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Deferred")
        case .skippedMerged:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Merged")
        case .skippedUserDisabled:
            scheduledActionType.replacingOccurrences(of: "Success", with: "UserDisabled")
        case .scheduled:
            scheduledActionType
        }
    }
}

// MARK: - 频次 → 每日次数

extension PetMedicationFrequency {
    /// 每日应服次数（asNeeded / custom = 0 表示按需，不自动调度）
    nonisolated var dosesPerDay: Int {
        switch self {
        case .daily: 1
        case .twiceDaily: 2
        case .threeTimesDaily: 3
        case .everyOtherDay: 1 // 隔天算作1次
        case .weekly: 1 // 每周
        case .asNeeded: 0
        case .custom: 0
        }
    }
}

extension MedicationFrequency {
    nonisolated var dosesPerDay: Int {
        switch self {
        case .daily: 1
        case .twiceDaily: 2
        case .threeTimesDaily: 3
        case .weekly: 1
        case .asNeeded: 0
        case .custom: 0
        }
    }
}

// MARK: - Reminder Service

final class MedicationReminderService {
    private let center = UNUserNotificationCenter.current()
    private let careLedger: CareLedgerRecording

    init(careLedger: CareLedgerRecording = CareLedgerService()) {
        self.careLedger = careLedger
    }

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
        let meds = pet.medications.filter(\.isActiveToday)

        // 先移除该宠物旧的用药通知
        let prefix = "medreminder_\(pet.id.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            var knownNotificationIds = Set(requests.map(\.identifier)).subtracting(ids)

            // 重新调度
            for med in meds {
                self.scheduleRemindersForMedication(
                    med,
                    pet: pet,
                    write: write,
                    context: context,
                    knownNotificationIds: &knownNotificationIds
                )
            }
        }
    }

    // MARK: - 调度单个药物的通知（未来14天窗口）

    private func scheduleRemindersForMedication(
        _ med: PetMedication,
        pet: Pet,
        write: AuthorizedDomainEffectWrite?,
        context: ModelContext?,
        knownNotificationIds: inout Set<String>
    ) {
        let dosesPerDay = med.frequency.dosesPerDay
        guard dosesPerDay > 0 else { return } // asNeeded / custom 不推送

        let calendar = Calendar.current
        let now = Date()
        let doseMinutes = PetMedicationSchedulePlan.doseMinutes(for: med, required: dosesPerDay)
        let l = L10n.current

        // 起始基准时间：今天 08:00
        var baseComponents = calendar.dateComponents([.year, .month, .day], from: now)
        baseComponents.hour = 0
        baseComponents.minute = 0
        baseComponents.second = 0
        guard let baseTime = calendar.date(from: baseComponents) else { return }

        var scheduled = 0
        let maxNotifications = 14 * dosesPerDay // 14天窗口

        outerLoop: for day in 0 ..< 14 {
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: baseTime) else { continue }

            // 检查 everyOtherDay：只有奇数天调度（从startDate算起）
            if med.frequency == .everyOtherDay {
                let daysSinceStart = calendar.dateComponents([.day], from: med.startDate, to: dayDate).day ?? 0
                if daysSinceStart % 2 != 0 { continue }
            }

            for doseIdx in 0 ..< dosesPerDay {
                let minute = doseMinutes.indices.contains(doseIdx) ? doseMinutes[doseIdx] : 8 * 60
                let fireDate = dayDate.addingTimeInterval(Double(minute) * 60)
                guard fireDate > now else { continue }
                if let endDate = med.endDate, fireDate > endDate { break outerLoop }

                let content = UNMutableNotificationContent()
                content.title = l.tr(zh: "宠物用药提醒", en: "Pet medication reminder", de: "Medikamentenerinnerung")
                content.body = MedicationNotificationPrivacyStore.hidesPetMedicationDetails()
                    ? l.tr(zh: "请打开 Ohana 查看用药详情。", en: "Open Ohana to view medication details.", de: "Öffne Ohana, um Medikamentendetails anzusehen.")
                    : "\(pet.name) · \(med.name) · \(med.dosage)"
                content.sound = .default
                let classification = NotificationDeliveryClassification(tier: .healthCritical, category: .medication, mergeAllowed: false)
                content.userInfo = [
                    "medicationId": med.id.uuidString,
                    "petId": pet.id.uuidString,
                    "scheduledAt": fireDate.timeIntervalSince1970,
                    "doseIndex": doseIdx,
                    "eventType": EventType.petMedication.rawValue,
                    "relatedEntityType": DomainEntityLinkRegistry.petMedicationPlan,
                    "relatedEntityId": med.id.uuidString
                ].merging(NotificationDeliveryPolicy.userInfo(for: classification)) { _, new in new }
                content.categoryIdentifier = "MED_REMINDER"

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "medreminder_\(pet.id.uuidString)_\(med.id.uuidString)_d\(day)_i\(doseIdx)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                let petId = pet.id.uuidString
                let medicationId = med.id.uuidString
                let medicationName = med.name
                let reservation = MedicationNotificationBudget.reserve(
                    notificationId: identifier,
                    existingNotificationIds: &knownNotificationIds
                )
                let contextBox = MedicationReminderContextBox(context)
                guard reservation == .scheduled else {
                    recordMedicationScheduleResult(
                        contextBox: contextBox,
                        write: write,
                        subjectKind: .pet,
                        subjectId: petId,
                        medicationId: medicationId,
                        medicationName: medicationName,
                        actionType: MedicationNotificationBudget.skippedActionType(
                            for: reservation,
                            scheduledActionType: "medicationScheduleSuccess"
                        ),
                        metadataJSON: MedicationNotificationBudget.metadataJSON(
                            for: reservation,
                            notificationId: identifier,
                            scheduledAt: fireDate
                        )
                    )
                    continue
                }
                center.add(request) { error in
                    self.recordMedicationScheduleResult(
                        contextBox: contextBox,
                        write: write,
                        subjectKind: .pet,
                        subjectId: petId,
                        medicationId: medicationId,
                        medicationName: medicationName,
                        actionType: error == nil ? "medicationScheduleSuccess" : "medicationScheduleFailed",
                        metadataJSON: error.map { "{\"notificationId\":\"\(identifier)\",\"error\":\"\($0.localizedDescription.replacingOccurrences(of: "\"", with: "\\\""))\"}" } ?? MedicationNotificationBudget.metadataJSON(
                            for: .scheduled,
                            notificationId: identifier,
                            scheduledAt: fireDate
                        )
                    )
                }
                scheduled += 1
                if scheduled >= maxNotifications { break outerLoop }
            }
        }

        // 疗程结束前3天提醒
        scheduleEndReminder(
            for: med,
            pet: pet,
            write: write,
            context: context,
            knownNotificationIds: &knownNotificationIds
        )
    }

    // MARK: - 疗程结束前3天提醒

    private func scheduleEndReminder(
        for med: PetMedication,
        pet: Pet,
        write: AuthorizedDomainEffectWrite?,
        context: ModelContext?,
        knownNotificationIds: inout Set<String>
    ) {
        guard let endDate = med.endDate else { return }
        guard let alertDate = Calendar.current.date(byAdding: .day, value: -3, to: endDate) else { return }
        guard alertDate > Date() else { return }

        let content = UNMutableNotificationContent()
        let l = L10n.current
        content.title = l.tr(zh: "用药即将结束", en: "Medication ending soon", de: "Medikation endet bald")
        content.body = MedicationNotificationPrivacyStore.hidesPetMedicationDetails()
            ? l.tr(zh: "请打开 Ohana 查看用药详情。", en: "Open Ohana to view medication details.", de: "Öffne Ohana, um Medikamentendetails anzusehen.")
            : l.tr(
                zh: "\(pet.name) · \(med.name) 疗程还剩 3 天，请确认是否续药",
                en: "\(pet.name) · \(med.name) has 3 days left. Check whether to renew.",
                de: "\(pet.name) · \(med.name) endet in 3 Tagen. Bitte Verlängerung prüfen."
            )
        content.sound = .default
        let classification = NotificationDeliveryClassification(tier: .healthCritical, category: .medication, mergeAllowed: false)
        content.userInfo = [
            "medicationId": med.id.uuidString,
            "petId": pet.id.uuidString,
            "eventType": EventType.petMedication.rawValue,
            "relatedEntityType": DomainEntityLinkRegistry.petMedicationPlan,
            "relatedEntityId": med.id.uuidString
        ].merging(NotificationDeliveryPolicy.userInfo(for: classification)) { _, new in new }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "medend_\(pet.id.uuidString)_\(med.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let petId = pet.id.uuidString
        let medicationId = med.id.uuidString
        let medicationName = med.name
        let contextBox = MedicationReminderContextBox(context)
        let reservation = MedicationNotificationBudget.reserve(
            notificationId: identifier,
            existingNotificationIds: &knownNotificationIds
        )
        guard reservation == .scheduled else {
            recordMedicationScheduleResult(
                contextBox: contextBox,
                write: write,
                subjectKind: .pet,
                subjectId: petId,
                medicationId: medicationId,
                medicationName: medicationName,
                actionType: MedicationNotificationBudget.skippedActionType(
                    for: reservation,
                    scheduledActionType: "medicationEndScheduleSuccess"
                ),
                metadataJSON: MedicationNotificationBudget.metadataJSON(
                    for: reservation,
                    notificationId: identifier,
                    scheduledAt: alertDate
                )
            )
            return
        }
        center.add(request) { error in
            self.recordMedicationScheduleResult(
                contextBox: contextBox,
                write: write,
                subjectKind: .pet,
                subjectId: petId,
                medicationId: medicationId,
                medicationName: medicationName,
                actionType: error == nil ? "medicationEndScheduleSuccess" : "medicationEndScheduleFailed",
                metadataJSON: error.map { "{\"notificationId\":\"\(identifier)\",\"error\":\"\($0.localizedDescription.replacingOccurrences(of: "\"", with: "\\\""))\"}" } ?? "{\"notificationId\":\"\(identifier)\",\"scheduledAt\":\(alertDate.timeIntervalSince1970)}"
            )
        }
    }

    // MARK: - 取消某只宠物所有用药通知

    func cancelMedicationReminders(for petId: UUID) {
        let prefixes = [
            "medreminder_\(petId.uuidString)",
            "medend_\(petId.uuidString)"
        ]
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { identifier in prefixes.contains { identifier.hasPrefix($0) } }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

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
        let prefix = "humanmedreminder_\(human.id.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            var knownNotificationIds = Set(requests.map(\.identifier)).subtracting(ids)

            for med in meds {
                self.scheduleRemindersForHumanMedication(
                    med,
                    human: human,
                    write: write,
                    context: context,
                    knownNotificationIds: &knownNotificationIds
                )
            }
        }
    }

    private func scheduleRemindersForHumanMedication(
        _ med: HumanMedication,
        human: Human,
        write: AuthorizedDomainEffectWrite?,
        context: ModelContext?,
        knownNotificationIds: inout Set<String>
    ) {
        let now = Date()
        let doses = HumanMedicationSchedulePlan.futureDoses(for: med, from: now, days: 14)
        guard !doses.isEmpty else { return }

        let l = L10n.current
        let hidesMedicationDetail = HumanLocalPrivacyPolicy.isEnabled &&
            human.privateFields.contains(HumanPrivateField.medication.rawValue)

        for dose in doses {
            let fireDate = dose.scheduledTime
            let content = UNMutableNotificationContent()
            content.title = l.tr(zh: "吃药提醒", en: "Medication reminder", de: "Medikamentenerinnerung")
            content.body = hidesMedicationDetail
                ? l.tr(zh: "该记录已设为隐私，请打开 Ohana 查看。", en: "This medication is private. Open Ohana to view it.", de: "Dieser Eintrag ist privat. Öffne Ohana, um ihn anzusehen.")
                : "\(med.name) · \(med.dosage)"
            content.sound = .default
            let classification = NotificationDeliveryClassification(tier: .healthCritical, category: .medication, mergeAllowed: false)
            content.userInfo = [
                "humanMedicationId": med.id.uuidString,
                "humanId": human.id.uuidString,
                "scheduledAt": fireDate.timeIntervalSince1970,
                "doseIndex": dose.doseIndex,
                "eventType": EventType.medication.rawValue,
                "relatedEntityType": DomainEntityLinkRegistry.humanMedicationPlan,
                "relatedEntityId": med.id.uuidString
            ].merging(NotificationDeliveryPolicy.userInfo(for: classification)) { _, new in new }
            content.categoryIdentifier = "HUMAN_MED_REMINDER"

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let minuteKey = Int(fireDate.timeIntervalSince1970 / 60)
            let identifier = "humanmedreminder_\(human.id.uuidString)_\(med.id.uuidString)_m\(minuteKey)_i\(dose.doseIndex)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            let humanId = human.id.uuidString
            let medicationId = med.id.uuidString
            let medicationName = hidesMedicationDetail
                ? l.tr(zh: "隐私用药", en: "Private medication", de: "Privates Medikament")
                : med.name
            let contextBox = MedicationReminderContextBox(context)
            let reservation = MedicationNotificationBudget.reserve(
                notificationId: identifier,
                existingNotificationIds: &knownNotificationIds
            )
            guard reservation == .scheduled else {
                recordMedicationScheduleResult(
                    contextBox: contextBox,
                    write: write,
                    subjectKind: .human,
                    subjectId: humanId,
                    medicationId: medicationId,
                    medicationName: medicationName,
                    actionType: MedicationNotificationBudget.skippedActionType(
                        for: reservation,
                        scheduledActionType: "medicationScheduleSuccess"
                    ),
                    metadataJSON: MedicationNotificationBudget.metadataJSON(
                        for: reservation,
                        notificationId: identifier,
                        scheduledAt: fireDate
                    )
                )
                continue
            }
            center.add(request) { error in
                self.recordMedicationScheduleResult(
                    contextBox: contextBox,
                    write: write,
                    subjectKind: .human,
                    subjectId: humanId,
                    medicationId: medicationId,
                    medicationName: medicationName,
                    actionType: error == nil ? "medicationScheduleSuccess" : "medicationScheduleFailed",
                    metadataJSON: error.map { "{\"notificationId\":\"\(identifier)\",\"error\":\"\($0.localizedDescription.replacingOccurrences(of: "\"", with: "\\\""))\"}" } ?? "{\"notificationId\":\"\(identifier)\",\"scheduledAt\":\(fireDate.timeIntervalSince1970)}"
                )
            }
        }
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
        let prefix = "humanmedreminder_\(humanId.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
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
