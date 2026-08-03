//
//  MemberResidenceValue.swift
//  Ohana
//
//  Stable storage and localized presentation for a member's residence.
//

import Foundation

nonisolated struct MemberResidenceValue: Equatable, Sendable {
    let country: String
    let city: String

    init(country: String, city: String) {
        self.country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        self.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(storedValue: String) {
        let value = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = value.firstIndex(of: "·") {
            self.init(
                country: String(value[..<separator]),
                city: String(value[value.index(after: separator)...])
            )
            return
        }

        if PetBreedDatabase.countries.contains(value) {
            self.init(country: value, city: "")
            return
        }

        let matchingCountries = PetBreedDatabase.countries.filter {
            $0 != "其他" && PetBreedDatabase.cities(for: $0).contains(value)
        }
        self.init(
            country: matchingCountries.count == 1 ? matchingCountries[0] : "",
            city: value
        )
    }

    var storedValue: String {
        if country.isEmpty { return city }
        if city.isEmpty {
            return PetBreedDatabase.countries.contains(country) ? country : "\(country)·"
        }
        return "\(country)·\(city)"
    }

    func localized(l: L10n) -> String {
        [country, city]
            .filter { !$0.isEmpty }
            .map { PetBreedDatabase.localizedRegionName($0, l: l) }
            .joined(separator: " · ")
    }
}
