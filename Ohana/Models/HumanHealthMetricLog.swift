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

/// 化验单对单项指标给出的状态标记。仅保存报告原文语义，不作为诊断结论。
nonisolated enum HumanHealthMetricReportedFlag: String, Codable, CaseIterable, Sendable {
    case normal
    case low
    case high
    case unknown
}

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
    /// 本次记录由哪位本地家庭成员录入；与被检查成员分离，可空以兼容旧数据。
    var recordedByHumanId: String?
    /// 由同一次化验单导入时关联的报告；手工记录为空。
    var sourceReportID: UUID?
    /// 化验单中的原始项目名称，便于复核目录映射。
    var sourceLabel: String = ""
    /// 化验单自己的参考区间；不同实验室、方法与人群可能不同。
    var referenceLow: Double?
    var referenceHigh: Double?
    /// 无法安全结构化时保留的参考范围原文，例如 “< 5.0”。
    var referenceRangeText: String = ""
    /// 化验单印刷的 H/L/正常标记；默认未知。
    var reportedFlagRaw: String = HumanHealthMetricReportedFlag.unknown.rawValue
    /// 关联的人类成员（与 HumanWeightLog 一致的反向关系模式）
    var human: Human?
    /// 写入时间，用于排序歧义和审计
    var createdAt: Date

    init(
        id: UUID = UUID(),
        metricKey: String,
        unitCode: String,
        value: Double,
        date: Date = Date(),
        notes: String = "",
        recordedByHumanId: String? = nil,
        sourceReportID: UUID? = nil,
        sourceLabel: String = "",
        referenceLow: Double? = nil,
        referenceHigh: Double? = nil,
        referenceRangeText: String = "",
        reportedFlag: HumanHealthMetricReportedFlag = .unknown,
        human: Human? = nil
    ) {
        self.id = id
        self.metricKey = metricKey
        self.unitCode = unitCode
        self.value = value
        self.date = date
        self.notes = notes
        self.recordedByHumanId = recordedByHumanId
        self.sourceReportID = sourceReportID
        self.sourceLabel = sourceLabel
        self.referenceLow = referenceLow
        self.referenceHigh = referenceHigh
        self.referenceRangeText = referenceRangeText
        self.reportedFlagRaw = reportedFlag.rawValue
        self.human = human
        self.createdAt = Date()
    }

    var reportedFlag: HumanHealthMetricReportedFlag {
        get { HumanHealthMetricReportedFlag(rawValue: reportedFlagRaw) ?? .unknown }
        set { reportedFlagRaw = newValue.rawValue }
    }
}
