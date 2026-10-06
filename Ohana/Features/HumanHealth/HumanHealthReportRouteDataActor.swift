//
//  HumanHealthReportRouteDataActor.swift
//  Ohana
//
//  Bounded, cancellable route reads for Human health reports.
//

import Foundation
import SwiftData

nonisolated struct HumanHealthReportPageReference: Sendable {
    let recordModelIDs: [PersistentIdentifier]
    let nextCursor: HumanHealthHistoryPageCursor?
    let hasOlder: Bool
}

nonisolated struct HumanHealthReportLinkedMetricsReference: Sendable {
    let recordModelIDs: [PersistentIdentifier]
    let isTruncated: Bool
}

struct HumanHealthReportRouteData {
    nonisolated static let reportPageSize = 50

    var reports: [HumanHealthReport] = []
    var nextCursor: HumanHealthHistoryPageCursor?
    var hasMoreReports = false

    init() {}

    @MainActor
    init(reference: HumanHealthReportPageReference, context: ModelContext) {
        reports = reference.recordModelIDs.compactMap {
            context.model(for: $0) as? HumanHealthReport
        }
        nextCursor = reference.nextCursor
        hasMoreReports = reference.hasOlder
    }

    @MainActor
    mutating func append(_ page: HumanHealthReportPage) {
        let existingIDs = Set(reports.map(\.id))
        reports.append(contentsOf: page.records.filter { !existingIDs.contains($0.id) })
        reports.sort(by: Self.isNewer)
        nextCursor = page.nextCursor
        hasMoreReports = page.hasOlder
    }

    private static func isNewer(_ lhs: HumanHealthReport, _ rhs: HumanHealthReport) -> Bool {
        if lhs.reportDate != rhs.reportDate { return lhs.reportDate > rhs.reportDate }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id > rhs.id
    }
}

@MainActor
struct HumanHealthReportPage {
    let records: [HumanHealthReport]
    let nextCursor: HumanHealthHistoryPageCursor?
    let hasOlder: Bool

    init(reference: HumanHealthReportPageReference, context: ModelContext) {
        records = reference.recordModelIDs.compactMap {
            context.model(for: $0) as? HumanHealthReport
        }
        nextCursor = reference.nextCursor
        hasOlder = reference.hasOlder
    }
}

@ModelActor
actor HumanHealthReportRouteDataActor {
    private static let maximumPageSize = 100
    private static let ownerCandidateMultiplier = 3
    private static let maximumLinkedMetricLimit = 200

    func load(humanID: UUID) throws -> HumanHealthReportPageReference {
        try loadPage(humanID: humanID)
    }

    func loadPage(
        humanID: UUID,
        olderThan cursor: HumanHealthHistoryPageCursor? = nil,
        limit: Int = HumanHealthReportRouteData.reportPageSize
    ) throws -> HumanHealthReportPageReference {
        try Task.checkCancellation()
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        let pageSize = max(1, min(limit, Self.maximumPageSize))
        let candidateLimit = (pageSize + 1) * Self.ownerCandidateMultiplier
        var descriptor: FetchDescriptor<HumanHealthReport>
        if let cursor {
            let cursorDate = cursor.primaryDate
            let cursorCreatedAt = cursor.createdAt
            let cursorID = cursor.id
            descriptor = FetchDescriptor<HumanHealthReport>(
                predicate: #Predicate<HumanHealthReport> { report in
                    (report.humanId.contains(humanKey) || report.humanId.contains(humanKeyLower)) &&
                        (report.reportDate < cursorDate ||
                            (report.reportDate == cursorDate && report.createdAt < cursorCreatedAt) ||
                            (report.reportDate == cursorDate && report.createdAt == cursorCreatedAt && report.id < cursorID))
                },
                sortBy: reportSortDescriptors
            )
        } else {
            descriptor = FetchDescriptor<HumanHealthReport>(
                predicate: #Predicate<HumanHealthReport> { report in
                    report.humanId.contains(humanKey) || report.humanId.contains(humanKeyLower)
                },
                sortBy: reportSortDescriptors
            )
        }
        descriptor.fetchLimit = candidateLimit
        let fetched = try modelContext.fetch(descriptor)
        try Task.checkCancellation()
        let canonical = fetched.filter {
            UUID(uuidString: $0.humanId.trimmingCharacters(in: .whitespacesAndNewlines)) == humanID
        }
        let probed = Array(canonical.prefix(pageSize + 1))
        let records = Array(probed.prefix(pageSize))
        let hasOlder = probed.count > pageSize || fetched.count == candidateLimit
        return HumanHealthReportPageReference(
            recordModelIDs: records.map(\.persistentModelID),
            nextCursor: hasOlder ? records.last.map(Self.makeCursor) : nil,
            hasOlder: hasOlder && !records.isEmpty
        )
    }

    func linkedMetrics(
        humanID: UUID,
        reportID: UUID,
        limit: Int
    ) throws -> HumanHealthReportLinkedMetricsReference {
        try Task.checkCancellation()
        let presentationLimit = max(1, min(limit, Self.maximumLinkedMetricLimit))
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { log in
                log.sourceReportID == reportID && log.human?.id == humanID
            },
            sortBy: [
                SortDescriptor(\HumanHealthMetricLog.date, order: .reverse),
                SortDescriptor(\HumanHealthMetricLog.createdAt, order: .reverse),
                SortDescriptor(\HumanHealthMetricLog.id, order: .reverse)
            ]
        )
        descriptor.fetchLimit = presentationLimit + 1
        let logs = try modelContext.fetch(descriptor)
        try Task.checkCancellation()
        return HumanHealthReportLinkedMetricsReference(
            recordModelIDs: Array(logs.prefix(presentationLimit)).map(\.persistentModelID),
            isTruncated: logs.count > presentationLimit
        )
    }

    private var reportSortDescriptors: [SortDescriptor<HumanHealthReport>] {
        [
            SortDescriptor(\HumanHealthReport.reportDate, order: .reverse),
            SortDescriptor(\HumanHealthReport.createdAt, order: .reverse),
            SortDescriptor(\HumanHealthReport.id, order: .reverse)
        ]
    }

    private static func makeCursor(_ report: HumanHealthReport) -> HumanHealthHistoryPageCursor {
        HumanHealthHistoryPageCursor(
            primaryDate: report.reportDate,
            createdAt: report.createdAt,
            id: report.id
        )
    }
}
