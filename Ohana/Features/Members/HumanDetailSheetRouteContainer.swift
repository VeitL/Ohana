//
//  HumanDetailSheetRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for human detail sheets.
//

import SwiftData
import SwiftUI

enum AppHumanDetailSheetDestination: Hashable {
    case basicInfo
    case medicationQuick
    case medication
    case weightQuick
    case weight
    case workoutQuick
    case workout
    case workoutDashboard
    case metrics
    case report
    case expenseQuick
    case expense
    case wishlist
    case noteQuick
    case note
}

extension AppHumanDetailSheetDestination {
    var isAvailableInMemorialMode: Bool {
        switch self {
        case .basicInfo, .noteQuick, .note:
            true
        case .medicationQuick, .medication, .weightQuick, .weight, .workoutQuick, .workout,
             .workoutDashboard, .metrics, .report, .expenseQuick, .expense, .wishlist:
            false
        }
    }
}

struct HumanAllFeaturesRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = HumanAllFeaturesRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let onMissing: () -> Void
    let onOpenDestination: (UUID, HumanAllFeatureDestination) -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onOpenDestination: @escaping (UUID, HumanAllFeatureDestination) -> Void
    ) {
        self.id = id
        self.onMissing = onMissing
        self.onOpenDestination = onOpenDestination
    }

    var body: some View {
        if let human = routeData.human {
            HumanAllFeaturesSheet(
                human: human,
                allMeds: routeData.allMeds,
                allReports: routeData.allReports,
                allExpenses: routeData.allExpenses,
                summary: routeData.summary,
                onOpenDestination: { destination in
                    guard !human.hasPassedAway || destination.isAvailableInMemorialMode else {
                        return
                    }
                    onOpenDestination(human.id, destination)
                }
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
        } else if routeData.hasLoaded {
            HumanRouteMissingEntityView(kind: "human")
                .onAppear(perform: onMissing)
        } else {
            HumanRouteLoadingEntityView(kind: "human")
                .onAppear {
                    scheduleRouteDataLoad()
                }
                .onDisappear {
                    dataLoadTask?.cancel()
                    dataLoadTask = nil
                }
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = HumanAllFeaturesRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct AppHumanDetailSheetRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = HumanDetailRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let destination: AppHumanDetailSheetDestination
    let onMissing: () -> Void
    let onDismiss: () -> Void
    let onOpenDestination: ((UUID, AppHumanDetailSheetDestination) -> Void)?
    let onHumanDoseTaken: (UUID) -> Void

    init(
        id: UUID,
        destination: AppHumanDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {},
        onOpenDestination: ((UUID, AppHumanDetailSheetDestination) -> Void)? = nil,
        onHumanDoseTaken: @escaping (UUID) -> Void = { _ in }
    ) {
        self.id = id
        self.destination = destination
        self.onMissing = onMissing
        self.onDismiss = onDismiss
        self.onOpenDestination = onOpenDestination
        self.onHumanDoseTaken = onHumanDoseTaken
    }

    var body: some View {
        if let human = routeData.human {
            humanDestination(for: human)
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
        } else if routeData.hasLoaded {
            HumanRouteMissingEntityView(kind: "human")
                .onAppear(perform: onMissing)
        } else {
            HumanRouteLoadingEntityView(kind: "human")
                .onAppear {
                    scheduleRouteDataLoad()
                }
                .onDisappear {
                    dataLoadTask?.cancel()
                    dataLoadTask = nil
                }
        }
    }

    @ViewBuilder
    private func humanDestination(for human: Human) -> some View {
        if human.hasPassedAway && !destination.isAvailableInMemorialMode {
            HumanRouteMissingEntityView(kind: "memorial")
        } else {
            switch destination {
            case .basicInfo:
                NavigationStack { HumanBasicInfoDetailView(human: human) }
            case .medicationQuick:
                QuickHumanMedicationSheet(
                    human: human,
                    onManage: {
                        onOpenDestination?(human.id, .medication)
                    },
                    onDismiss: onDismiss
                )
            case .medication:
                NavigationStack {
                    HumanMedicationView(
                        human: human,
                        showsDoneButton: true,
                        onDoseTaken: {
                            onHumanDoseTaken(human.id)
                        }
                    )
                }
            case .weightQuick:
                GenericWeightEntrySheet(
                    target: .human(human),
                    onDismiss: onDismiss
                )
            case .weight:
                NavigationStack { HumanWeightHistoryView(human: human) }
            case .workoutQuick:
                QuickHumanWorkoutSheet(
                    human: human,
                    onDismiss: onDismiss
                )
            case .workout:
                HumanWorkoutSummaryView(human: human)
            case .workoutDashboard:
                HumanWorkoutSummaryView(human: human)
            case .metrics:
                NavigationStack { HumanHealthCheckupView(human: human) }
            case .report:
                HumanHealthReportView(human: human)
            case .expenseQuick:
                QuickHumanExpenseSheet(
                    human: human,
                    onDismiss: onDismiss
                )
            case .expense:
                NavigationStack { HumanExpenseDetailView(human: human) }
            case .wishlist:
                HumanWishlistView(human: human)
            case .noteQuick:
                QuickHumanNoteSheet(
                    human: human,
                    onDismiss: onDismiss
                )
            case .note:
                HumanNoteHistorySheet(human: human)
            }
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = HumanDetailRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct HumanAllFeaturesRouteData {
    var human: Human?
    var allMeds: [HumanMedication] = []
    var allReports: [HumanHealthReport] = []
    var allExpenses: [PetExpenseLog] = []
    var summary: HumanAllFeaturesActivitySummary = .empty
    var hasLoaded = false

    @MainActor
    static func load(id: UUID, from context: ModelContext) -> HumanAllFeaturesRouteData {
        let humanKey = id.uuidString
        let human = fetchOne(
            FetchDescriptor<Human>(
                predicate: #Predicate<Human> { $0.id == id }
            ),
            context: context,
            name: "Human"
        )
        let allMeds = fetch(
            FetchDescriptor<HumanMedication>(
                predicate: #Predicate<HumanMedication> { $0.humanId == humanKey },
                sortBy: [SortDescriptor(\.createdAt)]
            ),
            context: context,
            name: "HumanMedication"
        )
        let allReports = fetch(
            FetchDescriptor<HumanHealthReport>(
                predicate: #Predicate<HumanHealthReport> { $0.humanId == humanKey },
                sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
            ),
            context: context,
            name: "HumanHealthReport"
        )
        let allExpenses = fetch(
            FetchDescriptor<PetExpenseLog>(
                predicate: #Predicate<PetExpenseLog> { $0.executorId == humanKey },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            context: context,
            name: "PetExpenseLog"
        )
        return HumanAllFeaturesRouteData(
            human: human,
            allMeds: allMeds,
            allReports: allReports,
            allExpenses: allExpenses,
            summary: human.map {
                HumanAllFeaturesActivitySummary.load(
                    human: $0,
                    allMeds: allMeds,
                    allReports: allReports,
                    allExpenses: allExpenses
                )
            } ?? .empty,
            hasLoaded: true
        )
    }
}

private struct HumanDetailRouteData {
    var human: Human?
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> HumanDetailRouteData {
        HumanDetailRouteData(
            human: fetchOne(
                FetchDescriptor<Human>(
                    predicate: #Predicate<Human> { $0.id == id }
                ),
                context: context,
                name: "Human"
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
            "Human detail route data fetch failed for \(name): \(error.localizedDescription)",
            category: "Members"
        )
        return []
    }
}

struct HumanRouteMissingEntityView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    let kind: String
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
            Text(localizedKind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }

    private var localizedKind: String {
        switch kind {
        case "human":
            l.tr(zh: "成员", en: "Member", de: "Mitglied")
        case "memorial":
            l.tr(zh: "纪念资料", en: "Memorial profile", de: "Gedenkprofil")
        default:
            kind
        }
    }
}

private struct HumanRouteLoadingEntityView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    let kind: String
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(localizedKind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }

    private var localizedKind: String {
        switch kind {
        case "human":
            l.tr(zh: "正在载入成员", en: "Loading member", de: "Mitglied wird geladen")
        default:
            kind
        }
    }
}
