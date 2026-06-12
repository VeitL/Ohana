//
//  FamilyWeeklyReportService.swift
//  Ohana
//
//  每周日 20:00 本地推送「本周 Ohana 家庭周报」提醒主理人查看照护周报
//

import Foundation
import UserNotifications

final class FamilyWeeklyReportService {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "family_weekly_report_sunday_2000"

    init() {}

    /// 注册每周日 20:00 的重复本地推送（幂等：先移除再添加）
    func scheduleWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = Self.makeWeeklyReportContent()

        var comps = DateComponents()
        comps.weekday = 1 // Calendar.current：周日
        comps.hour = 20
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    /// 取消周报推送
    func cancelWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func makeWeeklyReportContent(l: L10n = .current) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = l.tr(
            zh: "本周 Ohana 照护周报",
            en: "This week's Ohana care report",
            de: "Ohanas Pflegebericht der Woche"
        )
        content.body = l.tr(
            zh: "回顾这周的照护、提醒和小小进步。",
            en: "Review this week's care, reminders, and little wins.",
            de: "Blicke auf Pflege, Erinnerungen und kleine Fortschritte zurück."
        )
        content.sound = .default
        content.categoryIdentifier = "FAMILY_WEEKLY_REPORT"
        content.userInfo = NotificationDeliveryPolicy.userInfo(for: NotificationDeliveryPolicy.weeklyReportClassification())
        return content
    }
}
