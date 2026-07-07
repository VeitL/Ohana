//
//  NotificationManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Combine
import Foundation
import SwiftData
import UserNotifications

final class NotificationManager: NSObject, @unchecked Sendable {
    // F10: 保持 @unchecked Sendable 但确保内部状态不可变
    // center 和 categoryID 均为 let，init 后不再变化，线程安全

    private let center = UNUserNotificationCenter.current()
    private let categoryID = "OHANA_REMINDER"
    private let plantBatchCareCategoryID = "OHANA_PLANT_BATCH_CARE"
    private let petMedicationCategoryID = "MED_REMINDER"
    private let humanMedicationCategoryID = "HUMAN_MED_REMINDER"
    private let routeCenter: OhanaNotificationRouteCenter

    init(routeCenter: OhanaNotificationRouteCenter) {
        self.routeCenter = routeCenter
        super.init()
        center.delegate = self
        registerActions()
    }

    // MARK: - Permission
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Register Actions
    private func registerActions() {
        let l = L10n()
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: l.tr(zh: "完成 ✅", en: "Done ✅", de: "Erledigt ✅"),
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: "SKIP",
            title: l.tr(zh: "跳过 ⏭️", en: "Skip ⏭️", de: "Überspringen ⏭️"),
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: l.tr(zh: "明天再说 🕐", en: "Tomorrow 🕐", de: "Morgen 🕐"),
            options: []
        )
        let openPlantBatchCareAction = UNNotificationAction(
            identifier: "OPEN_PLANT_BATCH_CARE",
            title: l.tr(zh: "全部完成", en: "Complete all", de: "Alle erledigen"),
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [completeAction, skipAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        let plantBatchCareCategory = UNNotificationCategory(
            identifier: plantBatchCareCategoryID,
            actions: [openPlantBatchCareAction],
            intentIdentifiers: [],
            options: []
        )

        let petMedicationCategory = UNNotificationCategory(
            identifier: petMedicationCategoryID,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        let humanMedicationCategory = UNNotificationCategory(
            identifier: humanMedicationCategoryID,
            actions: [completeAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category, plantBatchCareCategory, petMedicationCategory, humanMedicationCategory])
    }

    // MARK: - 滚动窗口常量
    /// 单次最多注册未来 N 天的通知（iOS 硬限制 64 条，14 天 × 合理事件数 = 安全阈值）
    private let rollingWindowDays = 14
    private struct PreparedReminderNotificationRequest {
        let notificationId: String
        let fireDate: Date
        let classification: NotificationDeliveryClassification
        let createdAt: Date
        let content: UNMutableNotificationContent
    }

    // MARK: - Schedule（单条，原有接口保持不变）
    func schedule(reminder: Reminder) {
        scheduleWithPolicy(reminder: reminder, existingNotificationIds: nil, completion: nil)
    }

    func schedule(
        reminder: Reminder,
        existingNotificationIds: Set<String>? = nil,
        completion: ((ReminderNotificationScheduleResult) -> Void)? = nil
    ) {
        scheduleWithPolicy(
            reminder: reminder,
            existingNotificationIds: existingNotificationIds,
            completion: completion
        )
    }

    private func scheduleWithPolicy(
        reminder: Reminder,
        existingNotificationIds: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        guard let policyDecision = NotificationDeliveryPolicy.plan(reminders: [reminder])[reminder.id] else {
            schedule(
                reminder: reminder,
                deliveryDate: nil,
                existingNotificationIds: existingNotificationIds,
                completion: completion
            )
            return
        }

        switch policyDecision {
        case let .deliver(deliveryDate, _, _):
            schedule(
                reminder: reminder,
                deliveryDate: deliveryDate,
                existingNotificationIds: existingNotificationIds,
                completion: completion
            )
        case .skippedBudget:
            cancel(notificationId: reminder.notificationId)
            completion?(.skippedBudget(policyDecision.metadataJSON))
        case .merged:
            cancel(notificationId: reminder.notificationId)
            completion?(.skippedMerged(policyDecision.metadataJSON))
        case .skippedUserDisabled:
            cancel(notificationId: reminder.notificationId)
            completion?(.skippedUserDisabled(policyDecision.metadataJSON))
        }
    }

    func schedule(
        reminder: Reminder,
        deliveryDate: Date? = nil,
        existingNotificationIds: Set<String>? = nil,
        completion: ((ReminderNotificationScheduleResult) -> Void)? = nil
    ) {
        scheduleDirect(
            reminder: reminder,
            deliveryDate: deliveryDate,
            existingNotificationIds: existingNotificationIds,
            completion: completion
        )
    }

    private func scheduleDirect(
        reminder: Reminder,
        deliveryDate: Date? = nil,
        existingNotificationIds: Set<String>? = nil,
        completion: ((ReminderNotificationScheduleResult) -> Void)? = nil
    ) {
        guard let event = reminder.event else {
            completion?(.missingEvent)
            return
        }
        let fireDate = deliveryDate ?? reminder.scheduledAt
        guard fireDate > Date() else {
            completion?(.skippedPastDue)
            return
        }
        if existingNotificationIds?.contains(reminder.notificationId) == true {
            completion?(.skippedDuplicate)
            return
        }

        let classification = NotificationDeliveryPolicy.classification(for: event)
        guard let prepared = makePreparedRequest(
            reminder: reminder,
            deliveryDate: fireDate,
            classification: classification
        ) else {
            completion?(.missingEvent)
            return
        }
        schedulePrepared(
            prepared,
            existingNotificationIds: existingNotificationIds,
            completion: completion
        )
    }

    private func schedulePrepared(
        _ prepared: PreparedReminderNotificationRequest,
        existingNotificationIds: Set<String>? = nil,
        completion: ((ReminderNotificationScheduleResult) -> Void)? = nil
    ) {
        if existingNotificationIds?.contains(prepared.notificationId) == true {
            completion?(.skippedDuplicate)
            return
        }

        let scheduleIfCapacityAllows: (Set<String>) -> Void = { [self] knownIds in
            if knownIds.contains(prepared.notificationId) {
                completion?(.skippedDuplicate)
                return
            }
            guard NotificationPendingBudget.hasCapacity(existingPendingCount: knownIds.count) else {
                completion?(.skippedBudget(NotificationPendingBudget.skippedBudgetMetadataJSON(existingPendingCount: knownIds.count)))
                return
            }

            let components = Self.triggerDateComponents(for: prepared.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: prepared.notificationId,
                content: prepared.content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    completion?(.failed(error.localizedDescription))
                } else {
                    completion?(.scheduled)
                }
            }
        }

        if let existingNotificationIds {
            scheduleIfCapacityAllows(existingNotificationIds)
        } else {
            center.getPendingNotificationRequests { requests in
                scheduleIfCapacityAllows(Set(requests.map(\.identifier)))
            }
        }
    }

    nonisolated static func triggerDateComponents(for fireDate: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
    }

    func pendingNotificationIds() async -> Set<String> {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: Set(requests.map(\.identifier)))
            }
        }
    }

    // MARK: - scheduleRollingWindow
    /// 从 reminders 列表中，只注册未来 rollingWindowDays 天内的待定提醒
    /// 超出窗口的通知不注册，等待下次 refill 时再加入
    func scheduleRollingWindow(reminders: [Reminder]) {
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: rollingWindowDays, to: now)!

        let candidates = reminders.filter { reminder in
            reminder.isPending && reminder.scheduledAt > now && reminder.scheduledAt <= windowEnd
        }
        let policyDecisions = NotificationDeliveryPolicy.plan(reminders: candidates)
        let deliverable = candidates.compactMap { reminder -> PreparedReminderNotificationRequest? in
            guard case let .deliver(deliveryDate, classification, _) = policyDecisions[reminder.id] else { return nil }
            return makePreparedRequest(
                reminder: reminder,
                deliveryDate: deliveryDate,
                classification: classification
            )
        }.sorted {
            NotificationPendingBudget.shouldScheduleBefore(
                lhsDeliveryDate: $0.fireDate,
                lhsClassification: $0.classification,
                lhsCreatedAt: $0.createdAt,
                rhsDeliveryDate: $1.fireDate,
                rhsClassification: $1.classification,
                rhsCreatedAt: $1.createdAt
            )
        }
        center.getPendingNotificationRequests { existing in
            var knownIds = Set(existing.map(\.identifier))
            for entry in deliverable {
                guard NotificationPendingBudget.hasCapacity(existingPendingCount: knownIds.count) else { break }
                let existingIdsForRequest = knownIds
                knownIds.insert(entry.notificationId)
                self.schedulePrepared(
                    entry,
                    existingNotificationIds: existingIdsForRequest
                )
            }
        }
    }

    // MARK: - refillWindowIfNeeded（App 启动时 / 打卡完成时调用）
    /// 检查当前已注册的待触发通知数量，不足时把窗口外的 reminders 补充进来
    func refillWindowIfNeeded(allReminders: [Reminder]) {
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: rollingWindowDays, to: now)!

        let candidates = allReminders.filter { reminder in
            reminder.isPending && reminder.scheduledAt > now && reminder.scheduledAt <= windowEnd
        }
        let policyDecisions = NotificationDeliveryPolicy.plan(reminders: candidates)
        let deliverable = candidates.compactMap { reminder -> PreparedReminderNotificationRequest? in
            guard case let .deliver(deliveryDate, classification, _) = policyDecisions[reminder.id] else { return nil }
            return makePreparedRequest(
                reminder: reminder,
                deliveryDate: deliveryDate,
                classification: classification
            )
        }.sorted {
            NotificationPendingBudget.shouldScheduleBefore(
                lhsDeliveryDate: $0.fireDate,
                lhsClassification: $0.classification,
                lhsCreatedAt: $0.createdAt,
                rhsDeliveryDate: $1.fireDate,
                rhsClassification: $1.classification,
                rhsCreatedAt: $1.createdAt
            )
        }

        center.getPendingNotificationRequests { existing in
            let existingIds = Set(existing.map(\.identifier))
            var knownIds = existingIds
            var added = 0
            for entry in deliverable {
                guard !knownIds.contains(entry.notificationId) else { continue }
                guard NotificationPendingBudget.hasCapacity(existingPendingCount: knownIds.count) else { break }
                let existingIdsForRequest = knownIds
                knownIds.insert(entry.notificationId)
                self.schedulePrepared(
                    entry,
                    existingNotificationIds: existingIdsForRequest
                )
                added += 1
            }
            #if DEBUG
                OhanaLog.debug("refillWindow: existing=\(existingIds.count), added=\(added), budget=\(NotificationPendingBudget.managedPendingRequestLimit)", category: "Notifications")
            #endif
        }
    }

    func schedulePlantBatchCareSummary(_ summary: PlantBatchCareNotificationSummary) {
        center.getPendingNotificationRequests { existing in
            let existingIds = Set(existing.map(\.identifier))
            _ = self.schedulePlantBatchCareSummary(summary, existingNotificationIds: existingIds)
        }
    }

    @discardableResult
    func schedulePlantBatchCareSummary(
        _ summary: PlantBatchCareNotificationSummary,
        existingNotificationIds: Set<String>
    ) -> ReminderNotificationScheduleResult {
        guard summary.deliveryDate > Date() else { return .skippedPastDue }
        guard !existingNotificationIds.contains(summary.notificationId) else {
            return .skippedDuplicate
        }
        guard NotificationPendingBudget.hasCapacity(existingPendingCount: existingNotificationIds.count) else {
            return .skippedBudget(NotificationPendingBudget.skippedBudgetMetadataJSON(existingPendingCount: existingNotificationIds.count))
        }
        let l = L10n()
        let content = UNMutableNotificationContent()
        content.title = l.tr(zh: "植物照护提醒", en: "Plant care reminder", de: "Pflanzenpflege-Erinnerung")
        content.body = plantBatchCareSummaryBody(summary, l: l)
        content.sound = .default
        content.categoryIdentifier = plantBatchCareCategoryID
        content.userInfo = [
            "plantBatchCareSummary": true,
            "plantCareType": summary.careType.rawValue,
            "plantBatchCarePlantCount": summary.plantCount,
            "plantBatchCareTaskCount": summary.taskCount,
            "notificationTier": NotificationDeliveryTier.routine.rawValue,
            "notificationCategory": NotificationDeliveryCategory.plantCare.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Self.triggerDateComponents(for: summary.deliveryDate),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: summary.notificationId,
            content: content,
            trigger: trigger
        )
        center.add(request)
        return .scheduled
    }

    // MARK: - Cancel
    func cancel(notificationId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    func cancelAll(for pet: Pet, reminders: [Reminder]) {
        let disposition = MemberLifecycleGate.disposition(
            pet: pet,
            writeKind: .lifecycle(.cleanupActiveSchedules)
        )
        guard disposition.allowsDerivedEffects else { return }

        let ids = Self.cancellableNotificationIds(for: pet, reminders: reminders)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancellableNotificationIds(for pet: Pet, reminders: [Reminder]) -> [String] {
        let petId = pet.id.uuidString
        return reminders.compactMap { reminder in
            guard let event = reminder.event,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                      event,
                      petId: petId,
                      petMedications: pet.medications,
                      insurances: pet.insurances
                  ) else { return nil }
            return reminder.notificationId
        }
    }

    // MARK: - Compensate（过期 pending：计划喂食标失败；其它待办标跳过，避免误报已完成）
    func compensate(reminders: [Reminder]) {
        let now = Date()
        for reminder in reminders {
            guard reminder.isPending, reminder.scheduledAt < now else { continue }
            cancel(notificationId: reminder.notificationId)
        }
    }

    // MARK: - Private helpers
    private func makePreparedRequest(
        reminder: Reminder,
        deliveryDate: Date,
        classification: NotificationDeliveryClassification
    ) -> PreparedReminderNotificationRequest? {
        guard let event = reminder.event else { return nil }
        return PreparedReminderNotificationRequest(
            notificationId: reminder.notificationId,
            fireDate: deliveryDate,
            classification: classification,
            createdAt: reminder.createdAt,
            content: makeContent(event: event, reminder: reminder)
        )
    }

    private func makeContent(event: Event, reminder: Reminder) -> UNMutableNotificationContent {
        let l = L10n()
        let content = UNMutableNotificationContent()
        let localizedEventTitle = WaterRuleMetadata.localizedTitle(for: event, l: l) ?? FeedRuleMetadata.localizedTitle(for: event, l: l)
        if PlantReminderPreferenceStore.isPlantCareEvent(event) {
            content.title = l.tr(zh: "植物护理提醒", en: "Plant care reminder", de: "Pflanzenpflege-Erinnerung")
            content.body = plantCareNotificationBody(for: event, fallbackTitle: localizedEventTitle)
        } else {
            content.title = l.tr(zh: "Ohana 提醒", en: "Ohana reminder", de: "Ohana Erinnerung")
            content.body = "\(event.emoji) \(localizedEventTitle)"
        }
        content.sound = .default
        content.categoryIdentifier = categoryID
        let classification = NotificationDeliveryPolicy.classification(for: event)
        let policyUserInfo = NotificationDeliveryPolicy.userInfo(for: classification)
        var userInfo: [AnyHashable: Any] = [
            "reminderId": reminder.id.uuidString,
            "notificationId": reminder.notificationId,
            "reminderCreatedAt": reminder.createdAt.timeIntervalSince1970,
            "eventId": event.id.uuidString,
            "eventType": event.eventType,
            "relatedEntityType": event.relatedEntityType,
            "relatedEntityId": event.relatedEntityId
        ].merging(policyUserInfo) { _, new in new }
        if let plantId = DomainEntityLinkRegistry.plantId(for: event) {
            userInfo["plantId"] = plantId.uuidString
        }
        if let plantCareType = PlantReminderPreferenceStore.careType(forEventType: event.eventType) {
            userInfo["plantCareType"] = plantCareType.rawValue
        }
        content.userInfo = userInfo
        return content
    }

    private func plantCareNotificationBody(for event: Event, fallbackTitle: String) -> String {
        let title = fallbackTitle
            .replacingOccurrences(of: "植物计划", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(event.emoji) \(title)"
    }

    private func plantBatchCareSummaryBody(_ summary: PlantBatchCareNotificationSummary, l: L10n) -> String {
        let careName = summary.careType.displayName(l: l)
        return l.tr(
            zh: "\(summary.plantCount) 棵植物今天要\(careName)",
            en: "\(summary.plantCount) plants need \(careName.lowercased()) today",
            de: "\(summary.plantCount) Pflanzen brauchen heute \(careName.lowercased())"
        )
    }
}

struct ReminderNotificationActionEvent: Identifiable {
    let id = UUID()
    let userInfo: [AnyHashable: Any]

    init(payload: [String: Any]) {
        userInfo = Dictionary(
            uniqueKeysWithValues: payload.map { key, value in
                (AnyHashable(key), value)
            }
        )
    }
}

@MainActor
final class OhanaNotificationRouteCenter: ObservableObject {
    @Published private(set) var lastRouteEvent: AppRoutePublishedEvent?
    @Published private(set) var lastReminderActionEvent: ReminderNotificationActionEvent?

    private var pendingReminderRoute: [String: Any]?

    init() {}

    var routeEvents: AnyPublisher<AppRoutePublishedEvent, Never> {
        $lastRouteEvent.compactMap(\.self).eraseToAnyPublisher()
    }

    var reminderActionEvents: AnyPublisher<ReminderNotificationActionEvent, Never> {
        $lastReminderActionEvent.compactMap(\.self).eraseToAnyPublisher()
    }

    func requestReminderRoute(_ payload: [String: Any]) {
        pendingReminderRoute = payload
        publishRouteEvent(.reminderRouteRequested)
    }

    func requestPlantBatchCareRoute(careType: PlantCareType?) {
        publishRouteEvent(.plantBatchCareRouteRequested(careType: careType))
    }

    func publishRouteEvent(_ event: AppRouteNotificationEvent) {
        lastRouteEvent = AppRoutePublishedEvent(event: event)
    }

    func publishReminderAction(_ payload: [String: Any]) {
        lastReminderActionEvent = ReminderNotificationActionEvent(payload: payload)
    }

    func pendingRoute() -> [String: Any]? {
        pendingReminderRoute
    }

    func clearPendingRoute(reminderId: String?) {
        guard let reminderId else {
            pendingReminderRoute = nil
            return
        }
        if pendingReminderRoute?["reminderId"] as? String == reminderId {
            pendingReminderRoute = nil
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        // F8: 记录用户操作，通过 NotificationCenter 广播到 App 层处理 ModelContext
        var payload: [String: Any] = ["action": action]
        if let reminderId = userInfo["reminderId"] as? String {
            payload["reminderId"] = reminderId
        }
        if let notificationId = userInfo["notificationId"] as? String {
            payload["notificationId"] = notificationId
        }
        if let createdAt = userInfo["reminderCreatedAt"] as? TimeInterval {
            payload["reminderCreatedAt"] = createdAt
        }
        if let eventId = userInfo["eventId"] as? String {
            payload["eventId"] = eventId
        }
        if let eventType = userInfo["eventType"] as? String {
            payload["eventType"] = eventType
        }
        if let relatedEntityType = userInfo["relatedEntityType"] as? String {
            payload["relatedEntityType"] = relatedEntityType
        }
        if let relatedEntityId = userInfo["relatedEntityId"] as? String {
            payload["relatedEntityId"] = relatedEntityId
        }
        if let plantId = userInfo["plantId"] as? String {
            payload["plantId"] = plantId
        }
        if let plantCareType = userInfo["plantCareType"] as? String {
            payload["plantCareType"] = plantCareType
        }
        let isPlantBatchCareSummary = userInfo["plantBatchCareSummary"] as? Bool == true
        if isPlantBatchCareSummary {
            payload["plantBatchCareSummary"] = true
        }
        if let petId = userInfo["petId"] as? String {
            payload["petId"] = petId
        }
        if let humanId = userInfo["humanId"] as? String {
            payload["humanId"] = humanId
        }
        if let medicationId = userInfo["medicationId"] as? String {
            payload["medicationId"] = medicationId
        }
        if let humanMedicationId = userInfo["humanMedicationId"] as? String {
            payload["humanMedicationId"] = humanMedicationId
        }
        if let scheduledAt = userInfo["scheduledAt"] as? TimeInterval {
            payload["scheduledAt"] = scheduledAt
        }
        if let doseIndex = userInfo["doseIndex"] as? Int {
            payload["doseIndex"] = doseIndex
        }

        switch action {
        case UNNotificationDefaultActionIdentifier:
            DispatchQueue.main.async {
                if isPlantBatchCareSummary {
                    self.routeCenter.requestPlantBatchCareRoute(
                        careType: (payload["plantCareType"] as? String).flatMap(PlantCareType.init(rawValue:))
                    )
                } else {
                    self.routeCenter.requestReminderRoute(payload)
                }
            }
        case "OPEN_PLANT_BATCH_CARE":
            DispatchQueue.main.async {
                self.routeCenter.requestPlantBatchCareRoute(
                    careType: (payload["plantCareType"] as? String).flatMap(PlantCareType.init(rawValue:))
                )
            }
        case "COMPLETE", "SKIP", "SNOOZE":
            DispatchQueue.main.async {
                self.routeCenter.publishReminderAction(payload)
            }
        default:
            break
        }

        #if DEBUG
            OhanaLog.debug("Notification action: \(action)", category: "Notifications")
        #endif
        completionHandler()
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
