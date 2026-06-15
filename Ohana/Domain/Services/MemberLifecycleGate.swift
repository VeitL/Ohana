//
//  MemberLifecycleGate.swift
//  Ohana
//
//  Central member lifecycle write decisions.
//

import Foundation

enum MemberWriteKind: Equatable {
    case care
    case memorial
    case profileEdit
    case lifecycle(MemberLifecycleAction)
}

enum MemberLifecycleAction: Equatable {
    case markPassedAway
    case undoPassedAway
    case clearActivityRecords
}

enum MemberWriteDenialReason: Equatable {
    case memberPassedAway
    case unsupportedWriteKind
}

struct MemberWriteAllowance: Equatable {
    let writeKind: MemberWriteKind
    let allowsContentWrite: Bool
    let allowsCareFactWrite: Bool
    let allowsDerivedEffects: Bool
    let allowsEconomyDerivation: Bool
    let allowsRevisionPublish: Bool
}

enum MemberWriteDisposition: Equatable {
    case allow(MemberWriteAllowance)
    case deny(MemberWriteDenialReason)

    static let activeWritable = MemberWriteDisposition.allow(
        MemberWriteAllowance(
            writeKind: .care,
            allowsContentWrite: true,
            allowsCareFactWrite: true,
            allowsDerivedEffects: true,
            allowsEconomyDerivation: true,
            allowsRevisionPublish: true
        )
    )

    static let memorialContentOnly = MemberWriteDisposition.allow(
        MemberWriteAllowance(
            writeKind: .memorial,
            allowsContentWrite: true,
            allowsCareFactWrite: false,
            allowsDerivedEffects: false,
            allowsEconomyDerivation: false,
            allowsRevisionPublish: true
        )
    )

    static let noOp = MemberWriteDisposition.deny(.memberPassedAway)

    nonisolated var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }

    nonisolated var writesContent: Bool {
        allowance?.allowsContentWrite == true
    }

    nonisolated var allowsCareFactWrite: Bool {
        allowance?.allowsCareFactWrite == true
    }

    nonisolated var allowsDerivedEffects: Bool {
        allowance?.allowsDerivedEffects == true
    }

    nonisolated var allowsEconomyDerivation: Bool {
        allowance?.allowsEconomyDerivation == true
    }

    nonisolated var allowsRevisionPublish: Bool {
        allowance?.allowsRevisionPublish == true
    }

    nonisolated var denialReason: MemberWriteDenialReason? {
        if case let .deny(reason) = self { return reason }
        return nil
    }

    private nonisolated var allowance: MemberWriteAllowance? {
        if case let .allow(allowance) = self { return allowance }
        return nil
    }
}

enum MemberLifecycleGate {
    nonisolated static func disposition(pet: Pet, writeKind: MemberWriteKind) -> MemberWriteDisposition {
        disposition(hasPassedAway: pet.hasPassedAway, writeKind: writeKind)
    }

    nonisolated static func disposition(human: Human, writeKind: MemberWriteKind) -> MemberWriteDisposition {
        disposition(hasPassedAway: human.hasPassedAway, writeKind: writeKind)
    }

    private nonisolated static func disposition(
        hasPassedAway: Bool,
        writeKind: MemberWriteKind
    ) -> MemberWriteDisposition {
        switch writeKind {
        case .care:
            guard !hasPassedAway else { return .deny(.memberPassedAway) }
            return .allow(
                MemberWriteAllowance(
                    writeKind: writeKind,
                    allowsContentWrite: true,
                    allowsCareFactWrite: true,
                    allowsDerivedEffects: true,
                    allowsEconomyDerivation: true,
                    allowsRevisionPublish: true
                )
            )
        case .memorial:
            return .allow(
                MemberWriteAllowance(
                    writeKind: writeKind,
                    allowsContentWrite: true,
                    allowsCareFactWrite: false,
                    allowsDerivedEffects: false,
                    allowsEconomyDerivation: false,
                    allowsRevisionPublish: true
                )
            )
        case .profileEdit:
            guard !hasPassedAway else { return .deny(.memberPassedAway) }
            return .allow(
                MemberWriteAllowance(
                    writeKind: writeKind,
                    allowsContentWrite: true,
                    allowsCareFactWrite: false,
                    allowsDerivedEffects: false,
                    allowsEconomyDerivation: false,
                    allowsRevisionPublish: true
                )
            )
        case let .lifecycle(action):
            if case .clearActivityRecords = action, hasPassedAway {
                return .deny(.memberPassedAway)
            }
            return .allow(
                MemberWriteAllowance(
                    writeKind: writeKind,
                    allowsContentWrite: true,
                    allowsCareFactWrite: false,
                    allowsDerivedEffects: false,
                    allowsEconomyDerivation: false,
                    allowsRevisionPublish: true
                )
            )
        }
    }
}

enum MemberWriteIntent: Equatable {
    case activeOnly
    case memorialContent

    var writeKind: MemberWriteKind {
        switch self {
        case .activeOnly:
            .care
        case .memorialContent:
            .memorial
        }
    }
}

enum MemberWritePolicy {
    static func disposition(pet: Pet, intent: MemberWriteIntent) -> MemberWriteDisposition {
        MemberLifecycleGate.disposition(pet: pet, writeKind: intent.writeKind)
    }

    static func disposition(human: Human, intent: MemberWriteIntent) -> MemberWriteDisposition {
        MemberLifecycleGate.disposition(human: human, writeKind: intent.writeKind)
    }
}
