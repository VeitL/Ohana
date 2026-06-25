//
//  AddExpenseSheetRouteContainer.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct AddExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    let pet: Pet
    let humans: [Human]
    var allPets: [Pet] = []
    var preselectedPayerId: String?
    var onSaved: (() -> Void)?
    var onRewarded: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    init(
        pet: Pet,
        humans: [Human],
        allPets: [Pet] = [],
        preselectedPayerId: String? = nil,
        onSaved: (() -> Void)? = nil,
        onRewarded: ((Int) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.pet = pet
        self.humans = humans
        self.allPets = allPets
        self.preselectedPayerId = preselectedPayerId
        self.onSaved = onSaved
        self.onRewarded = onRewarded
        self.onDismiss = onDismiss
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: AddExpenseSheetRouteData(),
            refreshToken: appServices.domainRevisions.homeRevision,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 48,
            shouldLoad: { !$0.hasLoaded },
            load: { AddExpenseSheetRouteData.load(petID: pet.id, from: modelContext) }
        ) { data in
            AddExpenseSheetContent(
                pet: pet,
                humans: humans,
                allPets: allPets,
                routeExpenseLogs: data.expenseLogs,
                routeInsurances: data.insurances,
                preselectedPayerId: preselectedPayerId,
                onSaved: onSaved,
                onRewarded: onRewarded,
                onDismiss: onDismiss
            )
        }
    }
}

private struct AddExpenseSheetRouteData {
    var expenseLogs: [PetExpenseLog] = []
    var insurances: [PetInsurance] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> AddExpenseSheetRouteData {
        AddExpenseSheetRouteData(
            expenseLogs: fetch(
                FetchDescriptor<PetExpenseLog>(
                    predicate: #Predicate<PetExpenseLog> { log in
                        log.pet?.id == petID
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "PetExpenseLog"
            ),
            insurances: fetch(
                FetchDescriptor<PetInsurance>(
                    predicate: #Predicate<PetInsurance> { insurance in
                        insurance.pet?.id == petID
                    }
                ),
                context: context,
                name: "PetInsurance"
            ),
            hasLoaded: true
        )
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
                "Expense sheet route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Expenses"
            )
            return []
        }
    }
}
