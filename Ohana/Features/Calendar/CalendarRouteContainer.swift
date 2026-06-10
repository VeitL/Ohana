import SwiftData
import SwiftUI

struct CalendarRouteContainer: View {
    var preselectedPetId: String? = nil
    var preselectedHumanId: String? = nil
    var hideToolbar: Bool = false
    var showsEmbeddedControls: Bool = false
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (() -> Void)? = nil
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)? = nil
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \PetInsurance.createdAt) private var insurances: [PetInsurance]
    @Query(sort: \PetMedication.createdAt) private var petMedications: [PetMedication]
    @Query(sort: \HumanMedication.createdAt) private var humanMedications: [HumanMedication]

    var body: some View {
        CalendarView(
            preselectedPetId: preselectedPetId,
            preselectedHumanId: preselectedHumanId,
            hideToolbar: hideToolbar,
            showsEmbeddedControls: showsEmbeddedControls,
            addEventTrigger: addEventTrigger,
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            onRequestAddEvent: onRequestAddEvent,
            onOpenEventDestination: onOpenEventDestination,
            onPresentCoconutLog: onPresentCoconutLog,
            events: events,
            pets: pets,
            humans: humans,
            plants: [],
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications
        )
    }
}
