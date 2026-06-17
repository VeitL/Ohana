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
        RouteFirstFrameDeferredMount(
            delayMilliseconds: 96
        ) {
            SettingsFirstFrameShell(onClose: onClose)
        } content: {
            RouteFirstFrameDeferredLoad(
                initialData: SettingsRouteData(),
                refreshToken: refreshToken,
                loadDelayMilliseconds: 160,
                reloadDelayMilliseconds: 120,
                shouldLoad: { !$0.hasLoaded },
                load: { SettingsRouteData.load(from: modelContext) }
            ) { data in
                SettingsView(
                    homeHouseholds: data.households,
                    homePets: data.pets,
                    homeHumans: data.humans,
                    homeElectronicPets: data.electronicPets,
                    onClose: onClose
                )
            }
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            refreshToken &+= 1
        }
    }
}

private struct SettingsFirstFrameShell: View {
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()

            VStack(spacing: 28) {
                HStack(alignment: .center, spacing: 12) {
                    Text(l.tr(zh: "设置", en: "Settings", de: "Einstellungen"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Button {
                        onClose()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .background(Color.ohanaControlFill, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "关闭设置", en: "Close settings", de: "Einstellungen schliessen"))
                }

                Spacer(minLength: 0)

                ProgressView()
                    .tint(Color.goPrimary)
                    .controlSize(.large)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("settings-screen")
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
    var households: [Household]?
    var pets: [Pet]?
    var humans: [Human]?
    var electronicPets: [OasisElectronicPet]?
    var hasLoaded = false

    static func load(from context: ModelContext) -> SettingsRouteData {
        SettingsRouteData(
            households: SettingsRouteFetch.fetch(
                FetchDescriptor<Household>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Household"
            ),
            pets: SettingsRouteFetch.fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            humans: SettingsRouteFetch.fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            electronicPets: SettingsRouteFetch.fetch(
                FetchDescriptor<OasisElectronicPet>(),
                context: context,
                name: "OasisElectronicPet"
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
