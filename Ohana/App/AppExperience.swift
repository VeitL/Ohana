//
//  AppExperience.swift
//  Ohana
//
//  Root-owned selection between the full and intentionally minimal app shells.
//

import Foundation
import Observation

nonisolated enum AppExperienceMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case standard
    case zen

    static let storageKey = "ohana_app_experience_mode.v1"
    static let zenIntroductionSeenKey = "ohana_zen_introduction_seen.v1"
    static let zenIntroductionEligibleKey = "ohana_zen_introduction_eligible.v1"
    // Shared with PresenceCheckInCommandService's owner selector. Keep the
    // literal here so static initialization cannot recurse across the two
    // types while still leaving exactly one local owner identity.
    static let zenOwnerHumanIDKey = "presence.ownerHumanId"
    static let zenOwnerNeedsRebindKey = "presence.ownerNeedsRebind"

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .standard:
            l.tr(zh: "普通模式", en: "Standard", de: "Standard", es: "Estándar", pt: "Padrão", fr: "Standard", ja: "通常モード", ko: "일반 모드", it: "Standard")
        case .zen:
            l.tr(zh: "佛系模式", en: "Zen", de: "Zen", es: "Zen", pt: "Zen", fr: "Zen", ja: "佛系モード", ko: "마음 편한 모드", it: "Zen")
        }
    }

    func subtitle(_ l: L10n) -> String {
        switch self {
        case .standard:
            l.tr(
                zh: "完整的成员、照护、记录与家庭功能",
                en: "Full members, care, records, and household tools",
                de: "Alle Mitglieder-, Pflege-, Verlaufs- und Haushaltsfunktionen",
                es: "Miembros, cuidados, registros y hogar completos",
                pt: "Membros, cuidados, registros e casa completos",
                fr: "Membres, soins, suivis et foyer au complet",
                ja: "メンバー、ケア、記録、家族機能をすべて利用",
                ko: "구성원, 돌봄, 기록과 가족 기능 전체",
                it: "Membri, cure, registri e strumenti per la famiglia"
            )
        case .zen:
            l.tr(
                zh: "只保留首页打卡、连续记录与 Oasis",
                en: "Only check-ins, streaks, and Oasis",
                de: "Nur Check-ins, Serien und Oasis",
                es: "Solo check-ins, rachas y Oasis",
                pt: "Somente check-ins, sequências e Oasis",
                fr: "Seulement les check-ins, les séries et Oasis",
                ja: "チェックイン、連続記録、Oasisだけ",
                ko: "체크인, 연속 기록과 Oasis만",
                it: "Solo check-in, serie e Oasis"
            )
        }
    }
}

nonisolated struct AppExperienceHumanChoice: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let createdAt: Date
}

nonisolated enum ZenOwnerBindingState: Equatable, Sendable {
    case unresolved
    case ready(UUID)
    case requiresSelection([AppExperienceHumanChoice])
    case unavailable
}

