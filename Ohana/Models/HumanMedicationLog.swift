//
//  HumanMedicationLog.swift
//  Ohana
//

import Foundation
import SwiftData

/// The status of a human medication dose
enum HumanMedicationStatus: String, Codable {
    case pending = "pending"
    case taken = "taken"
    case skipped = "skipped"
}

/// 记录人类每一次吃药物的状态
@Model
final class HumanMedicationLog {
    var id: UUID
    /// 对应的 Human ID
    var humanId: String
    /// 对应的 HumanMedication ID
    var medicationId: String
    
    /// 该次用药计划发生的时间（年、月、日、时、分）
    var scheduledTime: Date
    /// 用户实际点击吃药/跳过的时间
    var recordedTime: Date?
    
    /// 当次用药的状态 rawValue
    var statusRaw: String
    
    var createdAt: Date

    init(
        humanId: String,
        medicationId: String,
        scheduledTime: Date,
        status: HumanMedicationStatus = .pending,
        recordedTime: Date? = nil
    ) {
        self.id = UUID()
        self.humanId = humanId
        self.medicationId = medicationId
        self.scheduledTime = scheduledTime
        self.statusRaw = status.rawValue
        self.recordedTime = recordedTime
        self.createdAt = Date()
    }
    
    /// 当前状态枚举
    var status: HumanMedicationStatus {
        get { HumanMedicationStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
