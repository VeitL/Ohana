//
//  HumanMedicationModels.swift
//  Ohana
//
//  Render support values for HumanMedicationContentView.
//

import Foundation

struct DailyDoseItem: Identifiable, Hashable {
    let medication: HumanMedication
    let scheduledTime: Date
    let doseIndex: Int
    var log: HumanMedicationLog?

    var id: String {
        let minuteKey = Int(scheduledTime.timeIntervalSince1970 / 60)
        return "\(medication.id.uuidString)-\(minuteKey)-\(doseIndex)"
    }
}

nonisolated enum HumanMedicationTimelineRefreshPolicy {
    static func dayIdentity(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func nextDayBoundary(after date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        )
    }

    static func crossesDayBoundary(
        from previous: Date,
        to current: Date,
        calendar: Calendar = .current
    ) -> Bool {
        !calendar.isDate(previous, inSameDayAs: current)
    }

    static func nextDosePresentationDeadline(
        after date: Date,
        medications: [HumanMedication],
        calendar: Calendar = .current
    ) -> Date? {
        HumanMedicationSchedulePlan
            .doses(on: date, medications: medications, calendar: calendar)
            .lazy
            .map(\.scheduledTime)
            .filter { $0 > date }
            .min()
    }
}

enum HumanMedicationDoseCompletion: Equatable {
    case persisted(shouldNotifyDoseTaken: Bool)
    case failed
}

enum HumanMedicationPlanActivationCompletion: Equatable {
    case persisted(isActive: Bool)
    case failed
}

/// Owns only optimistic medication presentation state.
/// Persistent facts remain owned by the medication command services.
struct HumanMedicationPresentationState {
    private var pendingStatusByID: [String: HumanMedicationStatus] = [:]
    private var pendingActiveByMedicationID: [UUID: Bool] = [:]

    mutating func begin(itemID: String, status: HumanMedicationStatus) {
        pendingStatusByID[itemID] = status
    }

    func pendingStatus(for itemID: String) -> HumanMedicationStatus? {
        pendingStatusByID[itemID]
    }

    func effectiveStatus(
        for itemID: String,
        persistedStatus: HumanMedicationStatus?
    ) -> HumanMedicationStatus? {
        pendingStatusByID[itemID] ?? persistedStatus
    }

    mutating func complete(
        itemID: String,
        result: HumanMedicationDoseCommandResult
    ) -> HumanMedicationDoseCompletion {
        pendingStatusByID[itemID] = nil
        guard result.didPersist else { return .failed }
        return .persisted(
            shouldNotifyDoseTaken: result.status == .taken && result.didChange
        )
    }

    mutating func beginPlanActivation(medicationID: UUID, isActive: Bool) {
        pendingActiveByMedicationID[medicationID] = isActive
    }

    func isPlanActivationPending(medicationID: UUID) -> Bool {
        pendingActiveByMedicationID[medicationID] != nil
    }

    func effectivePlanActive(
        medicationID: UUID,
        persistedIsActive: Bool
    ) -> Bool {
        pendingActiveByMedicationID[medicationID] ?? persistedIsActive
    }

    mutating func completePlanActivation(
        medicationID: UUID,
        result: HumanMedicationPlanActivationCommandResult
    ) -> HumanMedicationPlanActivationCompletion {
        pendingActiveByMedicationID[medicationID] = nil
        guard result.didPersist else { return .failed }
        return .persisted(isActive: result.isActive)
    }

    mutating func cancelAll() {
        pendingStatusByID.removeAll()
        pendingActiveByMedicationID.removeAll()
    }
}

struct MedicationAdherenceDay: Identifiable, Equatable {
    let date: Date
    let planned: Int
    let taken: Int

    var id: Date { date }

    var completion: Double {
        guard planned > 0 else { return 0 }
        return min(1, Double(taken) / Double(planned))
    }
}

struct HumanMedicationAdherenceSnapshot: Equatable {
    let days: [MedicationAdherenceDay]
    let plannedDoseCount: Int
    let takenDoseCount: Int

    static let empty = HumanMedicationAdherenceSnapshot(
        days: [],
        plannedDoseCount: 0,
        takenDoseCount: 0
    )

