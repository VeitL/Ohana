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
    case score1
    case score2
    case score3
    case score4
    case score5
    case score6
    case score7
    case score8
    case score9
    case score10

    /// New writes use an integer score. The four legacy cases remain decodable
    /// so existing local facts and v31/v32 backups retain their original bytes.
    static let selectableCases: [Self] = [
        .score1, .score2, .score3, .score4, .score5,
        .score6, .score7, .score8, .score9, .score10
    ]

    var id: String { rawValue }

    var currentPresentationStatus: Self {
        switch self {
        case .poor: .score2
        case .needsAttention: .score4
        case .okay: .score7
        case .great: .score9
        default: self
        }
    }

    init(score: Int) {
        switch min(max(score, 1), 10) {
        case 1: self = .score1
        case 2: self = .score2
        case 3: self = .score3
        case 4: self = .score4
        case 5: self = .score5
        case 6: self = .score6
        case 7: self = .score7
        case 8: self = .score8
        case 9: self = .score9
        default: self = .score10
        }
    }

    var score: Int {
        switch self {
        case .poor: 2
        case .needsAttention: 4
        case .okay: 7
        case .great: 9
        case .score1: 1
        case .score2: 2
        case .score3: 3
        case .score4: 4
        case .score5: 5
        case .score6: 6
        case .score7: 7
        case .score8: 8
        case .score9: 9
        case .score10: 10
        }
    }

    var icon: String {
        scoreBand.icon
    }

    func title(_ l: L10n) -> String {
        "\(score)/10 · \(scoreBand.title(l))"
    }

    var scoreBand: ZenPresenceScoreBand { ZenPresenceScoreBand(score: score) }
}

nonisolated enum ZenPresenceScoreBand: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case low
    case attention
    case steady
    case good
    case great

    var id: Int { rawValue }

    init(score: Int) {
        switch min(max(score, 1), 10) {
        case 1 ... 2: self = .low
        case 3 ... 4: self = .attention
        case 5 ... 6: self = .steady
        case 7 ... 8: self = .good
        default: self = .great
        }
    }

    var scoreRange: ClosedRange<Int> {
        switch self {
        case .low: 1 ... 2
        case .attention: 3 ... 4
        case .steady: 5 ... 6
        case .good: 7 ... 8
        case .great: 9 ... 10
        }
    }

    var icon: String {
        switch self {
        case .low: "heart.slash.fill"
        case .attention: "exclamationmark.circle.fill"
        case .steady: "minus.circle.fill"
        case .good: "leaf.fill"
        case .great: "sun.max.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .low:
            l.tr(zh: "状态较差", en: "Low", de: "Nicht gut", es: "Bajo", pt: "Baixo", fr: "Difficile", ja: "調子が悪い", ko: "좋지 않음", it: "Basso")
        case .attention:
            l.tr(zh: "需留意", en: "Needs attention", de: "Im Blick behalten", es: "Necesita atención", pt: "Precisa de atenção", fr: "À surveiller", ja: "要注意", ko: "살펴보기", it: "Da monitorare")
        case .steady:
            l.tr(zh: "一般", en: "Steady", de: "In Ordnung", es: "Estable", pt: "Estável", fr: "Stable", ja: "ふつう", ko: "보통", it: "Stabile")
        case .good:
            l.tr(zh: "不错", en: "Good", de: "Gut", es: "Bien", pt: "Bem", fr: "Bien", ja: "良い", ko: "좋음", it: "Bene")
        case .great:
            l.tr(zh: "很好", en: "Great", de: "Sehr gut", es: "Muy bien", pt: "Muito bem", fr: "Très bien", ja: "とても良い", ko: "아주 좋음", it: "Molto bene")
        }
    }
}

nonisolated enum ZenParticipationState: String, Codable, Hashable, Sendable {
    case participating
    case notParticipating
    case unknown
}

