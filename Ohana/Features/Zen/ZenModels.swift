//
//  ZenModels.swift
//  Ohana
//
//  Value-only presentation contracts for the intentionally small Zen shell.
//  Persistent facts and economy side effects remain behind injected intents.
//

import Foundation

nonisolated enum ZenTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case streak
    case oasis

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .streak: "calendar"
        case .oasis: "tree.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .home:
            l.tr(zh: "首页", en: "Home", de: "Home", es: "Inicio", pt: "Início", fr: "Accueil", ja: "ホーム", ko: "홈", it: "Home")
        case .streak:
            l.tr(zh: "连续", en: "Streak", de: "Serie", es: "Racha", pt: "Sequência", fr: "Série", ja: "連続", ko: "연속", it: "Serie")
        case .oasis:
            l.tr(zh: "Oasis", en: "Oasis", de: "Oasis", es: "Oasis", pt: "Oásis", fr: "Oasis", ja: "オアシス", ko: "오아시스", it: "Oasi")
        }
    }
}

nonisolated enum ZenPresenceSubjectKind: String, CaseIterable, Codable, Hashable, Sendable {
    case human
    case pet
    case plant

    var icon: String {
        switch self {
        case .human: "person.fill"
        case .pet: "pawprint.fill"
        case .plant: "leaf.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .human: 0
        case .pet: 1
        case .plant: 2
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .human:
            l.tr(zh: "家人", en: "Person", de: "Person", es: "Persona", pt: "Pessoa", fr: "Personne", ja: "家族", ko: "가족", it: "Persona")
        case .pet:
            l.tr(zh: "宠物", en: "Pet", de: "Tier", es: "Mascota", pt: "Pet", fr: "Animal", ja: "ペット", ko: "반려동물", it: "Animale")
        case .plant:
            l.tr(zh: "植物", en: "Plant", de: "Pflanze", es: "Planta", pt: "Planta", fr: "Plante", ja: "植物", ko: "식물", it: "Pianta")
        }
    }
}

nonisolated enum ZenPresenceStatus: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case great
    case okay
    case needsAttention
    case poor

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .great: "sun.max.fill"
        case .okay: "cloud.sun.fill"
        case .needsAttention: "exclamationmark.circle.fill"
        case .poor: "heart.slash.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .great:
            l.tr(zh: "很好", en: "Great", de: "Sehr gut", es: "Muy bien", pt: "Muito bem", fr: "Très bien", ja: "とても良い", ko: "아주 좋아요", it: "Molto bene")
        case .okay:
            l.tr(zh: "还好", en: "Okay", de: "Okay", es: "Bien", pt: "Bem", fr: "Ça va", ja: "まあまあ", ko: "괜찮아요", it: "Bene")
        case .needsAttention:
            l.tr(zh: "需要关注", en: "Needs attention", de: "Braucht Aufmerksamkeit", es: "Necesita atención", pt: "Precisa de atenção", fr: "À surveiller", ja: "注意が必要", ko: "관심 필요", it: "Richiede attenzione")
        case .poor:
            l.tr(zh: "状态较差", en: "Not doing well", de: "Nicht gut", es: "No está bien", pt: "Não está bem", fr: "Ne va pas bien", ja: "調子が悪い", ko: "상태가 좋지 않아요", it: "Non sta bene")
        }
    }
}

nonisolated enum ZenParticipationState: String, Codable, Hashable, Sendable {
    case participating
    case notParticipating
    case unknown
}

