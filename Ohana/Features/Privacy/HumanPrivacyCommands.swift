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

enum HumanPrivacyCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        let l = L10n.current
        switch self {
        case let .persistenceFailed(reason):
            let detail = reason.map { "\n\($0)" } ?? ""
            return l.tr(
                zh: "隐私设置保存失败，请稍后重试。\(detail)",
                en: "Could not save privacy settings. Try again.\(detail)",
                de: "Datenschutzeinstellungen konnten nicht gespeichert werden. Versuche es erneut.\(detail)"
            )
        }
    }
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
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            if !saveResult.didSave {
                context.rollback()
            }
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
        try savePrivacyChanges(context: context)
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
            try savePrivacyChanges(context: context)
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
            try savePrivacyChanges(context: context)
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
    ) throws -> HumanPrivacyCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else {
            return HumanPrivacyCommandResult(humanID: human.id, action: "privacy.field", changedFields: [])
        }
        let before = human.privateFields
        human.setPrivate(field, isPrivate)
        try savePrivacyChanges(context: context)
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
    ) throws -> HumanPrivacyCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else {
            return HumanPrivacyCommandResult(
                humanID: human.id,
                action: isPrivate ? "privacy.allPrivate" : "privacy.allPublic",
                changedFields: []
            )
        }
        let before = human.privateFields
        for field in HumanPrivateField.allCases {
            human.setPrivate(field, isPrivate)
        }
        try savePrivacyChanges(context: context)
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: isPrivate ? "privacy.allPrivate" : "privacy.allPublic",
            changedFields: before.symmetricDifference(human.privateFields)
        )
    }

    private static func shouldSaveVerificationResult(_ result: HumanPasscodeVerification) -> Bool {
        switch result {
        case .success, .incorrect, .locked:
            true
        case .invalidFormat, .noPasscode, .memberInactive:
            false
        }
    }

    @MainActor
    private static func savePrivacyChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw HumanPrivacyCommandError.persistenceFailed(saveResult.errorDescription)
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
    ) throws -> HumanPrivacyCommandResult {
        let result = try HumanPrivacyCommandService.setPrivateField(
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
    ) throws -> HumanPrivacyCommandResult {
        let result = try HumanPrivacyCommandService.setAllPrivateFields(
            isPrivate: isPrivate,
            for: human,
            context: context
        )
        revisions.publishHumanPrivacy(result, note: note)
        return result
    }
}
