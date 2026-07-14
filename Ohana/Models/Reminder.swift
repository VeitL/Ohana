//
//  Reminder.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

enum ReminderStatus: String, Codable {
    case pending
    case completed
    case skipped
    case snoozed
    /// 计划喂食等到点仍未打卡（与「已完成」区分）
    case failed

    func localizedLabel(_ l: L10n) -> String {
        switch self {
        case .pending:
            l.tr(zh: "待处理", en: "Pending", de: "Offen")
        case .completed:
            l.tr(zh: "已完成", en: "Completed", de: "Erledigt")
        case .skipped:
            l.tr(zh: "已跳过", en: "Skipped", de: "Uebersprungen")
        case .snoozed:
            l.tr(zh: "已稍后提醒", en: "Snoozed", de: "Zurueckgestellt")
        case .failed:
            l.tr(zh: "失败", en: "Failed", de: "Fehlgeschlagen")
        }
    }
}

@Model
final class Reminder {
    var id: UUID
    var event: Event?
    /// The task occurrence this reminder represents. `scheduledAt` remains the
    /// notification delivery time and may be earlier than this value.
    var occurrenceAt: Date?
    var scheduledAt: Date
    var status: String
    var completedAt: Date?
    var completedBy: String
    var notificationId: String
    var createdAt: Date

    init(
        event: Event? = nil,
        scheduledAt: Date = Date(),
        occurrenceAt: Date? = nil
    ) {
        self.id = UUID()
        self.event = event
        self.occurrenceAt = occurrenceAt
        self.scheduledAt = scheduledAt
        self.status = ReminderStatus.pending.rawValue
        self.completedAt = nil
        self.completedBy = ""
        self.notificationId = UUID().uuidString
        self.createdAt = Date()
    }

    var statusEnum: ReminderStatus {
        get { ReminderStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var isPending: Bool { statusEnum == .pending }
    var isCompleted: Bool { statusEnum == .completed }
    var isFailed: Bool { statusEnum == .failed }

    /// V89 compatibility: older rows treated the notification timestamp as the
    /// occurrence timestamp, so a missing value preserves that behavior.
    var resolvedOccurrenceAt: Date { occurrenceAt ?? scheduledAt }
}
