//
//  FamilyWeeklyReportDataContainer.swift
//  Ohana
//
//  Screen-level query container for the weekly family report.
//

import SwiftData
import SwiftUI

struct FamilyWeeklyReportDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = FamilyWeeklyReportRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        FamilyWeeklyReportDashboardContentView(
            pets: routeData.pets,
            humans: routeData.humans,
            ledgerEvents: routeData.ledgerEvents,
            photoMemories: routeData.photoMemories,
            healthAlertSources: routeData.healthAlertSources
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = FamilyWeeklyReportRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct FamilyWeeklyReportRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var ledgerEvents: [CareLedgerEvent] = []
    var photoMemories: [FamilyWeeklyPhotoMemory] = []
    var healthAlertSources: [PetHealthAlertSource] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> FamilyWeeklyReportRouteData {
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Pet"
        )
        return FamilyWeeklyReportRouteData(
            pets: pets,
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            ledgerEvents: fetchLedgerEvents(from: context),
            photoMemories: fetchPhotoMemories(pets: pets, from: context),
            healthAlertSources: PetHealthAlertSourceRouteData.load(pets: pets, from: context),
            hasLoaded: true
        )
    }

    private static func fetchLedgerEvents(from context: ModelContext) -> [CareLedgerEvent] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let start = fourWeekWindowStart()
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.occurredAt >= start
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1200
        return fetch(descriptor, context: context, name: "CareLedgerEvent")
    }

    private static func fetchPhotoMemories(pets: [Pet], from context: ModelContext) -> [FamilyWeeklyPhotoMemory] {
        let activePetNames = Dictionary(uniqueKeysWithValues: pets.filter { !$0.hasPassedAway }.map { ($0.id, $0.name) })
        guard !activePetNames.isEmpty else { return [] }
        let interval = currentWeekInterval()
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<PetPhotoLog>(
            predicate: #Predicate<PetPhotoLog> { log in
                log.date >= start &&
                    log.date < end
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return fetch(descriptor, context: context, name: "PetPhotoLog")
            .compactMap { log in
                guard let petID = log.pet?.id,
                      let petName = activePetNames[petID] else { return nil }
                return FamilyWeeklyPhotoMemory(
                    id: log.id,
                    modelID: log.persistentModelID,
                    petName: petName,
                    imageSignature: log.imageThumbnailSignature,
                    canAttemptImageAttachmentLoad: log.canAttemptImageAttachmentLoad,
                    note: log.note,
                    date: log.date
                )
            }
    }

    private static func fourWeekWindowStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        return calendar.date(byAdding: .weekOfYear, value: -3, to: currentWeekStart)
            ?? currentWeekStart.addingTimeInterval(-21 * 86400)
    }

    private static func currentWeekInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: now.addingTimeInterval(-6 * 86400), duration: 7 * 86400)
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Family weekly report failed to fetch \(name): \(error.localizedDescription)",
                category: "FamilyReports"
            )
            return []
        }
    }
}
