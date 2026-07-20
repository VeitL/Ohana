//
//  SystemSurfaceContracts.swift
//  Ohana
//
//  Value-only contracts shared by the app and the WidgetKit extension.
//

import ActivityKit
import Foundation

nonisolated enum OhanaSystemSurfaceConstants {
    static let todayCareWidgetKind = "com.guanchen.li.Ohana.today-care"
    static let snapshotFileName = "today-care-widget-v1.json"

    static var appGroupIdentifier: String {
        #if OHANA_LOCAL_DEVICE
            "group.com.guanchen.li.Ohana.LocalDevice"
        #else
            "group.com.guanchen.li.Ohana"
        #endif
    }
}

nonisolated enum SystemSurfaceAccess: String, Codable, Equatable, Sendable {
    case personal
    case upgradeRequired
    case unavailable
}

nonisolated enum TodayCareWidgetUrgency: String, Codable, Equatable, Sendable {
    case standard
    case overdue
    case critical
}

nonisolated struct TodayCareWidgetItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let subjectName: String?
    let symbolName: String
    let dueAt: Date?
    let urgency: TodayCareWidgetUrgency

    init(
        id: String,
        title: String,
        subjectName: String?,
        symbolName: String,
        dueAt: Date?,
        urgency: TodayCareWidgetUrgency
    ) {
        self.id = id
        self.title = title
        self.subjectName = subjectName
        self.symbolName = symbolName
        self.dueAt = dueAt
        self.urgency = urgency
    }

    var deepLinkURL: URL {
        OhanaExternalRoute.taskCenter(focusedItemID: id).url
    }
}

nonisolated struct TodayCareWidgetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let languageCode: String
    let access: SystemSurfaceAccess
    let completedTodayCount: Int
    let totalTodayCount: Int
    let overdueCount: Int
    let items: [TodayCareWidgetItem]
    let nextRefreshAt: Date

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        generatedAt: Date,
        languageCode: String,
        access: SystemSurfaceAccess,
        completedTodayCount: Int,
        totalTodayCount: Int,
        overdueCount: Int,
        items: [TodayCareWidgetItem],
        nextRefreshAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.languageCode = languageCode
        self.access = access
        self.completedTodayCount = max(0, completedTodayCount)
        self.totalTodayCount = max(0, totalTodayCount)
        self.overdueCount = max(0, overdueCount)
        self.items = Array(items.prefix(3))
        self.nextRefreshAt = nextRefreshAt
    }

    static func upgradeRequired(languageCode: String, now: Date = Date()) -> Self {
        TodayCareWidgetSnapshot(
            generatedAt: now,
            languageCode: languageCode,
            access: .upgradeRequired,
            completedTodayCount: 0,
            totalTodayCount: 0,
            overdueCount: 0,
            items: [],
            nextRefreshAt: nextMidnight(after: now)
        )
    }

    static func unavailable(languageCode: String, now: Date = Date()) -> Self {
        TodayCareWidgetSnapshot(
            generatedAt: now,
            languageCode: languageCode,
            access: .unavailable,
            completedTodayCount: 0,
            totalTodayCount: 0,
            overdueCount: 0,
            items: [],
            nextRefreshAt: now.addingTimeInterval(60 * 30)
        )
    }

    static func placeholder(now: Date = Date()) -> Self {
        TodayCareWidgetSnapshot(
            generatedAt: now,
            languageCode: "en",
            access: .personal,
            completedTodayCount: 2,
            totalTodayCount: 4,
            overdueCount: 1,
            items: [
                TodayCareWidgetItem(
                    id: "placeholder-water",
                    title: "Fresh water",
                    subjectName: "Mochi",
                    symbolName: "drop.fill",
                    dueAt: now.addingTimeInterval(60 * 20),
                    urgency: .standard
                ),
                TodayCareWidgetItem(
                    id: "placeholder-walk",
                    title: "Walk",
                    subjectName: "Piper",
                    symbolName: "figure.walk",
                    dueAt: now.addingTimeInterval(60 * 60),
                    urgency: .standard
                )
            ],
            nextRefreshAt: now.addingTimeInterval(60 * 20)
        )
    }

    var deepLinkURL: URL {
        OhanaExternalRoute.taskCenter(focusedItemID: nil).url
    }

    func isFresh(at date: Date) -> Bool {
        access != .personal || date < nextRefreshAt
    }

    private static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(60 * 60 * 24)
    }
}