nonisolated enum ZenExpandedMetricKind: String, Codable, Hashable, Sendable {
    case age
    case together
    case zodiac
    case mbti
    case humanEquivalentAge
    case species
    case location
    case condition

    var icon: String {
        switch self {
        case .age: "birthday.cake.fill"
        case .together: "heart.fill"
        case .zodiac: "sparkles"
        case .mbti: "person.text.rectangle.fill"
        case .humanEquivalentAge: "figure.stand"
        case .species: "leaf.fill"
        case .location: "mappin.and.ellipse"
        case .condition: "sun.max.fill"
        }
    }
}

nonisolated struct ZenExpandedMetricDTO: Identifiable, Equatable, Sendable {
    let kind: ZenExpandedMetricKind
    let label: String
    let value: String

    var id: String { kind.rawValue }
}

nonisolated enum ZenRecentStatusTrend: String, Codable, Equatable, Sendable {
    case rising
    case steady
    case softening
    case insufficient
}

nonisolated struct ZenRecentStatusEntry: Equatable, Sendable {
    let dayKey: String
    let score: Int

    init(dayKey: String, score: Int) {
        self.dayKey = dayKey
        self.score = min(max(score, 1), 10)
    }
}

nonisolated struct ZenRecentStatusSummary: Equatable, Sendable {
    let todayScore: Int?
    let latestScore: Int?
    let scoredCount: Int
    let trend: ZenRecentStatusTrend

    static let empty = ZenRecentStatusSummary(
        todayScore: nil,
        latestScore: nil,
        scoredCount: 0,
        trend: .insufficient
    )

    static func make(
        entries: [ZenRecentStatusEntry],
        todayKey: String
    ) -> ZenRecentStatusSummary {
        let ordered = entries.sorted {
            if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
            return $0.score < $1.score
        }
        guard let latest = ordered.last else { return .empty }

        let trend: ZenRecentStatusTrend
        if ordered.count >= 3 {
            let splitIndex = max(1, ordered.count / 2)
            let earlier = ordered.prefix(splitIndex)
            let later = ordered.suffix(from: splitIndex)
            let earlierAverage = Double(earlier.reduce(0) { $0 + $1.score }) / Double(earlier.count)
            let laterAverage = Double(later.reduce(0) { $0 + $1.score }) / Double(later.count)
            let delta = laterAverage - earlierAverage
            if delta >= 1 {
                trend = .rising
            } else if delta <= -1 {
                trend = .softening
            } else {
                trend = .steady
            }
        } else {
            trend = .insufficient
        }

        return ZenRecentStatusSummary(
            todayScore: ordered.last(where: { $0.dayKey == todayKey })?.score,
            latestScore: latest.score,
            scoredCount: ordered.count,
            trend: trend
        )
    }
}

nonisolated struct ZenExpandedProfileDTO: Equatable, Sendable {
    let metrics: [ZenExpandedMetricDTO]
    let personalityStory: String?
    var recentStatus: ZenRecentStatusSummary

    init(
        metrics: [ZenExpandedMetricDTO] = [],
        personalityStory: String? = nil,
        recentStatus: ZenRecentStatusSummary = .empty
    ) {
        self.metrics = Array(metrics.prefix(4))
        let trimmedStory = personalityStory?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.personalityStory = trimmedStory.isEmpty ? nil : trimmedStory
        self.recentStatus = recentStatus
    }
}

nonisolated enum ZenPresenceCardTapIntent: Equatable, Sendable {
    case checkIn
    case bringToFront

    static func resolve(checkedToday: Bool) -> ZenPresenceCardTapIntent {
        checkedToday ? .bringToFront : .checkIn
    }
}

