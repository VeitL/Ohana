//
//  AppRouteDestinationContainers.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for global destinations.
//

import SwiftData
import SwiftUI

struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case let .petProfile(id, initialTab):
            AppPetRouteContainer(id: id, initialTab: initialTab)
        case let .humanProfile(id):
            AppHumanRouteContainer(id: id)
        case let .plantProfile(id):
            AppPlantRouteContainer(id: id)
        }
    }
}

private struct AppPetRouteContainer: View {
    @Query private var pets: [Pet]
    let initialTab: PetDetailTab

    init(id: UUID, initialTab: PetDetailTab) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.initialTab = initialTab
    }

    var body: some View {
        if let pet = pets.first {
            if initialTab == .health {
                PetHealthDetailView(pet: pet)
            } else {
                PetBasicInfoDetailView(pet: pet)
            }
        } else {
            MissingRouteEntityView(kind: "pet")
        }
    }
}

private struct AppHumanRouteContainer: View {
    @Query private var humans: [Human]

    init(id: UUID) {
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
    }

    var body: some View {
        if let human = humans.first {
            HumanDetailView(human: human)
        } else {
            MissingRouteEntityView(kind: "human")
        }
    }
}

private struct AppPlantRouteContainer: View {
    @Query private var plants: [Plant]

    init(id: UUID) {
        _plants = Query(filter: #Predicate<Plant> { plant in
            plant.id == id
        })
    }

    var body: some View {
        if let plant = plants.first {
            PlantDetailView(plant: plant)
        } else {
            MissingRouteEntityView(kind: "plant")
        }
    }
}

private struct MissingRouteEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goPrimary)
            Text("内容已不可用")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
