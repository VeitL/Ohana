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
        PetWeightDashboardDataContainer(
            pet: pet,
            showsCloseButton: showsCloseButton,
            onClose: { dismiss() },
            onAdd: { showingWeightPopup = true },
            onRemove: onRemove
        )
        .sheet(isPresented: $showingWeightPopup) {
            GenericWeightEntrySheet(
                target: .pet(pet),
                onDismiss: { showingWeightPopup = false }
            )
        }
        .accessibilityIdentifier("pet-weight-detail-screen")
    }
}
