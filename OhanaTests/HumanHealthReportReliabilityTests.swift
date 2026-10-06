import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanHealthReportReliabilityTests {
    @Test func firstLoadFailureTransitionsToBlockingFailedStateAndRetryReturnsToLoading() {
        var state = HumanHealthReportDataState()

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadFailed)
        #expect(state.phase == .failed)
        #expect(!state.hasSuccessfulSnapshot)
        #expect(!state.refreshFailed)
        #expect(!state.isRefreshing)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadStarted)
        #expect(state.phase == .loading)
        #expect(!state.refreshFailed)
    }

    @Test func refreshFailurePreservesLoadedSnapshotAndShowsNonBlockingError() {
        var state = HumanHealthReportDataStateReducer.reduce(
            HumanHealthReportDataState(),
            event: .loadSucceeded
        )

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadStarted)
        #expect(state.phase == .loaded)
        #expect(state.hasSuccessfulSnapshot)
        #expect(state.isRefreshing)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadFailed)
        #expect(state.phase == .loaded)
        #expect(state.hasSuccessfulSnapshot)
        #expect(state.refreshFailed)
        #expect(!state.isRefreshing)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadStarted)
        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadSucceeded)
        #expect(state.phase == .loaded)
        #expect(!state.refreshFailed)
        #expect(!state.isRefreshing)
    }

    @Test func cancelledRefreshKeepsSnapshotAndRequiresReloadOnNextAppearance() {
        var state = HumanHealthReportDataStateReducer.reduce(
            HumanHealthReportDataState(),
            event: .loadSucceeded
        )

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadStarted)
        #expect(state.isRefreshing)
        #expect(!state.needsReload)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadCancelled)
        #expect(state.phase == .loaded)
        #expect(state.hasSuccessfulSnapshot)
        #expect(!state.isRefreshing)
        #expect(state.needsReload)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadStarted)
        #expect(state.phase == .loaded)
        #expect(state.isRefreshing)
        #expect(!state.needsReload)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadSucceeded)
        #expect(!state.isRefreshing)
        #expect(!state.needsReload)
    }

    @Test func cancelledRetryPreservesStaleSnapshotWarningUntilSuccess() {
        var state = HumanHealthReportDataStateReducer.reduce(
            HumanHealthReportDataState(),
            event: .loadSucceeded
        )
        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadFailed)
        #expect(state.refreshFailed)

        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadStarted)
        #expect(state.refreshFailed)
        state = HumanHealthReportDataStateReducer.reduce(state, event: .loadCancelled)

        #expect(state.phase == .loaded)
        #expect(state.refreshFailed)
        #expect(state.needsReload)
    }

    @Test func mutationFailuresReleaseSavingStateAndRetainFailedAction() {
        for action in HumanHealthReportMutationAction.allCases {
            var state = HumanHealthReportMutationStateReducer.reduce(
                HumanHealthReportMutationState(),
                event: .started(action)
            )
            #expect(state.isSaving)
            #expect(state.activeAction == action)
            #expect(state.failedAction == nil)

            state = HumanHealthReportMutationStateReducer.reduce(
                state,
                event: .completed(action, succeeded: false)
            )
            #expect(!state.isSaving)
            #expect(state.failedAction == action)

            state = HumanHealthReportMutationStateReducer.reduce(state, event: .started(action))
            state = HumanHealthReportMutationStateReducer.reduce(
                state,
                event: .completed(action, succeeded: true)
            )
            #expect(!state.isSaving)
            #expect(state.failedAction == nil)
        }
    }

    @Test func routeLoadMatchesCanonicalAndLegacyLowercaseHumanIDs() async throws {
        let humanID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let otherID = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let container = try ModelContainer(
            for: Schema([HumanHealthReport.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let canonical = HumanHealthReport(
            humanId: humanID.uuidString,
            reportDate: Date(timeIntervalSinceReferenceDate: 100)
        )
        let legacyLowercase = HumanHealthReport(
            humanId: humanID.uuidString.lowercased(),
            reportDate: Date(timeIntervalSinceReferenceDate: 200)
        )
        let legacyWhitespace = HumanHealthReport(
            humanId: "  \(humanID.uuidString.lowercased())  ",
            reportDate: Date(timeIntervalSinceReferenceDate: 250)
        )
        let unrelated = HumanHealthReport(
            humanId: otherID.uuidString,
            reportDate: Date(timeIntervalSinceReferenceDate: 300)
        )
        context.insert(canonical)
        context.insert(legacyLowercase)
        context.insert(legacyWhitespace)
        context.insert(unrelated)
        try context.save()

        let reference = try await HumanHealthReportRouteDataActor(modelContainer: container)
            .load(humanID: humanID)
        let loaded = HumanHealthReportRouteData(reference: reference, context: context)

        #expect(loaded.reports.map(\.id) == [legacyWhitespace.id, legacyLowercase.id, canonical.id])
        #expect(!loaded.hasMoreReports)
    }

    @Test func routeLoadIsBoundedToNewestReports() async throws {
        let humanID = UUID()
        let container = try ModelContainer(
            for: Schema([HumanHealthReport.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let reportCount = HumanHealthReportRouteData.reportPageSize + 5
        for offset in 0 ..< reportCount {
            context.insert(HumanHealthReport(
                humanId: humanID.uuidString,
                reportDate: Date(timeIntervalSinceReferenceDate: Double(offset))
            ))
        }
        try context.save()

        let actor = HumanHealthReportRouteDataActor(modelContainer: container)
        let reference = try await actor.load(humanID: humanID)
        let loaded = HumanHealthReportRouteData(reference: reference, context: context)

        #expect(loaded.reports.count == HumanHealthReportRouteData.reportPageSize)
        #expect(loaded.hasMoreReports)
        #expect(loaded.reports.first?.reportDate == Date(timeIntervalSinceReferenceDate: Double(reportCount - 1)))
        #expect(loaded.reports.last?.reportDate == Date(timeIntervalSinceReferenceDate: 5))

        let olderReference = try await actor.loadPage(
            humanID: humanID,
            olderThan: loaded.nextCursor
        )
        let olderPage = HumanHealthReportPage(reference: olderReference, context: context)
        var accumulated = loaded
        accumulated.append(olderPage)

        #expect(accumulated.reports.count == reportCount)
        #expect(!accumulated.hasMoreReports)
        #expect(accumulated.reports.last?.reportDate == Date(timeIntervalSinceReferenceDate: 0))
    }

    @Test func linkedMetricReadIsOwnerScopedBoundedAndReturnsStableModelIDs() async throws {
        let container = try ModelContainer(
            for: Schema(ArkSchemaV99.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = container.mainContext
        let human = Human(name: "Owner")
        let otherHuman = Human(name: "Other")
        let report = HumanHealthReport(humanId: human.id.uuidString, captureSource: .documentScan)
        let otherReport = HumanHealthReport(humanId: human.id.uuidString, captureSource: .documentScan)
        let oldest = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 1,
            date: Date(timeIntervalSinceReferenceDate: 100),
            sourceReportID: report.id,
            human: human
        )
        let middle = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2,
            date: Date(timeIntervalSinceReferenceDate: 200),
            sourceReportID: report.id,
            human: human
        )
        let newest = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 3,
            date: Date(timeIntervalSinceReferenceDate: 300),
            sourceReportID: report.id,
            human: human
        )
        let otherOwner = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 4,
            date: Date(timeIntervalSinceReferenceDate: 400),
            sourceReportID: report.id,
            human: otherHuman
        )
        let otherSource = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 5,
            date: Date(timeIntervalSinceReferenceDate: 500),
            sourceReportID: otherReport.id,
            human: human
        )
        context.insert(human)
        context.insert(otherHuman)
        context.insert(report)
        context.insert(otherReport)
        for log in [oldest, middle, newest, otherOwner, otherSource] {
            context.insert(log)
        }
        try context.save()

        let reference = try await HumanHealthReportRouteDataActor(modelContainer: container).linkedMetrics(
            humanID: human.id,
            reportID: report.id,
            limit: 2
        )
        let loadedIDs = reference.recordModelIDs.compactMap {
            (context.model(for: $0) as? HumanHealthMetricLog)?.id
        }

        #expect(loadedIDs == [newest.id, middle.id])
        #expect(reference.isTruncated)
    }

    @Test func reportSourceKeepsMemorialAndFailureBoundariesVisible() throws {
        let rootURL = repositoryRootURL()
        let dataSource = try source(
            "Ohana/Features/HumanHealth/HumanHealthReportDataContainer.swift",
            rootURL: rootURL
        )
        let actorSource = try source(
            "Ohana/Features/HumanHealth/HumanHealthReportRouteDataActor.swift",
            rootURL: rootURL
        )
        let viewSource = try source(
            "Ohana/Features/HumanHealth/Views/HumanHealthReportView.swift",
            rootURL: rootURL
        )

        #expect(actorSource.contains("report.humanId.contains(humanKey) || report.humanId.contains(humanKeyLower)"))
        #expect(dataSource.contains("case .loading, .failed"))
        #expect(dataSource.contains("refreshFailed: dataState.refreshFailed"))
        #expect(dataSource.contains("case .loadCancelled"))
        #expect(dataSource.contains("force: dataState.needsReload"))
        #expect(actorSource.contains("descriptor.fetchLimit = candidateLimit"))
        #expect(actorSource.contains("olderThan cursor"))
        #expect(actorSource.contains("@ModelActor"))
        #expect(actorSource.contains("records.map(\\.persistentModelID)"))
        #expect(!dataSource.contains("@Query"))
        #expect(!dataSource.contains("context.fetch("))
        #expect(dataSource.contains(".task(id: linkedMetricLoadID)"))
        #expect(dataSource.contains("reloadRequestedWhileLoading"))
        #expect(viewSource.contains("if !isPrivacyLocked && !isReadOnly"))
        #expect(viewSource.contains(".disabled(isReadOnly)"))
        #expect(viewSource.contains("result.didChange && result.persistenceErrorDescription == nil"))
        #expect(viewSource.contains("UIAccessibility.post"))
        #expect(viewSource.contains("add-human-health-report-command-error"))
        #expect(viewSource.contains("HumanHealthReportDetailView(human: human, report: report)"))
        #expect(viewSource.contains("human-health-report-detail-edit-action"))
        #expect(viewSource.contains("human-health-report-lab-import-action"))
        #expect(viewSource.contains("showingDeleteConfirmation"))
        #expect(viewSource.contains("Requires confirmation"))
        #expect(viewSource.contains("interactiveDismissDisabled(isSaving || hasUnsavedChanges)"))
        #expect(dataSource.contains("human-health-report-linked-metrics"))
        #expect(dataSource.contains("else if dataPhase == .failed"))
        #expect(dataSource.contains("human-health-report-linked-metrics-load-failed-state"))
        #expect(dataSource.contains("human-health-report-linked-metrics-load-retry-action"))
        #expect(viewSource.contains("HumanHealthReportLinkedMetricsView("))
    }

    @Test func reportDatesAndFollowUpOrderAreValidatedByTheDomain() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 12)))
        let future = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        let past = try #require(calendar.date(byAdding: .day, value: -1, to: now))

        #expect(HumanHealthReportInputValidation.error(
            for: input(reportDate: future),
            now: now,
            calendar: calendar
        ) == "reportDate.future")
        #expect(HumanHealthReportInputValidation.error(
            for: input(reportDate: now, nextCheckDate: past),
            now: now,
            calendar: calendar
        ) == "nextCheckDate.beforeReportDate")
        #expect(HumanHealthReportInputValidation.error(
            for: input(reportDate: past, nextCheckDate: future),
            now: now,
            calendar: calendar
        ) == nil)
    }

    @Test func reportCommandsDoNotSaveOrRollbackUnrelatedPendingChanges() throws {
        let container = try ModelContainer(
            for: Schema(ArkSchemaV97.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = container.mainContext
        let human = Human(name: "Owner")
        context.insert(human)
        try context.save()

        let unrelatedPending = HumanHealthReport(
            humanId: UUID().uuidString,
            reportType: .other,
            reportDate: Date()
        )
        context.insert(unrelatedPending)

        let result = HumanHealthReportCommandService.createReport(
            human: human,
            input: input(reportDate: Date()),
            context: context
        )

        #expect(!result.didChange)
        #expect(result.persistenceErrorDescription != nil)
        #expect(context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).map(\.id) == [unrelatedPending.id])
    }

    @Test func scannedReportsKeepTheirBloodTestType() throws {
        let container = try ModelContainer(
            for: Schema(ArkSchemaV97.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = container.mainContext
        let human = Human(name: "Owner")
        let report = HumanHealthReport(
            humanId: human.id.uuidString,
            reportType: .bloodTest,
            reportDate: Date(),
            captureSource: .documentScan
        )
        context.insert(human)
        context.insert(report)
        try context.save()

        let result = HumanHealthReportCommandService.updateReport(
            report,
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .physical,
                conclusion: .normal,
                hospitalName: "",
                doctorName: "",
                reportDate: report.reportDate,
                nextCheckDate: nil,
                summary: "",
                notes: ""
            ),
            context: context
        )

        #expect(!result.didChange)
        #expect(result.persistenceErrorDescription == "documentScan.reportTypeLocked")
        #expect(report.reportType == .bloodTest)
        #expect(!context.hasChanges)
    }

    private func input(
        reportDate: Date,
        nextCheckDate: Date? = nil
    ) -> HumanHealthReportCommandInput {
        HumanHealthReportCommandInput(
            reportType: .physical,
            conclusion: .normal,
            hospitalName: "",
            doctorName: "",
            reportDate: reportDate,
            nextCheckDate: nextCheckDate,
            summary: "",
            notes: ""
        )
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
