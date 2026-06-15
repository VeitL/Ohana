//
//  HumanMedicationLog.swift
//  Ohana
//

import Foundation
import SwiftData

/// The status of a human medication dose
enum HumanMedicationStatus: String, Codable {
    case pending
    case taken
    case skipped
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

struct HumanMedicationDoseLogUpdate {
    let log: HumanMedicationLog?
    let previousStatus: HumanMedicationStatus?
    let didChange: Bool

    var shouldRecordLedgerEvent: Bool {
        guard didChange, let log else { return false }
        return log.status != .pending
    }
}

enum HumanMedicationLogStore {
    nonisolated static func sameScheduledMinute(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, equalTo: rhs, toGranularity: .minute)
    }

    nonisolated static func matchingLog(
        in logs: [HumanMedicationLog],
        humanId: String,
        medicationId: String,
        scheduledTime: Date,
        calendar: Calendar = .current
    ) -> HumanMedicationLog? {
        logs.first {
            $0.humanId == humanId &&
                $0.medicationId == medicationId &&
                sameScheduledMinute($0.scheduledTime, scheduledTime, calendar: calendar)
        }
    }

    @MainActor
    static func applyDoseStatus(
        humanId: String,
        medicationId: String,
        scheduledTime: Date,
        status: HumanMedicationStatus,
        existingLogs: [HumanMedicationLog],
        context: ModelContext,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> HumanMedicationDoseLogUpdate {
        let matching = matchingLog(
            in: existingLogs,
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            calendar: calendar
        ) ?? fetchMatchingLog(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            context: context,
            calendar: calendar
        )

        guard let log = matching else {
            guard status != .pending else {
                return HumanMedicationDoseLogUpdate(log: nil, previousStatus: nil, didChange: false)
            }
            let log = HumanMedicationLog(
                humanId: humanId,
                medicationId: medicationId,
                scheduledTime: scheduledTime,
                status: status,
                recordedTime: now
            )
            context.insert(log)
            return HumanMedicationDoseLogUpdate(log: log, previousStatus: nil, didChange: true)
        }

        let previous = log.status
        guard previous != status else {
            return HumanMedicationDoseLogUpdate(log: log, previousStatus: previous, didChange: false)
        }

        log.status = status
        log.recordedTime = status == .pending ? nil : now
        return HumanMedicationDoseLogUpdate(log: log, previousStatus: previous, didChange: true)
    }

    @MainActor
    private static func fetchMatchingLog(
        humanId: String,
        medicationId: String,
        scheduledTime: Date,
        context: ModelContext,
        calendar: Calendar
    ) -> HumanMedicationLog? {
        var descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                log.humanId == humanId && log.medicationId == medicationId
            }
        )
        descriptor.fetchLimit = 128
        let logs: [HumanMedicationLog]
        do {
            logs = try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[HumanMedicationLogStore] failed to fetch matching log for humanId=\(humanId) medicationId=\(medicationId): \(error.localizedDescription)",
                category: "Care"
            )
            logs = []
        }
        return matchingLog(
            in: logs,
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            calendar: calendar
        )
    }
}
