import SwiftData
import SwiftUI

struct HumanExpenseDetailView: View {
    let human: Human

    @Query(sort: \PetExpenseLog.date, order: .reverse) private var allExpenses: [PetExpenseLog]

    init(human: Human) {
        self.human = human
        let humanKey = human.id.uuidString
        _allExpenses = Query(
            filter: #Predicate<PetExpenseLog> { log in
                log.executorId == humanKey
            },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        HumanExpenseDetailContentView(
            human: human,
            allExpenses: allExpenses
        )
    }
}
