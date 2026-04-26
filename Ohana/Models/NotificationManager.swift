//
//  NotificationManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import UserNotifications
import SwiftData

enum ReminderNotificationScheduleResult: Equatable {
    case scheduled
    case skippedDuplicate
    case skippedPastDue
    case missingEvent
    case failed(String)

    var ledgerActionType: String {
        switch self {
        case .scheduled: return "scheduleSuccess"
        case .skippedDuplicate: return "scheduleDuplicate"
        case .skippedPastDue: return "scheduleSkippedPastDue"
        case .missingEvent: return "scheduleMissingEvent"
        case .failed: return "scheduleFailed"
        }
    }

    var metadataJSON: String {
        switch self {
        case .failed(let message):
            return "{\"error\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        default:
            return ""
        }
    }
}

final class NotificationManager: NSObject, @unchecked Sendable {
    // F10: 保持 @unchecked Sendable 但确保内部状态不可变
    // center 和 categoryID 均为 let，init 后不再变化，线程安全
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    private let categoryID = "OHANA_REMINDER"
    
    private override init() {
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
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "完成 ✅",
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: "SKIP",
            title: "跳过 ⏭️",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "明天再说 🕐",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [completeAction, skipAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
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
            print("🔔 refillWindow: existing=\(existingIds.count), added=\(toSchedule.count)")
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
        let content = UNMutableNotificationContent()
        content.title = "Ohana 提醒"
        content.body = "\(event.emoji) \(event.title)"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "reminderId": reminder.id.uuidString,
            "notificationId": reminder.notificationId,
            "reminderCreatedAt": reminder.createdAt.timeIntervalSince1970
        ]
        return content
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        // F8: 记录用户操作，通过 NotificationCenter 广播到 App 层处理 ModelContext
        let notifName = Notification.Name("OhanaReminderAction")
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
        
        switch action {
        case "COMPLETE", "SKIP", "SNOOZE":
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: notifName, object: nil, userInfo: payload)
            }
        default:
            break
        }
        
        #if DEBUG
        print("📬 Notification action: \(action)")
        #endif
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
