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
    @Environment(\.modelContext) private var modelContext
    @StateObject private var appRoutes = AppRouteCoordinator()
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @State private var homeResetToken = UUID()
    @Namespace private var heroNS
    
    var body: some View {
        ZStack {
            if !hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            NavigationStack(path: $appRoutes.path) {
                selectedHomeView
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestination(route: route)
                        .navigationTransition(.zoom(sourceID: route.sourceID, in: heroNS))
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

            if hasOnboarded && appRoutes.fullScreen != .requiredHumanProfile {
                GlobalWalkBanner()
                    .zIndex(80)
            }

            CoconutRewardFeedbackOverlay()
                .zIndex(120)
        }
        .onAppear {
            AppLifecycleCoordinator.shared.handle(.rootAppeared(scenePhase: scenePhase))
            reconcileHumanProfileRequirement()
        }
        .onChange(of: hasOnboarded) { _, _ in
            reconcileHumanProfileRequirement()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReturnHomeAfterHumanDeletion)) { notification in
            appRoutes.resetToHome()
            homeResetToken = UUID()
            let requiresReplacementHuman = (notification.userInfo?["requiresReplacementHuman"] as? Bool) == true
            if requiresReplacementHuman {
                currentActiveHumanId = ""
                appRoutes.presentRequiredHumanProfile()
            } else if (notification.userInfo?["requiresAccountSwitch"] as? Bool) == true {
                currentActiveHumanId = ""
                appRoutes.presentRequiredAccountSwitch()
            } else {
                reconcileHumanProfileRequirement()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReminderRouteRequested)) { _ in
            appRoutes.resetToHome()
        }
        .fullScreenCover(item: $appRoutes.fullScreen) { route in
            switch route {
            case .requiredHumanProfile:
                RequiredHumanProfileView { human in
                    currentActiveHumanId = human.id.uuidString
                    appRoutes.dismissFullScreen(.requiredHumanProfile)
                }
                .interactiveDismissDisabled(true)
            }
        }
        .sheet(item: $appRoutes.sheet) { route in
            switch route {
            case .requiredAccountSwitch:
                HumanAccountSwitcherSheet {
                    appRoutes.dismissSheet(.requiredAccountSwitch)
                }
                .interactiveDismissDisabled(true)
            }
        }
        .onChange(of: currentActiveHumanId) { _, newValue in
            if !newValue.isEmpty {
                appRoutes.dismissSheet(.requiredAccountSwitch)
                reconcileHumanProfileRequirement()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            AppLifecycleCoordinator.shared.handle(.scenePhaseChanged(newPhase))
            if newPhase == .active {
                reconcileHumanProfileRequirement()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var selectedHomeView: some View {
        VerticalSolidHomeDataContainer(
            onOpenPet: { id, tab in
                appRoutes.openPet(id, initialTab: tab)
            },
            onOpenHuman: { id in
                appRoutes.openHuman(id)
            },
            onOpenPlant: { id in
                appRoutes.openPlant(id)
            }
        )
    }

    private func reconcileHumanProfileRequirement() {
        let resolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: hasOnboarded,
            currentActiveHumanId: currentActiveHumanId,
            isAccountSwitchPresented: appRoutes.sheet == .requiredAccountSwitch,
            context: modelContext
        )

        switch resolution {
        case .notOnboarded:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        case .needsRequiredProfile:
            appRoutes.presentRequiredHumanProfile()
        case .preserveAccountSwitch:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        case let .activateHuman(id):
            currentActiveHumanId = id
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        case .ready:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("当前没有人类成员。Ohana 需要至少一个人类成员，用来记录谁完成了喂食、喂水、护理、健康记录和花费。")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    requirementRow(icon: "sparkles", text: "新的第一个人类会再次默认使用 2.5D 头像")
                    requirementRow(icon: "checkmark.seal.fill", text: "快速打卡会自动绑定到你")
                    requirementRow(icon: "creditcard.fill", text: "花费、护理和健康记录会有明确执行者")
                }

                Button {
                    withAnimation(GoMotion.page) {
                        isCreatingProfile = true
                    }
                } label: {
                    Text("建立我的档案")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
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
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.make())
}
