//
//  WeightHistoryView.swift
//  Ohana
//
//  Route-scoped pet weight dashboard host.
//

import SwiftUI

struct WeightHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)?
    var showsCloseButton: Bool = true

    @Environment(\.dismiss) private var dismiss

    @State private var showingWeightPopup = false

    var body: some View {
        ZStack {
            PetWeightDashboardDataContainer(
                pet: pet,
                showsCloseButton: showsCloseButton,
                onClose: { dismiss() },
                onAdd: {
                    withAnimation(GoMotion.feedback) {
                        showingWeightPopup = true
                    }
                },
                onRemove: onRemove
            )

            if showingWeightPopup {
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    onDismiss: {
                        withAnimation(GoMotion.feedback) {
                            showingWeightPopup = false
                        }
                    }
                )
                .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("pet-weight-detail-screen")
    }
}
