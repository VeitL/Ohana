//
//  PetFoodManagementView.swift
//  Ohana
//
//  Unified wrapper for the guided feeding experience.
//

import SwiftUI

struct PetFoodManagementView: View {
    let pet: Pet

    var body: some View {
        QuickFeedDetailRouteContainer(
            id: pet.id,
            onRemove: {},
            showsRemoveQuickActionFooter: false,
            showsCloseButton: false
        )
    }
}
