//
//  HumanExpenseDetailView.swift
//  Ohana
//
//  V4 human expense history.
//

import SwiftUI

struct HumanExpenseDetailContentView: View {
    let human: Human
    let allExpenses: [PetExpenseLog]

    @Environment(\.dismiss) private var dismiss

    init(human: Human, allExpenses: [PetExpenseLog]) {
        self.human = human
        self.allExpenses = allExpenses
    }

    var body: some View {
        HumanExpenseDashboardContent(
            human: human,
            allExpenses: allExpenses,
            onClose: { dismiss() }
        )
    }
}
