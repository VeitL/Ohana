import SwiftData
import SwiftUI

struct HumanExpenseDetailView: View {
    let human: Human

    @Query(sort: \PetExpenseLog.date, order: .reverse) private var allExpenses: [PetExpenseLog]

    init(human: Human) {
        self.human = human
        let humanKey = human.id.uuidString
        let humanKeyLower = humanKey.lowercased()
        _allExpenses = Query(
            filter: #Predicate<PetExpenseLog> { log in
                log.executorId == humanKey ||
                    log.executorId == humanKeyLower ||
                    log.payerContributionsJSON.contains(humanKey) ||
                    log.payerContributionsJSON.contains(humanKeyLower)
            },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        HumanExpenseDetailContentView(
            human: human,
            allExpenses: ExpenseSummaryBuilder.paidBy(human.id, from: allExpenses)
        )
    }
}