nonisolated struct SystemSurfaceSnapshotStore: Sendable {
    enum StoreError: Error, Equatable {
        case containerUnavailable
        case unsupportedSchema(Int)
    }

    let containerURL: URL?

    init(containerURL: URL?) {
        self.containerURL = containerURL
    }

    static var live: Self {
        SystemSurfaceSnapshotStore(
            containerURL: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: OhanaSystemSurfaceConstants.appGroupIdentifier
            )
        )
    }

    var snapshotURL: URL? {
        containerURL?.appendingPathComponent(OhanaSystemSurfaceConstants.snapshotFileName, isDirectory: false)
    }

    func read() throws -> TodayCareWidgetSnapshot? {
        guard let snapshotURL else { throw StoreError.containerUnavailable }
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return nil }
        let data = try Data(contentsOf: snapshotURL)
        let snapshot = try JSONDecoder().decode(TodayCareWidgetSnapshot.self, from: data)
        guard snapshot.schemaVersion == TodayCareWidgetSnapshot.currentSchemaVersion else {
            throw StoreError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func write(_ snapshot: TodayCareWidgetSnapshot) throws {
        guard let snapshotURL else { throw StoreError.containerUnavailable }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = snapshotURL
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            try? FileManager.default.removeItem(at: snapshotURL)
            throw error
        }
    }

    func removeSnapshotIfPresent() throws {
        guard let snapshotURL else { return }
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        try FileManager.default.removeItem(at: snapshotURL)
    }
}

nonisolated enum OhanaExternalRoute: Equatable, Sendable {
    case taskCenter(focusedItemID: String?)
    case activeWalk(petID: UUID)
    case settings

    static var scheme: String {
        #if OHANA_LOCAL_DEVICE
            "ohana-local"
        #else
            "ohana"
        #endif
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case let .taskCenter(focusedItemID):
            components.host = "task-center"
            if let focusedItemID {
                components.queryItems = [URLQueryItem(name: "item", value: focusedItemID)]
            }
        case let .activeWalk(petID):
            components.host = "walk"
            components.queryItems = [URLQueryItem(name: "pet", value: petID.uuidString)]
        case .settings:
            components.host = "settings"
        }
        return components.url ?? URL(string: "\(Self.scheme)://task-center")!
    }

    static func parse(_ url: URL) -> Self? {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased()
        else { return nil }

        switch host {
        case "task-center":
            let focusedItemID = components.queryItems?
                .first(where: { $0.name == "item" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .taskCenter(focusedItemID: focusedItemID?.isEmpty == false ? focusedItemID : nil)
        case "walk":
            guard let rawID = components.queryItems?.first(where: { $0.name == "pet" })?.value,
                  let petID = UUID(uuidString: rawID)
            else { return nil }
            return .activeWalk(petID: petID)
        case "settings":
            return .settings
        default:
            return nil
        }
    }
}

nonisolated enum WalkActivityPhase: String, Codable, Equatable, Hashable, Sendable {
    case running
    case paused
    case finished
}

nonisolated struct WalkActivityAttributes: ActivityAttributes, Hashable, Sendable {
    nonisolated struct ContentState: Codable, Equatable, Hashable, Sendable {
        let phase: WalkActivityPhase
        let elapsedSeconds: TimeInterval
        let elapsedReferenceDate: Date
        let distanceMeters: Double
        let poopCount: Int
        let measurementSystemCode: String
        let updatedAt: Date

        init(
            phase: WalkActivityPhase,
            elapsedSeconds: TimeInterval,
            elapsedReferenceDate: Date,
            distanceMeters: Double,
            poopCount: Int,
            measurementSystemCode: String,
            updatedAt: Date
        ) {
            self.phase = phase
            self.elapsedSeconds = max(0, elapsedSeconds)
            self.elapsedReferenceDate = elapsedReferenceDate
            self.distanceMeters = max(0, distanceMeters)
            self.poopCount = max(0, poopCount)
            self.measurementSystemCode = measurementSystemCode == "imperial" ? "imperial" : "metric"
            self.updatedAt = updatedAt
        }
    }

    let sessionID: UUID
    let petID: UUID
    let petName: String
    let startedAt: Date
    let languageCode: String
}
