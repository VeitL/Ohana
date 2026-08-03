import Foundation
import Testing
@testable import Ohana

@MainActor
struct HumanHealthConditionAnalysisTests {
    @Test func trendSnapshotComparesThirtyDayHalvesAndSummarizesOptionalState() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let humanID = UUID().uuidString
        let conditionID = UUID().uuidString
        let observations = [
            observation(
                humanID: humanID,
                conditionID: conditionID,
                date: try #require(calendar.date(byAdding: .day, value: -24, to: now)),
                severity: 8,
                mood: 3,
                sleep: 5,
                tags: ["疲劳", "心悸"]
            ),
            observation(
                humanID: humanID,
                conditionID: conditionID,
                date: try #require(calendar.date(byAdding: .day, value: -18, to: now)),
                severity: 7,
                mood: 4,
                sleep: 6,
                tags: ["疲劳"]
            ),
            observation(
                humanID: humanID,
                conditionID: conditionID,
                date: try #require(calendar.date(byAdding: .day, value: -5, to: now)),
                severity: 3,
                mood: 7,
                sleep: 8,
                tags: ["疲劳", "怕冷"]
            ),
            observation(
                humanID: humanID,
                conditionID: conditionID,
                date: try #require(calendar.date(byAdding: .day, value: -1, to: now)),
                severity: 2,
                mood: 8,
                sleep: 7,
                tags: ["怕冷"]
            )
        ]

