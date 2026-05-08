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
}
