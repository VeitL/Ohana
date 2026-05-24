//
//  ExpandedQuickActionMenuOverlayHost.swift
//  Ohana
//
//  Hosts the expanded-card quick-action inline menu outside the home view's
//  main body so business state changes do not bloat the wallet stack diff.
//

import SwiftUI

struct ExpandedQuickActionMenuOverlayHost: View {
    @Binding var target: ExpandedQuickActionMenuTarget?

    @State private var visibleTarget: ExpandedQuickActionMenuTarget?
    @State private var isPresented = false
    @State private var closeGeneration = UUID()

    let colorScheme: ColorScheme
    let l: L10n
    let waterManagementLabel: String
    let petIsCompleted: (QuickActionItem, Pet) -> Bool
    let petStatus: (QuickActionItem, Pet) -> String?
    let humanIsLocked: (QuickActionItem, Human) -> Bool
    let humanStatus: (QuickActionItem, Human) -> String?
    let onPetQuick: (QuickActionItem, Pet) -> Void
    let onPetDetail: (QuickActionItem, Pet) -> Void
    let onPetOption: (String, QuickActionItem, Pet) -> Void
    let onHumanQuick: (QuickActionItem, Human) -> Void
    let onHumanDetail: (QuickActionItem, Human) -> Void

    var body: some View {
        Group {
            if let visibleTarget {
                GeometryReader { proxy in
                    OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: isPresented) {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10), // ui-v4: allow modal scrim
                                Color.black.opacity(colorScheme == .dark ? 0.46 : 0.22)  // ui-v4: allow modal scrim
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .opacity(isPresented ? 1 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(isPresented)
                        .onTapGesture { dismiss() }

                        panel(for: visibleTarget)
                            .padding(.horizontal, 6)
                            .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
                            .offset(y: isPresented ? 0 : 280)
                            .opacity(isPresented ? 1 : 0)
                            .scaleEffect(isPresented ? 1 : 0.985, anchor: .bottom)
                            .allowsHitTesting(isPresented)
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .onAppear {
            syncVisibleTarget(with: target)
        }
        .onChange(of: target?.id) { _, _ in
            syncVisibleTarget(with: target)
        }
    }

    @ViewBuilder
    private func panel(for target: ExpandedQuickActionMenuTarget) -> some View {
        switch target {
        case .pet(let item, let pet):
            let isSingleUseDone = ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil &&
                petIsCompleted(item, pet)
            let options = ExpandedQuickActionMenuPolicy.petOptions(for: item, l: l)
            ExpandedQuickActionMenuPanel(
                icon: WaterQuickActionPolicy.iconOverride(for: item, pet: pet) ?? item.icon,
                title: WaterQuickActionPolicy.titleOverride(for: item, pet: pet, managementLabel: waterManagementLabel) ?? item.label,
                status: petStatus(item, pet) ?? l.tr(zh: "选择下一步", en: "Choose next step", de: "Nächsten Schritt wählen"),
                accent: Color(hex: item.colorHex),
                isLocked: false,
                lockedText: nil,
                quickTitle: ExpandedQuickActionMenuPolicy.petPrimaryTitle(for: item, pet: pet, isSingleUseDone: isSingleUseDone, hasOptions: !options.isEmpty, l: l),
                detailTitle: ExpandedQuickActionMenuPolicy.petDetailTitle(for: item, l: l),
                isQuickDisabled: isSingleUseDone,
                quickOptions: options,
                onQuick: {
                    dismiss()
                    onPetQuick(item, pet)
                },
                onDetail: {
                    dismiss()
                    onPetDetail(item, pet)
                },
                onOption: { optionId in
                    dismiss()
                    onPetOption(optionId, item, pet)
                },
                onClose: dismiss
            )
        case .human(let item, let human):
            let locked = humanIsLocked(item, human)
            ExpandedQuickActionMenuPanel(
                icon: item.icon,
                title: item.label,
                status: locked
                    ? l.tr(zh: "仅本人可见", en: "Only visible to this member", de: "Nur für dieses Mitglied sichtbar")
                    : (humanStatus(item, human) ?? l.tr(zh: "选择下一步", en: "Choose next step", de: "Nächsten Schritt wählen")),
                accent: Color(hex: item.colorHex),
                isLocked: locked,
                lockedText: l.tr(zh: "切换到该成员账户后才能查看或记录。", en: "Switch to this member account to view or record.", de: "Wechsle zu diesem Mitglied, um zu sehen oder zu erfassen."),
                quickTitle: ExpandedQuickActionMenuPolicy.humanPrimaryTitle(for: item, l: l),
                detailTitle: ExpandedQuickActionMenuPolicy.humanDetailTitle(for: item, l: l),
                isQuickDisabled: false,
                quickOptions: [],
                onQuick: {
                    dismiss()
                    onHumanQuick(item, human)
                },
                onDetail: {
                    dismiss()
                    onHumanDetail(item, human)
                },
                onOption: { _ in },
                onClose: dismiss
            )
        }
    }

    private func dismiss() {
        let generation = UUID()
        closeGeneration = generation
        withAnimation(GoMotion.sheetEnter) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard closeGeneration == generation else { return }
            target = nil
            visibleTarget = nil
        }
    }

    private func syncVisibleTarget(with nextTarget: ExpandedQuickActionMenuTarget?) {
        if let nextTarget {
            closeGeneration = UUID()
            visibleTarget = nextTarget
            withAnimation(GoMotion.sheetEnter) {
                isPresented = true
            }
        } else if visibleTarget != nil {
            let generation = UUID()
            closeGeneration = generation
            withAnimation(GoMotion.sheetEnter) {
                isPresented = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard closeGeneration == generation else { return }
                visibleTarget = nil
            }
        }
    }
}
