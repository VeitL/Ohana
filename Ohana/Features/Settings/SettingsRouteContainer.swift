import SwiftData
import SwiftUI

struct AppAccountSwitcherRouteContainer: View {
    @Environment(\.modelContext) private var modelContext

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
                onSwitched: onSwitched
            )
        }
    }
}

struct AppSettingsSheetRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var refreshToken = 0

    let onClose: () -> Void

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: SettingsRouteData(),
            refreshToken: refreshToken,
            loadDelayMilliseconds: 0,
            reloadDelayMilliseconds: 0,
            shouldLoad: { !$0.hasLoaded },
            load: { SettingsRouteData.load(from: modelContext) }
        ) { data in
            SettingsView(
                homeHouseholds: data.households,
                homePets: data.pets,
                homeHumans: data.humans,
                isRouteDataLoaded: data.hasLoaded,
                onClose: onClose
            )
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            guard SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: revision) else { return }
            refreshToken &+= 1
        }
    }
}

enum SettingsRouteReloadPolicy {
    static func shouldReloadSettingsRouteData(for revision: HomeRevision) -> Bool {
        guard let command = revision.lastCommand else { return false }

        switch (command.feature, command.action) {
        case ("privacy", _),
             ("settings", "coconutBalance"):
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

private struct SettingsRouteData {
    var households: [SettingsHouseholdSnapshot]?
    var pets: [SettingsPetSnapshot]?
    var humans: [SettingsHumanSnapshot]?
    var hasLoaded = false

    @MainActor
    static func load(from context: ModelContext) -> SettingsRouteData {
        SettingsRouteData(
            households: SettingsRouteFetch.fetch(
                FetchDescriptor<Household>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Household"
            ).map(SettingsHouseholdSnapshot.init),
            pets: SettingsRouteFetch.fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ).map(SettingsPetSnapshot.init),
            humans: SettingsRouteFetch.fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ).map(SettingsHumanSnapshot.init),
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
