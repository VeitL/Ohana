//
//  HumanAppleHealthBinding.swift
//  Ohana
//
//  Device-local ownership boundary for presenting Apple Health data on a
//  Human workout screen. This pointer is deliberately not part of backup DTOs.
//

import Foundation

nonisolated enum HumanAppleHealthBindingState: Equatable, Sendable {
    case unbound
    case boundToViewedHuman
    case boundToOtherHuman(UUID)
    case viewedHumanUnavailable

    var allowsLiveHealthRead: Bool {
        self == .boundToViewedHuman
    }
}

nonisolated enum HumanAppleHealthBindingPolicy {
    static func state(
        boundHumanID: UUID?,
        viewedHumanID: UUID,
        viewedHumanHasPassedAway: Bool
    ) -> HumanAppleHealthBindingState {
        guard !viewedHumanHasPassedAway else { return .viewedHumanUnavailable }
        guard let boundHumanID else { return .unbound }
        if boundHumanID == viewedHumanID {
            return .boundToViewedHuman
        }
        return .boundToOtherHuman(boundHumanID)
    }

    static func normalizedHumanID(from rawValue: String?) -> UUID? {
        guard let rawValue else { return nil }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

nonisolated enum HumanAppleHealthBindingStore {
    /// A device-local pointer only. `DataBackupManager` and its DTOs never read
    /// this key, so neither manual nor automatic Ohana backup exports it.
    static let storageKey = "humanAppleHealthBinding.v1"

    static func boundHumanID(defaults: UserDefaults = .standard) -> UUID? {
        let rawValue = defaults.string(forKey: storageKey)
        guard let humanID = HumanAppleHealthBindingPolicy.normalizedHumanID(from: rawValue) else {
            if rawValue != nil {
                defaults.removeObject(forKey: storageKey)
            }
            return nil
        }
        return humanID
    }

    @discardableResult
    static func bind(
        to humanID: UUID,
        humanHasPassedAway: Bool = false,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !humanHasPassedAway else { return false }
        defaults.set(humanID.uuidString, forKey: storageKey)
        return true
    }

    @discardableResult
    static func unbind(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: storageKey) != nil else { return false }
        defaults.removeObject(forKey: storageKey)
        return true
    }

    @discardableResult
    static func invalidateIfBound(
        to humanID: UUID,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard boundHumanID(defaults: defaults) == humanID else { return false }
        defaults.removeObject(forKey: storageKey)
        return true
    }
}
