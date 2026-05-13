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
        QuickFeedDetailSheet(
            pet: pet,
            onRemove: {},
            showsRemoveQuickActionFooter: false,
            showsCloseButton: false
        )
    }
}