    var completionRate: Int? {
        guard plannedDoseCount > 0 else { return nil }
        let rate = Int((Double(takenDoseCount) / Double(plannedDoseCount) * 100).rounded())
        return max(0, min(100, rate))
    }
}

struct HumanMedicationRouteReadCompleteness: Equatable {
    let activePlans: Bool
    let inactivePlanHistory: Bool
    let recentLogs: Bool

    static let complete = HumanMedicationRouteReadCompleteness(
        activePlans: true,
        inactivePlanHistory: true,
        recentLogs: true
    )

    var today: Bool {
        activePlans && recentLogs
    }

    var sevenDayAnalysis: Bool {
        activePlans && inactivePlanHistory && recentLogs
    }

    var all: Bool {
        activePlans && inactivePlanHistory && recentLogs
    }
}

/// Builds one canonical due-to-now adherence snapshot for every Human surface.
/// Manual/as-needed logs are valid medication facts, but are not scheduled doses
/// and therefore never inflate plan completion.
enum HumanMedicationAdherenceAnalysis {
    static func snapshot(
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        dayCount: Int = 7,
        calendar: Calendar = .current
    ) -> HumanMedicationAdherenceSnapshot {
        guard dayCount > 0 else { return .empty }

        let today = calendar.startOfDay(for: now)
        let days = (0 ..< dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0 - (dayCount - 1), to: today)
        }
        guard let windowStart = days.first else { return .empty }

        var schedulableMedicationOwners: [String: String] = [:]
        for medication in medications where !medication.frequency.isManualEntry {
            guard let humanID = canonicalID(medication.humanId) else { continue }
            schedulableMedicationOwners[medication.id.uuidString] = humanID
        }

        var plannedDayByDoseKey: [String: Date] = [:]
        for day in days {
            let doses = HumanMedicationSchedulePlan.doses(
                on: day,
                medications: medications,
                calendar: calendar
            )
            for dose in doses where dose.scheduledTime <= now {
                plannedDayByDoseKey[doseKey(
                    medicationID: dose.medication.id.uuidString,
                    scheduledTime: dose.scheduledTime
                )] = calendar.startOfDay(for: dose.scheduledTime)
            }
        }

        var finalLogByDoseKey: [String: HumanMedicationLog] = [:]
        for log in logs {
            guard log.scheduledTime >= windowStart,
                  log.scheduledTime <= now,
                  let medicationID = canonicalID(log.medicationId),
                  let expectedHumanID = schedulableMedicationOwners[medicationID],
                  canonicalID(log.humanId) == expectedHumanID else {
                continue
            }

            let key = doseKey(
                medicationID: medicationID,
                scheduledTime: log.scheduledTime
            )
            // Recorded rows preserve handled historical doses after a plan is
            // stopped, while the key keeps duplicates/conflicts to one dose.
            plannedDayByDoseKey[key] = calendar.startOfDay(for: log.scheduledTime)
            if let existing = finalLogByDoseKey[key] {
                if HumanMedicationLogStore.actionPrecedes(existing, log) {
                    finalLogByDoseKey[key] = log
                }
            } else {
                finalLogByDoseKey[key] = log
            }
        }
        let takenDoseKeys = Set(finalLogByDoseKey.compactMap { key, log in
            log.status == .taken ? key : nil
        })

        let daySnapshots = days.map { day in
            let keys = Set(plannedDayByDoseKey.compactMap { key, doseDay in
                calendar.isDate(doseDay, inSameDayAs: day) ? key : nil
            })
            return MedicationAdherenceDay(
                date: day,
                planned: keys.count,
                taken: keys.intersection(takenDoseKeys).count
            )
        }
        let plannedDoseCount = plannedDayByDoseKey.count

        return HumanMedicationAdherenceSnapshot(
            days: daySnapshots,
            plannedDoseCount: plannedDoseCount,
            takenDoseCount: takenDoseKeys.intersection(Set(plannedDayByDoseKey.keys)).count
        )
    }

    private static func canonicalID(_ raw: String) -> String? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))?.uuidString
    }

    private static func doseKey(medicationID: String, scheduledTime: Date) -> String {
        let normalizedID = canonicalID(medicationID) ?? medicationID.lowercased()
        let minute = Int((scheduledTime.timeIntervalSinceReferenceDate / 60).rounded(.down))
        return "\(normalizedID):\(minute)"
    }
}
