//
//  MemberProfileRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for member profile destinations.
//

import SwiftData
import SwiftUI

struct AppPetRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = PetProfileRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let initialTab: PetDetailTab

    init(id: UUID, initialTab: PetDetailTab) {
        self.id = id
        self.initialTab = initialTab
    }

    var body: some View {
        Group {
            if let pet = routeData.pet {
                if initialTab == .health {
                    PetHealthDetailView(pet: pet)
                } else {
                    PetBasicInfoDetailView(pet: pet)
                }
            } else if routeData.hasLoaded {
                MemberProfileMissingEntityView(kind: "pet")
            } else {
                MemberProfileLoadingEntityView(kind: "pet")
            }
        }
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
            routeData = PetProfileRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct AppHumanRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = HumanProfileRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    init(
        id: UUID,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        self.id = id
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        Group {
            if let human = routeData.human {
                HumanDetailView(
                    human: human,
                    allPets: routeData.allPets,
                    allHumans: routeData.allHumans,
                    allPendingReminders: routeData.allPendingReminders,
                    allMeds: routeData.allMeds,
                    allReports: routeData.allReports,
                    onPresentCoconutLog: onPresentCoconutLog
                )
            } else if routeData.hasLoaded {
                MemberProfileMissingEntityView(kind: "human")
            } else {
                MemberProfileLoadingEntityView(kind: "human")
            }
        }
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
            routeData = HumanProfileRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct PetProfileRouteData {
    var pet: Pet?
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> PetProfileRouteData {
        PetProfileRouteData(
            pet: fetchOne(
                FetchDescriptor<Pet>(
                    predicate: #Predicate<Pet> { $0.id == id }
                ),
                context: context,
                name: "Pet"
            ),
            hasLoaded: true
        )
    }
}

private struct HumanProfileRouteData {
    var human: Human?
    var allPets: [Pet] = []
    var allHumans: [Human] = []
    var allPendingReminders: [Reminder] = []
    var allMeds: [HumanMedication] = []
    var allReports: [HumanHealthReport] = []
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> HumanProfileRouteData {
        let humanKey = id.uuidString
        return HumanProfileRouteData(
            human: fetchOne(
                FetchDescriptor<Human>(
                    predicate: #Predicate<Human> { $0.id == id }
                ),
                context: context,
                name: "Human"
            ),
            allPets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            allHumans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            allPendingReminders: fetch(
                FetchDescriptor<Reminder>(
                    predicate: #Predicate<Reminder> { $0.status == "pending" },
                    sortBy: [SortDescriptor(\.scheduledAt)]
                ),
                context: context,
                name: "Reminder"
            ),
            allMeds: fetch(
                FetchDescriptor<HumanMedication>(
                    predicate: #Predicate<HumanMedication> { $0.humanId == humanKey },
                    sortBy: [SortDescriptor(\.createdAt)]
                ),
                context: context,
                name: "HumanMedication"
            ),
            allReports: fetch(
                FetchDescriptor<HumanHealthReport>(
                    predicate: #Predicate<HumanHealthReport> { $0.humanId == humanKey },
                    sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
                ),
                context: context,
                name: "HumanHealthReport"
            ),
            hasLoaded: true
        )
    }
}

private func fetchOne<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    name: String
) -> T? {
    fetch(descriptor, context: context, name: name).first
}

private func fetch<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    name: String
) -> [T] {
    do {
        return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
    } catch {
        OhanaLog.warning(
            "Member profile route data fetch failed for \(name): \(error.localizedDescription)",
            category: "Members"
        )
        return []
    }
}

private struct MemberProfileMissingEntityView: View {
    let kind: String
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text(l.tr(zh: "内容已不可用", en: "Content is no longer available", de: "Inhalt ist nicht mehr verfügbar"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}

private struct MemberProfileLoadingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
