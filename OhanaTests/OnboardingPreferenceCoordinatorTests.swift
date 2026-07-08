import CoreLocation
import Foundation
import Testing
import UserNotifications
@testable import Ohana

@MainActor
@Suite(.serialized)
struct OnboardingPreferenceCoordinatorTests {
    @Test func automaticLocationStoresCountryCityAndLeavesAppCountryUntouched() async {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(
            defaults: defaults,
            locationResolver: FakeOnboardingLocationResolver(
                resolved: OnboardingResolvedLocation(country: "美国", city: "旧金山")
            )
        )
        let provider = FakeOnboardingLocationProvider(
            authorizationStatus: .authorizedWhenInUse,
            result: .success(CLLocation(latitude: 37.7749, longitude: -122.4194))
        )

        await coordinator.requestAutomaticLocation(locationProvider: provider)

        #expect(coordinator.hasResolvedAutomaticLocation)
        #expect(!coordinator.showsManualLocationFields)
        #expect(coordinator.country == "美国")
        #expect(coordinator.city == "旧金山")
        #expect(defaults.string(forKey: OnboardingPreferenceCoordinator.countryKey) == "美国")
        #expect(defaults.string(forKey: OnboardingPreferenceCoordinator.cityKey) == "旧金山")
        #expect(defaults.string(forKey: AppCountry.storageKey) == nil)
    }

    @Test func deniedLocationKeepsManualFallbackButDoesNotBlockProfileCreation() {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(defaults: defaults)

        coordinator.syncLocationAuthorizationStatus(.denied)

        #expect(coordinator.showsManualLocationFields)
        #expect(coordinator.canContinueFromPreferencePage)

        coordinator.selectCountry("中国")

        #expect(coordinator.canContinueFromPreferencePage)

        coordinator.selectCity("上海")

        #expect(coordinator.canContinueFromPreferencePage)
    }

    @Test func uiTestLaunchDefaultsProvideCompleteManualLocationWithoutSystemPermission() {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(
            defaults: defaults,
            usesUITestDefaults: true
        )

        #expect(coordinator.locationSource == .manual)
        #expect(coordinator.usesCustomCountry)
        #expect(coordinator.usesCustomCity)
        #expect(coordinator.country == "Germany")
        #expect(coordinator.city == "Berlin")
        #expect(coordinator.manualLocationIsComplete)
        #expect(coordinator.canContinueFromPreferencePage)
    }

    @Test func unresolvedLocationRequestTimesOutToManualFields() async {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(
            defaults: defaults,
            locationRequestTimeoutNanoseconds: 1_000_000
        )
        let provider = SilentOnboardingLocationProvider(authorizationStatus: .authorizedWhenInUse)

        await coordinator.requestAutomaticLocation(locationProvider: provider)

        #expect(!coordinator.isResolvingLocation)
        #expect(coordinator.locationSource == .manual)
        #expect(coordinator.showsManualLocationFields)
        #expect(coordinator.locationError == "location_request_failed")
    }

    @Test func manualLocationCancelsStaleAutomaticLocationCallback() async {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(
            defaults: defaults,
            locationResolver: FakeOnboardingLocationResolver(
                resolved: OnboardingResolvedLocation(country: "United States", city: "San Francisco")
            ),
            locationRequestTimeoutNanoseconds: 1_000_000_000
        )
        let provider = DeferredOnboardingLocationProvider(authorizationStatus: .authorizedWhenInUse)

        let task = Task {
            await coordinator.requestAutomaticLocation(locationProvider: provider)
        }

        while !coordinator.isResolvingLocation {
            await Task.yield()
        }

        coordinator.useManualLocation()
        coordinator.updateCustomCountry("Custom Land")
        coordinator.updateCustomCity("Custom City")
        provider.complete(.success(CLLocation(latitude: 37.7749, longitude: -122.4194)))
        await task.value

        #expect(coordinator.locationSource == .manual)
        #expect(coordinator.country == "Custom Land")
        #expect(coordinator.city == "Custom City")
    }

