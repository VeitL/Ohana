//
//  LocalizationSettings.swift
//  Ohana
//
//  App language, localized text, unit, currency, and region settings.
//

import Foundation

// MARK: - App language (与设置页 `appLanguage` / `@AppStorage` 同步)

nonisolated enum AppLanguage {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: String
        let localeIdentifier: String
        let swiftUILocaleIdentifier: String
        let lprojName: String

        var id: String { code }
    }

    /// 以后新增语言时只需要在这里追加一项，并添加对应 `.lproj/Localizable.strings`。
    static let supported: [Option] = [
        Option(
            code: "zh",
            displayName: "中文",
            localeIdentifier: "zh_CN",
            swiftUILocaleIdentifier: "zh-Hans",
            lprojName: "zh-Hans"
        ),
        Option(
            code: "en",
            displayName: "English",
            localeIdentifier: "en_US",
            swiftUILocaleIdentifier: "en",
            lprojName: "en"
        ),
        Option(
            code: "de",
            displayName: "Deutsch",
            localeIdentifier: "de_DE",
            swiftUILocaleIdentifier: "de",
            lprojName: "de"
        ),
        Option(
            code: "es",
            displayName: "Español",
            localeIdentifier: "es_ES",
            swiftUILocaleIdentifier: "es",
            lprojName: "es"
        ),
        Option(
            code: "pt",
            displayName: "Português",
            localeIdentifier: "pt_BR",
            swiftUILocaleIdentifier: "pt-BR",
            lprojName: "pt"
        ),
        Option(
            code: "fr",
            displayName: "Français",
            localeIdentifier: "fr_FR",
            swiftUILocaleIdentifier: "fr",
            lprojName: "fr"
        ),
        Option(
            code: "ja",
            displayName: "日本語",
            localeIdentifier: "ja_JP",
            swiftUILocaleIdentifier: "ja",
            lprojName: "ja"
        ),
        Option(
            code: "ko",
            displayName: "한국어",
            localeIdentifier: "ko_KR",
            swiftUILocaleIdentifier: "ko",
            lprojName: "ko"
        ),
        Option(
            code: "it",
            displayName: "Italiano",
            localeIdentifier: "it_IT",
            swiftUILocaleIdentifier: "it",
            lprojName: "it"
        )
    ]

    static let fallbackCode = "zh"

    /// 与 `SettingsView` 中 Picker 的 tag 一致。
    static var code: String {
        normalize(UserDefaults.standard.string(forKey: "appLanguage") ?? detectedCode)
    }

    static var isEnglish: Bool { code == "en" }
    static var isGerman: Bool { code == "de" }
    static var isSpanish: Bool { code == "es" }
    static var isPortuguese: Bool { code == "pt" }
    static var isFrench: Bool { code == "fr" }
    static var isJapanese: Bool { code == "ja" }
    static var isKorean: Bool { code == "ko" }
    static var isItalian: Bool { code == "it" }
    static var usesChineseDateFormat: Bool { code == "zh" }
    static var supportedCodes: Set<String> { Set(supported.map(\.code)) }
    static var supportedLprojNames: Set<String> { Set(supported.map(\.lprojName)) }

    static func normalize(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: "_", with: "-").lowercased()
        if supported.contains(where: { $0.code == normalized }) {
            return normalized
        }
        if let languagePrefix = normalized.split(separator: "-").first {
            let code = String(languagePrefix)
            if supported.contains(where: { $0.code == code }) {
                return code
            }
        }
        return fallbackCode
    }

    static var detectedCode: String {
        for identifier in Locale.preferredLanguages {
            let languageCode = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
            let normalized = normalize(languageCode)
            if normalized != fallbackCode || languageCode.lowercased().hasPrefix(fallbackCode) {
                return normalized
            }
        }

        if let currentLanguage = Locale.current.language.languageCode?.identifier {
            return normalize(currentLanguage)
        }
        return fallbackCode
    }

    static func fallbackChain(for raw: String) -> [String] {
        let code = normalize(raw)
        var chain = [code]
        if code != "en" { chain.append("en") }
        if fallbackCode != code, fallbackCode != "en" { chain.append(fallbackCode) }
        return Array(NSOrderedSet(array: chain).compactMap { $0 as? String })
    }

    static func lprojName(for raw: String) -> String {
        option(for: raw).lprojName
    }

    static var currentOption: Option {
        supported.first { $0.code == code } ?? supported[0]
    }

    static func option(for raw: String) -> Option {
        supported.first { $0.code == normalize(raw) } ?? supported[0]
    }

    /// `DateFormatter` / `NumberFormatter` 等使用。
    static var effectiveLocale: Locale {
        Locale(identifier: currentOption.localeIdentifier)
    }

    static var compactMonthDayFormat: String {
        switch code {
        case "zh":
            return "M月d日"
        case "ja":
            return "M月d日"
        case "ko":
            return "M월 d일"
        case "de":
            return "d. MMM"
        case "es", "pt", "fr", "it":
            return "d MMM"
        default:
            return "MMM d"
        }
    }

    static var fullMonthYearFormat: String {
        usesChineseDateFormat ? "yyyy年 M月" : "MMMM yyyy"
    }

    static var dailyReportDateFormat: String {
        switch code {
        case "zh":
            return "M月d日 EEEE"
        case "ja":
            return "M月d日 EEEE"
        case "ko":
            return "M월 d일 EEEE"
        case "de", "es", "pt", "fr", "it":
            return "EEEE, d. MMM"
        default:
            return "EEEE, MMM d"
        }
    }

    /// SwiftUI `Text` 等查 `Localizable.strings` 时使用，与 `en.lproj` / `zh-Hans` 资源一致。
    static var swiftUIPreferredLocale: Locale {
        Locale(identifier: currentOption.swiftUILocaleIdentifier)
    }

    /// 例：`2026-04-19`，用于「每日只弹一次」等与展示语言无关的键。
    static var calendarDayKeyToday: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.startOfDay(for: Date()))
    }
}

