//
//  HumanExpenseDetailView.swift
//  Ohana
//
//  V4 human expense history.
//

import SwiftUI

struct HumanExpenseDetailContentView: View {
    let human: Human
    let showsCloseButton: Bool
    let allExpenses: [PetExpenseLog]

    @Environment(\.dismiss) private var dismiss

    init(human: Human, allExpenses: [PetExpenseLog], showsCloseButton: Bool = true) {
        self.human = human
        self.showsCloseButton = showsCloseButton
        self.allExpenses = allExpenses
    }

    var body: some View {
        HumanExpenseDashboardContent(
            human: human,
            showsCloseButton: showsCloseButton,
            allExpenses: allExpenses,
            onClose: { dismiss() }
        )
    }
}
