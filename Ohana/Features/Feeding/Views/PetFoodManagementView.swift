//
//  PetFoodManagementView.swift
//  Ohana
//
//  Unified wrapper for the guided feeding experience.
//

import SwiftUI

struct PetFoodManagementView: View {
    let pet: Pet
    let onClose: (() -> Void)?
    let showsCloseButton: Bool

    init(
        pet: Pet,
        onClose: (() -> Void)? = nil,
        showsCloseButton: Bool = false
    ) {
        self.pet = pet
        self.onClose = onClose
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        QuickFeedDetailRouteContainer(
            id: pet.id,
            onRemove: {},
            onClose: onClose,
            showsRemoveQuickActionFooter: false,
            showsCloseButton: showsCloseButton
        )
    }
}
