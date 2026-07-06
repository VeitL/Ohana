//
//  QuickWeightEntrySheetDataContainer.swift
//  Ohana
//
//  Screen-scoped hosts for direct weight quick-entry sheets.
//

import SwiftData
import SwiftUI

struct AppPetWeightQuickSheetHost: View {
    @Environment(\.modelContext) private var modelContext

    let id: UUID
    let onMissing: () -> Void
    let onDismiss: () -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.id = id
        self.onMissing = onMissing
        self.onDismiss = onDismiss
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: AppPetWeightQuickSheetRouteData(),
            refreshToken: id,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 48,
            shouldLoad: { !$0.hasLoaded },
            load: { AppPetWeightQuickSheetRouteData.load(id: id, from: modelContext) }
        ) { data in
            if let pet = data.pet, !pet.hasPassedAway {
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    onDismiss: onDismiss
                )
            } else if data.hasLoaded {
                PetRouteMissingEntityView(kind: "pet")
                    .onAppear(perform: onMissing)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
}

struct AppHumanWeightQuickSheetHost: View {
    @Environment(\.modelContext) private var modelContext

    let id: UUID
    let onMissing: () -> Void
    let onDismiss: () -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.id = id
        self.onMissing = onMissing
        self.onDismiss = onDismiss
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: AppHumanWeightQuickSheetRouteData(),
            refreshToken: id,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 48,
            shouldLoad: { !$0.hasLoaded },
            load: { AppHumanWeightQuickSheetRouteData.load(id: id, from: modelContext) }
        ) { data in
            if let human = data.human, !human.hasPassedAway {
                GenericWeightEntrySheet(
                    target: .human(human),
                    onDismiss: onDismiss
                )
            } else if data.hasLoaded {
                HumanRouteMissingEntityView(kind: "human")
                    .onAppear(perform: onMissing)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
}

private struct AppPetWeightQuickSheetRouteData {
    var pet: Pet?
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> AppPetWeightQuickSheetRouteData {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return AppPetWeightQuickSheetRouteData(
            pet: fetch(descriptor, context: context).first,
            hasLoaded: true
        )
    }

    private static func fetch(_ descriptor: FetchDescriptor<Pet>, context: ModelContext) -> [Pet] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Quick pet weight route data fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }
}

private struct AppHumanWeightQuickSheetRouteData {
    var human: Human?
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> AppHumanWeightQuickSheetRouteData {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return AppHumanWeightQuickSheetRouteData(
            human: fetch(descriptor, context: context).first,
            hasLoaded: true
        )
    }

    private static func fetch(_ descriptor: FetchDescriptor<Human>, context: ModelContext) -> [Human] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Quick human weight route data fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }
}
