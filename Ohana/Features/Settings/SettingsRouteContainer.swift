import SwiftData
import SwiftUI

struct AppAccountSwitcherRouteContainer: View {
    @Environment(\.modelContext) private var modelContext

    var allowsDismiss = true
    let onSwitched: () -> Void

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: AccountSwitcherRouteData(),
            loadDelayMilliseconds: 120,
            shouldLoad: { !$0.hasLoaded },
            load: { AccountSwitcherRouteData.load(from: modelContext) }
        ) { data in
            HumanAccountSwitcherSheet(
                humans: data.humans,
                homePets: data.pets,
                homeHumans: data.humans,
                homeElectronicPets: data.electronicPets,
                allowsDismiss: allowsDismiss,
                onSwitched: onSwitched
            )
        }
    }
}

struct AppSettingsSheetRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(AppExperienceController.self) private var experienceController
    @State private var routeData = SettingsRouteData.empty
    @State private var routeLoadErrorMessage: String?
    @State private var routeDataLoadTask: Task<Void, Never>?
    @State private var revisionReloadTask: Task<Void, Never>?

    let onClose: () -> Void

    var body: some View {
        SettingsView(
            homeHouseholds: routeData.households,
            homePets: routeData.pets,
            homeHumans: routeData.humans,
            isRouteDataLoaded: routeData.hasLoaded,
            routeLoadErrorMessage: routeLoadErrorMessage,
            onRetryRouteData: { scheduleRouteDataLoad() },
            experienceMode: experienceController.mode,
            zenOwnerHumanID: experienceController.zenOwnerHumanID,
            onRequestExperienceModeChange: { mode in
                guard mode != experienceController.mode else { return }
                onClose()
                dismiss()
                experienceController.switchAfterRouteDismissal(to: mode)
            },
            onRequestZenOwnerChange: experienceController.bindZenOwner,
            onClose: onClose
        )
        .task {
            SettingsOpenPerformance.ensureStarted(source: "settingsRoute")
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            SettingsOpenPerformance.mark(AppPerformancePhases.firstFrame)
            scheduleRouteDataLoad()
        }
        .onDisappear {
            routeDataLoadTask?.cancel()
            revisionReloadTask?.cancel()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            guard SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: revision) else { return }
            scheduleRevisionReload()
        }
    }

    @MainActor
    private func scheduleRouteDataLoad() {
        routeDataLoadTask?.cancel()
        let container = modelContext.container
        routeDataLoadTask = Task { @MainActor in
            do {
                let data = try await SettingsRouteDataActor(modelContainer: container).load()
                try Task.checkCancellation()
                routeData = data
                routeLoadErrorMessage = nil
                SettingsOpenPerformance.mark(AppPerformancePhases.dataReady)
            } catch is CancellationError {
                return
            } catch {
                routeData = SettingsRouteDataFailurePolicy.preservingLastGoodData(routeData)
                routeLoadErrorMessage = error.localizedDescription
                OhanaLog.warning(
                    "Settings route snapshot load failed: \(error.localizedDescription)",
                    category: "Settings"
                )
            }
        }
    }

    @MainActor
    private func scheduleRevisionReload() {
        revisionReloadTask?.cancel()
        revisionReloadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            scheduleRouteDataLoad()
        }
    }
}

@MainActor
enum SettingsOpenPerformance {
    private static var startedAt: CFAbsoluteTime?
    private static var markedPhases: Set<String> = []

    static func start(source: String) {
        startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.settingsOpen,
            note: ["source": source]
        )
        markedPhases.removeAll(keepingCapacity: true)
    }

    static func ensureStarted(source: String) {
        guard startedAt == nil else { return }
        start(source: source)
    }

    static func mark(_ phase: String) {
        guard let startedAt, markedPhases.insert(phase).inserted else { return }
        AppFlowPerformance.mark(
            AppPerformanceFlows.settingsOpen,
            phase,
            startedAt: startedAt
        )
        if phase == AppPerformancePhases.dataReady {
            Self.startedAt = nil
        }
    }
}

enum SettingsRouteReloadPolicy {
    static func shouldReloadSettingsRouteData(for revision: HomeRevision) -> Bool {
        guard let command = revision.lastCommand else { return false }

        switch (command.feature, command.action) {
        case ("privacy", _),
             ("settings", "coconutBalance"),
             ("settings", "activeHumanSwitch"):
            return false
        default:
            return true
        }
    }
}

private struct AccountSwitcherRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var electronicPets: [OasisElectronicPet] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> AccountSwitcherRouteData {
        AccountSwitcherRouteData(
            pets: SettingsRouteFetch.fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "AccountSwitcher.Pet"
            ),
            humans: SettingsRouteFetch.fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "AccountSwitcher.Human"
            ),
            electronicPets: SettingsRouteFetch.fetch(
                FetchDescriptor<OasisElectronicPet>(),
                context: context,
                name: "AccountSwitcher.OasisElectronicPet"
            ),
            hasLoaded: true
        )
    }
}

private enum SettingsRouteFetch {
    static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Settings route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Settings"
            )
            return []
        }
    }
}
