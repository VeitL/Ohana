import Foundation
@testable import Ohana

@MainActor
final class EmptyPetHealthAlerts: PetHealthAlerting {
    func scanAlerts(pets _: [Pet]) -> [HealthAlert] {
        []
    }
}
