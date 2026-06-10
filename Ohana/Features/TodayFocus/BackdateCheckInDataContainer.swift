import SwiftData
import SwiftUI

struct BackdateCheckInSheet: View {
    let backdateDays: Int

    @Query(sort: \Pet.name) private var pets: [Pet]

    var body: some View {
        BackdateCheckInContentSheet(
            pets: pets,
            backdateDays: backdateDays
        )
    }
}