// MARK: - Localized text value

nonisolated struct AppLocalizedText: Hashable {
    let translations: [String: String]
    let fallbackCode: String

    init(
        zh: String,
        en: String? = nil,
        de: String? = nil,
        es: String? = nil,
        pt: String? = nil,
        fr: String? = nil,
        ja: String? = nil,
        ko: String? = nil,
        it: String? = nil,
        extras: [String: String] = [:],
        fallbackCode: String = AppLanguage.fallbackCode
    ) {
        var values = extras
        values["zh"] = zh
        if let en { values["en"] = en }
        if let de { values["de"] = de }
        if let es { values["es"] = es }
        if let pt { values["pt"] = pt }
        if let fr { values["fr"] = fr }
        if let ja { values["ja"] = ja }
        if let ko { values["ko"] = ko }
        if let it { values["it"] = it }

        self.translations = values
        self.fallbackCode = AppLanguage.normalize(fallbackCode)
    }

    init(
        translations: [String: String],
        fallbackCode: String = AppLanguage.fallbackCode
    ) {
        self.translations = translations
        self.fallbackCode = AppLanguage.normalize(fallbackCode)
    }

    func resolve(_ rawLanguageCode: String = AppLanguage.code) -> String {
        for code in AppLanguage.fallbackChain(for: rawLanguageCode) {
            if let value = translations[code], !value.isEmpty {
                return value
            }
        }
        return translations.values.first { !$0.isEmpty } ?? ""
    }

    var missingSupportedLanguageCodes: [String] {
        AppLanguage.supported
            .map(\.code)
            .filter { translations[$0]?.isEmpty ?? true }
    }
}

// MARK: - App measurement system (全局显示单位；不迁移历史数据)

