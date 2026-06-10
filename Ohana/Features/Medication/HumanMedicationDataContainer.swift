import SwiftData
import SwiftUI

struct HumanMedicationView: View {
    let human: Human
    var showsDoneButton: Bool = true
    var onDoseTaken: (() -> Void)? = nil

    @Query private var allMeds: [HumanMedication]
    @Query private var allLogs: [HumanMedicationLog]

    init(
        human: Human,
        showsDoneButton: Bool = true,
        onDoseTaken: (() -> Void)? = nil
    ) {
        self.human = human
        self.showsDoneButton = showsDoneButton
        self.onDoseTaken = onDoseTaken

        let humanKey = human.id.uuidString
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let logStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        _allMeds = Query(
            filter: #Predicate<HumanMedication> { med in
                med.humanId == humanKey
            },
            sort: \.createdAt,
            order: .reverse
        )
        _allLogs = Query(
            filter: #Predicate<HumanMedicationLog> { log in
                log.humanId == humanKey && log.scheduledTime >= logStart
            },
            sort: \.scheduledTime,
            order: .reverse
        )
    }

    var body: some View {
        HumanMedicationContentView(
            human: human,
            allMeds: allMeds,
            allLogs: allLogs,
            showsDoneButton: showsDoneButton,
            onDoseTaken: onDoseTaken
        )
    }
}
