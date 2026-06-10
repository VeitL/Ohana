//
//  QuickLitterDetailSheet.swift
//  Ohana
//
//  Compatibility wrapper. Litter and potty now share one management page.
//

import SwiftUI

struct QuickLitterDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)?

    var body: some View {
        QuickPottyDetailRouteContainer(id: pet.id, onRemove: onRemove, onClose: onClose)
    }
}
