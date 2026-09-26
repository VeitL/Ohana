import Testing
@testable import Ohana

struct OhanaPlanCapabilitiesTests {
    @Test func personalAndFamilyComposeCapabilitiesWithoutChangingRewards() {
        #expect(!OhanaPlanLevel.free.hasPersonal)
        #expect(OhanaPlanLevel.personal.hasPersonal)
        #expect(OhanaPlanLevel.family.hasPersonal)
        #expect(OhanaPlanLevel.family.hasFamily)
        #expect(!OhanaPlanLevel.personal.hasFamily)
    }

    @Test func presenceCapabilityMatrixMatchesTheApprovedContract() {
        let free = OhanaPlanCapabilities.make(for: .free)
        let personal = OhanaPlanCapabilities.make(for: .personal)
        let family = OhanaPlanCapabilities.make(for: .family)

        #expect(free.analytics == .rawCalendar)
        #expect(free.contacts.maximumLocalContacts == 0)
        #expect(!free.contacts.allowsEditableMessageTemplate)
        #expect(free.contacts.maximumAcceptedGuardians == 0)
        #expect(free.reminders.maximumScheduleCount == 1)
        #expect(!free.reminders.allowsGracePeriod)

        #expect(personal.analytics == .longRange)
        #expect(personal.contacts.maximumLocalContacts == 0)
        #expect(!personal.contacts.allowsEditableMessageTemplate)
        #expect(personal.contacts.maximumAcceptedGuardians == 0)
        #expect(personal.reminders.allowsWeekdaySchedules)
        #expect(personal.reminders.allowsSecondLocalReminder)
        #expect(!personal.reminders.allowsServerGuardianEscalation)

        #expect(family.analytics == .familyAudit)
        #expect(family.reminders.allowsServerGuardianEscalation)
        #expect(family.contacts.allowsAcceptedFamilyGuardians)
        #expect(family.contacts.maximumAcceptedGuardians == 3)
        #expect(!family.contacts.allowsAutomaticExternalMessaging)
    }

    @Test func personalGraceRangeIsLockedToFifteenThroughOneHundredEightyMinutes() {
        #expect(PresenceReminderCapabilities.gracePeriodMinutes.lowerBound == 15)
        #expect(PresenceReminderCapabilities.gracePeriodMinutes.upperBound == 180)
    }
}
