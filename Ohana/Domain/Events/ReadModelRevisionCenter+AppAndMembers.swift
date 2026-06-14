//
//  ReadModelRevisionCenter+AppAndMembers.swift
//  Ohana
//
//  Revision publishing helpers for app, settings, privacy, and member flows.
//

import Foundation

extension ReadModelRevisionCenter {
    func publishMemberDeletion(_ result: MemberDeletionCommandResult, note: String) {
        var affected = Set(result.removedRelatedEventIDs)
        affected.insert(result.entityID)
        publish(
            DomainMutationResult(
                command: .memberDeletion(entityID: result.entityID, kind: result.kind),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberProfile(_ result: MemberProfileCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberProfile(entityID: result.entityID, kind: result.kind),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberProfileChange(entityID: UUID, kind: String, note: String) {
        publish(
            DomainMutationResult(
                command: .memberProfile(entityID: entityID, kind: kind),
                affectedEntityIDs: [entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberHomeVisibility(_ result: MemberHomeVisibilityCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberHomeVisibility(
                    entityID: result.entityID,
                    kind: result.kind,
                    visible: result.visible
                ),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberLifecycle(_ result: MemberLifecycleCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberLifecycle(
                    entityID: result.entityID,
                    kind: result.kind,
                    action: result.action
                ),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishSettingsActiveHumanSwitch(_ result: SettingsActiveHumanSwitchCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .settingsActiveHumanSwitch(humanID: result.humanID),
                affectedEntityIDs: [result.humanID],
                wroteBusinessFact: result.didSyncHomeStack,
                note: note
            )
        )
    }

    func publishSettingsCoconutBalance(_ result: SettingsCoconutBalanceCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .settingsCoconutBalance(humanID: result.humanID, amount: result.amount),
                affectedEntityIDs: Set(result.humanID.map { [$0] } ?? []),
                wroteBusinessFact: false,
                note: note
            )
        )
    }

    func publishHumanPrivacy(_ result: HumanPrivacyCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanPrivacy(humanID: result.humanID, action: result.action),
                affectedEntityIDs: [result.humanID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberCreation(_ result: PlantCreationCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberCreation(entityID: result.plantID, kind: result.kind),
                affectedEntityIDs: [result.plantID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberCreation(entityID: UUID, kind: String, note: String) {
        publish(
            DomainMutationResult(
                command: .memberCreation(entityID: entityID, kind: kind),
                affectedEntityIDs: [entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetCardAppearance(_ result: PetCardAppearanceCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petCardAppearance(petID: result.petID, action: result.action),
                affectedEntityIDs: [result.petID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishAvatar2DUpgrade(_ result: Avatar2DUpgradeCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .avatar2DUpgrade(entityID: result.entityID, kind: result.kind),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: result.didUpgrade,
                note: note
            )
        )
    }
}
