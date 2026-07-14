//
//  CrewRosterPresentationModifier.swift
//  Ohana
//
//  Full-screen route host for the Ohana members surface.
//

import SwiftUI

struct CrewRosterPresentationModifier: ViewModifier {
    @Binding var fullScreenRoute: CrewRosterFullScreenRoute?

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

    private func onFullScreenDismissed() {
        defer { lastFullScreenRoute = nil }
        if case .addEntity = lastFullScreenRoute {
            onAddEntityDismissed()
        }
    }
}

extension View {
    func crewRosterPresentations(
        fullScreenRoute: Binding<CrewRosterFullScreenRoute?>,
        onAddEntityDismissed: @escaping () -> Void,
        onAddEntityComplete: @escaping () -> Void,
        onPetSaved: @escaping (Pet) -> Void,
        onHumanSaved: @escaping (Human) -> Void,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) -> some View {
        modifier(
            CrewRosterPresentationModifier(
                fullScreenRoute: fullScreenRoute,
                onAddEntityDismissed: onAddEntityDismissed,
                onAddEntityComplete: onAddEntityComplete,
                onPetSaved: onPetSaved,
                onHumanSaved: onHumanSaved,
                onPresentCoconutLog: onPresentCoconutLog
            )
        )
    }
}
