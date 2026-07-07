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
                    isRouteDataLoaded: data.hasLoaded,
                    onClose: onClose
                )
            }
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

private struct SettingsFirstFrameShell: View {
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

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

                SettingsFirstFrameSkeleton()
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("settings-loading-screen")
        .accessibilityLabel(l.tr(zh: "正在打开设置", en: "Opening settings", de: "Einstellungen werden geoffnet"))
    }
}

private struct SettingsFirstFrameSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            skeletonSection(width: 86)

            VStack(spacing: 10) {
                skeletonRow(width: 252)
                skeletonProfileBlock()
            }
            .padding(16)
            .background(Color.ohanaCardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))

            skeletonSection(width: 76)
            skeletonRow(width: 220)

            skeletonSection(width: 54)
            skeletonRow(width: 236)

            skeletonSection(width: 86)
            VStack(spacing: 12) {
                skeletonRow(width: 244)
                skeletonRow(width: 208)
                skeletonRow(width: 232)
            }
            .padding(16)
            .background(Color.ohanaCardSurface.opacity(0.64), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: .placeholder)
    }

    private func skeletonSection(width: CGFloat) -> some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(Color.goPrimary.opacity(0.9))
                .frame(width: 4, height: 22) // a11y: allow non-interactive loading skeleton hidden from accessibility
            Capsule()
                .fill(Color.ohanaSecondaryText.opacity(0.32))
                .frame(width: width, height: 14)
        }
    }

    private func skeletonRow(width: CGFloat) -> some View {
        HStack(spacing: 13) {
            Circle()
                .fill(Color.goPrimary.opacity(0.82))
                .frame(width: 30, height: 30) // a11y: allow non-interactive loading skeleton hidden from accessibility
            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(Color.ohanaPrimaryText.opacity(0.34))
                    .frame(width: width, height: 18)
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.24))
                    .frame(width: min(width * 0.74, 190), height: 12)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
    }

    private func skeletonProfileBlock() -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.goPrimary.opacity(0.42))
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 10) {
                Capsule()
                    .fill(Color.goPrimary.opacity(0.44))
                    .frame(width: 190, height: 18)
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.24))
                    .frame(width: 260, height: 12)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
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