@MainActor
@Observable
final class AppExperienceController {
    private(set) var mode: AppExperienceMode
    private(set) var requiresInitialSelection: Bool
    private(set) var shellIdentity = UUID()
    private(set) var pendingMode: AppExperienceMode?
    private(set) var shouldOfferZenIntroduction: Bool
    private(set) var zenOwnerHumanID: String
    private(set) var zenOwnerBindingState: ZenOwnerBindingState = .unresolved

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var pendingSwitchTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        hasCompletedOnboarding: Bool? = nil
    ) {
        self.defaults = defaults
        let onboardingComplete = hasCompletedOnboarding
            ?? defaults.bool(forKey: "ohana_has_onboarded")

        if let rawMode = defaults.string(forKey: AppExperienceMode.storageKey),
           let storedMode = AppExperienceMode(rawValue: rawMode) {
            mode = storedMode
            requiresInitialSelection = false
            shouldOfferZenIntroduction = defaults.bool(forKey: AppExperienceMode.zenIntroductionEligibleKey)
                && !defaults.bool(forKey: AppExperienceMode.zenIntroductionSeenKey)
        } else {
            // Existing users must never be blocked by a newly introduced
            // preference. A genuinely fresh install chooses before creating
            // its first Human.
            mode = .standard
            requiresInitialSelection = !onboardingComplete
            shouldOfferZenIntroduction = onboardingComplete
                && !defaults.bool(forKey: AppExperienceMode.zenIntroductionSeenKey)
            if onboardingComplete {
                defaults.set(AppExperienceMode.standard.rawValue, forKey: AppExperienceMode.storageKey)
                defaults.set(true, forKey: AppExperienceMode.zenIntroductionEligibleKey)
            }
        }
        zenOwnerHumanID = defaults.string(forKey: AppExperienceMode.zenOwnerHumanIDKey) ?? ""
    }

    func selectInitialMode(_ selectedMode: AppExperienceMode) {
        pendingSwitchTask?.cancel()
        pendingSwitchTask = nil
        apply(selectedMode)
        requiresInitialSelection = false
    }

    /// Settings first dismisses its route, then asks the long-lived root to
    /// rebuild the selected shell. The delay keeps route teardown ahead of
    /// persistence and heavier feature startup.
    func switchAfterRouteDismissal(
        to selectedMode: AppExperienceMode,
        delayMilliseconds: UInt64 = 220
    ) {
        guard selectedMode != mode else { return }
        pendingSwitchTask?.cancel()
        pendingMode = selectedMode
        pendingSwitchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            apply(selectedMode)
            pendingSwitchTask = nil
        }
    }

    func prepareForFreshOnboardingAfterReset() {
        pendingSwitchTask?.cancel()
        pendingSwitchTask = nil
        pendingMode = nil
        defaults.removeObject(forKey: AppExperienceMode.storageKey)
        defaults.removeObject(forKey: AppExperienceMode.zenOwnerHumanIDKey)
        defaults.removeObject(forKey: AppExperienceMode.zenOwnerNeedsRebindKey)
        defaults.removeObject(forKey: AppExperienceMode.zenIntroductionSeenKey)
        defaults.removeObject(forKey: AppExperienceMode.zenIntroductionEligibleKey)
        mode = .standard
        requiresInitialSelection = true
        shouldOfferZenIntroduction = false
        zenOwnerHumanID = ""
        zenOwnerBindingState = .unresolved
        shellIdentity = UUID()
    }

    func dismissZenIntroduction() {
        guard shouldOfferZenIntroduction else { return }
        shouldOfferZenIntroduction = false
        defaults.set(true, forKey: AppExperienceMode.zenIntroductionSeenKey)
        defaults.removeObject(forKey: AppExperienceMode.zenIntroductionEligibleKey)
    }

    func reconcileZenOwner(with livingHumans: [AppExperienceHumanChoice]) {
        guard mode == .zen else {
            zenOwnerBindingState = .unresolved
            return
        }

        let orderedHumans = livingHumans.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.createdAt < $1.createdAt
        }
        let hadStoredOwner = !zenOwnerHumanID.isEmpty
        let requiresExplicitRebind = hadStoredOwner
            || defaults.bool(forKey: AppExperienceMode.zenOwnerNeedsRebindKey)
        if let storedID = UUID(uuidString: zenOwnerHumanID),
           orderedHumans.contains(where: { $0.id == storedID }) {
            defaults.removeObject(forKey: AppExperienceMode.zenOwnerNeedsRebindKey)
            zenOwnerBindingState = .ready(storedID)
            return
        }

        clearZenOwner(requiresExplicitRebind: hadStoredOwner)
        switch orderedHumans.count {
        case 0:
            zenOwnerBindingState = .unavailable
        case _ where requiresExplicitRebind:
            // Deleting or memorializing the bound owner is a safety boundary.
            // Never silently move automatic check-ins to another person.
            zenOwnerBindingState = .requiresSelection(orderedHumans)
        case 1:
            bindZenOwner(orderedHumans[0].id)
        default:
            zenOwnerBindingState = .requiresSelection(orderedHumans)
        }
    }

    func bindZenOwner(_ humanID: UUID) {
        let rawID = humanID.uuidString
        zenOwnerHumanID = rawID
        defaults.set(rawID, forKey: AppExperienceMode.zenOwnerHumanIDKey)
        defaults.removeObject(forKey: AppExperienceMode.zenOwnerNeedsRebindKey)
        zenOwnerBindingState = .ready(humanID)
    }

    private func apply(_ selectedMode: AppExperienceMode) {
        pendingMode = nil
        defaults.set(selectedMode.rawValue, forKey: AppExperienceMode.storageKey)
        requiresInitialSelection = false
        guard mode != selectedMode else { return }
        mode = selectedMode
        zenOwnerBindingState = .unresolved
        shellIdentity = UUID()
    }

    private func clearZenOwner(requiresExplicitRebind: Bool) {
        if !zenOwnerHumanID.isEmpty {
            zenOwnerHumanID = ""
            defaults.removeObject(forKey: AppExperienceMode.zenOwnerHumanIDKey)
        }
        if requiresExplicitRebind {
            defaults.set(true, forKey: AppExperienceMode.zenOwnerNeedsRebindKey)
        }
    }
}