    @Test func customCountryAndCityPersistAsManualLocation() {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(defaults: defaults)

        coordinator.selectCountry("其他")
        coordinator.country = "月球基地"
        coordinator.city = "静海"

        #expect(coordinator.canContinueFromPreferencePage)
        #expect(coordinator.usesCustomCountry)
        #expect(coordinator.usesCustomCity)
        #expect(defaults.string(forKey: OnboardingPreferenceCoordinator.countryKey) == "月球基地")
        #expect(defaults.bool(forKey: OnboardingPreferenceCoordinator.countryIsCustomKey))
        #expect(defaults.string(forKey: OnboardingPreferenceCoordinator.cityKey) == "静海")
        #expect(defaults.bool(forKey: OnboardingPreferenceCoordinator.cityIsCustomKey))
        #expect(defaults.string(forKey: OnboardingPreferenceCoordinator.locationSourceKey) == OnboardingLocationSource.manual.rawValue)
    }

    @Test func manualPlaceListsFollowRequestedLanguage() {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(defaults: defaults)

        let englishCountries = coordinator.countryMenuOptions.map { $0.title(languageCode: "en") }
        #expect(englishCountries.contains("United States"))
        #expect(!englishCountries.contains("美国"))

        let unitedStates = coordinator.countryMenuOptions.first { $0.countryCode == "US" }!
        coordinator.selectCountry(unitedStates, languageCode: "en")

        let englishCities = coordinator.cityMenuOptions.map { $0.title(languageCode: "en") }
        #expect(englishCities.contains("San Francisco"))
        #expect(!englishCities.contains("旧金山"))

        #expect(coordinator.countryDisplayName(languageCode: "es").contains("Estados"))

        let germany = coordinator.countryMenuOptions.first { $0.countryCode == "DE" }!
        coordinator.selectCountry(germany, languageCode: "de")
        let germanCities = coordinator.cityMenuOptions.map { $0.title(languageCode: "de") }
        #expect(germanCities.contains("München"))
        #expect(!germanCities.contains("Munich"))
    }

    @Test func authorizedNotificationsHideToggleState() async {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(defaults: defaults)
        let manager = FakeOnboardingNotificationManager(status: .authorized)

        await coordinator.refreshNotificationStatus(manager)

        #expect(coordinator.notificationPreferenceState == .enabled)
        #expect(coordinator.notificationIntent)
    }

    @Test func deniedNotificationsStayOffAndSurfaceSettingsGuidance() async {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(defaults: defaults)
        let manager = FakeOnboardingNotificationManager(status: .denied)

        await coordinator.requestNotificationPermission(manager)

        #expect(manager.requestCount == 0)
        #expect(!coordinator.notificationIntent)
        #expect(coordinator.notificationPreferenceState == .settingsRequired)
        #expect(coordinator.shouldShowNotificationSettings)
    }

    @Test func notificationToggleCanRequestPermissionWhenUndetermined() async {
        let defaults = makeDefaults()
        let coordinator = OnboardingPreferenceCoordinator(defaults: defaults)
        let manager = FakeOnboardingNotificationManager(status: .notDetermined, requestResult: true)

        await coordinator.requestNotificationPermission(manager)

        #expect(manager.requestCount == 1)
        #expect(coordinator.notificationPreferenceState == .enabled)
        #expect(coordinator.notificationIntent)
    }

    @Test func onboardingSourceStaysMinimalAndRequiresHumanProfileCreation() throws {
        let source = try projectSource("Ohana/Features/Onboarding/Views/OnboardingView.swift")

        #expect(!source.contains("植物经验"))
        #expect(!source.contains("主要场景"))
        #expect(!source.contains("Detect location"))
        #expect(!source.contains("Plants at home"))
        #expect(!source.contains("Care setup"))
        #expect(!source.contains("照护设置"))
        #expect(!source.contains("Location, reminders, home safety."))
        #expect(!source.contains("For local weather risk."))
        #expect(!source.contains("For care reminders."))
        #expect(!source.contains("For ingestion and placement risk."))
        #expect(!source.contains("Flags pet ingestion risk."))
        #expect(!source.contains("Flags child safety risk."))
        #expect(source.contains("Allow location"))
        #expect(source.contains("Allow notifications"))
        #expect(source.contains("onboarding-notification-off-row"))
        #expect(!source.contains("Skip identity"))
        #expect(!source.contains("暂时跳过"))
        #expect(!source.contains("Skip for now"))
        #expect(!source.contains("skipProfileSetup"))
        #expect(!source.contains("MemberCreationDraft(kind: .human)"))
        #expect(source.contains("startProfileSetup()"))
    }

