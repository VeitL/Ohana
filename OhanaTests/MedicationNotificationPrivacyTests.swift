import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Ohana

@MainActor
@Suite(.serialized)
struct MedicationNotificationPrivacyTests {
    @Test func petPlansFollowCalendarFrequencyAndBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 0)))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 7)))
        let service = MedicationReminderService(notificationCenter: FakeMedicationNotificationCenter(requests: []))

        for (frequency, expectedCount) in [
            (PetMedicationFrequency.daily, 14),
            (.weekly, 2),
            (.everyOtherDay, 7),
            (.asNeeded, 0)
        ] {
            let container = try makeContainer()
            let context = container.mainContext
            let pet = Pet(name: "Momo", species: "dog")
            let medication = PetMedication(name: "Apoquel", frequency: frequency, startDate: start, pet: pet)
            context.insert(pet)
            context.insert(medication)
            try context.save()

            let plans = service.petNotificationPlans(for: pet, hidesDetails: true, now: now, calendar: calendar)
                .filter { $0.medicationID == medication.id.uuidString }
            #expect(plans.count == expectedCount)
            #expect(plans.allSatisfy {
                PetMedicationDoseLogging.requiredDoses(on: $0.scheduledAt, for: medication, calendar: calendar) > 0
            })
            #expect(plans.allSatisfy { $0.scheduledAt >= medication.startDate })
        }

        let boundedContainer = try makeContainer()
        let boundedContext = boundedContainer.mainContext
        let boundedPet = Pet(name: "Momo", species: "dog")
        let endDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 0)))
        let boundedMedication = PetMedication(
            name: "Apoquel",
            frequency: .daily,
            startDate: start,
            endDate: endDay,
            pet: boundedPet
        )
        boundedContext.insert(boundedPet)
        boundedContext.insert(boundedMedication)
        try boundedContext.save()
        let boundedPlans = service.petNotificationPlans(for: boundedPet, hidesDetails: true, now: now, calendar: calendar)
            .filter { $0.medicationID == boundedMedication.id.uuidString }
        #expect(boundedPlans.count == 3)
        #expect(boundedPlans.allSatisfy { calendar.startOfDay(for: $0.scheduledAt) <= endDay })
    }

    @Test func medicationDashboardReadsPersistedDoseEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog")
        let medication = PetMedication(name: "Apoquel", frequency: .daily, pet: pet)
        let event = Event(
            title: "Dose",
            startDate: Date(),
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationDose,
            relatedEntityId: medication.id.uuidString
        )
        context.insert(pet)
        context.insert(medication)
        context.insert(event)
        try context.save()

        let routeData = IslandMedicationRouteData.load(from: context)
        #expect(routeData.todayDoseCounts[medication.id] == 1)
    }

    @Test func legacyPreferenceKeyDrivesGlobalMedicationPrivacyPolicy() throws {
        let suiteName = "MedicationNotificationPrivacyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let rawLegacyKey = "privacy_hide_pet_medication_notification_details"
        defaults.set(true, forKey: rawLegacyKey)

        #expect(MedicationNotificationPrivacyStore.hideDetailsKey == rawLegacyKey)
        #expect(MedicationNotificationPrivacyStore.hidePetDetailsKey == rawLegacyKey)
        #expect(MedicationNotificationPrivacyStore.hidesMedicationDetails(defaults: defaults))
        #expect(MedicationNotificationPrivacyStore.hidesPetMedicationDetails(defaults: defaults))

        let detailed = "Alex · Thyroid medicine · 50 mcg"
        let generic = "Open Ohana to view medication details."
        #expect(MedicationNotificationContentPolicy.hidesHumanDetails(
            globalPreference: true,
            memberMedicationIsPrivate: false
        ))
        #expect(MedicationNotificationContentPolicy.hidesHumanDetails(
            globalPreference: false,
            memberMedicationIsPrivate: true
        ))
        #expect(!MedicationNotificationContentPolicy.hidesHumanDetails(
            globalPreference: false,
            memberMedicationIsPrivate: false
        ))
        #expect(MedicationNotificationContentPolicy.body(
            hidesDetails: true,
            generic: generic,
            detailed: detailed
        ) == generic)
    }

    @Test func hiddenRefreshRemovesOldRequestsBeforeRebuildingPetAndHumanBodies() async throws {
        let fixture = try makeRefreshFixture()
        let center = FakeMedicationNotificationCenter(requests: [
            pendingRequest(
                identifier: "medreminder_\(fixture.petID.uuidString)_old",
                body: "Momo · Apoquel · 1 tablet"
            ),
            pendingRequest(
                identifier: "humanmedreminder_\(fixture.humanID.uuidString)_old",
                body: "Levothyroxine · 50 mcg"
            ),
            pendingRequest(identifier: "unrelated-reminder", body: "Keep me")
        ])
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let service = MedicationReminderService(
            notificationCenter: center,
            privacyDefaults: defaults
        )

        let result = await fixture.refresh(using: service, hidingDetails: true)

        #expect(result.didSucceed)
        #expect(result.replacedNotificationCount == 2)
        #expect(result.scheduledNotificationCount > 0)
        #expect(!result.didFailSafeCancel)
        let firstRemoval = try #require(center.operations.firstIndex(where: { $0.hasPrefix("remove:") }))
        let firstAdd = try #require(center.operations.firstIndex(where: { $0.hasPrefix("add:") }))
        #expect(firstRemoval < firstAdd)
        #expect(center.requests["unrelated-reminder"]?.content.body == "Keep me")

        let medicationIDs = MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(center.requests.keys)
        )
        #expect(!medicationIDs.isEmpty)
        let medicationBodies = medicationIDs.compactMap { center.requests[$0]?.content.body }
        #expect(medicationBodies.count == medicationIDs.count)
        #expect(medicationBodies.allSatisfy { body in
            fixture.sensitiveDetails.allSatisfy { !body.contains($0) }
        })
        #expect(medicationIDs.allSatisfy { identifier in
            guard let content = center.requests[identifier]?.content else { return false }
            return MedicationNotificationPrivacyMarker.isCurrent(content, hidesDetails: true)
        })
        #expect(MedicationNotificationRefreshScopeStore.load(defaults: defaults) == nil)
    }

    @Test func hiddenRefreshRemovesDeliveredDetailedMedicationNotificationsBeforeRebuilding() async throws {
        let fixture = try makeRefreshFixture()
        let deliveredMedicationRequests = [
            pendingRequest(
                identifier: "medreminder_\(fixture.petID.uuidString)_delivered",
                body: "Momo · Apoquel · 1 tablet"
            ),
            pendingRequest(
                identifier: "humanmedreminder_\(fixture.humanID.uuidString)_delivered",
                body: "Levothyroxine · 50 mcg"
            )
        ]
        let center = FakeMedicationNotificationCenter(
            requests: [pendingRequest(identifier: "unrelated-pending", body: "Keep pending")],
            deliveredRequests: deliveredMedicationRequests + [
                pendingRequest(identifier: "unrelated-delivered", body: "Keep delivered")
            ]
        )
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let service = MedicationReminderService(
            notificationCenter: center,
            privacyDefaults: defaults
        )

        let result = await fixture.refresh(using: service, hidingDetails: true)

        #expect(result.didSucceed)
        #expect(result.replacedNotificationCount == 2)
        #expect(result.scheduledNotificationCount > 0)
        #expect(center.deliveredRequestsByID["unrelated-delivered"]?.content.body == "Keep delivered")
        #expect(deliveredMedicationRequests.allSatisfy {
            center.deliveredRequestsByID[$0.identifier] == nil
        })
        let deliveredRemoval = try #require(center.operations.firstIndex(where: {
            $0.hasPrefix("removeDelivered:")
        }))
        let firstAdd = try #require(center.operations.firstIndex(where: { $0.hasPrefix("add:") }))
        #expect(deliveredRemoval < firstAdd)
    }

    @Test func startupRecoveryFindsAndRemovesDeliveredOnlyStaleMedicationDetails() async throws {
        let fixture = try makeRefreshFixture()
        let delivered = pendingRequest(
            identifier: "humanmedreminder_\(fixture.humanID.uuidString)_delivered",
            body: "Levothyroxine · 50 mcg",
            hidesDetailsMarker: false
        )
        let center = FakeMedicationNotificationCenter(
            requests: [],
            deliveredRequests: [delivered]
        )
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: MedicationNotificationPrivacyStore.hideDetailsKey)
        let service = MedicationReminderService(
            notificationCenter: center,
            privacyDefaults: defaults
        )

        let result = await service.recoverMedicationNotificationPrivacyIfNeeded(
            context: fixture.container.mainContext
        )

        #expect(result.didSucceed)
        #expect(result.replacedNotificationCount == 1)
        #expect(center.deliveredRequestsByID[delivered.identifier] == nil)
        let medicationIDs = MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(center.requests.keys)
        )
        #expect(!medicationIDs.isEmpty)
        #expect(medicationIDs.allSatisfy { identifier in
            guard let content = center.requests[identifier]?.content else { return false }
            return MedicationNotificationPrivacyMarker.isCurrent(content, hidesDetails: true)
                && fixture.sensitiveDetails.allSatisfy { !content.body.contains($0) }
        })
    }

    @Test func hiddenRefreshGloballySortsAndCapsMoreThanManagedCapacityWithoutFailSafeCancellation() async throws {
        let fixture = try makeRefreshFixture()
        let context = fixture.container.mainContext
        for index in 0 ..< 4 {
            context.insert(HumanMedication(
                humanId: fixture.humanID.uuidString,
                name: "Additional medication \(index)",
                dosage: "1 tablet",
                frequency: .daily,
                firstDoseTime: Date().addingTimeInterval(3600 + Double(index * 60)),
                startDate: Date().addingTimeInterval(-86400)
            ))
        }
        try context.save()

        let center = FakeMedicationNotificationCenter(requests: [
            pendingRequest(identifier: "medreminder_\(fixture.petID.uuidString)_old", body: "Sensitive pet body"),
            pendingRequest(identifier: "humanmedreminder_\(fixture.humanID.uuidString)_old", body: "Sensitive human body"),
            pendingRequest(identifier: "unrelated-reminder", body: "Keep me")
        ])
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let service = MedicationReminderService(notificationCenter: center, privacyDefaults: defaults)

        let result = await fixture.refresh(using: service, hidingDetails: true)
        let medicationIDs = MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(center.requests.keys)
        )

        #expect(result.didSucceed)
        #expect(!result.didFailSafeCancel)
        #expect(result.scheduledNotificationCount == NotificationPendingBudget.managedPendingRequestLimit - 1)
        #expect(center.requests.count == NotificationPendingBudget.managedPendingRequestLimit)
        #expect(medicationIDs.count == NotificationPendingBudget.managedPendingRequestLimit - 1)
        #expect(center.requests["unrelated-reminder"]?.content.body == "Keep me")
        #expect(medicationIDs.allSatisfy { identifier in
            guard let content = center.requests[identifier]?.content else { return false }
            return MedicationNotificationPrivacyMarker.isCurrent(content, hidesDetails: true)
        })
        #expect(MedicationNotificationRefreshScopeStore.load(defaults: defaults) != nil)
    }

    @Test func recoveryReplacesAStaleDetailedMarkerForMemberPrivateMedication() async throws {
        let fixture = try makeRefreshFixture()
        let context = fixture.container.mainContext
        let human = try #require(try context.fetch(FetchDescriptor<Human>()).first { $0.id == fixture.humanID })
        human.setPrivate(.medication, true)
        try context.save()

        let stale = pendingRequest(
            identifier: "humanmedreminder_\(fixture.humanID.uuidString)_old",
            body: "Levothyroxine · 50 mcg",
            hidesDetailsMarker: false
        )
        let center = FakeMedicationNotificationCenter(requests: [stale])
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let service = MedicationReminderService(notificationCenter: center, privacyDefaults: defaults)

        let result = await service.recoverMedicationNotificationPrivacyIfNeeded(context: context)
        let medicationRequests = center.requests.values.filter {
            MedicationNotificationIdentifierPolicy.isHumanReminder($0.identifier)
        }

        #expect(result.didSucceed)
        #expect(result.replacedNotificationCount == 1)
        #expect(!medicationRequests.isEmpty)
        #expect(medicationRequests.allSatisfy {
            MedicationNotificationPrivacyMarker.isCurrent($0.content, hidesDetails: true)
                && !$0.content.body.contains("Levothyroxine")
                && !$0.content.body.contains("50 mcg")
        })
    }

    @Test func hiddenRefreshAddFailurePerformsSecondFailSafeMedicationCancellation() async throws {
        let fixture = try makeRefreshFixture()
        let center = FakeMedicationNotificationCenter(
            requests: [
                pendingRequest(
                    identifier: "medreminder_\(fixture.petID.uuidString)_old",
                    body: "Momo · Apoquel · 1 tablet"
                ),
                pendingRequest(
                    identifier: "humanmedreminder_\(fixture.humanID.uuidString)_old",
                    body: "Levothyroxine · 50 mcg"
                ),
                pendingRequest(identifier: "unrelated-reminder", body: "Keep me")
            ],
            shouldFailAdd: { $0.hasPrefix("humanmedreminder_") }
        )
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let service = MedicationReminderService(
            notificationCenter: center,
            privacyDefaults: defaults
        )

        let result = await fixture.refresh(using: service, hidingDetails: true)

        #expect(!result.didSucceed)
        #expect(result.didFailSafeCancel)
        #expect(!result.failureDescriptions.isEmpty)
        #expect(center.operations.count(where: { $0.hasPrefix("remove:") }) >= 2)
        #expect(MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(center.requests.keys)
        ).isEmpty)
        #expect(center.requests["unrelated-reminder"]?.content.body == "Keep me")
    }

    @Test func hiddenRefreshRetryUsesSavedScopeAfterFailSafeCancellation() async throws {
        let fixture = try makeRefreshFixture()
        var rejectsHumanAdds = true
        let center = FakeMedicationNotificationCenter(
            requests: [
                pendingRequest(
                    identifier: "medreminder_\(fixture.petID.uuidString)_old",
                    body: "Momo · Apoquel · 1 tablet"
                ),
                pendingRequest(
                    identifier: "humanmedreminder_\(fixture.humanID.uuidString)_old",
                    body: "Levothyroxine · 50 mcg"
                )
            ],
            shouldFailAdd: { rejectsHumanAdds && $0.hasPrefix("humanmedreminder_") }
        )
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let service = MedicationReminderService(
            notificationCenter: center,
            privacyDefaults: defaults
        )

        let first = await fixture.refresh(using: service, hidingDetails: true)
        #expect(first.didFailSafeCancel)
        #expect(MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(center.requests.keys)
        ).isEmpty)
        #expect(MedicationNotificationRefreshScopeStore.load(defaults: defaults) != nil)

        rejectsHumanAdds = false
        let retry = await fixture.refresh(using: service, hidingDetails: true)

        #expect(retry.didSucceed)
        #expect(retry.scheduledNotificationCount > 0)
        #expect(!MedicationNotificationIdentifierPolicy.medicationNotificationIDs(
            in: Set(center.requests.keys)
        ).isEmpty)
        #expect(MedicationNotificationRefreshScopeStore.load(defaults: defaults) == nil)
    }

    @Test func successfulHumanDeletionFlushesMedicationPrefixCancellation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Delete me")
        context.insert(human)
        try context.save()
        let notifications = PrefixRecordingNotificationScheduler()
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let result = MemberDeletionCommandService.deleteHuman(
            human,
            activeHumanID: human.id.uuidString,
            context: context,
            userDefaults: defaults,
            notifications: notifications
        )

        #expect(result.didPersist)
        #expect(notifications.cancelledPrefixBatches == [[
            MedicationNotificationIdentifierPolicy.humanReminderPrefix(for: human.id)
        ]])
    }

    @Test func failedHumanDeletionDoesNotFlushMedicationPrefixCancellation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Keep me")
        context.insert(human)
        try context.save()
        let notifications = PrefixRecordingNotificationScheduler()
        let (defaultsName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let result = MemberDeletionCommandService.deleteHuman(
            human,
            activeHumanID: human.id.uuidString,
            context: context,
            userDefaults: defaults,
            notifications: notifications,
            saveChanges: { _ in
                .failed(NSError(domain: "MedicationNotificationPrivacyTests", code: 1))
            }
        )

        #expect(!result.didPersist)
        #expect(notifications.cancelledPrefixBatches.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Human>()).map(\.id) == [human.id])
    }

    @Test func everyMedicationPrivacyMutationPathInvalidatesThenRefreshesScheduledBodies() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Alex")
        context.insert(human)
        try context.save()
        let reminders = PrivacyMutationMedicationReminderSpy()
        let revisions = SharedDomainRevisionPublisher(center: ReadModelRevisionCenter())
        let privacyExecutor = HumanPrivacyCommandExecutor(
            context: context,
            revisions: revisions,
            medicationReminders: reminders
        )

        _ = try privacyExecutor.setPrivateField(
            .medication,
            isPrivate: true,
            for: human,
            note: "test.member.medication.private"
        )
        await waitForRefreshCount(1, reminders: reminders)

        _ = try privacyExecutor.setAllPrivateFields(
            isPrivate: false,
            for: human,
            note: "test.member.all.public"
        )
        await waitForRefreshCount(2, reminders: reminders)

        let memberExecutor = MemberCommandExecutor(
            context: context,
            revisions: revisions,
            questManager: QuestManager(),
            medicationReminders: reminders
        )
        let profileResult = memberExecutor.updateHumanProfile(
            human,
            input: HumanProfileCommandInput(
                name: human.name,
                avatarImageData: human.avatarImageData,
                avatarEmoji: human.avatarEmoji,
                role: human.role,
                gender: human.genderIdentityRaw ?? "",
                birthday: human.birthday,
                bloodType: human.bloodType,
                heightText: String(human.heightCm),
                mbti: human.mbti,
                nationality: human.nationality,
                city: human.city,
                themeHex: human.themeColorHex,
                notes: human.notes,
                preservedNoteParts: [],
                privateFieldsRaw: [HumanPrivateField.medication.rawValue]
            ),
            note: "test.member.profile.medication.private"
        )
        #expect(profileResult.didPersist)
        await waitForRefreshCount(3, reminders: reminders)

        #expect(reminders.invalidationCount == 3)
        #expect(reminders.refreshCount == 3)
    }

    private func makeRefreshFixture() throws -> RefreshFixture {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog")
        let petMedication = PetMedication(
            name: "Apoquel",
            dosage: "1 tablet",
            frequency: .daily,
            startDate: Date().addingTimeInterval(-86400),
            pet: pet
        )
        let human = Human(name: "Alex")
        let humanMedication = HumanMedication(
            humanId: human.id.uuidString.lowercased(),
            name: "Levothyroxine",
            dosage: "50 mcg",
            frequency: .daily,
            firstDoseTime: Date().addingTimeInterval(3600),
            startDate: Date().addingTimeInterval(-86400)
        )
        context.insert(pet)
        context.insert(petMedication)
        context.insert(human)
        context.insert(humanMedication)
        try context.save()
        return RefreshFixture(
            container: container,
            petID: pet.id,
            humanID: human.id,
            sensitiveDetails: [
                pet.name,
                petMedication.name,
                petMedication.dosage,
                human.name,
                humanMedication.name,
                humanMedication.dosage
            ]
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV97.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let suiteName = "MedicationNotificationPrivacyTests.Deletion.\(UUID().uuidString)"
        return (suiteName, try #require(UserDefaults(suiteName: suiteName)))
    }

    private func pendingRequest(
        identifier: String,
        body: String,
        hidesDetailsMarker: Bool? = nil
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = body
        if let hidesDetailsMarker {
            content.userInfo = MedicationNotificationPrivacyMarker.userInfo(
                hidesDetails: hidesDetailsMarker
            )
        }
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    private func waitForRefreshCount(
        _ expectedCount: Int,
        reminders: PrivacyMutationMedicationReminderSpy
    ) async {
        for _ in 0 ..< 20 where reminders.refreshCount < expectedCount {
            await Task.yield()
        }
        #expect(reminders.refreshCount == expectedCount)
    }
}

@MainActor
private struct RefreshFixture {
    let container: ModelContainer
    let petID: UUID
    let humanID: UUID
    let sensitiveDetails: [String]

    func refresh(
        using service: MedicationReminderService,
        hidingDetails: Bool
    ) async -> MedicationNotificationPrivacyRefreshResult {
        let result = await service.refreshScheduledMedicationReminders(
            context: container.mainContext,
            hidingDetails: hidingDetails
        )
        withExtendedLifetime(container) {}
        return result
    }
}

@MainActor
private final class FakeMedicationNotificationCenter: MedicationLocalNotificationCenterScheduling {
    enum AddFailure: Error {
        case rejected
    }

    private(set) var requests: [String: UNNotificationRequest]
    private(set) var deliveredRequestsByID: [String: UNNotificationRequest]
    private(set) var operations: [String] = []
    private let shouldFailAdd: (String) -> Bool

    init(
        requests: [UNNotificationRequest],
        deliveredRequests: [UNNotificationRequest] = [],
        shouldFailAdd: @escaping (String) -> Bool = { _ in false }
    ) {
        self.requests = Dictionary(uniqueKeysWithValues: requests.map { ($0.identifier, $0) })
        deliveredRequestsByID = Dictionary(
            uniqueKeysWithValues: deliveredRequests.map { ($0.identifier, $0) }
        )
        self.shouldFailAdd = shouldFailAdd
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        operations.append("pending")
        return requests.values.sorted { $0.identifier < $1.identifier }
    }

    func deliveredRequests() async -> [UNNotificationRequest] {
        operations.append("delivered")
        return deliveredRequestsByID.values.sorted { $0.identifier < $1.identifier }
    }

    func add(_ request: UNNotificationRequest) async throws {
        operations.append("add:\(request.identifier)")
        guard !shouldFailAdd(request.identifier) else { throw AddFailure.rejected }
        requests[request.identifier] = request
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        operations.append("remove:\(identifiers.sorted().joined(separator: ","))")
        for identifier in identifiers {
            requests.removeValue(forKey: identifier)
        }
    }

    func removeDeliveredRequests(withIdentifiers identifiers: [String]) {
        operations.append("removeDelivered:\(identifiers.sorted().joined(separator: ","))")
        for identifier in identifiers {
            deliveredRequestsByID.removeValue(forKey: identifier)
        }
    }
}

private final class PrefixRecordingNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var storedCancelledPrefixBatches: [[String]] = []

    var cancelledPrefixBatches: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storedCancelledPrefixBatches
    }

    func schedule(reminder _: Reminder) {}

    func schedule(
        reminder _: Reminder,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.scheduled)
    }

    func schedule(
        reminder _: Reminder,
        deliveryDate _: Date?,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.scheduled)
    }

    func pendingNotificationIds() async -> Set<String> { [] }
    func scheduleRollingWindow(reminders _: [Reminder]) {}
    func refillWindowIfNeeded(allReminders _: [Reminder]) {}
    func cancel(notificationId _: String) {}
    func cancelPendingNotifications(withPrefixes prefixes: [String]) {
        lock.lock()
        storedCancelledPrefixBatches.append(prefixes)
        lock.unlock()
    }
    func cancelAll(for _: Pet, reminders _: [Reminder]) {}
    func compensate(reminders _: [Reminder]) {}
}

@MainActor
private final class PrivacyMutationMedicationReminderSpy: MedicationReminderManaging {
    private(set) var invalidationCount = 0
    private(set) var refreshCount = 0

    func dosesTakenToday(for _: UUID) -> Int { 0 }
    func recordDose(for _: UUID) {}
    func undoDose(for _: UUID) {}
    func scheduleMedicationReminders(for _: Pet, context _: ModelContext?) {}
    func scheduleHumanMedicationReminders(for _: Human, meds _: [HumanMedication], context _: ModelContext?) {}

    func invalidateNotificationMutations() {
        invalidationCount += 1
    }

    func refreshScheduledMedicationReminders(
        context _: ModelContext,
        hidingDetails _: Bool
    ) async -> MedicationNotificationPrivacyRefreshResult {
        refreshCount += 1
        return MedicationNotificationPrivacyRefreshResult(
            replacedNotificationCount: 0,
            scheduledNotificationCount: 0,
            didFailSafeCancel: false,
            failureDescriptions: []
        )
    }
}
