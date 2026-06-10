import SwiftData
import SwiftUI

struct FunctionMenuDestinationRouteContainer: View {
    let destination: FMDest
    @Binding var parentPath: NavigationPath

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    var body: some View {
        FunctionMenuDestinationRouter(
            destination: destination,
            parentPath: $parentPath,
            pets: pets,
            humans: humans,
            plants: []
        )
    }
}

struct FunctionMenuRootRouteContainer: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    var body: some View {
        FunctionMenuRootView(
            appLanguage: appLanguage,
            onSelect: onSelect,
            onClose: onClose,
            pets: pets,
            humans: humans
        )
    }
}
