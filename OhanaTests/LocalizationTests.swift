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
                "es": "Guardar",
                "pt": "Salvar",
                "fr": "Enregistrer",
                "ja": "保存",
                "ko": "저장",
                "it": "Salva"
            ]
        )

        #expect(text.resolve("zh") == "保存")
        #expect(text.resolve("en") == "Save")
        #expect(text.resolve("de") == "Speichern")
        #expect(text.resolve("es") == "Guardar")
        #expect(text.resolve("pt") == "Salvar")
        #expect(text.resolve("fr") == "Enregistrer")
        #expect(text.resolve("ja") == "保存")
        #expect(text.resolve("ko") == "저장")
        #expect(text.resolve("it") == "Salva")
        #expect(text.missingSupportedLanguageCodes.isEmpty)
    }

    @Test func localizedTextReportsMissingRegisteredTranslations() {
        let text = AppLocalizedText(zh: "货币", en: "Currency")

        #expect(text.resolve("de") == "Currency")
        #expect(text.resolve("es") == "Currency")
        #expect(text.resolve("pt") == "Currency")
        #expect(text.resolve("fr") == "Currency")
        #expect(text.resolve("ja") == "Currency")
        #expect(text.resolve("ko") == "Currency")
        #expect(text.resolve("it") == "Currency")
        #expect(text.missingSupportedLanguageCodes == ["de", "es", "pt", "fr", "ja", "ko", "it"])
    }

    @Test func languageRegistryProvidesFutureReadyFallbackChains() {
        #expect(AppLanguage.supported.map(\.code) == ["zh", "en", "de", "es", "pt", "fr", "ja", "ko", "it"])
        #expect(AppLanguage.supportedLprojNames == Set(["zh-Hans", "en", "de", "es", "pt", "fr", "ja", "ko", "it"]))
        #expect(AppLanguage.fallbackChain(for: "de") == ["de", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "es") == ["es", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "pt") == ["pt", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "fr") == ["fr", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "ja") == ["ja", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "ko") == ["ko", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "it") == ["it", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "en") == ["en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "nl") == ["zh", "en"])
        #expect(AppLanguage.lprojName(for: "de") == "de")
        #expect(AppLanguage.lprojName(for: "es") == "es")
        #expect(AppLanguage.lprojName(for: "pt") == "pt")
        #expect(AppLanguage.lprojName(for: "fr") == "fr")
        #expect(AppLanguage.lprojName(for: "ja") == "ja")
        #expect(AppLanguage.lprojName(for: "ko") == "ko")
        #expect(AppLanguage.lprojName(for: "it") == "it")
    }

    @Test func highTrafficCopyResolvesSupportedLanguages() {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")
        let es = L10n("es")
        let pt = L10n("pt")
        let fr = L10n("fr")
        let ja = L10n("ja")
        let ko = L10n("ko")
        let it = L10n("it")

        #expect(zh.potty == "噗噗")
        #expect(en.potty == "Poop")
        #expect(de.potty == "Häufchen")
        #expect(es.potty == "Popó")
        #expect(pt.potty == "Cocô")
        #expect(fr.potty == "Caca")
        #expect(ja.potty == "ぷっぷ")
        #expect(ko.potty == "뿌뿌")
        #expect(it.potty == "Popò")
        #expect(zh.edit == "编辑")
        #expect(en.edit == "Edit")
        #expect(de.edit == "Bearbeiten")
        #expect(es.edit == "Editar")
        #expect(pt.edit == "Editar")
        #expect(fr.edit == "Modifier")
        #expect(ja.edit == "編集")
        #expect(ko.edit == "편집")
        #expect(it.edit == "Modifica")
        #expect(zh.addEntityHeadline == "谁要上岛？")
        #expect(en.addEntityHeadline == "Who's joining the fun?")
        #expect(de.addEntityHeadline == "Wer kommt dazu?")
        #expect(es.addEntityHeadline == "¿Quién sube a la isla?")
        #expect(pt.addEntityHeadline == "Quem chega à ilha?")
        #expect(fr.addEntityHeadline == "Qui monte sur l'île ?")
        #expect(ja.addEntityHeadline == "だれが島にくる？")
        #expect(ko.addEntityHeadline == "누가 섬에 올까요?")
        #expect(it.addEntityHeadline == "Chi sale sull'isola?")
        #expect(de.petCardWalkPoopLabel == "Häufchen-Stopps")
        #expect(es.petCardWalkPoopLabel == "Paradas popó")
        #expect(pt.petCardWalkPoopLabel == "Paradas cocô")
        #expect(fr.petCardWalkPoopLabel == "Arrêts caca")
        #expect(ja.petCardWalkPoopLabel == "ぷっぷ電台")
        #expect(ko.petCardWalkPoopLabel == "뿌뿌 방송국")
        #expect(it.petCardWalkPoopLabel == "Radio popò")
        #expect(es.daysLeft(3) == "Quedan 3 días")
        #expect(pt.homeToastPotty("Mochi", points: 2) == "Mochi cocô registrado +2 🥥")
        #expect(fr.petCardVaccineCountdown(daysUntilDue: 5) == "dans 5 j")
        #expect(ja.daysLeft(3) == "あと 3 日")
        #expect(ko.homeToastPotty("Mochi", points: 2) == "Mochi 뿌뿌 기록 +2 🥥")
        #expect(it.petCardVaccineCountdown(daysUntilDue: 5) == "tra 5 g")
    }

    @Test func localizedHelpersDoNotCollapseGermanToEnglish() {
        let de = L10n("de")
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 1))!

        #expect(Human.westernZodiacDisplay(for: date, l: de) == "Steinbock")
        #expect(PetPersonalityTag.displayTitle(for: "curious", l: de) == "Neugierig")
        #expect(PetAgeConverter.humanAge(birthday: date, species: "狗", l: de).contains("Menschenalter"))
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