nonisolated enum AppMeasurementSystem {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: AppLocalizedText
        let shortLabel: String
        let systemIconName: String

        var id: String { code }

        func title(_ languageCode: String = AppLanguage.code) -> String {
            displayName.resolve(languageCode)
        }
    }

    static let storageKey = "appMeasurementSystem"
    static let fallbackCode = "metric"

    static let supported: [Option] = [
        Option(
            code: "metric",
            displayName: AppLocalizedText(
                zh: "公制 · kg / cm",
                en: "Metric · kg / cm",
                de: "Metrisch · kg / cm",
                es: "Métrico · kg / cm",
                pt: "Métrico · kg / cm",
                fr: "Métrique · kg / cm",
                ja: "メートル法 · kg / cm",
                ko: "미터법 · kg / cm",
                it: "Metrico · kg / cm"
            ),
            shortLabel: "kg",
            systemIconName: "scalemass"
        ),
        Option(
            code: "imperial",
            displayName: AppLocalizedText(
                zh: "英制 · lb / in",
                en: "Imperial · lb / in",
                de: "Imperial · lb / in",
                es: "Imperial · lb / in",
                pt: "Imperial · lb / in",
                fr: "Impérial · lb / in",
                ja: "ヤード・ポンド法 · lb / in",
                ko: "야드파운드법 · lb / in",
                it: "Imperiale · lb / in"
            ),
            shortLabel: "lb",
            systemIconName: "ruler"
        )
    ]

    static var code: String {
        normalize(UserDefaults.standard.string(forKey: storageKey) ?? fallbackCode)
    }

    static func normalize(_ raw: String) -> String {
        supported.contains { $0.code == raw } ? raw : fallbackCode
    }

    static var currentOption: Option {
        supported.first { $0.code == code } ?? supported[0]
    }

    static func option(for raw: String) -> Option {
        supported.first { $0.code == normalize(raw) } ?? supported[0]
    }

    static func formatWeightKilograms(_ kilograms: Double, fractionDigits: Int = 1) -> String {
        switch code {
        case "imperial":
            let pounds = kilograms * 2.2046226218
            return "\(formattedNumber(pounds, fractionDigits: fractionDigits)) lb"
        default:
            return "\(formattedNumber(kilograms, fractionDigits: fractionDigits)) kg"
        }
    }

    static func formatFoodGrams(_ grams: Double, fractionDigits: Int = 0) -> String {
        switch code {
        case "imperial":
            let pounds = grams / 453.59237
            let preciseDigits = fractionDigits == 0 ? 1 : fractionDigits
            return pounds >= 1
                ? "\(formattedNumber(pounds, fractionDigits: preciseDigits)) lb"
                : "\(formattedNumber(grams * 0.0352739619, fractionDigits: preciseDigits)) oz"
        default:
            let preciseDigits = fractionDigits == 0 ? 1 : fractionDigits
            return grams >= 1_000
                ? "\(formattedNumber(grams / 1_000, fractionDigits: preciseDigits)) kg"
                : "\(formattedNumber(grams, fractionDigits: fractionDigits)) g"
        }
    }

    static func formatDistanceMeters(_ meters: Double, fractionDigits: Int = 1) -> String {
        switch code {
        case "imperial":
            let miles = meters / 1_609.344
            return miles >= 0.1
                ? "\(formattedNumber(miles, fractionDigits: fractionDigits)) mi"
                : "\(formattedNumber(meters * 3.280839895, fractionDigits: 0)) ft"
        default:
            return meters >= 1_000
                ? "\(formattedNumber(meters / 1_000, fractionDigits: fractionDigits)) km"
                : "\(formattedNumber(meters, fractionDigits: 0)) m"
        }
    }

    private static func formattedNumber(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

// MARK: - App currency (全局真实货币显示；不做汇率换算)

nonisolated enum AppCurrency {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: String
        let symbol: String
        let localeIdentifier: String
        let systemIconName: String

        var id: String { code }
    }

    static let storageKey = "appCurrency"
    static let fallbackCode = "CNY"

    static let supported: [Option] = [
        Option(code: "CNY", displayName: "CNY · ¥", symbol: "¥", localeIdentifier: "zh_CN", systemIconName: "yensign.circle"),
        Option(code: "USD", displayName: "USD · $", symbol: "$", localeIdentifier: "en_US", systemIconName: "dollarsign.circle"),
        Option(code: "EUR", displayName: "EUR · €", symbol: "€", localeIdentifier: "de_DE", systemIconName: "eurosign.circle"),
        Option(code: "GBP", displayName: "GBP · £", symbol: "£", localeIdentifier: "en_GB", systemIconName: "sterlingsign.circle"),
        Option(code: "JPY", displayName: "JPY · ¥", symbol: "¥", localeIdentifier: "ja_JP", systemIconName: "yensign.circle"),
        Option(code: "HKD", displayName: "HKD · HK$", symbol: "HK$", localeIdentifier: "zh_HK", systemIconName: "dollarsign.circle"),
        Option(code: "TWD", displayName: "TWD · NT$", symbol: "NT$", localeIdentifier: "zh_TW", systemIconName: "dollarsign.circle")
    ]

    static var code: String {
        normalize(UserDefaults.standard.string(forKey: storageKey) ?? fallbackCode)
    }

    static func normalize(_ raw: String) -> String {
        let upper = raw.uppercased()
        return supported.contains { $0.code == upper } ? upper : fallbackCode
    }

    static var currentOption: Option {
        supported.first { $0.code == code } ?? supported[0]
    }

    static var symbol: String { currentOption.symbol }
    static var systemIconName: String { currentOption.systemIconName }

    static func format(_ amount: Double, fractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: currentOption.localeIdentifier)
        formatter.currencyCode = currentOption.code
        formatter.currencySymbol = currentOption.symbol
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currentOption.symbol)\(amount)"
    }

    static func formatCompact(_ amount: Double) -> String {
        if amount >= 10_000 {
            return "\(symbol)\(String(format: "%.0fk", amount / 1_000))"
        }
        if amount >= 100 {
            return format(amount, fractionDigits: 0)
        }
        return amount > 0 ? format(amount, fractionDigits: 1) : format(0, fractionDigits: 0)
    }
}

