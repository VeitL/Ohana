import Foundation
import Testing
@testable import Ohana

struct LocalizedProfileCatalogTests {
    @Test func germanProfileCatalogsAreTranslatedAndLocaleSorted() {
        let l = L10n("de")

        assertLocalizedAndSorted(
            l.sortedCatalogKeys(
                Pet.canonicalSpeciesOptions,
                otherKey: "other",
                displayName: { Pet.localizedSpeciesName($0, l: l) }
            ),
            l: l,
            otherKey: "other",
            displayName: { Pet.localizedSpeciesName($0, l: l) }
        )

        assertLocalizedAndSorted(
            PetBreedDatabase.sortedCountries(l: l),
            l: l,
            displayName: { PetBreedDatabase.localizedRegionName($0, l: l) }
        )

        for country in PetBreedDatabase.countries where country != "其他" {
            assertLocalizedAndSorted(
                PetBreedDatabase.sortedCities(for: country, l: l),
                l: l,
                displayName: { PetBreedDatabase.localizedRegionName($0, l: l) }
            )
        }

        for species in Pet.canonicalSpeciesOptions {
            let breeds = l.sortedCatalogValues(
                PetBreedDatabase.breeds(for: species),
                key: \.name
            )
            assertLocalizedAndSorted(
                breeds.map(\.name),
                l: l,
                displayName: { l.resourceName($0) }
            )

            let coatNames = Set(
                breeds.flatMap { $0.coatColors.map(\.name) }
                    + PetBreedDatabase.genericCoatColors.map(\.name)
            )
            for coatName in coatNames {
                #expect(
                    !containsCJK(l.resourceName(coatName)),
                    "German coat color is missing: \(coatName)"
                )
            }
            assertLocalizedAndSorted(
                l.sortedCatalogKeys(Array(coatNames)),
                l: l,
                displayName: { l.resourceName($0) }
            )
        }
    }

    @Test func germanBreedOrderingUsesDisplayedNames() {
        let l = L10n("de")
        let raw = ["法国斗牛犬", "其他", "德国牧羊犬", "阿富汗猎犬"]

        #expect(
            l.sortedCatalogKeys(raw) == [
                "阿富汗猎犬",
                "德国牧羊犬",
                "法国斗牛犬",
                "其他"
            ]
        )
    }

    @Test func residenceStorageIsIndependentFromNationalityAndReadsLegacyValues() {
        let composed = MemberResidenceValue(country: "德国", city: "慕尼黑")
        #expect(composed.storedValue == "德国·慕尼黑")
        #expect(composed.localized(l: L10n("de")) == "Deutschland · München")

        let legacyCity = MemberResidenceValue(storedValue: "慕尼黑")
        #expect(legacyCity.country == "德国")
        #expect(legacyCity.city == "慕尼黑")

        let ambiguousCity = MemberResidenceValue(storedValue: "纽卡斯尔")
        #expect(ambiguousCity.country.isEmpty)
        #expect(ambiguousCity.city == "纽卡斯尔")

        let custom = MemberResidenceValue(storedValue: "Wakanda·Birnin Zana")
        #expect(custom.country == "Wakanda")
        #expect(custom.city == "Birnin Zana")
        #expect(custom.storedValue == "Wakanda·Birnin Zana")

        let customCountryOnly = MemberResidenceValue(country: "Wakanda", city: "")
        #expect(customCountryOnly.storedValue == "Wakanda·")
        #expect(
            MemberResidenceValue(storedValue: customCountryOnly.storedValue)
                == customCountryOnly
        )
    }

    private func assertLocalizedAndSorted(
        _ keys: [String],
        l: L10n,
        otherKey: String = "其他",
        displayName: (String) -> String
    ) {
        let regularKeys = keys.filter { !$0.isEmpty && $0 != otherKey }
        let localizedNames = regularKeys.map(displayName)

        for (key, name) in zip(regularKeys, localizedNames) {
            #expect(!containsCJK(name), "German catalog name is missing: \(key)")
        }

        let expected = localizedNames.sorted {
            $0.compare(
                $1,
                options: [.caseInsensitive, .numeric],
                locale: Locale(
                    identifier: AppLanguage.option(for: l.languageCode).localeIdentifier
                )
            ) == .orderedAscending
        }
        #expect(localizedNames == expected)

        if keys.contains(otherKey) {
            #expect(keys.last == otherKey)
        }
    }

    private func containsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            (0x3400 ... 0x4DBF).contains($0.value)
                || (0x4E00 ... 0x9FFF).contains($0.value)
                || (0xF900 ... 0xFAFF).contains($0.value)
        }
    }
}