nonisolated struct ZenPresenceSubjectDTO: Identifiable, Equatable, Sendable {
    let id: String
    let kind: ZenPresenceSubjectKind
    let name: String
    let subtitle: String?
    let avatarAssetName: String?
    let avatarEmoji: String
    let avatarThumbnailSignature: String
    let createdAt: Date
    let inactiveAt: Date?
    let themeHex: String?
    let isOwner: Bool
    let sortIndex: Int
    let isActive: Bool
    let isAnonymousHistory: Bool
    let expandedProfile: ZenExpandedProfileDTO?
    var currentDisplayStreak: Int
    var checkedToday: Bool
    var status: ZenPresenceStatus?
    var checkedAt: Date?

    init(
        id: String,
        kind: ZenPresenceSubjectKind,
        name: String,
        subtitle: String? = nil,
        avatarAssetName: String? = nil,
        avatarEmoji: String = "",
        avatarThumbnailSignature: String = "",
        createdAt: Date = .distantPast,
        inactiveAt: Date? = nil,
        themeHex: String? = nil,
        isOwner: Bool = false,
        sortIndex: Int = 0,
        isActive: Bool = true,
        isAnonymousHistory: Bool = false,
        expandedProfile: ZenExpandedProfileDTO? = nil,
        currentDisplayStreak: Int = 0,
        checkedToday: Bool = false,
        status: ZenPresenceStatus? = nil,
        checkedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.subtitle = subtitle
        self.avatarAssetName = avatarAssetName
        self.avatarEmoji = avatarEmoji
        self.avatarThumbnailSignature = avatarThumbnailSignature
        self.createdAt = createdAt
        self.inactiveAt = inactiveAt
        self.themeHex = themeHex
        self.isOwner = isOwner
        self.sortIndex = sortIndex
        self.isActive = isActive
        self.isAnonymousHistory = isAnonymousHistory
        self.expandedProfile = expandedProfile
        self.currentDisplayStreak = max(0, currentDisplayStreak)
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
    let isRetrospectiveStatus: Bool
    let participation: ZenParticipationState

    var id: String { "\(subjectID):\(dayKey)" }

    init(
        subjectID: String,
        dayKey: String,
        checkedIn: Bool,
        status: ZenPresenceStatus? = nil,
        isRetrospectiveStatus: Bool = false,
        participation: ZenParticipationState = .participating
    ) {
        self.subjectID = subjectID
        self.dayKey = dayKey
        self.checkedIn = checkedIn
        self.status = status
        self.isRetrospectiveStatus = isRetrospectiveStatus
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
    var avatarCacheRevision: Int = 0

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

/// Pure presentation gate. The domain command repeats every check so a stale
/// calendar can never create an invalid or reward-bearing historical fact.
nonisolated enum ZenRetrospectiveStatusEligibility {
    static func allows(
        day: ZenPresenceDayDTO?,
        targetDayKey: String,
        todayKey: String,
        subjectCreatedDayKey: String,
        subjectInactiveDayKey: String?,
        isAnonymousHistory: Bool
    ) -> Bool {
        guard !isAnonymousHistory,
              targetDayKey < todayKey,
              targetDayKey >= subjectCreatedDayKey,
              day?.participation == .participating,
              day?.checkedIn == false
        else { return false }
        if let subjectInactiveDayKey, targetDayKey > subjectInactiveDayKey {
            return false
        }
        return true
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
    var achievementsLockedLevel: Int?
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
        achievementsLockedLevel: Int? = nil,
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
        self.achievementsLockedLevel = achievementsLockedLevel
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
    var onAutoCheckInOwner: () async -> Bool
    var onCheckIn: (
        _ subjectID: String,
        _ kind: ZenPresenceSubjectKind,
        _ status: ZenPresenceStatus?
    ) async -> Void
    var onUpdateStatus: (_ subjectID: String, _ kind: ZenPresenceSubjectKind, _ status: ZenPresenceStatus?) async -> Void
    var onRecordRetrospectiveStatus: (
        _ subjectID: String,
        _ kind: ZenPresenceSubjectKind,
        _ dayKey: String,
        _ status: ZenPresenceStatus
    ) async -> Void
    var onUndoCheckIn: (_ subjectID: String, _ kind: ZenPresenceSubjectKind) async -> Void
    var onCheckInAll: () async -> Void
    var onLoadStreak: () async -> Void
    var onLoadOasis: () async -> Void
    var onAdd: (_ kind: ZenPresenceSubjectKind) -> Void
    var onOpenProfile: (_ subject: ZenPresenceSubjectDTO) -> Void
    var onOpenMembers: () -> Void
    var onOpenCoconutLog: () -> Void
    var onOpenSettings: () -> Void
    var onOpenPersonalAnalytics: () -> Void
    var onOpenShop: (_ category: ShopItem.ShopCategory) -> Void
    var onOpenAchievements: () -> Void
    var onOpenGacha: () -> Void
    var onOpenCritters: () -> Void
    var onOpenGrowthRoadmap: () -> Void
    var onInjectEnergy: () async -> Void
    var onClaimStarterGift: () async -> Void

    static let noop = ZenShellActions(
        onAutoCheckInOwner: { false },
        onCheckIn: { _, _, _ in },
        onUpdateStatus: { _, _, _ in },
        onRecordRetrospectiveStatus: { _, _, _, _ in },
        onUndoCheckIn: { _, _ in },
        onCheckInAll: {},
        onLoadStreak: {},
        onLoadOasis: {},
        onAdd: { _ in },
        onOpenProfile: { _ in },
        onOpenMembers: {},
        onOpenCoconutLog: {},
        onOpenSettings: {},
        onOpenPersonalAnalytics: {},
        onOpenShop: { _ in },
        onOpenAchievements: {},
        onOpenGacha: {},
        onOpenCritters: {},
        onOpenGrowthRoadmap: {},
        onInjectEnergy: {},
        onClaimStarterGift: {}
    )
}

nonisolated enum ZenPresencePresentation {
    enum CardBackgroundState: Equatable, Sendable {
        case pending
        case checked
        case score(Int)

        var isChecked: Bool {
            self != .pending
        }
    }

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

    static func cardBackgroundState(for subject: ZenPresenceSubjectDTO) -> CardBackgroundState {
        guard subject.checkedToday else { return .pending }
        guard let status = subject.status else { return .checked }
        return .score(status.score)
    }
}

nonisolated struct ZenCalendarDaySlot: Identifiable, Equatable, Sendable {
    let index: Int
    let date: Date?

    var id: Int { index }
}

nonisolated enum ZenCalendarLayout {
    static let visibleWeekCount = 6

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
        let visibleSlotCount = visibleWeekCount * 7
        let trailingCount = max(0, visibleSlotCount - dates.count)
        dates.append(contentsOf: [Date?](repeating: nil, count: trailingCount))
        return dates.enumerated().map { ZenCalendarDaySlot(index: $0.offset, date: $0.element) }
    }
}

nonisolated enum ZenCalendarViewportMetrics {
    static let rowSpacing: CGFloat = 8
    static let verticalInset: CGFloat = 8
    static let standardCellHeight: CGFloat = 42

    static func pagerHeight(cellHeight: CGFloat) -> CGFloat {
        let safeCellHeight = max(standardCellHeight, cellHeight)
        return safeCellHeight * CGFloat(ZenCalendarLayout.visibleWeekCount) +
            rowSpacing * CGFloat(ZenCalendarLayout.visibleWeekCount - 1) +
            verticalInset * 2
    }

    static func circleDiameter(cellHeight: CGFloat) -> CGFloat {
        min(54, max(40, cellHeight - 2))
    }
}

nonisolated enum ZenCalendarPresentation {
    /// Read projections contain an explicit row for every participating day,
    /// including a missed one. Missing historical rows are outside Zen.
    static func participation(for day: ZenPresenceDayDTO?) -> ZenParticipationState {
        day?.participation ?? .notParticipating
    }
}