    @Test func humanCreationUsesSharedInputAndOnboardingBackdrop() throws {
        let controls = try projectSource("Ohana/Features/Members/Views/MemberCardCreationContentView+Controls.swift")
        let steps = try projectSource("Ohana/Features/Members/Views/MemberCardCreationContentView+Steps.swift")
        let shell = try projectSource("Ohana/Features/Members/Views/MemberCardCreationView.swift")
        let layout = try projectSource("Ohana/Features/Members/Views/MemberCardCreationContentView+Layout.swift")

        #expect(controls.contains("func humanNameInput"))
        #expect(controls.contains("OhanaTextField("))
        #expect(steps.contains("humanNameInput(width: 148)"))
        #expect(shell.contains("presentationStyle != .onboarding && !usesTransparentHomeJoinHandoffBackdrop"))
        #expect(layout.contains("presentationStyle != .onboarding"))
        #expect(layout.contains("MemberCreationJoinHandoffCard(snapshot: joinHandoffSnapshot)"))
    }

    @Test func onboardingDoesNotAutoPresentFirstPetPromptAfterHumanProfile() throws {
        let content = try projectSource("Ohana/App/ContentView.swift")
        let snapshotBuilder = try projectSource("Ohana/Features/Home/VerticalSolidHomeSnapshotBuilder.swift")

        #expect(!content.contains("didAutoPresentFirstPetPrompt"))
        #expect(!content.contains("appRoutes.presentAddEntity(.pet)"))
        #expect(!snapshotBuilder.contains("Add your first pet"))
        #expect(snapshotBuilder.contains("firstPetEmptyState: nil"))
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "OhanaTests.OnboardingPreferenceCoordinator.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func projectSource(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}

private enum FakeOnboardingError: Error {
    case failed
}

private struct FakeOnboardingLocationResolver: OnboardingLocationResolving {
    let resolved: OnboardingResolvedLocation?

    init(resolved: OnboardingResolvedLocation? = nil) {
        self.resolved = resolved
    }

    func resolve(location: CLLocation) async throws -> OnboardingResolvedLocation {
        guard let resolved else {
            throw FakeOnboardingError.failed
        }
        return resolved
    }
}

@MainActor
private final class SilentOnboardingLocationProvider: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus
    var collectedLocations: [CLLocation] = []
    var totalDistance: Double = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy,
        completion: @escaping (Result<CLLocation, Error>) -> Void
    ) {}
}

@MainActor
private final class FakeOnboardingLocationProvider: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus
    var collectedLocations: [CLLocation] = []
    var totalDistance: Double = 0
    var result: Result<CLLocation, Error>

    init(authorizationStatus: CLAuthorizationStatus, result: Result<CLLocation, Error>) {
        self.authorizationStatus = authorizationStatus
        self.result = result
    }

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy,
        completion: @escaping (Result<CLLocation, Error>) -> Void
    ) {
        completion(result)
    }
}

@MainActor
private final class DeferredOnboardingLocationProvider: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus
    var collectedLocations: [CLLocation] = []
    var totalDistance: Double = 0
    private var completion: ((Result<CLLocation, Error>) -> Void)?

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy,
        completion: @escaping (Result<CLLocation, Error>) -> Void
    ) {
        self.completion = completion
    }

    func complete(_ result: Result<CLLocation, Error>) {
        completion?(result)
        completion = nil
    }
}

@MainActor
private final class FakeOnboardingNotificationManager: UserNotificationManaging {
    var status: UNAuthorizationStatus
    var requestResult: Bool
    var requestCount = 0

    init(status: UNAuthorizationStatus, requestResult: Bool = false) {
        self.status = status
        self.requestResult = requestResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestPermission() async -> Bool {
        requestCount += 1
        if requestResult {
            status = .authorized
        } else {
            status = .denied
        }
        return requestResult
    }

    func pendingNotificationIds() async -> Set<String> {
        []
    }
}
