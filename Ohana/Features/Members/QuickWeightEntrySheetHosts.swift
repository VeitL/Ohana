//
//  QuickWeightEntrySheetHosts.swift
//  Ohana
//
//  Screen-scoped hosts for direct weight quick-entry sheets.
//

import SwiftData
import SwiftUI

struct AppPetWeightQuickSheetHost: View {
    @Query private var pets: [Pet]
    let onMissing: () -> Void
    let onDismiss: () -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.onMissing = onMissing
        self.onDismiss = onDismiss
    }

    var body: some View {
        if let pet = pets.first, !pet.hasPassedAway {
            GenericWeightEntrySheet(
                target: .pet(pet),
                onDismiss: onDismiss
            )
        } else {
            PetRouteMissingEntityView(kind: "pet")
                .onAppear(perform: onMissing)
        }
    }
}

struct AppHumanWeightQuickSheetHost: View {
    @Query private var humans: [Human]
    let onMissing: () -> Void
    let onDismiss: () -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
        self.onMissing = onMissing
        self.onDismiss = onDismiss
    }

    var body: some View {
        if let human = humans.first, !human.hasPassedAway {
            GenericWeightEntrySheet(
                target: .human(human),
                onDismiss: onDismiss
            )
        } else {
            HumanRouteMissingEntityView(kind: "human")
                .onAppear(perform: onMissing)
        }
    }
}
