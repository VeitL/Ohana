import Foundation

enum PetAgeConverter {
    static func humanAge(birthday: Date, species: String, l: L10n) -> String {
        let equivalent = equivalentHumanYears(birthday: birthday, species: species)
        guard equivalent > 0 else { return "" }
        return l.tr(
            zh: "约人类\(equivalent)岁",
            en: "about \(equivalent) human years",
            de: "ca. \(equivalent) Menschenalter"
        )
    }

    private static func equivalentHumanYears(birthday: Date, species: String) -> Int {
        let days = max(0, Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0)
        let age = max(0, Double(days) / 365.25)
        let years = days / 365
        switch Pet.canonicalSpeciesKey(species) {
        case "dog":
            return dogHumanYears(age: age)
        case "cat":
            return catHumanYears(age: age)
        case "rabbit":
            return Int((age * 8.0).rounded())
        case "hamster":
            return Int((age * 26.0).rounded())
        case "bird":
            return Int((age * 5.0).rounded())
        case "fish":
            return Int((age * 6.0).rounded())
        default:
            return max(0, years)
        }
    }

    private static func dogHumanYears(age: Double) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }
        return Int((24 + (age - 2) * 5).rounded())
    }

    private static func catHumanYears(age: Double) -> Int {
        guard age > 0 else { return 0 }
        if age <= 1 { return Int((age * 15).rounded()) }
        if age <= 2 { return Int((15 + (age - 1) * 9).rounded()) }
        return Int((24 + (age - 2) * 4).rounded())
    }
}
