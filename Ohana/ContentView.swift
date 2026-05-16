//
//  ContentView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedPet: Pet?
    @State private var selectedHuman: Human?
    @State private var selectedPlant: Plant?
    @State private var selectedPetTab: PetDetailTab = .overview
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @State private var showingRequiredHumanProfile = false
    @State private var showingRequiredAccountSwitch = false
    @State private var homeResetToken = UUID()
    @Namespace private var heroNS
    
    var body: some View {
        ZStack {
            if !hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            NavigationStack {
                FocusStackHomeTestView(
                    selectedPet: $selectedPet,
                    selectedHuman: $selectedHuman,
                    selectedPlant: $selectedPlant,
                    selectedPetTab: $selectedPetTab,
                    heroNS: heroNS
                )
                .navigationDestination(item: $selectedPet) { pet in
                    petDestination(for: pet)
                }
                .navigationDestination(item: $selectedHuman) { human in
                    HumanDetailView(human: human)
                }
                .navigationDestination(item: $selectedPlant) { plant in
                    PlantDetailView(plant: plant)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            dismissKeyboard()
                        } label: {
                            Label("隐藏键盘", systemImage: "keyboard.chevron.compact.down")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                    }
                }
            }
            .id(homeResetToken)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if hasOnboarded && !showingRequiredHumanProfile {
                GlobalWalkBanner()
                    .zIndex(80)
            }
        }
        .onAppear {
            allowSystemAutoLock()
            AppWorkloadPolicy.shared.updateScenePhase(scenePhase)
            AppWorkloadPolicy.shared.refresh(reason: "contentAppear")
            reconcileHumanProfileRequirement()
            handleAppForegroundTransition()
        }
        .onChange(of: hasOnboarded) { _, _ in
            reconcileHumanProfileRequirement()
        }
        .onChange(of: humans.map { $0.id }) { _, _ in
            reconcileHumanProfileRequirement()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReturnHomeAfterHumanDeletion)) { notification in
            selectedPet = nil
            selectedHuman = nil
            selectedPlant = nil
            selectedPetTab = .overview
            homeResetToken = UUID()
            let requiresReplacementHuman = (notification.userInfo?["requiresReplacementHuman"] as? Bool) == true
            if requiresReplacementHuman {
                currentActiveHumanId = ""
                showingRequiredHumanProfile = true
            } else if (notification.userInfo?["requiresAccountSwitch"] as? Bool) == true {
                currentActiveHumanId = ""
                showingRequiredAccountSwitch = true
            } else {
                reconcileHumanProfileRequirement()
            }
        }
        .fullScreenCover(isPresented: $showingRequiredHumanProfile) {
            RequiredHumanProfileView { human in
                currentActiveHumanId = human.id.uuidString
                showingRequiredHumanProfile = false
            }
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showingRequiredAccountSwitch) {
            HumanAccountSwitcherSheet {
                showingRequiredAccountSwitch = false
            }
            .interactiveDismissDisabled(true)
        }
        .onChange(of: currentActiveHumanId) { _, newValue in
            if !newValue.isEmpty {
                showingRequiredAccountSwitch = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private func petDestination(for pet: Pet) -> some View {
        Group {
            if selectedPetTab == .health {
                PetHealthDetailView(pet: pet)
            } else {
                PetBasicInfoDetailView(pet: pet)
            }
        }
        .navigationTransition(.zoom(sourceID: pet.id, in: heroNS))
    }

    private func reconcileHumanProfileRequirement() {
        guard hasOnboarded else {
            showingRequiredHumanProfile = false
            return
        }

        guard let firstHuman = humans.first else {
            showingRequiredHumanProfile = true
            return
        }

        if showingRequiredAccountSwitch {
            showingRequiredHumanProfile = false
            return
        }

        if currentActiveHumanId.isEmpty ||
            !humans.contains(where: { $0.id.uuidString == currentActiveHumanId }) {
            currentActiveHumanId = firstHuman.id.uuidString
        }
        showingRequiredHumanProfile = false
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        AppWorkloadPolicy.shared.updateScenePhase(phase)
        switch phase {
        case .background:
            PetWalkingManager.shared.handleAppBackgroundTransition()
        case .inactive:
            PetWalkingManager.shared.handleAppInactiveTransition()
        case .active:
            allowSystemAutoLock()
            handleAppForegroundTransition()
        @unknown default:
            PetWalkingManager.shared.handleAppInactiveTransition()
        }
    }

    private func allowSystemAutoLock() {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handleAppForegroundTransition() {
        PetWalkingManager.shared.handleAppForegroundTransition()
    }
}

extension Notification.Name {
    static let ohanaReturnHomeAfterHumanDeletion = Notification.Name("ohanaReturnHomeAfterHumanDeletion")
}

private struct RequiredHumanProfileView: View {
    let onHumanSaved: (Human) -> Void

    @State private var isCreatingProfile = false
    @State private var savedHuman: Human?

    var body: some View {
        NavigationStack {
            ZStack {
                GoIslandWizardBackdrop()

                if isCreatingProfile {
                    AddHumanWizardView(
                        onComplete: {
                            if let savedHuman {
                                onHumanSaved(savedHuman)
                            }
                        },
                        onHumanSaved: { human in
                            savedHuman = human
                        }
                    )
                } else {
                    promptCard
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var promptCard: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.goLime.opacity(0.16))
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.goLime)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("先建立你的本人档案")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("当前没有人类成员。Ohana 需要至少一个人类成员，用来记录谁完成了喂食、喂水、护理、健康记录和花费。")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    requirementRow(icon: "sparkles", text: "新的第一个人类会再次默认使用 2.5D 头像")
                    requirementRow(icon: "checkmark.seal.fill", text: "快速打卡会自动绑定到你")
                    requirementRow(icon: "creditcard.fill", text: "花费、护理和健康记录会有明确执行者")
                }

                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        isCreatingProfile = true
                    }
                } label: {
                    Text("建立我的档案")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 4)
            }
            .padding(24)
            .goTranslucentCard(cornerRadius: 30)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func requirementRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.goLime)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.make())
}
