//
//  HumanHealthMetricLog.swift
//  Ohana
//
//  ArkSchemaV56：人类体检指标追踪
//  与 HumanHealthReport（整份体检报告存档）配套：
//  - HumanHealthReport：单次报告抽象（医院/结论/摘要）
//  - HumanHealthMetricLog：单一指标的某次具体数值（TSH 4.5 mIU/L），用于趋势图
//

import Foundation
import SwiftData

/// 单条体检指标记录
@Model
final class HumanHealthMetricLog {
    var id: UUID
    /// HealthMetricCatalog 里指标的稳定 id，例如 "tsh"、"hba1c"
    var metricKey: String
    /// 录入时使用的 unit code（每个指标的可用 unit 在 catalog 定义），例如 "mIU_L"
    var unitCode: String
    /// 数值，按 unitCode 解读
    var value: Double
    /// 测量日期（一般是采血/检查当日）
    var date: Date
    /// 录入备注（医院/医生/特殊状态等，可空）
    var notes: String
    /// 关联的人类成员（与 HumanWeightLog 一致的反向关系模式）
    var human: Human?
    /// 写入时间，用于排序歧义和审计
    var createdAt: Date

    init(
        metricKey: String,
        unitCode: String,
        value: Double,
        date: Date = Date(),
        notes: String = "",
        human: Human? = nil
    ) {
        self.id = UUID()
        self.metricKey = metricKey
        self.unitCode = unitCode
        self.value = value
        self.date = date
        self.notes = notes
        self.human = human
        self.createdAt = Date()
    }
}
