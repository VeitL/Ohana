import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HumanMedicationAdherenceAnalysisTests {
    @Test func routeDefersOnlyTheNewInactivePlanRead() throws {
        let route = try source("Ohana/Features/Medication/HumanMedicationDataContainer.swift")

        #expect(route.components(separatedBy: "@Query").count - 1 == 2)
        #expect(route.contains("@Query private var activeMeds"))
        #expect(route.contains("@Query private var allLogs"))
        #expect(!route.contains("@Query private var recentInactiveMeds"))
        #expect(route.contains("RouteFirstFrameDeferredLoad("))
        #expect(route.contains("HumanMedicationInactiveRouteData.load("))
        #expect(route.contains("route-first-frame: allow deferred-fetch"))
        #expect(route.contains("medicationPlanFetchLimit"))
        #expect(route.contains("homeRevisionUpdates"))
        #expect(route.contains("inactivePlanHistory: inactiveData.isComplete"))
    }

    @Test func routeCompletenessRequiresEveryBoundedMedicationSource() {
        let complete = HumanMedicationRouteReadCompleteness.complete
        let activePlansTruncated = HumanMedicationRouteReadCompleteness(
            activePlans: false,
            inactivePlanHistory: true,
            recentLogs: true
        )
        let stoppedHistoryTruncated = HumanMedicationRouteReadCompleteness(
            activePlans: true,
            inactivePlanHistory: false,
            recentLogs: true
        )

        #expect(complete.today)
        #expect(complete.sevenDayAnalysis)
        #expect(!activePlansTruncated.today)
        #expect(!activePlansTruncated.sevenDayAnalysis)
        #expect(stoppedHistoryTruncated.today)
        #expect(!stoppedHistoryTruncated.sevenDayAnalysis)
    }

    @Test func snapshotCountsOnlyScheduledDosesDueThroughNow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 1,
            hour: 12
        )))
        let today = calendar.startOfDay(for: now)
        let startDate = try #require(calendar.date(byAdding: .day, value: -30, to: today))
        let firstDose = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startDate))
        let humanID = UUID().uuidString
        let scheduled = HumanMedication(
            humanId: humanID,
            name: "Scheduled",
            frequency: .twiceDaily,
            firstDoseTime: firstDose,
            startDate: startDate
        )
        let asNeeded = HumanMedication(
            humanId: humanID,
            name: "As needed",
            frequency: .asNeeded,
            firstDoseTime: firstDose,
            startDate: startDate
        )
        let manualLog = HumanMedicationLog(
            humanId: humanID,
            medicationId: asNeeded.id.uuidString,
            scheduledTime: try #require(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)),
            status: .taken,
            recordedTime: now
        )
        let foreignLog = HumanMedicationLog(
            humanId: UUID().uuidString,
            medicationId: scheduled.id.uuidString,
            scheduledTime: try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)),
            status: .taken,
            recordedTime: now
        )

        let snapshot = HumanMedicationAdherenceAnalysis.snapshot(
            medications: [scheduled, asNeeded],
            logs: [manualLog, foreignLog],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.plannedDoseCount == 13)
        #expect(snapshot.takenDoseCount == 0)
        #expect(snapshot.completionRate == 0)
        #expect(snapshot.days.last?.planned == 1)
    }

    @Test func snapshotUsesLatestConflictingLegacyActionAndRetainsStoppedHistory() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 1,
            hour: 12
        )))
        let today = calendar.startOfDay(for: now)
        let scheduledTime = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today))
        let humanID = UUID().uuidString
        let stopped = HumanMedication(
            humanId: humanID,
            name: "Stopped",
            frequency: .daily,
            firstDoseTime: scheduledTime,
            startDate: today
        )
        stopped.isActive = false
        let taken = HumanMedicationLog(
            humanId: humanID.lowercased(),
            medicationId: stopped.id.uuidString.lowercased(),
            scheduledTime: scheduledTime,
            status: .taken,
            recordedTime: scheduledTime
        )
        let duplicate = HumanMedicationLog(
            humanId: humanID,
            medicationId: stopped.id.uuidString,
            scheduledTime: scheduledTime.addingTimeInterval(20),
            status: .skipped,
            recordedTime: scheduledTime.addingTimeInterval(30)
        )

        let snapshot = HumanMedicationAdherenceAnalysis.snapshot(
            medications: [stopped],
            logs: [taken, duplicate],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.plannedDoseCount == 1)
        #expect(snapshot.takenDoseCount == 0)
        #expect(snapshot.completionRate == 0)
    }

    @Test func routeWindowAndExactMinuteLookupReadWhitespaceLegacyOwner() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let today = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 1
        )))
        let logStart = try #require(calendar.date(byAdding: .day, value: -6, to: today))
        let logEnd = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let scheduledTime = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today))
        let humanID = UUID()
        let medicationID = UUID()
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: HumanMedicationLog.self, configurations: configuration)
        let context = container.mainContext
        let whitespaceOwnerLog = HumanMedicationLog(
            humanId: "  \(humanID.uuidString.lowercased())  ",
            medicationId: "  \(medicationID.uuidString.lowercased())  ",
            scheduledTime: scheduledTime,
            status: .taken,
            recordedTime: scheduledTime
        )
        let otherHumanLog = HumanMedicationLog(
            humanId: UUID().uuidString,
            medicationId: medicationID.uuidString,
            scheduledTime: scheduledTime,
            status: .skipped,
            recordedTime: scheduledTime
        )
        context.insert(whitespaceOwnerLog)
        context.insert(otherHumanLog)
        try context.save()

        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        let descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                (log.humanId.contains(humanKey) || log.humanId.contains(humanKeyLower)) &&
                    log.scheduledTime >= logStart && log.scheduledTime < logEnd
            }
        )
        let routeLogs = try context.fetch(descriptor)
        let todayOwnerLogs = routeLogs.filter { log in
            calendar.isDate(log.scheduledTime, inSameDayAs: today)
                && HumanMedicationLogStore.canonicalID(log.humanId) == humanID.uuidString
        }
        let matched = HumanMedicationLogStore.matchingLog(
            in: todayOwnerLogs,
            humanId: humanID.uuidString,
            medicationId: medicationID.uuidString,
            scheduledTime: scheduledTime,
            calendar: calendar
        )
        let update = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanID.uuidString,
            medicationId: medicationID.uuidString,
            scheduledTime: scheduledTime,
            status: .skipped,
            existingLogs: [],
            context: context,
            calendar: calendar,
            now: scheduledTime.addingTimeInterval(30)
        )

        #expect(routeLogs.map(\.id) == [whitespaceOwnerLog.id])
        #expect(todayOwnerLogs.map(\.id) == [whitespaceOwnerLog.id])
        #expect(matched?.id == whitespaceOwnerLog.id)
        #expect(update.log?.id == whitespaceOwnerLog.id)
        #expect(whitespaceOwnerLog.status == .skipped)
        #expect(try context.fetchCount(FetchDescriptor<HumanMedicationLog>()) == 2)
    }

    @Test func snapshotUsesNoRateWhenNothingIsDue() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 1,
            hour: 7
        )))
        let today = calendar.startOfDay(for: now)
        let firstDose = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today))
        let medication = HumanMedication(
            humanId: UUID().uuidString,
            name: "Future",
            frequency: .daily,
            firstDoseTime: firstDose,
            startDate: today
        )

        let snapshot = HumanMedicationAdherenceAnalysis.snapshot(
            medications: [medication],
            logs: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.plannedDoseCount == 0)
        #expect(snapshot.takenDoseCount == 0)
        #expect(snapshot.completionRate == nil)
    }

    @Test func logStoreFindsExactLegacyMinuteBeyondOldHistoryLimit() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: HumanMedicationLog.self, configurations: configuration)
        let context = container.mainContext
        let humanID = UUID().uuidString
        let medicationID = UUID().uuidString
        let targetTime = Date(timeIntervalSince1970: 1_800_000_000)

        for index in 0 ..< 140 {
            context.insert(HumanMedicationLog(
                humanId: humanID,
                medicationId: medicationID,
                scheduledTime: targetTime.addingTimeInterval(Double((index + 1) * 86400)),
                status: .taken,
                recordedTime: targetTime
            ))
        }
        let target = HumanMedicationLog(
            humanId: humanID.lowercased(),
            medicationId: medicationID.lowercased(),
            scheduledTime: targetTime,
            status: .taken,
            recordedTime: targetTime
        )
        context.insert(target)
        try context.save()

        let update = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanID,
            medicationId: medicationID,
            scheduledTime: targetTime.addingTimeInterval(20),
            status: .skipped,
            existingLogs: [],
            context: context,
            now: targetTime.addingTimeInterval(60)
        )

        #expect(update.didChange)
        #expect(update.log?.id == target.id)
        #expect(target.status == .skipped)
        #expect(try context.fetchCount(FetchDescriptor<HumanMedicationLog>()) == 141)
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