// MARK: - App country / region (国家默认偏好映射)

nonisolated enum AppCountry {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: AppLocalizedText
        let flag: String
        let defaultLanguageCode: String
        let defaultCurrencyCode: String
        let defaultMeasurementSystemCode: String

        var id: String { code }

        func title(_ languageCode: String = AppLanguage.code) -> String {
            "\(flag) \(displayName.resolve(languageCode))"
        }
    }

    static let storageKey = "appCountry"
    static let fallbackCode = "CN"

    static let supported: [Option] = [
        Option(
            code: "CN",
            displayName: AppLocalizedText(zh: "中国大陆", en: "Mainland China", de: "Festlandchina"),
            flag: "🇨🇳",
            defaultLanguageCode: "zh",
            defaultCurrencyCode: "CNY",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "US",
            displayName: AppLocalizedText(zh: "美国", en: "United States", de: "Vereinigte Staaten"),
            flag: "🇺🇸",
            defaultLanguageCode: "en",
            defaultCurrencyCode: "USD",
            defaultMeasurementSystemCode: "imperial"
        ),
        Option(
            code: "DE",
            displayName: AppLocalizedText(zh: "德国", en: "Germany", de: "Deutschland"),
            flag: "🇩🇪",
            defaultLanguageCode: "de",
            defaultCurrencyCode: "EUR",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "GB",
            displayName: AppLocalizedText(zh: "英国", en: "United Kingdom", de: "Vereinigtes Königreich"),
            flag: "🇬🇧",
            defaultLanguageCode: "en",
            defaultCurrencyCode: "GBP",
            defaultMeasurementSystemCode: "imperial"
        ),
        Option(
            code: "JP",
            displayName: AppLocalizedText(zh: "日本", en: "Japan", de: "Japan"),
            flag: "🇯🇵",
            defaultLanguageCode: "en",
            defaultCurrencyCode: "JPY",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "HK",
            displayName: AppLocalizedText(zh: "中国香港", en: "Hong Kong", de: "Hongkong"),
            flag: "🇭🇰",
            defaultLanguageCode: "zh",
            defaultCurrencyCode: "HKD",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "TW",
            displayName: AppLocalizedText(zh: "中国台湾", en: "Taiwan", de: "Taiwan"),
            flag: "🇹🇼",
            defaultLanguageCode: "zh",
            defaultCurrencyCode: "TWD",
            defaultMeasurementSystemCode: "metric"
        )
    ]

    static var code: String {
        normalize(UserDefaults.standard.string(forKey: storageKey) ?? detectedCode)
    }

    static var detectedCode: String {
        let regionCode = Locale.current.region?.identifier.uppercased()
        if let regionCode, supported.contains(where: { $0.code == regionCode }) {
            return regionCode
        }

        let languageCode = Locale.current.language.languageCode?.identifier.lowercased()
        switch languageCode {
        case "de":
            return "DE"
        case "en":
            return "US"
        default:
            return fallbackCode
        }
    }

    static func normalize(_ raw: String) -> String {
        let upper = raw.uppercased()
        return supported.contains { $0.code == upper } ? upper : fallbackCode
    }

    static var currentOption: Option {
        option(for: code)
    }

    static func option(for raw: String) -> Option {
        supported.first { $0.code == normalize(raw) } ?? supported[0]
    }

    static func ensureInitialized() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: storageKey) == nil else { return }

        let selected = option(for: detectedCode)
        defaults.set(selected.code, forKey: storageKey)

        if defaults.object(forKey: "appLanguage") == nil {
            defaults.set(AppLanguage.detectedCode, forKey: "appLanguage")
        }
        if defaults.object(forKey: AppCurrency.storageKey) == nil {
            defaults.set(AppCurrency.normalize(selected.defaultCurrencyCode), forKey: AppCurrency.storageKey)
        }
        if defaults.object(forKey: AppMeasurementSystem.storageKey) == nil {
            defaults.set(AppMeasurementSystem.normalize(selected.defaultMeasurementSystemCode), forKey: AppMeasurementSystem.storageKey)
        }
    }

    static func applyDefaults(for countryCode: String) {
        let selected = option(for: countryCode)
        let defaults = UserDefaults.standard
        defaults.set(selected.code, forKey: storageKey)
        defaults.set(AppLanguage.normalize(selected.defaultLanguageCode), forKey: "appLanguage")
        defaults.set(AppCurrency.normalize(selected.defaultCurrencyCode), forKey: AppCurrency.storageKey)
        defaults.set(AppMeasurementSystem.normalize(selected.defaultMeasurementSystemCode), forKey: AppMeasurementSystem.storageKey)
    }
}
