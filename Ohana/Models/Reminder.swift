//
//  Reminder.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation

enum ReminderStatus: String, Codable {
    case pending
    case completed
    case skipped
    case snoozed
    /// 计划喂食等到点仍未打卡（与「已完成」区分）
    case failed
}

@Model
final class Reminder {
    var id: UUID
    var event: Event?
    var scheduledAt: Date
    var status: String
    var completedAt: Date?
    var completedBy: String
    var notificationId: String
    var createdAt: Date
    
    init(
        event: Event? = nil,
        scheduledAt: Date = Date()
    ) {
        self.id = UUID()
        self.event = event
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
}
