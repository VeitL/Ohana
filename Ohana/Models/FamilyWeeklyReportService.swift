//
//  FamilyWeeklyReportService.swift
//  Ohana
//
//  P0 家庭协作：家庭周报推送服务
//  每周日 20:00 本地推送「本周 Ohana 家庭周报」提醒家人查看悬赏榜周报 Tab
//

import Foundation
import UserNotifications

final class FamilyWeeklyReportService {

    static let shared = FamilyWeeklyReportService()

    private let center = UNUserNotificationCenter.current()
    private let identifier = "family_weekly_report_sunday_2000"

    private init() {}

    /// 注册每周日 20:00 的重复本地推送（幂等：先移除再添加）
    func scheduleWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "📊 本周 Ohana 家庭周报"
        content.body  = "看看这周谁最勤快、谁在默默付出，别忘了感谢家人"
        content.sound = .default
        content.categoryIdentifier = "FAMILY_WEEKLY_REPORT"

        var comps = DateComponents()
        comps.weekday = 1   // Calendar.current：周日
        comps.hour    = 20
        comps.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    /// 取消周报推送
    func cancelWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
