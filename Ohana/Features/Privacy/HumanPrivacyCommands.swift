//
//  HumanPrivacyCommands.swift
//  Ohana
//
//  Domain write boundaries for human account privacy.
//

import Foundation
import SwiftData

struct HumanPrivacyCommandResult: Equatable {
    let humanID: UUID
    let action: String
    let changedFields: Set<String>
}

enum HumanPrivacyCommandService {
    @discardableResult
    @MainActor
    static func verifyPasscode(
        _ pin: String,
        for human: Human,
        now: Date,
        context: ModelContext
    ) -> HumanPasscodeVerification {
        let result = HumanPasscodeService.verify(pin, for: human, now: now)
        if shouldSaveVerificationResult(result) {
            context.safeSave()
        }
        return result
    }

    @discardableResult
    @MainActor
    static func setPasscode(
        _ pin: String,
        for human: Human,
        context: ModelContext
    ) throws -> HumanPrivacyCommandResult {
        try HumanPasscodeService.setPasscode(pin, for: human)
        context.safeSave()
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: "passcode.set",
            changedFields: ["pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"]
        )
    }

    @discardableResult
    @MainActor
    static func changePasscode(
        currentPin: String,
        newPin: String,
        for human: Human,
        now: Date = Date(),
        context: ModelContext
    ) throws -> HumanPasscodeVerification {
        let result = try HumanPasscodeService.changePasscode(
            currentPin: currentPin,
            newPin: newPin,
            for: human,
            now: now
        )
        if shouldSaveVerificationResult(result) {
            context.safeSave()
        }
        return result
    }

    @discardableResult
    @MainActor
    static func removePasscode(
        currentPin: String,
        for human: Human,
        now: Date = Date(),
        context: ModelContext
    ) throws -> HumanPasscodeVerification {
        let result = try HumanPasscodeService.removePasscode(currentPin: currentPin, for: human, now: now)
        if shouldSaveVerificationResult(result) {
            context.safeSave()
        }
        return result
    }

    @discardableResult
    @MainActor
    static func setPrivateField(
        _ field: HumanPrivateField,
        isPrivate: Bool,
        for human: Human,
        context: ModelContext
    ) -> HumanPrivacyCommandResult {
        let before = human.privateFields
        human.setPrivate(field, isPrivate)
        context.safeSave()
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: "privacy.field",
            changedFields: before.symmetricDifference(human.privateFields)
        )
    }

    @discardableResult
    @MainActor
    static func setAllPrivateFields(
        isPrivate: Bool,
        for human: Human,
        context: ModelContext
    ) -> HumanPrivacyCommandResult {
        let before = human.privateFields
        for field in HumanPrivateField.allCases {
            human.setPrivate(field, isPrivate)
        }
        context.safeSave()
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: isPrivate ? "privacy.allPrivate" : "privacy.allPublic",
            changedFields: before.symmetricDifference(human.privateFields)
        )
    }

    private static func shouldSaveVerificationResult(_ result: HumanPasscodeVerification) -> Bool {
        switch result {
        case .success, .incorrect, .locked:
            return true
        case .invalidFormat, .noPasscode:
            return false
        }
    }
}

@MainActor
struct HumanPrivacyCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func verifyPasscode(_ pin: String, for human: Human, now: Date) -> HumanPasscodeVerification {
        HumanPrivacyCommandService.verifyPasscode(pin, for: human, now: now, context: context)
    }

    @discardableResult
    func setPasscode(_ pin: String, for human: Human, note: String) throws -> HumanPrivacyCommandResult {
        let result = try HumanPrivacyCommandService.setPasscode(pin, for: human, context: context)
        revisions.publishHumanPrivacy(result, note: note)
        return result
    }

    @discardableResult
    func changePasscode(
        currentPin: String,
        newPin: String,
        for human: Human,
        now: Date = Date(),
        note: String
    ) throws -> HumanPasscodeVerification {
        let verification = try HumanPrivacyCommandService.changePasscode(
            currentPin: currentPin,
            newPin: newPin,
            for: human,
            now: now,
            context: context
        )
        if verification == .success {
            revisions.publishHumanPrivacy(
                HumanPrivacyCommandResult(
                    humanID: human.id,
                    action: "passcode.change",
                    changedFields: ["pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"]
                ),
                note: note
            )
        }
        return verification
    }

    @discardableResult
    func removePasscode(
        currentPin: String,
        for human: Human,
        now: Date = Date(),
        note: String
    ) throws -> HumanPasscodeVerification {
        let verification = try HumanPrivacyCommandService.removePasscode(
            currentPin: currentPin,
            for: human,
            now: now,
            context: context
        )
        if verification == .success {
            revisions.publishHumanPrivacy(
                HumanPrivacyCommandResult(
                    humanID: human.id,
                    action: "passcode.remove",
                    changedFields: ["pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"]
                ),
                note: note
            )
        }
        return verification
    }

    @discardableResult
    func setPrivateField(
        _ field: HumanPrivateField,
        isPrivate: Bool,
        for human: Human,
        note: String
    ) -> HumanPrivacyCommandResult {
        let result = HumanPrivacyCommandService.setPrivateField(
            field,
            isPrivate: isPrivate,
            for: human,
            context: context
        )
        revisions.publishHumanPrivacy(result, note: note)
        return result
    }

    @discardableResult
    func setAllPrivateFields(
        isPrivate: Bool,
        for human: Human,
        note: String
    ) -> HumanPrivacyCommandResult {
        let result = HumanPrivacyCommandService.setAllPrivateFields(
            isPrivate: isPrivate,
            for: human,
            context: context
        )
        revisions.publishHumanPrivacy(result, note: note)
        return result
    }
}
