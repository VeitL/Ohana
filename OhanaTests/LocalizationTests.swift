import Foundation
import Testing
@testable import Ohana

struct LocalizationTests {
    @Test func localizedTextResolvesSupportedLanguages() {
        let text = AppLocalizedText(
            translations: [
                "zh": "保存",
                "en": "Save",
                "de": "Speichern",
                "fr": "Enregistrer"
            ]
        )

        #expect(text.resolve("zh") == "保存")
        #expect(text.resolve("en") == "Save")
        #expect(text.resolve("de") == "Speichern")
        #expect(text.resolve("fr") == "保存")
        #expect(text.missingSupportedLanguageCodes.isEmpty)
    }

    @Test func localizedTextReportsMissingRegisteredTranslations() {
        let text = AppLocalizedText(zh: "货币", en: "Currency")

        #expect(text.resolve("de") == "货币")
        #expect(text.missingSupportedLanguageCodes == ["de"])
    }

    @Test func countryDefaultsMapToLanguageUnitsAndCurrency() {
        let us = AppCountry.option(for: "US")
        let germany = AppCountry.option(for: "DE")
        let china = AppCountry.option(for: "CN")

        #expect(us.defaultLanguageCode == "en")
        #expect(us.defaultCurrencyCode == "USD")
        #expect(us.defaultMeasurementSystemCode == "imperial")
        #expect(germany.defaultLanguageCode == "de")
        #expect(germany.defaultCurrencyCode == "EUR")
        #expect(germany.defaultMeasurementSystemCode == "metric")
        #expect(china.defaultLanguageCode == "zh")
        #expect(china.defaultCurrencyCode == "CNY")
        #expect(china.defaultMeasurementSystemCode == "metric")
    }

    @Test func countrySelectionAppliesEditablePreferenceDefaults() {
        let defaults = UserDefaults.standard
        let previousCountry = defaults.string(forKey: AppCountry.storageKey)
        let previousLanguage = defaults.string(forKey: "appLanguage")
        let previousCurrency = defaults.string(forKey: AppCurrency.storageKey)
        let previousMeasurement = defaults.string(forKey: AppMeasurementSystem.storageKey)
        defer {
            restore(previousCountry, forKey: AppCountry.storageKey)
            restore(previousLanguage, forKey: "appLanguage")
            restore(previousCurrency, forKey: AppCurrency.storageKey)
            restore(previousMeasurement, forKey: AppMeasurementSystem.storageKey)
        }

        AppCountry.applyDefaults(for: "GB")

        #expect(defaults.string(forKey: AppCountry.storageKey) == "GB")
        #expect(defaults.string(forKey: "appLanguage") == "en")
        #expect(defaults.string(forKey: AppCurrency.storageKey) == "GBP")
        #expect(defaults.string(forKey: AppMeasurementSystem.storageKey) == "imperial")
    }

    @Test func measurementSystemNormalizesUnknownValues() {
        #expect(AppMeasurementSystem.normalize("metric") == "metric")
        #expect(AppMeasurementSystem.normalize("imperial") == "imperial")
        #expect(AppMeasurementSystem.normalize("unknown") == AppMeasurementSystem.fallbackCode)
    }

    private func restore(_ value: String?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
