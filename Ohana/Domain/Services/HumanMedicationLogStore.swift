import Foundation
import SwiftData

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
        guard let humanId = canonicalID(humanId),
              let medicationId = canonicalID(medicationId) else { return nil }

        return logs
            .filter {
                canonicalID($0.humanId) == humanId &&
                    canonicalID($0.medicationId) == medicationId &&
                    sameScheduledMinute($0.scheduledTime, scheduledTime, calendar: calendar)
            }
            .max(by: actionPrecedes)
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
                humanId: canonicalID(humanId) ?? humanId,
                medicationId: canonicalID(medicationId) ?? medicationId,
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
    static func fetchMatchingLog(
        humanId: String,
        medicationId: String,
        scheduledTime: Date,
        context: ModelContext,
        calendar: Calendar
    ) -> HumanMedicationLog? {
        guard let canonicalHumanId = canonicalID(humanId),
              let canonicalMedicationId = canonicalID(medicationId),
              let minute = calendar.dateInterval(of: .minute, for: scheduledTime) else {
            return nil
        }
        let minuteStart = minute.start
        let minuteEnd = minute.end
        let descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                log.scheduledTime >= minuteStart &&
                    log.scheduledTime < minuteEnd
            },
            sortBy: [
                SortDescriptor(\HumanMedicationLog.createdAt, order: .reverse),
                SortDescriptor(\HumanMedicationLog.id)
            ]
        )
        // A one-minute household window remains time-bounded while allowing
        // in-memory UUID normalization to recover whitespace legacy owners.
        // Do not apply a fixed row limit: it could exclude the target owner.
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
            humanId: canonicalHumanId,
            medicationId: canonicalMedicationId,
            scheduledTime: scheduledTime,
            calendar: calendar
        )
    }

    nonisolated static func canonicalID(_ raw: String) -> String? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))?.uuidString
    }

    /// Orders duplicate rows by the user's effective action, then by stable
    /// creation and identity tie-breakers. Adherence and exact-minute lookup
    /// must use the same winner when legacy stores contain conflicting rows.
    nonisolated static func actionPrecedes(_ lhs: HumanMedicationLog, _ rhs: HumanMedicationLog) -> Bool {
        let lhsActionTime = lhs.recordedTime ?? lhs.createdAt
        let rhsActionTime = rhs.recordedTime ?? rhs.createdAt
        if lhsActionTime != rhsActionTime { return lhsActionTime < rhsActionTime }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
