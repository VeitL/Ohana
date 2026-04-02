//
//  ContentView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedPet: Pet?
    @State private var selectedHuman: Human?
    @State private var selectedPlant: Plant?
    @State private var selectedPetTab: PetDetailTab = .overview
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("appUIStyle") private var appUIStyle: String = "classic"
    @Namespace private var heroNS
    
    var body: some View {
        ZStack {
            if !hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            NavigationStack {
                Group {
                    if appUIStyle == "material" {
                        MaterialDashboardView(
                            selectedPet: $selectedPet,
                            selectedHuman: $selectedHuman,
                            selectedPlant: $selectedPlant,
                            selectedPetTab: $selectedPetTab,
                            heroNS: heroNS
                        )
                    } else {
                        OverviewView(
                            selectedPet: $selectedPet,
                            selectedHuman: $selectedHuman,
                            selectedPlant: $selectedPlant,
                            selectedPetTab: $selectedPetTab,
                            heroNS: heroNS
                        )
                    }
                }
                .navigationDestination(item: $selectedPet) { pet in
                    PetDetailView(
                        pet: pet,
                        initialTab: selectedPetTab,
                        openHealthOnAppear: selectedPetTab == .health
                    )
                    .navigationTransition(.zoom(sourceID: pet.id, in: heroNS))
                }
                .navigationDestination(item: $selectedHuman) { human in
                    HumanDetailView(human: human)
                }
                .navigationDestination(item: $selectedPlant) { plant in
                    PlantDetailView(plant: plant)
                }
            }

            // 全局遛狗悬浮卡（底部，任何页面均可见）
            GlobalWalkBanner()
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.make())
}