nonisolated struct ZenPresenceSubjectDTO: Identifiable, Equatable, Sendable {
    let id: String
    let kind: ZenPresenceSubjectKind
    let name: String
    let subtitle: String?
    let avatarAssetName: String?
    let themeHex: String?
    let isOwner: Bool
    let sortIndex: Int
    let isActive: Bool
    let isAnonymousHistory: Bool
    var checkedToday: Bool
    var status: ZenPresenceStatus?
    var checkedAt: Date?

    init(
        id: String,
        kind: ZenPresenceSubjectKind,
        name: String,
        subtitle: String? = nil,
        avatarAssetName: String? = nil,
        themeHex: String? = nil,
        isOwner: Bool = false,
        sortIndex: Int = 0,
        isActive: Bool = true,
        isAnonymousHistory: Bool = false,
        checkedToday: Bool = false,
        status: ZenPresenceStatus? = nil,
        checkedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.subtitle = subtitle
        self.avatarAssetName = avatarAssetName
        self.themeHex = themeHex
        self.isOwner = isOwner
        self.sortIndex = sortIndex
        self.isActive = isActive
        self.isAnonymousHistory = isAnonymousHistory
        self.checkedToday = checkedToday
        self.status = status
        self.checkedAt = checkedAt
    }
}

nonisolated struct ZenPresenceDayDTO: Identifiable, Equatable, Sendable {
    let subjectID: String
    let dayKey: String
    let checkedIn: Bool
    let status: ZenPresenceStatus?
    let participation: ZenParticipationState

    var id: String { "\(subjectID):\(dayKey)" }

    init(
        subjectID: String,
        dayKey: String,
        checkedIn: Bool,
        status: ZenPresenceStatus? = nil,
        participation: ZenParticipationState = .participating
    ) {
        self.subjectID = subjectID
        self.dayKey = dayKey
        self.checkedIn = checkedIn
        self.status = status
        self.participation = participation
    }
}

nonisolated struct ZenPresenceSnapshot: Equatable, Sendable {
    var isReady: Bool
    var subjects: [ZenPresenceSubjectDTO]
    var streakSubjects: [ZenPresenceSubjectDTO] = []
    var ownerID: String?
    var dayKey: String
    var currentStreak: Int
    var longestStreak: Int
    var days: [ZenPresenceDayDTO]
    var coconutBalance: Int
    var personalAccessLevel: PersonalAccessLevel

    var hasPersonal: Bool {
        PersonalFeatureAccessPolicy.allows(.presenceLongRangeAnalytics, level: personalAccessLevel)
    }

    static let empty = ZenPresenceSnapshot(
        isReady: false,
        subjects: [],
        streakSubjects: [],
        ownerID: nil,
        dayKey: "",
        currentStreak: 0,
        longestStreak: 0,
        days: [],
        coconutBalance: 0,
        personalAccessLevel: .free
    )
}

/// `dayKey` is a civil calendar date, not an instant. Materialize it only in
/// the calendar that will group or render it so UTC midnight can never drift
/// to the previous or next day in the user's current time zone.
nonisolated enum ZenDayKey {
    static func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(_ dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: 12
        ))
    }

    static func monthKey(for date: Date, calendar: Calendar) -> String {
        String(key(for: date, calendar: calendar).prefix(7))
    }
}

nonisolated enum ZenStarterGiftState: String, Equatable, Sendable {
    case hidden
    case claimable
    case claimed
}

nonisolated struct ZenOasisSnapshot: Equatable, Sendable {
    var isReady: Bool
    var level: Int
    var progressToNextLevel: Double
    var totalEnergy: Int
    var nextLevelThreshold: Int
    var coconutBalance: Int
    var canInjectEnergy: Bool
    var shopLockedLevel: Int?
    var gachaLockedLevel: Int?
    var crittersLockedLevel: Int?
    var starterGiftState: ZenStarterGiftState

    init(
        isReady: Bool,
        level: Int,
        progressToNextLevel: Double,
        totalEnergy: Int,
        nextLevelThreshold: Int,
        coconutBalance: Int,
        canInjectEnergy: Bool,
        shopLockedLevel: Int? = nil,
        gachaLockedLevel: Int? = nil,
        crittersLockedLevel: Int? = nil,
        starterGiftState: ZenStarterGiftState = .hidden
    ) {
        self.isReady = isReady
        self.level = min(max(0, level), 10)
        self.progressToNextLevel = progressToNextLevel.isFinite
            ? min(max(0, progressToNextLevel), 1)
            : 0
        self.totalEnergy = max(0, totalEnergy)
        self.nextLevelThreshold = max(0, nextLevelThreshold)
        self.coconutBalance = max(0, coconutBalance)
        self.canInjectEnergy = canInjectEnergy
        self.shopLockedLevel = shopLockedLevel
        self.gachaLockedLevel = gachaLockedLevel
        self.crittersLockedLevel = crittersLockedLevel
        self.starterGiftState = starterGiftState
    }

    static let empty = ZenOasisSnapshot(
        isReady: false,
        level: 0,
        progressToNextLevel: 0,
        totalEnergy: 0,
        nextLevelThreshold: 50,
        coconutBalance: 0,
        canInjectEnergy: false
    )
}

