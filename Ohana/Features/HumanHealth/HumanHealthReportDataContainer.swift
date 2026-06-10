import SwiftData
import SwiftUI

struct HumanHealthReportView: View {
    let human: Human

    @Query private var myReports: [HumanHealthReport]

    init(human: Human) {
        self.human = human
        let humanId = human.id.uuidString
        _myReports = Query(
            filter: #Predicate<HumanHealthReport> { $0.humanId == humanId },
            sort: \HumanHealthReport.reportDate,
            order: .reverse
        )
    }

    var body: some View {
        HumanHealthReportContentView(
            human: human,
            myReports: myReports
        )
    }
}
