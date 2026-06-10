import Foundation
@testable import Ohana

@MainActor
final class EmptyPetHealthAlerts: PetHealthAlerting {
    func scanAlerts(pets: [Pet]) -> [HealthAlert] {
        []
    }
}
