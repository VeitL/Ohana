//
//  CrewRosterPresentationModifier.swift
//  Ohana
//
//  Sheet and full-screen route host for the Ohana members surface.
//

import SwiftUI

struct CrewRosterPresentationModifier: ViewModifier {
    let pets: [Pet]
    let l: L10n

    @Binding var fullScreenRoute: CrewRosterFullScreenRoute?
    @Binding var sheetRoute: CrewRosterSheetRoute?

    let onAddEntityDismissed: () -> Void
    let onAddEntityComplete: () -> Void
    let onPetSaved: (Pet) -> Void
    let onHumanSaved: (Human) -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @State private var lastFullScreenRoute: CrewRosterFullScreenRoute?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $fullScreenRoute, onDismiss: onFullScreenDismissed) { route in
                fullScreenDestination(for: route)
                    .onAppear {
                        lastFullScreenRoute = route
                    }
            }
            .sheet(item: $sheetRoute) { route in
                sheetDestination(for: route)
            }
    }

    @ViewBuilder
    private func fullScreenDestination(for route: CrewRosterFullScreenRoute) -> some View {
        switch route {
        case .coconutLog:
            Color.clear
                .onAppear {
                    onPresentCoconutLog(nil)
                    fullScreenRoute = nil
                }
        case let .addEntity(type):
            AddEntityDestinationView(
                type: type,
                onComplete: onAddEntityComplete,
                onPetSaved: onPetSaved,
                onHumanSaved: onHumanSaved
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OhanaAppBackground())
        }
    }

    @ViewBuilder
    private func sheetDestination(for route: CrewRosterSheetRoute) -> some View {
        switch route {
        case let .familyActivity(id):
            if let pet = pets.first(where: { $0.id == id }) {
                familyActivitySheet(pet)
            } else {
                missingSheetRouteView(route)
            }
        case .familyWeeklyReport:
            NavigationStack {
                FamilyWeeklyReportDashboardView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                                sheetRoute = nil
                            }
                            .foregroundStyle(Color.goPrimary)
                        }
                    }
            }
        }
    }

    private func familyActivitySheet(_ pet: Pet) -> some View {
        NavigationStack {
            ScrollView {
                FamilyActivityStripRouteContainer(pet: pet, style: .full)
                    .padding(.vertical, 20)
            }
            .navigationTitle(
                l.tr(
                    zh: "谁在照顾 \(pet.name)",
                    en: "Who's caring for \(pet.name)",
                    de: "Wer kümmert sich um \(pet.name)?"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        sheetRoute = nil
                    }
                    .foregroundStyle(Color.goPrimary)
                }
            }
        }
    }

    private func missingSheetRouteView(_ route: CrewRosterSheetRoute) -> some View {
        Color.clear
            .onAppear {
                if sheetRoute?.id == route.id {
                    sheetRoute = nil
                }
            }
    }

    private func onFullScreenDismissed() {
        defer { lastFullScreenRoute = nil }
        if case .addEntity = lastFullScreenRoute {
            onAddEntityDismissed()
        }
    }
}

extension View {
    func crewRosterPresentations(
        pets: [Pet],
        l: L10n,
        fullScreenRoute: Binding<CrewRosterFullScreenRoute?>,
        sheetRoute: Binding<CrewRosterSheetRoute?>,
        onAddEntityDismissed: @escaping () -> Void,
        onAddEntityComplete: @escaping () -> Void,
        onPetSaved: @escaping (Pet) -> Void,
        onHumanSaved: @escaping (Human) -> Void,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) -> some View {
        modifier(
            CrewRosterPresentationModifier(
                pets: pets,
                l: l,
                fullScreenRoute: fullScreenRoute,
                sheetRoute: sheetRoute,
                onAddEntityDismissed: onAddEntityDismissed,
                onAddEntityComplete: onAddEntityComplete,
                onPetSaved: onPetSaved,
                onHumanSaved: onHumanSaved,
                onPresentCoconutLog: onPresentCoconutLog
            )
        )
    }
}
