import SwiftData
import SwiftUI

struct AddEventView: View {
    var onClose: (() -> Void)?
    var plants: [Plant] = []
    var preselectedEntityType: String?
    var preselectedEntityId: String?
    var taskCreationPreset: TaskCreationPreset?

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        AddEventContentView(
            onClose: onClose,
            pets: pets,
            humans: humans,
            plants: plants,
            preselectedEntityType: preselectedEntityType,
            preselectedEntityId: preselectedEntityId,
            taskCreationPreset: taskCreationPreset
        )
    }
}
