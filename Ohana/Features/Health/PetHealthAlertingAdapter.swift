@MainActor
protocol PetHealthAlerting {
    func scanAlerts(pets: [Pet]) -> [HealthAlert]
}

@MainActor
final class SharedPetHealthAlertEngine: PetHealthAlerting {
    private let engine = PetHealthAlertEngine()

    func scanAlerts(pets: [Pet]) -> [HealthAlert] {
        engine.scanAlerts(pets: pets)
    }
}