        let snapshot = HumanHealthConditionAnalysis.trendSnapshot(
            observations: observations,
            includeMedicationDetails: true,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.totalCount == 4)
        #expect(snapshot.sevenDayCount == 2)
        #expect(snapshot.thirtyDayCount == 4)
        #expect(snapshot.latestSeverity == 2)
        #expect(snapshot.severityTrend == .improving)
        #expect(snapshot.averageSeverity == 5)
        #expect(snapshot.averageMood == 5.5)
        #expect(snapshot.averageSleepHours == 6.5)
        #expect(snapshot.topSymptomTags.first == "疲劳")
        #expect(snapshot.severityChartPoints.count == 4)
        #expect(snapshot.frequencyChartPoints.count == 7)
    }

    @Test func trendSnapshotNeedsRecordsInBothTimeHalvesBeforeClaimingDirection() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let observations = [
            observation(
                humanID: UUID().uuidString,
                conditionID: UUID().uuidString,
                date: try #require(calendar.date(byAdding: .day, value: -3, to: now)),
                severity: 6
            ),
            observation(
                humanID: UUID().uuidString,
                conditionID: UUID().uuidString,
                date: try #require(calendar.date(byAdding: .day, value: -1, to: now)),
                severity: 2
            )
        ]

        let snapshot = HumanHealthConditionAnalysis.trendSnapshot(
            observations: observations,
            includeMedicationDetails: true,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.severityTrend == .insufficientData)
    }

    @Test func trendSnapshotOmitsMedicationDetailsWhenMedicationPrivacyIsLocked() {
        let now = Date()
        let observation = HumanHealthObservation(
            humanId: UUID().uuidString,
            conditionId: UUID().uuidString,
            recordedAt: now,
            severity: 4,
            medicationResponse: .worse,
            sideEffects: "Private side effect"
        )

        let snapshot = HumanHealthConditionAnalysis.trendSnapshot(
            observations: [observation],
            includeMedicationDetails: false,
            now: now
        )

        #expect(snapshot.medicationResponseCounts.isEmpty)
        #expect(snapshot.sideEffectNoteCount == 0)
    }

    @Test func trendSnapshotUsesOneEligibleSetAtWindowAndFutureBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 30,
            hour: 12
        )))
        let today = calendar.startOfDay(for: now)
        let thirtyDayStart = try #require(calendar.date(byAdding: .day, value: -29, to: today))
        let humanID = UUID().uuidString
        let conditionID = UUID().uuidString
        let beforeWindow = observation(
            humanID: humanID,
            conditionID: conditionID,
            date: thirtyDayStart.addingTimeInterval(-1),
            severity: 10
        )
        let atWindowStart = observation(
            humanID: humanID,
            conditionID: conditionID,
            date: thirtyDayStart,
            severity: 2
        )
        let atNow = observation(
            humanID: humanID,
            conditionID: conditionID,
            date: now,
            severity: 4
        )
        let future = observation(
            humanID: humanID,
            conditionID: conditionID,
            date: now.addingTimeInterval(1),
            severity: 9
        )

        let snapshot = HumanHealthConditionAnalysis.trendSnapshot(
            observations: [future, beforeWindow, atNow, atWindowStart],
            includeMedicationDetails: true,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.totalCount == 3)
        #expect(snapshot.thirtyDayCount == 2)
        #expect(snapshot.latestRecordedAt == now)
        #expect(snapshot.latestSeverity == 4)
        #expect(snapshot.averageSeverity == 3)
        #expect(snapshot.severityChartPoints.count == 3)
        #expect(!snapshot.severityChartPoints.map(\.id).contains("human-health-severity-\(future.id.uuidString)"))
    }

    @Test func medicationSnapshotUsesOnlyLinkedPlansForSevenDayCompletion() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 1,
            hour: 12
        )))
        let today = calendar.startOfDay(for: now)
        let startDate = try #require(calendar.date(byAdding: .day, value: -30, to: today))
        let doseTime = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startDate))
        let humanID = UUID().uuidString
        let linked = HumanMedication(
            humanId: humanID,
            name: "Linked",
            dosage: "5 mg",
            frequency: .daily,
            firstDoseTime: doseTime,
            startDate: startDate
        )
        let unrelated = HumanMedication(
            humanId: humanID,
            name: "Unrelated",
            dosage: "1 tablet",
            frequency: .daily,
            firstDoseTime: doseTime,
            startDate: startDate
        )
        let condition = HumanHealthCondition(
            humanId: humanID,
            name: "Condition",
            linkedMedicationIDs: [linked.id]
        )
        let logs = try (0 ..< 5).map { offset in
            let day = try #require(calendar.date(byAdding: .day, value: offset - 6, to: today))
            let scheduled = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day))
            return HumanMedicationLog(
                humanId: humanID,
                medicationId: linked.id.uuidString,
                scheduledTime: scheduled,
                status: .taken,
                recordedTime: scheduled
            )
        }

        let snapshot = HumanHealthConditionAnalysis.medicationSnapshot(
            condition: condition,
            medications: [linked, unrelated],
            logs: logs,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.linkedPlanCount == 1)
        #expect(snapshot.activePlanCount == 1)
        #expect(snapshot.plannedDoseCount == 7)
        #expect(snapshot.takenDoseCount == 5)
        #expect(snapshot.completionRate == 71)
    }

    @Test func medicationSnapshotExcludesFutureDosesAndUsesFinalRecordedStoppedDoseActions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 1,
            hour: 12
        )))
        let today = calendar.startOfDay(for: now)
        let startDate = try #require(calendar.date(byAdding: .day, value: -30, to: today))
        let firstDoseTime = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startDate))
        let humanID = UUID().uuidString

        let twiceDaily = HumanMedication(
            humanId: humanID,
            name: "Twice daily",
            frequency: .twiceDaily,
            firstDoseTime: firstDoseTime,
            startDate: startDate
        )
        let activeCondition = HumanHealthCondition(
            humanId: humanID,
            name: "Active",
            linkedMedicationIDs: [twiceDaily.id]
        )
        let activeSnapshot = HumanHealthConditionAnalysis.medicationSnapshot(
            condition: activeCondition,
            medications: [twiceDaily],
            logs: [],
            now: now,
            calendar: calendar
        )

        #expect(activeSnapshot.plannedDoseCount == 13)
        #expect(activeSnapshot.takenDoseCount == 0)

        let stopped = HumanMedication(
            humanId: humanID,
            name: "Stopped",
            frequency: .daily,
            firstDoseTime: firstDoseTime,
            startDate: startDate
        )
        stopped.isActive = false
        let stoppedCondition = HumanHealthCondition(
            humanId: humanID,
            name: "Stopped",
            linkedMedicationIDs: [stopped.id]
        )
        var stoppedLogs = try (0 ..< 2).map { offset in
            let day = try #require(calendar.date(byAdding: .day, value: offset - 2, to: today))
            let scheduled = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day))
            return HumanMedicationLog(
                humanId: humanID,
                medicationId: stopped.id.uuidString.lowercased(),
                scheduledTime: scheduled,
                status: .taken,
                recordedTime: scheduled
            )
        }
        stoppedLogs.append(HumanMedicationLog(
            humanId: humanID,
            medicationId: stopped.id.uuidString,
            scheduledTime: stoppedLogs[0].scheduledTime,
            status: .skipped,
            recordedTime: stoppedLogs[0].scheduledTime.addingTimeInterval(60)
        ))
        let stoppedSnapshot = HumanHealthConditionAnalysis.medicationSnapshot(
            condition: stoppedCondition,
            medications: [stopped],
            logs: stoppedLogs,
            now: now,
            calendar: calendar
        )

        #expect(stoppedSnapshot.activePlanCount == 0)
        #expect(stoppedSnapshot.plannedDoseCount == 2)
        #expect(stoppedSnapshot.takenDoseCount == 1)
        #expect(stoppedSnapshot.completionRate == 50)
    }

    private func observation(
        humanID: String,
        conditionID: String,
        date: Date,
        severity: Int,
        mood: Int? = nil,
        sleep: Double? = nil,
        tags: [String] = []
    ) -> HumanHealthObservation {
        HumanHealthObservation(
            humanId: humanID,
            conditionId: conditionID,
            recordedAt: date,
            severity: severity,
            moodScore: mood,
            sleepHours: sleep,
            symptomTags: tags
        )
    }
}