@MainActor
struct ZenShellActions {
    var onAutoCheckInOwner: () async -> Void
    var onCheckIn: (_ subjectID: String, _ kind: ZenPresenceSubjectKind) async -> Void
    var onUpdateStatus: (_ subjectID: String, _ kind: ZenPresenceSubjectKind, _ status: ZenPresenceStatus?) async -> Void
    var onCheckInAll: () async -> Void
    var onLoadStreak: () async -> Void
    var onLoadOasis: () async -> Void
    var onAdd: (_ kind: ZenPresenceSubjectKind) -> Void
    var onManage: (_ subject: ZenPresenceSubjectDTO) -> Void
    var onOpenSettings: () -> Void
    var onOpenPersonalAnalytics: () -> Void
    var onOpenShop: () -> Void
    var onOpenGacha: () -> Void
    var onOpenCritters: () -> Void
    var onInjectEnergy: () async -> Void
    var onClaimStarterGift: () async -> Void

    static let noop = ZenShellActions(
        onAutoCheckInOwner: {},
        onCheckIn: { _, _ in },
        onUpdateStatus: { _, _, _ in },
        onCheckInAll: {},
        onLoadStreak: {},
        onLoadOasis: {},
        onAdd: { _ in },
        onManage: { _ in },
        onOpenSettings: {},
        onOpenPersonalAnalytics: {},
        onOpenShop: {},
        onOpenGacha: {},
        onOpenCritters: {},
        onInjectEnergy: {},
        onClaimStarterGift: {}
    )
}

nonisolated enum ZenPresencePresentation {
    static func orderedSubjects(_ subjects: [ZenPresenceSubjectDTO]) -> [ZenPresenceSubjectDTO] {
        subjects.sorted { lhs, rhs in
            if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    static func allChecked(_ subjects: [ZenPresenceSubjectDTO]) -> Bool {
        !subjects.isEmpty && subjects.allSatisfy(\.checkedToday)
    }

    static func canEarnAllCheckedReward(_ subjects: [ZenPresenceSubjectDTO]) -> Bool {
        guard allChecked(subjects) else { return false }
        return subjects.contains { !$0.isOwner }
    }
}

nonisolated struct ZenCalendarDaySlot: Identifiable, Equatable, Sendable {
    let index: Int
    let date: Date?

    var id: Int { index }
}

nonisolated enum ZenCalendarLayout {
    static func slots(
        for month: Date,
        calendar inputCalendar: Calendar
    ) -> [ZenCalendarDaySlot] {
        let calendar = inputCalendar
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dates = [Date?](repeating: nil, count: leadingCount)
        dates.append(contentsOf: dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        })
        let trailingCount = (7 - dates.count % 7) % 7
        dates.append(contentsOf: [Date?](repeating: nil, count: trailingCount))
        return dates.enumerated().map { ZenCalendarDaySlot(index: $0.offset, date: $0.element) }
    }
}

nonisolated enum ZenCalendarPresentation {
    /// Read projections contain an explicit row for every participating day,
    /// including a missed one. Missing historical rows are outside Zen.
    static func participation(for day: ZenPresenceDayDTO?) -> ZenParticipationState {
        day?.participation ?? .notParticipating
    }
}
