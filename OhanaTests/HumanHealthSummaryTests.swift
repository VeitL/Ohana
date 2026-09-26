import Foundation
import Testing
@testable import Ohana

@Suite("Human health summary")
struct HumanHealthSummaryTests {
    @Test("Today counts only doses that still need handling")
    func todayMedicationSnapshot() throws {
        let fixture = try Fixture()
        let firstMedicationID = UUID()
        let secondMedicationID = UUID()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                activeMedicationPlanCount: 2,
                doses: [
                    dose(firstMedicationID, at: fixture.hour(8), state: .taken),
                    dose(secondMedicationID, at: fixture.hour(12), state: .pending),
                    dose(firstMedicationID, at: fixture.hour(20), state: .skipped)
                ]
            ),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.scheduledDoseCount == 3)
        #expect(snapshot.pendingDoseCount == 1)
        #expect(snapshot.nextPendingDose?.medicationID == secondMedicationID)
        #expect(snapshot.focusItems.first == .medication)
        #expect(snapshot.recordCounts.activeMedicationPlans.loaded == 2)
        #expect(!snapshot.recordCounts.activeMedicationPlans.isTruncated)
    }

    @Test("An older abnormal metric is cleared by its latest normal log")
    func latestMetricStatusWins() throws {
        let fixture = try Fixture()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(metrics: [
                metric(
                    key: "tsh",
                    value: 8,
                    date: fixture.day(-4),
                    status: .high
                ),
                metric(
                    key: "tsh",
                    value: 2.2,
                    date: fixture.day(-1),
                    status: .normal
                ),
                metric(
                    key: "hba1c",
                    value: 7.1,
                    date: fixture.day(-2),
                    status: .high,
                    unitCode: "percent"
                )
            ]),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.latestMetricCount == 2)
        #expect(snapshot.abnormalMetrics.map(\.metricKey) == ["hba1c"])
        #expect(snapshot.focusItems.contains(.metrics))
    }

    @Test("Follow-up selects the earliest future date inside thirty days")
    func upcomingFollowUpWindow() throws {
        let fixture = try Fixture()
        let nearID = UUID()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(reports: [
                report(
                    reportTypeRaw: "血液检测",
                    reportDate: fixture.day(-12),
                    nextCheckDate: fixture.day(45)
                ),
                report(
                    id: nearID,
                    reportTypeRaw: "过敏检测",
                    reportDate: fixture.day(-7),
                    nextCheckDate: fixture.day(8)
                ),
                report(
                    reportTypeRaw: "心脏检查",
                    reportDate: fixture.day(-3),
                    nextCheckDate: fixture.day(18)
                )
            ]),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.followUpAttention?.reportID == nearID)
        #expect(snapshot.followUpAttention?.timing == .upcoming(days: 8))
        #expect(snapshot.focusItems.contains(.followUp))
    }

    @Test("An overdue follow-up takes priority over a future follow-up")
    func overdueFollowUpIsAttention() throws {
        let fixture = try Fixture()
        let overdueID = UUID()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(reports: [
                report(
                    id: overdueID,
                    reportTypeRaw: "血液检测",
                    reportDate: fixture.day(-14),
                    nextCheckDate: fixture.day(-3)
                ),
                report(
                    reportTypeRaw: "过敏检测",
                    reportDate: fixture.day(-2),
                    nextCheckDate: fixture.day(5)
                )
            ]),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.followUpAttention?.reportID == overdueID)
        #expect(snapshot.followUpAttention?.timing == .overdue(days: 3))
    }

    @Test("Only the latest report of each type can create a follow-up")
    func staleReportFollowUpIsIgnored() throws {
        let fixture = try Fixture()
        let staleBloodReportID = UUID()
        let allergyReportID = UUID()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(reports: [
                report(
                    id: staleBloodReportID,
                    reportTypeRaw: "血液检测",
                    reportDate: fixture.day(-20),
                    nextCheckDate: fixture.day(-3)
                ),
                report(
                    reportTypeRaw: "血液检测",
                    reportDate: fixture.day(-2),
                    nextCheckDate: nil
                ),
                report(
                    id: allergyReportID,
                    reportTypeRaw: "过敏检测",
                    reportDate: fixture.day(-5),
                    nextCheckDate: fixture.day(6)
                )
            ]),
            now: fixture.now,
            calendar: fixture.calendar
        )

        let followUp = try #require(snapshot.followUpAttention)
        #expect(snapshot.followUpAttention?.reportID == allergyReportID)
        #expect(snapshot.followUpAttention?.reportID != staleBloodReportID)
        #expect(snapshot.followUpStatus == .attention(followUp))
    }

    @Test("A truncated report query without a match stays incomplete")
    func truncatedReportsDoNotClaimNoFollowUp() throws {
        let fixture = try Fixture()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                reportsAreTruncated: true,
                reports: [
                    report(
                        reportDate: fixture.day(-1),
                        nextCheckDate: nil
                    )
                ]
            ),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.followUpAttention == nil)
        #expect(snapshot.followUpStatus == .incomplete)
    }

    @Test("Recent state links to its condition and ignores stale observations")
    func recentObservationWindow() throws {
        let fixture = try Fixture()
        let conditionID = UUID()
        let recentID = UUID()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                conditions: [
                    HumanHealthSummaryConditionInput(
                        id: conditionID,
                        name: "Thyroid",
                        isActive: true,
                        updatedAt: fixture.day(-1)
                    )
                ],
                observations: [
                    HumanHealthSummaryObservationInput(
                        id: UUID(),
                        conditionID: conditionID,
                        recordedAt: fixture.day(-20),
                        severity: 8,
                        moodScore: nil
                    ),
                    HumanHealthSummaryObservationInput(
                        id: recentID,
                        conditionID: conditionID,
                        recordedAt: fixture.day(-2),
                        severity: 4,
                        moodScore: 6
                    )
                ]
            ),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.recentObservation?.observationID == recentID)
        #expect(snapshot.recentObservation?.conditionName == "Thyroid")
        #expect(snapshot.recentObservation?.severity == 4)
        #expect(snapshot.activeConditionCount == 1)
    }

    @Test("Trends compare the latest two values in the same unit")
    func trendUsesSameUnit() throws {
        let fixture = try Fixture()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(metrics: [
                metric(
                    key: "tsh",
                    value: 3.0,
                    date: fixture.day(-6),
                    status: .normal,
                    unitCode: "mIU_L"
                ),
                metric(
                    key: "tsh",
                    value: 0.2,
                    date: fixture.day(-3),
                    status: .normal,
                    unitCode: "other_unit"
                ),
                metric(
                    key: "tsh",
                    value: 4.0,
                    date: fixture.day(-1),
                    status: .normal,
                    unitCode: "mIU_L"
                )
            ]),
            now: fixture.now,
            calendar: fixture.calendar
        )

        let trend = try #require(snapshot.trends.first)
        #expect(trend.currentValue == 4.0)
        #expect(trend.previousValue == 3.0)
        #expect(trend.direction == .rising)
    }

    @Test("Pinned preference preserves order and removes duplicates")
    func pinnedPreferenceRoundTrip() {
        let values: [HumanHealthSummaryDestination] = [
            .reports,
            .medication,
            .reports,
            .weight,
            .workouts
        ]
        let encoded = HumanHealthSummaryPinPreference.encode(values)
        let decoded = HumanHealthSummaryPinPreference.decode(encoded)

        #expect(decoded == [.reports, .medication, .weight, .workouts])
        #expect(HumanHealthSummaryPinPreference.decode(nil) == HumanHealthSummaryPinPreference.defaultItems)
        #expect(HumanHealthSummaryPinPreference.decode("[]").isEmpty)
    }

    @Test("Unknown metric ranges never become a normal-range claim")
    func unknownMetricUsesReviewFlagSemantics() throws {
        let fixture = try Fixture()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(metrics: [
                metric(
                    key: "tsh",
                    value: 2.5,
                    date: fixture.day(-1),
                    status: .unknown
                )
            ]),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.abnormalMetrics.isEmpty)
        #expect(snapshot.highlights == [.latestMetricsWithoutReviewFlag(1)])
    }

    @Test("Truncated metric history cannot produce a no-review conclusion")
    func truncatedMetricsUseIncompleteSemantics() throws {
        let fixture = try Fixture()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                metricLogsAreTruncated: true,
                metrics: [
                    metric(
                        key: "tsh",
                        value: 2.5,
                        date: fixture.day(-1),
                        status: .normal
                    )
                ]
            ),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.abnormalMetrics.isEmpty)
        #expect(snapshot.highlights.contains(.metricReviewIncomplete(1)))
        #expect(!snapshot.highlights.contains(.latestMetricsWithoutReviewFlag(1)))
    }

    @Test("Legacy owner IDs allow surrounding whitespace but reject embedded IDs")
    func canonicalOwnerIdentityFiltering() {
        let humanID = UUID()

        #expect(HumanHealthSummaryOwnerIdentity.matches(humanID.uuidString, humanID: humanID))
        #expect(HumanHealthSummaryOwnerIdentity.matches(
            " \n\(humanID.uuidString.lowercased())\t ",
            humanID: humanID
        ))
        #expect(!HumanHealthSummaryOwnerIdentity.matches(
            "prefix\(humanID.uuidString)suffix",
            humanID: humanID
        ))
        #expect(!HumanHealthSummaryOwnerIdentity.matches(UUID().uuidString, humanID: humanID))
    }

    @Test("Old long-term medication remains active in today's window")
    func medicationWindowKeepsLongTermPlans() throws {
        let fixture = try Fixture()

        #expect(HumanHealthSummaryMedicationWindow.includes(
            isActive: true,
            startDate: fixture.day(-1000),
            endDate: nil,
            on: fixture.now,
            calendar: fixture.calendar
        ))
        #expect(!HumanHealthSummaryMedicationWindow.includes(
            isActive: false,
            startDate: fixture.day(-1000),
            endDate: nil,
            on: fixture.now,
            calendar: fixture.calendar
        ))
        #expect(!HumanHealthSummaryMedicationWindow.includes(
            isActive: true,
            startDate: fixture.day(-1000),
            endDate: fixture.day(-1),
            on: fixture.now,
            calendar: fixture.calendar
        ))
        #expect(!HumanHealthSummaryMedicationWindow.includes(
            isActive: true,
            startDate: fixture.day(1),
            endDate: nil,
            on: fixture.now,
            calendar: fixture.calendar
        ))
    }

    @Test("Bounded source metadata is preserved for honest presentation")
    func boundedCountsRemainExplicit() throws {
        let fixture = try Fixture()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                activeMedicationPlanCount: 64,
                medicationPlansAreTruncated: true,
                medicationLogsAreTruncated: true,
                metricLogsAreTruncated: true,
                reportsAreTruncated: true,
                conditionsAreTruncated: true,
                observationsAreTruncated: true
            ),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.recordCounts.activeMedicationPlans == HumanHealthSummaryBoundedCount(
            loaded: 64,
            isTruncated: true
        ))
        #expect(snapshot.recordCounts.trackedMetrics.isTruncated)
        #expect(snapshot.recordCounts.reports.isTruncated)
        #expect(snapshot.recordCounts.activeConditions.isTruncated)
        #expect(snapshot.medicationLogsAreTruncated)
        #expect(snapshot.metricLogsAreTruncated)
        #expect(snapshot.observationsAreTruncated)
    }

    @Test("A truncated medication plan read cannot claim every dose is handled")
    func truncatedMedicationPlansKeepTodayIncomplete() throws {
        let fixture = try Fixture()
        let medicationID = UUID()
        let snapshot = HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                activeMedicationPlanCount: 64,
                medicationPlansAreTruncated: true,
                doses: [dose(medicationID, at: fixture.hour(8), state: .taken)]
            ),
            now: fixture.now,
            calendar: fixture.calendar
        )

        #expect(snapshot.medicationScheduleIsIncomplete)
        #expect(!snapshot.medicationLogsAreTruncated)
        #expect(!snapshot.highlights.contains(.dosesHandled(1)))
    }

    @Test("Day identity changes at local midnight")
    func dayIdentityChangesAtMidnight() throws {
        let fixture = try Fixture()
        let tomorrow = try #require(fixture.calendar.date(byAdding: .day, value: 1, to: fixture.now))

        #expect(HumanHealthSummaryDayIdentity.key(for: fixture.now, calendar: fixture.calendar) !=
            HumanHealthSummaryDayIdentity.key(for: tomorrow, calendar: fixture.calendar))
    }

    @Test("Summary route defers every bounded read until after its first frame")
    func summaryRouteDefersEveryBoundedRead() throws {
        let route = try source(
            "Ohana/Features/HumanHealth/Summary/HumanHealthSummaryDataContainer.swift"
        )

        #expect(route.components(separatedBy: "@Query").count - 1 == 0)
        #expect(route.contains("RouteFirstFrameDeferredLoad("))
        #expect(route.contains("route-first-frame: allow deferred-fetch"))
        #expect(route.contains("homeRevisionUpdates"))
        #expect(route.contains("homeRevisionUpdates.dropFirst()"))
        #expect(route.contains("guard readRevision != revision.value else { return }"))
        #expect(route.contains("readRevision = revision.value"))
        #expect(!route.contains("readRevision &+= 1"))
        #expect(route.contains("HumanHealthSummaryDayIdentity.key(for: referenceDate)"))
        #expect(!route.contains("referenceDate.timeIntervalSinceReferenceDate"))
        for descriptor in [
            "medicationDescriptor.fetchLimit",
            "medicationLogDescriptor.fetchLimit",
            "metricDescriptor.fetchLimit",
            "reportDescriptor.fetchLimit",
            "conditionDescriptor.fetchLimit",
            "observationDescriptor.fetchLimit"
        ] {
            #expect(route.contains(descriptor))
        }
        for loadState in [
            "!medicationsDidLoad",
            "!medicationLogsDidLoad",
            "!metricLogsDidLoad",
            "!reportsDidLoad",
            "!conditionsDidLoad",
            "!observationsDidLoad"
        ] {
            #expect(route.contains(loadState))
        }
    }

    @Test("Route reload subscribers ignore the current-value replay")
    func routeReloadSubscribersIgnoreCurrentValueReplay() throws {
        for path in [
            "Ohana/Features/HumanHealth/Summary/HumanHealthSummaryDataContainer.swift",
            "Ohana/Features/Medication/HumanMedicationDataContainer.swift",
            "Ohana/Features/Health/Views/HumanHealthMetricDetailView.swift",
            "Ohana/Features/HumanHealth/HumanHealthReportDataContainer.swift",
            "Ohana/Features/Health/HumanHealthCheckupDataContainer.swift",
            "Ohana/Features/Documents/Views/DocumentsListRouteContainer.swift"
        ] {
            let route = try source(path)
            #expect(route.contains("homeRevisionUpdates.dropFirst()"), "\(path) must ignore the replayed current revision")
        }
    }

    private func dose(
        _ medicationID: UUID,
        at date: Date,
        state: HumanHealthSummaryDoseState
    ) -> HumanHealthSummaryDoseInput {
        HumanHealthSummaryDoseInput(
            medicationID: medicationID,
            name: "Medicine",
            dosage: "1 tablet",
            scheduledTime: date,
            state: state
        )
    }

    private func metric(
        key: String,
        value: Double,
        date: Date,
        status: HumanHealthSummaryMetricStatus,
        unitCode: String = "mIU_L"
    ) -> HumanHealthSummaryMetricInput {
        HumanHealthSummaryMetricInput(
            id: UUID(),
            metricKey: key,
            unitCode: unitCode,
            value: value,
            date: date,
            createdAt: date,
            status: status
        )
    }

    private func report(
        id: UUID = UUID(),
        reportTypeRaw: String = "血液检测",
        reportDate: Date,
        nextCheckDate: Date?,
        createdAt: Date? = nil
    ) -> HumanHealthSummaryReportInput {
        HumanHealthSummaryReportInput(
            id: id,
            reportTypeRaw: reportTypeRaw,
            reportDate: reportDate,
            nextCheckDate: nextCheckDate,
            createdAt: createdAt ?? reportDate
        )
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}

private struct Fixture {
    let calendar: Calendar
    let now: Date

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        self.calendar = calendar
        now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 2,
            hour: 14
        )))
    }

    func hour(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now) ?? now
    }
}
