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

    var body: some View {
        QuickPottyDetailSheet(pet: pet, onRemove: onRemove)
    }
}
