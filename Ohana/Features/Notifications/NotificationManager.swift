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

enum ReminderNotificationScheduleResult: Equatable {
    case scheduled
    case skippedDuplicate
    case skippedPastDue
    case missingEvent
    case failed(String)

    var ledgerActionType: String {
        switch self {
        case .scheduled: "scheduleSuccess"
        case .skippedDuplicate: "scheduleDuplicate"
        case .skippedPastDue: "scheduleSkippedPastDue"
        case .missingEvent: "scheduleMissingEvent"
        case .failed: "scheduleFailed"
        }
    }

    var metadataJSON: String {
        switch self {
        case let .failed(message):
            "{\"error\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        default:
            ""
        }
    }
}

final class NotificationManager: NSObject, @unchecked Sendable {
    // F10: 保持 @unchecked Sendable 但确保内部状态不可变
    // center 和 categoryID 均为 let，init 后不再变化，线程安全

    private let center = UNUserNotificationCenter.current()
    private let categoryID = "OHANA_REMINDER"
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

        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [completeAction, skipAction, snoozeAction],
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

        center.setNotificationCategories([category, petMedicationCategory, humanMedicationCategory])
    }

    // MARK: - 滚动窗口常量
    /// 单次最多注册未来 N 天的通知（iOS 硬限制 64 条，14 天 × 合理事件数 = 安全阈值）
    private let rollingWindowDays = 14

    // MARK: - Schedule（单条，原有接口保持不变）
    func schedule(reminder: Reminder) {
        schedule(reminder: reminder, existingNotificationIds: nil, completion: nil)
    }

    func schedule(
        reminder: Reminder,
        existingNotificationIds: Set<String>? = nil,
        completion: ((ReminderNotificationScheduleResult) -> Void)? = nil
    ) {
        guard let event = reminder.event else {
            completion?(.missingEvent)
            return
        }
        guard reminder.scheduledAt > Date() else {
            completion?(.skippedPastDue)
            return
        }
        if existingNotificationIds?.contains(reminder.notificationId) == true {
            completion?(.skippedDuplicate)
            return
        }

        let content = makeContent(event: event, reminder: reminder)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.scheduledAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.notificationId,
            content: content,
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

        for reminder in reminders {
            guard reminder.isPending else { continue }
            guard reminder.scheduledAt > now, reminder.scheduledAt <= windowEnd else { continue }
            guard let event = reminder.event else { continue }

            let content = makeContent(event: event, reminder: reminder)
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.scheduledAt
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminder.notificationId,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - refillWindowIfNeeded（App 启动时 / 打卡完成时调用）
    /// 检查当前已注册的待触发通知数量，不足时把窗口外的 reminders 补充进来
    func refillWindowIfNeeded(allReminders: [Reminder]) {
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: rollingWindowDays, to: now)!

        center.getPendingNotificationRequests { existing in
            let existingIds = Set(existing.map(\.identifier))
            let toSchedule = allReminders.filter { r in
                guard r.isPending else { return false }
                guard r.scheduledAt > now, r.scheduledAt <= windowEnd else { return false }
                return !existingIds.contains(r.notificationId)
            }
            for reminder in toSchedule {
                self.schedule(reminder: reminder)
            }
            #if DEBUG
                OhanaLog.debug("refillWindow: existing=\(existingIds.count), added=\(toSchedule.count)", category: "Notifications")
            #endif
        }
    }

    // MARK: - Cancel
    func cancel(notificationId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    func cancelAll(for petId: String, reminders: [Reminder]) {
        let ids = reminders
            .filter { $0.event?.relatedEntityId == petId }
            .map(\.notificationId)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Compensate（过期 pending：计划喂食标失败；其它待办标跳过，避免误报已完成）
    func compensate(reminders: [Reminder]) {
        let now = Date()
        for reminder in reminders {
            guard reminder.isPending, reminder.scheduledAt < now else { continue }
            if reminder.event?.eventType == EventType.foodChange.rawValue {
                reminder.statusEnum = .failed
                reminder.completedAt = nil
            } else {
                reminder.statusEnum = .skipped
                reminder.completedAt = nil
            }
            cancel(notificationId: reminder.notificationId)
        }
    }

    // MARK: - Private helpers
    private func makeContent(event: Event, reminder: Reminder) -> UNMutableNotificationContent {
        let l = L10n()
        let content = UNMutableNotificationContent()
        content.title = l.tr(zh: "Ohana 提醒", en: "Ohana reminder", de: "Ohana Erinnerung")
        content.body = "\(event.emoji) \(FeedRuleMetadata.localizedTitle(for: event, l: l))"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "reminderId": reminder.id.uuidString,
            "notificationId": reminder.notificationId,
            "reminderCreatedAt": reminder.createdAt.timeIntervalSince1970,
            "eventId": event.id.uuidString,
            "eventType": event.eventType,
            "relatedEntityType": event.relatedEntityType,
            "relatedEntityId": event.relatedEntityId
        ]
        return content
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
                self.routeCenter.requestReminderRoute(payload)
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
