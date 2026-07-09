import CoreLocation
import Foundation
import MapKit
import Observation
import UserNotifications

struct OnboardingResolvedLocation: Equatable, Sendable {
    let country: String
    let city: String
}

struct OnboardingPlaceOption: Identifiable, Equatable, Sendable {
    let id: String
    let countryCode: String
    let title: AppLocalizedText

    var isCustom: Bool { id == OnboardingPlaceCatalog.customOptionId }
    var isCountry: Bool { id == countryCode && !countryCode.isEmpty }

    func title(languageCode: String) -> String {
        if isCountry,
           let regionName = localizedRegionName(languageCode: languageCode) {
            return regionName
        }
        return title.resolve(languageCode)
    }

    func localizedRegionName(languageCode: String) -> String? {
        guard isCountry else { return nil }
        let localeIdentifier = AppLanguage.option(for: languageCode).localeIdentifier
        return Locale(identifier: localeIdentifier)
            .localizedString(forRegionCode: countryCode)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private enum OnboardingPlaceCatalog {
    static let customOptionId = "__custom__"

    static let countries: [OnboardingPlaceOption] = [
        country("CN", zh: "中国", en: "China", de: "China"),
        country("US", zh: "美国", en: "United States", de: "Vereinigte Staaten"),
        country("CA", zh: "加拿大", en: "Canada", de: "Kanada"),
        country("GB", zh: "英国", en: "United Kingdom", de: "Vereinigtes Königreich"),
        country("DE", zh: "德国", en: "Germany", de: "Deutschland"),
        country("FR", zh: "法国", en: "France", de: "Frankreich"),
        country("ES", zh: "西班牙", en: "Spain", de: "Spanien"),
        country("IT", zh: "意大利", en: "Italy", de: "Italien"),
        country("PT", zh: "葡萄牙", en: "Portugal", de: "Portugal"),
        country("BR", zh: "巴西", en: "Brazil", de: "Brasilien"),
        country("MX", zh: "墨西哥", en: "Mexico", de: "Mexiko"),
        country("JP", zh: "日本", en: "Japan", de: "Japan"),
        country("KR", zh: "韩国", en: "South Korea", de: "Südkorea"),
        country("SG", zh: "新加坡", en: "Singapore", de: "Singapur"),
        country("AU", zh: "澳大利亚", en: "Australia", de: "Australien"),
        country("NL", zh: "荷兰", en: "Netherlands", de: "Niederlande")
    ]

    static let citiesByCountry: [String: [OnboardingPlaceOption]] = [
        "CN": [
            city("CN", "beijing", zh: "北京", en: "Beijing"),
            city("CN", "shanghai", zh: "上海", en: "Shanghai"),
            city("CN", "guangzhou", zh: "广州", en: "Guangzhou"),
            city("CN", "shenzhen", zh: "深圳", en: "Shenzhen"),
            city("CN", "chengdu", zh: "成都", en: "Chengdu"),
            city("CN", "hangzhou", zh: "杭州", en: "Hangzhou")
        ],
        "US": [
            city("US", "new-york", zh: "纽约", en: "New York"),
            city("US", "los-angeles", zh: "洛杉矶", en: "Los Angeles"),
            city("US", "san-francisco", zh: "旧金山", en: "San Francisco"),
            city("US", "seattle", zh: "西雅图", en: "Seattle"),
            city("US", "austin", zh: "奥斯汀", en: "Austin"),
            city("US", "chicago", zh: "芝加哥", en: "Chicago")
        ],
        "CA": [
            city("CA", "toronto", zh: "多伦多", en: "Toronto"),
            city("CA", "vancouver", zh: "温哥华", en: "Vancouver"),
            city("CA", "montreal", zh: "蒙特利尔", en: "Montreal"),
            city("CA", "calgary", zh: "卡尔加里", en: "Calgary")
        ],
        "GB": [
            city("GB", "london", zh: "伦敦", en: "London"),
            city("GB", "manchester", zh: "曼彻斯特", en: "Manchester"),
            city("GB", "edinburgh", zh: "爱丁堡", en: "Edinburgh"),
            city("GB", "birmingham", zh: "伯明翰", en: "Birmingham")
        ],
        "DE": [
            city("DE", "berlin", zh: "柏林", en: "Berlin"),
            city("DE", "munich", zh: "慕尼黑", en: "Munich", de: "München"),
            city("DE", "hamburg", zh: "汉堡", en: "Hamburg"),
            city("DE", "cologne", zh: "科隆", en: "Cologne", de: "Köln"),
            city("DE", "frankfurt", zh: "法兰克福", en: "Frankfurt")
        ],
        "FR": [
            city("FR", "paris", zh: "巴黎", en: "Paris"),
            city("FR", "lyon", zh: "里昂", en: "Lyon"),
            city("FR", "marseille", zh: "马赛", en: "Marseille"),
            city("FR", "bordeaux", zh: "波尔多", en: "Bordeaux")
        ],
        "ES": [
            city("ES", "madrid", zh: "马德里", en: "Madrid"),
            city("ES", "barcelona", zh: "巴塞罗那", en: "Barcelona"),
            city("ES", "valencia", zh: "瓦伦西亚", en: "Valencia"),
            city("ES", "seville", zh: "塞维利亚", en: "Seville", de: "Sevilla")
        ],
        "IT": [
            city("IT", "rome", zh: "罗马", en: "Rome"),
            city("IT", "milan", zh: "米兰", en: "Milan"),
            city("IT", "florence", zh: "佛罗伦萨", en: "Florence"),
            city("IT", "naples", zh: "那不勒斯", en: "Naples")
        ],
        "PT": [
            city("PT", "lisbon", zh: "里斯本", en: "Lisbon"),
            city("PT", "porto", zh: "波尔图", en: "Porto")
        ],
        "BR": [
            city("BR", "sao-paulo", zh: "圣保罗", en: "São Paulo"),
            city("BR", "rio-de-janeiro", zh: "里约热内卢", en: "Rio de Janeiro"),
            city("BR", "brasilia", zh: "巴西利亚", en: "Brasília")
        ],
        "MX": [
            city("MX", "mexico-city", zh: "墨西哥城", en: "Mexico City"),
            city("MX", "guadalajara", zh: "瓜达拉哈拉", en: "Guadalajara"),
            city("MX", "monterrey", zh: "蒙特雷", en: "Monterrey")
        ],
        "JP": [
            city("JP", "tokyo", zh: "东京", en: "Tokyo"),
            city("JP", "osaka", zh: "大阪", en: "Osaka"),
            city("JP", "kyoto", zh: "京都", en: "Kyoto"),
            city("JP", "yokohama", zh: "横滨", en: "Yokohama")
        ],
        "KR": [
            city("KR", "seoul", zh: "首尔", en: "Seoul"),
            city("KR", "busan", zh: "釜山", en: "Busan"),
            city("KR", "incheon", zh: "仁川", en: "Incheon")
        ],
        "SG": [
            city("SG", "singapore", zh: "新加坡", en: "Singapore")
        ],
        "AU": [
            city("AU", "sydney", zh: "悉尼", en: "Sydney"),
            city("AU", "melbourne", zh: "墨尔本", en: "Melbourne"),
            city("AU", "brisbane", zh: "布里斯班", en: "Brisbane"),
            city("AU", "perth", zh: "珀斯", en: "Perth")
        ],
        "NL": [
            city("NL", "amsterdam", zh: "阿姆斯特丹", en: "Amsterdam"),
            city("NL", "rotterdam", zh: "鹿特丹", en: "Rotterdam"),
            city("NL", "utrecht", zh: "乌得勒支", en: "Utrecht"),
            city("NL", "the-hague", zh: "海牙", en: "The Hague", de: "Den Haag")
        ]
    ]

    static var customOption: OnboardingPlaceOption {
        OnboardingPlaceOption(
            id: customOptionId,
            countryCode: "",
            title: AppLocalizedText(
                zh: "自定义",
                en: "Custom",
                de: "Eigener Eintrag",
                es: "Personalizado",
                pt: "Personalizado",
                fr: "Personnalisé",
                ja: "カスタム",
                ko: "직접 입력",
                it: "Personalizzato"
            )
        )
    }

    static var countryOptions: [OnboardingPlaceOption] {
        countries + [customOption]
    }

    static func cityOptions(for countryCode: String) -> [OnboardingPlaceOption] {
        (citiesByCountry[countryCode] ?? []) + [customOption]
    }

    static func countryOption(matching value: String) -> OnboardingPlaceOption? {
        let normalizedValue = normalized(value)
        return countries.first { option in
            option.countryCode.lowercased() == normalizedValue ||
                option.matchesLocalizedRegionName(normalizedValue: normalizedValue) ||
                option.matches(normalizedValue: normalizedValue)
        }
    }

    static func cityOption(matching value: String, countryCode: String) -> OnboardingPlaceOption? {
        let normalizedValue = normalized(value)
        return (citiesByCountry[countryCode] ?? []).first { option in
            option.matches(normalizedValue: normalizedValue)
        }
    }

    static func isCustomLabel(_ value: String) -> Bool {
        customOption.matches(normalizedValue: normalized(value))
    }

    private static func country(_ code: String, zh: String, en: String, de: String? = nil) -> OnboardingPlaceOption {
        OnboardingPlaceOption(
            id: code,
            countryCode: code,
            title: AppLocalizedText(zh: zh, en: en, de: de)
        )
    }

    private static func city(
        _ countryCode: String,
        _ id: String,
        zh: String,
        en: String,
        de: String? = nil
    ) -> OnboardingPlaceOption {
        OnboardingPlaceOption(
            id: "\(countryCode)-\(id)",
            countryCode: countryCode,
            title: AppLocalizedText(zh: zh, en: en, de: de)
        )
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension OnboardingPlaceOption {
    func matches(normalizedValue: String) -> Bool {
        title.translations.values.contains { value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedValue
        }
    }

    func matchesLocalizedRegionName(normalizedValue: String) -> Bool {
        AppLanguage.supported.contains { language in
            localizedRegionName(languageCode: language.code)?
                .lowercased() == normalizedValue
        }
    }
}

protocol OnboardingLocationResolving: Sendable {
    func resolve(location: CLLocation) async throws -> OnboardingResolvedLocation
}

struct LiveOnboardingLocationResolver: OnboardingLocationResolving {
    enum ResolutionError: Error {
        case missingPlace
    }

    func resolve(location: CLLocation) async throws -> OnboardingResolvedLocation {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw ResolutionError.missingPlace
        }
        let mapItems = try await request.mapItems
        guard let address = mapItems.first?.addressRepresentations else {
            throw ResolutionError.missingPlace
        }

        let country = address.regionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cityCandidates = [
            address.cityName,
            address.cityWithContext(.short),
            address.cityWithContext(.automatic)
        ]
        let city = cityCandidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        return try resolvedLocation(country: country, city: city)
    }

    private func resolvedLocation(country: String, city: String) throws -> OnboardingResolvedLocation {
        guard !country.isEmpty, !city.isEmpty else {
            throw ResolutionError.missingPlace
        }
        return OnboardingResolvedLocation(country: country, city: city)
    }
}

enum OnboardingLocationSource: String, Equatable, Sendable {
    case unresolved
    case automatic
    case manual
}

enum OnboardingNotificationPreferenceState: Equatable, Sendable {
    case enabled
    case requestable
    case settingsRequired
}

@MainActor
@Observable
final class OnboardingPreferenceCoordinator {
    static let countryKey = "ohana_onboarding_country"
    static let countryIsCustomKey = "ohana_onboarding_country_is_custom"
    static let countryCodeKey = "ohana_onboarding_country_code"
    static let cityKey = "ohana_onboarding_city"
    static let cityIsCustomKey = "ohana_onboarding_city_is_custom"
    static let locationSourceKey = "ohana_onboarding_location_source"
    static let notificationsIntentKey = "ohana_onboarding_notifications_intent"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let locationResolver: any OnboardingLocationResolving
    @ObservationIgnored private let locationRequestTimeoutNanoseconds: UInt64
    // 首次授权会弹系统对话框,用户读+点击常超过 GPS 超时。这个更宽的窗口只覆盖
    // "对话框 + 首个定位",避免把用户读对话框的时间误判为定位失败。
    @ObservationIgnored private let permissionPromptTimeoutNanoseconds: UInt64
    @ObservationIgnored private var locationRequestGeneration = 0

    var country: String {
        didSet { defaults.set(country, forKey: Self.countryKey) }
    }

    var usesCustomCountry: Bool {
        didSet { defaults.set(usesCustomCountry, forKey: Self.countryIsCustomKey) }
    }

    var selectedCountryCode: String {
        didSet {
            if selectedCountryCode.isEmpty {
                defaults.removeObject(forKey: Self.countryCodeKey)
            } else {
                defaults.set(selectedCountryCode, forKey: Self.countryCodeKey)
            }
        }
    }

    var city: String {
        didSet { defaults.set(city, forKey: Self.cityKey) }
    }

    var usesCustomCity: Bool {
        didSet { defaults.set(usesCustomCity, forKey: Self.cityIsCustomKey) }
    }

    var locationSource: OnboardingLocationSource {
        didSet { defaults.set(locationSource.rawValue, forKey: Self.locationSourceKey) }
    }

    var locationAuthorizationStatus: CLAuthorizationStatus
    var isResolvingLocation: Bool = false
    var locationError: String?
    var shouldShowLocationSettings: Bool = false
    var shouldShowLocationValidation: Bool = false

    var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var isRequestingNotificationPermission: Bool = false
    var shouldShowNotificationSettings: Bool = false

    var notificationIntent: Bool {
        didSet { defaults.set(notificationIntent, forKey: Self.notificationsIntentKey) }
    }

    init(
        defaults: UserDefaults = .standard,
        locationResolver: (any OnboardingLocationResolving)? = nil,
        locationRequestTimeoutNanoseconds: UInt64 = 4_000_000_000,
        permissionPromptTimeoutNanoseconds: UInt64 = 30_000_000_000,
        usesUITestDefaults: Bool? = nil
    ) {
        self.defaults = defaults
        self.locationResolver = locationResolver ?? LiveOnboardingLocationResolver()
        self.locationRequestTimeoutNanoseconds = locationRequestTimeoutNanoseconds
        self.permissionPromptTimeoutNanoseconds = permissionPromptTimeoutNanoseconds
        let storedCountry = defaults.string(forKey: Self.countryKey) ?? ""
        let storedCity = defaults.string(forKey: Self.cityKey) ?? ""
        let storedLocationSource = OnboardingLocationSource(rawValue: defaults.string(forKey: Self.locationSourceKey) ?? "") ?? .unresolved
        let shouldUseUITestDefaults = usesUITestDefaults ?? Self.usesUITestDefaultsFromLaunchArguments
        let shouldSeedUITestLocation = shouldUseUITestDefaults &&
            storedCountry.trimmedForOnboarding.isEmpty &&
            storedCity.trimmedForOnboarding.isEmpty &&
            storedLocationSource == .unresolved

        country = shouldSeedUITestLocation ? "Germany" : storedCountry
        selectedCountryCode = shouldSeedUITestLocation
            ? ""
            : defaults.string(forKey: Self.countryCodeKey) ?? OnboardingPlaceCatalog.countryOption(matching: storedCountry)?.countryCode ?? ""
        city = shouldSeedUITestLocation ? "Berlin" : storedCity
        usesCustomCountry = shouldSeedUITestLocation ? true : defaults.bool(forKey: Self.countryIsCustomKey)
        usesCustomCity = shouldSeedUITestLocation ? true : defaults.bool(forKey: Self.cityIsCustomKey)
        locationSource = shouldSeedUITestLocation ? .manual : storedLocationSource
        locationAuthorizationStatus = .notDetermined
        notificationIntent = defaults.bool(forKey: Self.notificationsIntentKey)
    }

    var hasResolvedAutomaticLocation: Bool {
        locationSource == .automatic && !country.trimmedForOnboarding.isEmpty && !city.trimmedForOnboarding.isEmpty
    }

    var showsManualLocationFields: Bool {
        locationSource == .manual ||
            locationAuthorizationStatus == .denied ||
            locationAuthorizationStatus == .restricted ||
            (!hasResolvedAutomaticLocation && locationError != nil)
    }

    var manualLocationIsComplete: Bool {
        !country.trimmedForOnboarding.isEmpty && !city.trimmedForOnboarding.isEmpty
    }

    var canContinueFromPreferencePage: Bool {
        true
    }

    var notificationPreferenceState: OnboardingNotificationPreferenceState {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .enabled
        case .denied:
            return .settingsRequired
        case .notDetermined:
            return .requestable
        @unknown default:
            return .requestable
        }
    }

    var countryMenuOptions: [OnboardingPlaceOption] {
        OnboardingPlaceCatalog.countryOptions
    }

    var cityMenuOptions: [OnboardingPlaceOption] {
        guard !usesCustomCountry, !selectedCountryCode.isEmpty else {
            return [OnboardingPlaceCatalog.customOption]
        }
        return OnboardingPlaceCatalog.cityOptions(for: selectedCountryCode)
    }

    func countryDisplayName(languageCode: String) -> String {
        if usesCustomCountry {
            return country
        }
        if let option = OnboardingPlaceCatalog.countryOption(matching: country) {
            return option.title(languageCode: languageCode)
        }
        if !selectedCountryCode.isEmpty,
           let option = OnboardingPlaceCatalog.countryOption(matching: selectedCountryCode) {
            return option.title(languageCode: languageCode)
        }
        return country
    }

    func cityDisplayName(languageCode: String) -> String {
        if usesCustomCity {
            return city
        }
        if let option = OnboardingPlaceCatalog.cityOption(matching: city, countryCode: selectedCountryCode) {
            return option.title(languageCode: languageCode)
        }
        return city
    }

    func syncLocationAuthorizationStatus(_ status: CLAuthorizationStatus) {
        locationAuthorizationStatus = status
        if status == .denied || status == .restricted {
            locationSource = .manual
            shouldShowLocationSettings = true
        }
    }

    func useManualLocation() {
        locationRequestGeneration += 1
        isResolvingLocation = false
        locationSource = .manual
        shouldShowLocationSettings = locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted
        locationError = nil
        shouldShowLocationValidation = false
        if !usesCustomCountry,
           selectedCountryCode.isEmpty,
           let option = OnboardingPlaceCatalog.countryOption(matching: country) {
            selectedCountryCode = option.countryCode
        }
        if !usesCustomCountry,
           !country.trimmedForOnboarding.isEmpty,
           selectedCountryCode.isEmpty {
            usesCustomCountry = true
            usesCustomCity = true
        } else if !usesCustomCity,
                  !city.trimmedForOnboarding.isEmpty,
                  OnboardingPlaceCatalog.cityOption(matching: city, countryCode: selectedCountryCode) == nil {
            usesCustomCity = true
        }
    }

    func selectCountry(_ option: OnboardingPlaceOption, languageCode: String) {
        useManualLocation()
        if option.isCustom {
            usesCustomCountry = true
            usesCustomCity = true
            selectedCountryCode = ""
            country = ""
            city = ""
        } else {
            usesCustomCountry = false
            selectedCountryCode = option.countryCode
            country = option.title(languageCode: languageCode)
            usesCustomCity = false
            city = ""
        }
    }

    func selectCountry(_ value: String) {
        if OnboardingPlaceCatalog.isCustomLabel(value) {
            selectCountry(OnboardingPlaceCatalog.customOption, languageCode: AppLanguage.fallbackCode)
        } else if let option = OnboardingPlaceCatalog.countryOption(matching: value) {
            selectCountry(option, languageCode: AppLanguage.fallbackCode)
        } else {
            useManualLocation()
            usesCustomCountry = true
            usesCustomCity = true
            selectedCountryCode = ""
            country = value
            city = ""
        }
    }

    func selectCity(_ option: OnboardingPlaceOption, languageCode: String) {
        useManualLocation()
        if option.isCustom {
            usesCustomCity = true
            city = ""
        } else {
            usesCustomCity = false
            city = option.title(languageCode: languageCode)
        }
    }

    func selectCity(_ value: String) {
        if OnboardingPlaceCatalog.isCustomLabel(value) {
            selectCity(OnboardingPlaceCatalog.customOption, languageCode: AppLanguage.fallbackCode)
        } else if let option = OnboardingPlaceCatalog.cityOption(matching: value, countryCode: selectedCountryCode) {
            selectCity(option, languageCode: AppLanguage.fallbackCode)
        } else {
            useManualLocation()
            usesCustomCity = true
            city = value
        }
    }

    func updateCustomCountry(_ value: String) {
        useManualLocation()
        usesCustomCountry = true
        usesCustomCity = true
        selectedCountryCode = ""
        country = value
    }

    func updateCustomCity(_ value: String) {
        useManualLocation()
        usesCustomCity = true
        city = value
    }

    func requestAutomaticLocation(locationProvider: LocationProviding) async {
        locationRequestGeneration += 1
        let requestGeneration = locationRequestGeneration
        shouldShowLocationValidation = false
        shouldShowLocationSettings = false
        locationError = nil
        locationAuthorizationStatus = locationProvider.authorizationStatus

        if locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted {
            useManualLocation()
            shouldShowLocationSettings = true
            return
        }

        isResolvingLocation = true
        defer {
            if requestGeneration == locationRequestGeneration {
                isResolvingLocation = false
            }
        }

        // 首次请求会先弹系统权限对话框——超时须覆盖用户读+点击的时间,否则会把
        // 对话框停留误判为定位失败(第一次报错、第二次才成功的经典竞态)。
        let timeout = locationAuthorizationStatus == .notDetermined
            ? permissionPromptTimeoutNanoseconds
            : locationRequestTimeoutNanoseconds
        let result = await oneShotLocation(from: locationProvider, timeoutNanoseconds: timeout)
        guard requestGeneration == locationRequestGeneration else { return }
        switch result {
        case let .success(location):
            do {
                let resolved = try await locationResolver.resolve(location: location)
                country = resolved.country
                city = resolved.city
                selectedCountryCode = OnboardingPlaceCatalog.countryOption(matching: resolved.country)?.countryCode ?? ""
                usesCustomCountry = false
                usesCustomCity = false
                locationSource = .automatic
                locationError = nil
            } catch {
                locationSource = .manual
                locationError = "location_resolution_failed"
            }
        case .failure:
            locationAuthorizationStatus = locationProvider.authorizationStatus
            if locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted {
                shouldShowLocationSettings = true
            }
            locationSource = .manual
            locationError = "location_request_failed"
        }
    }

    func refreshNotificationStatus(_ manager: UserNotificationManaging) async {
        notificationAuthorizationStatus = await manager.authorizationStatus()
        notificationIntent = notificationPreferenceState == .enabled
        if notificationPreferenceState == .enabled {
            shouldShowNotificationSettings = false
        }
    }

    func requestNotificationPermission(_ manager: UserNotificationManaging) async {
        shouldShowNotificationSettings = false
        notificationAuthorizationStatus = await manager.authorizationStatus()
        if notificationAuthorizationStatus == .denied {
            notificationIntent = false
            shouldShowNotificationSettings = true
            return
        }

        isRequestingNotificationPermission = true
        let granted = await manager.requestPermission()
        isRequestingNotificationPermission = false
        await refreshNotificationStatus(manager)
        notificationIntent = granted && notificationPreferenceState == .enabled
        if !notificationIntent && notificationPreferenceState == .settingsRequired {
            shouldShowNotificationSettings = true
        }
    }

    func validateBeforeLeavingPreferencePage() -> Bool {
        shouldShowLocationValidation = false
        return true
    }

    private func oneShotLocation(
        from provider: LocationProviding,
        timeoutNanoseconds: UInt64
    ) async -> Result<CLLocation, Error> {
        await withCheckedContinuation { continuation in
            let completion = OnboardingOneShotLocationCompletion(continuation: continuation)
            // 只需定位国家/城市:公里级精度靠 WiFi/基站即可秒回,无需等精确 GPS 卫星锁定
            // (100 米精度会让首次/室内定位慢十几秒)。反向地理编码城市级足够。
            provider.requestOneShotLocation(accuracy: kCLLocationAccuracyKilometer) { result in
                Task { @MainActor in
                    completion.resume(with: result)
                }
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                completion.resume(with: .failure(OnboardingLocationRequestError.timedOut))
            }
        }
    }
}

private extension OnboardingPreferenceCoordinator {
    static var usesUITestDefaultsFromLaunchArguments: Bool {
        ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TESTS")
    }
}

private enum OnboardingLocationRequestError: Error {
    case timedOut
}

@MainActor
private final class OnboardingOneShotLocationCompletion {
    private var continuation: CheckedContinuation<Result<CLLocation, Error>, Never>?

    init(continuation: CheckedContinuation<Result<CLLocation, Error>, Never>) {
        self.continuation = continuation
    }

    func resume(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: result)
    }
}

private extension String {
    var trimmedForOnboarding: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
