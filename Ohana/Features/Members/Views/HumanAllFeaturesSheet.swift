//
//  HumanAllFeaturesSheet.swift
//  Ohana
//
//  V4 human feature hub.
//

import SwiftUI
import UIKit

enum HumanAllFeatureDestination: Hashable {
    case basicInfo
    case weight
    case workout
    case metrics
    case medication
    case report
    case expense
    case wishlist
    case notes
    case achievements
}

extension HumanAllFeatureDestination: Identifiable {
    var id: String {
        switch self {
        case .basicInfo: "basicInfo"
        case .weight: "weight"
        case .workout: "workout"
        case .metrics: "metrics"
        case .medication: "medication"
        case .report: "report"
        case .expense: "expense"
        case .wishlist: "wishlist"
        case .notes: "notes"
        case .achievements: "achievements"
        }
    }

    var privacyField: HumanPrivateField? {
        switch self {
        case .basicInfo, .achievements:
            nil
        case .weight, .metrics, .report:
            .weight
        case .workout:
            .workout
        case .medication:
            .medication
        case .expense:
            .expense
        case .wishlist:
            .wishlist
        case .notes:
            .note
        }
    }

    var isAvailableInMemorialMode: Bool {
        switch self {
        case .basicInfo, .notes, .achievements:
            true
        case .weight, .workout, .metrics, .medication, .report, .expense, .wishlist:
            false
        }
    }
}

struct HumanAllFeaturesActivitySummary: Equatable {
    var latestWeightKg: Double?
    var latestWeightDate: Date?
    var monthlyWorkoutCount: Int = 0
    var latestWorkoutDate: Date?
    var trackedHealthMetricCount: Int = 0
    var latestHealthMetricKey: String?
    var latestHealthMetricUnitCode: String?
    var latestHealthMetricValue: Double?
    var weightChartPoints: [OhanaMinimalChartPoint] = []
    var workoutChartPoints: [OhanaMinimalChartPoint] = []
    var metricsChartPoints: [OhanaMinimalChartPoint] = []
    var reportChartPoints: [OhanaMinimalChartPoint] = []
    var medicationChartPoints: [OhanaMinimalChartPoint] = []
    var expenseChartPoints: [OhanaMinimalChartPoint] = []
    var coconutChartPoints: [OhanaMinimalChartPoint] = []
    var noteChartPoints: [OhanaMinimalChartPoint] = []
    var profileChartPoints: [OhanaMinimalChartPoint] = []

    static let empty = HumanAllFeaturesActivitySummary()

    @MainActor
    static func load(
        human: Human,
        allMeds: [HumanMedication],
        allReports: [HumanHealthReport],
        allExpenses: [PetExpenseLog],
        weightLogs: [HumanWeightLog] = [],
        workoutLogs: [HumanWorkoutLog] = [],
        healthMetricLogs: [HumanHealthMetricLog] = [],
        explicitlyResolvedProfileCategories: Set<MemberProfileCompletionCategory> = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HumanAllFeaturesActivitySummary {
        let todayStart = calendar.startOfDay(for: now)
        let recentDays = (0 ..< 7).compactMap {
            calendar.date(byAdding: .day, value: $0 - 6, to: todayStart)
        }
        let humanID = human.id.uuidString
        let myMeds = allMeds.filter { $0.humanId == humanID }
        let myReports = allReports.filter { $0.humanId == humanID }
        let myExpenses = allExpenses.filter { $0.executorId == humanID }
        let latestWeight = weightLogs.max(by: { $0.date < $1.date })
        let latestWorkout = workoutLogs.max(by: { $0.date < $1.date })
        let latestHealthMetric = healthMetricLogs.max(by: { $0.date < $1.date })
        let monthlyWorkoutCount = workoutLogs.count(where: { calendar.isDate($0.date, equalTo: now, toGranularity: .month) })
        let visibleNotes = HumanProfileOptions.visibleNoteParts(from: human.notes)
        let profileCompletion = MemberProfileCompletenessPolicy.human(
            human,
            explicitlyResolvedCategories: explicitlyResolvedProfileCategories
        )

        return HumanAllFeaturesActivitySummary(
            latestWeightKg: latestWeight?.weight,
            latestWeightDate: latestWeight?.date,
            monthlyWorkoutCount: monthlyWorkoutCount,
            latestWorkoutDate: latestWorkout?.date,
            trackedHealthMetricCount: Set(healthMetricLogs.map(\.metricKey)).count,
            latestHealthMetricKey: latestHealthMetric?.metricKey,
            latestHealthMetricUnitCode: latestHealthMetric?.unitCode,
            latestHealthMetricValue: latestHealthMetric?.value,
            weightChartPoints: weightLogs
                .sorted { $0.date < $1.date }
                .suffix(7)
                .map { OhanaMinimalChartPoint(date: $0.date, value: max(0, $0.weight), id: "human-all-weight-\($0.id.uuidString)") },
            workoutChartPoints: dailyPoints(
                days: recentDays,
                idPrefix: "human-all-workout",
                values: workoutLogs,
                date: \.date,
                value: { Double(max(0, $0.durationMinutes)) },
                calendar: calendar
            ),
            metricsChartPoints: dailyPoints(
                days: recentDays,
                idPrefix: "human-all-metrics",
                values: healthMetricLogs,
                date: \.date,
                value: { _ in 1 },
                calendar: calendar
            ),
            reportChartPoints: dailyPoints(
                days: recentDays,
                idPrefix: "human-all-reports",
                values: myReports,
                date: \.reportDate,
                value: { _ in 1 },
                calendar: calendar
            ),
            medicationChartPoints: FeatureHubChartPointFactory.bars(
                [
                    Double(myMeds.count { $0.isActive && $0.isActiveToday }),
                    Double(myMeds.count { !$0.isActive || !$0.isActiveToday })
                ],
                idPrefix: "human-all-medication"
            ),
            expenseChartPoints: dailyPoints(
                days: recentDays,
                idPrefix: "human-all-expense",
                values: myExpenses,
                date: \.date,
                value: { max(0, $0.amount) },
                calendar: calendar
            ),
            coconutChartPoints: FeatureHubChartPointFactory.quietPlaceholder(
                seed: Double(max(1, human.coconutBalance)),
                idPrefix: "human-all-coconuts"
            ),
            noteChartPoints: FeatureHubChartPointFactory.level(
                current: Double(visibleNotes.count),
                total: Double(max(visibleNotes.count, 1)),
                idPrefix: "human-all-notes"
            ),
            profileChartPoints: FeatureHubChartPointFactory.level(
                current: Double(profileCompletion.completedCategoryCount),
                total: Double(profileCompletion.totalCategoryCount),
                idPrefix: "human-all-profile"
            )
        )
    }

    private static func dailyPoints<T>(
        days: [Date],
        idPrefix: String,
        values: [T],
        date: KeyPath<T, Date>,
        value: (T) -> Double,
        calendar: Calendar
    ) -> [OhanaMinimalChartPoint] {
        days.enumerated().map { index, day in
            let total = values.reduce(0.0) { partial, item in
                guard calendar.isDate(item[keyPath: date], inSameDayAs: day) else {
                    return partial
                }
                return partial + max(0, value(item))
            }
            return OhanaMinimalChartPoint(
                date: day,
                value: total,
                id: "\(idPrefix)-\(index)-\(Int((total * 1000).rounded()))"
            )
        }
    }
}

struct HumanAllFeaturesSheet: View {
    let human: Human
    let allMeds: [HumanMedication]
    let allReports: [HumanHealthReport]
    let allExpenses: [PetExpenseLog]
    let summary: HumanAllFeaturesActivitySummary
    let onOpenDestination: (HumanAllFeatureDestination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current
    @State private var lockedField: HumanPrivateField?
    @State private var avatarSignature = ""
    @State private var avatarCacheKey = "human-feature-avatar-empty"

    init(
        human: Human,
        allMeds: [HumanMedication] = [],
        allReports: [HumanHealthReport] = [],
        allExpenses: [PetExpenseLog] = [],
        summary: HumanAllFeaturesActivitySummary = .empty,
        onOpenDestination: @escaping (HumanAllFeatureDestination) -> Void
    ) {
        self.human = human
        self.allMeds = allMeds
        self.allReports = allReports
        self.allExpenses = allExpenses
        self.summary = summary
        self.onOpenDestination = onOpenDestination
    }

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var themeColor: Color { Color(hex: human.safeThemeColorHex) }
    private var preparedAvatarImage: UIImage? {
        guard !avatarSignature.isEmpty else { return nil }
        return avatarPipeline.cachedImage(for: human.id, signature: avatarSignature)
    }

    var body: some View {
        NavigationStack {
            FeatureHubScaffold {
                FeatureHubHeader(
                    title: human.name,
                    subtitle: headerSubtitle,
                    eyebrow: l.tr(zh: "人类驾驶舱", en: "Human Hub", de: "Menschen-Hub"),
                    onClose: { dismiss() },
                    avatar: {
                        FeatureHubAvatar(
                            image: preparedAvatarImage,
                            imageData: nil,
                            emoji: human.avatarEmoji,
                            fallback: "👤",
                            tint: themeColor
                        )
                    }
                )
            } content: {
                if human.hasPassedAway {
                    HumanMemorialBanner(human: human, appLanguage: appLanguage)
                } else if HumanLocalPrivacyPolicy.isEnabled,
                          isViewingOwnProfile,
                          !human.privateFields.isEmpty {
                    HumanOwnerPrivacyHint(appLanguage: appLanguage)
                }

                FeatureHubSummaryPanel(
                    title: l.tr(zh: "成员摘要", en: "Member Summary", de: "Mitgliederübersicht"),
                    statusText: summaryStatusText,
                    statusTint: summaryStatusTint,
                    metrics: metrics
                )
                .accessibilityIdentifier("human-all-features-summary-panel")

                ForEach(visibleSections) { section in
                    FeatureHubSectionActionView(section: section) { destination in
                        open(destination)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .saturation(human.hasPassedAway ? 0.08 : 1)
            .grayscale(human.hasPassedAway ? 0.86 : 0)
            .animation(GoMotion.page, value: human.hasPassedAway)
        }
        .task(id: avatarSourceKey) {
            await prepareAvatar()
        }
        .onDisappear {
            avatarPipeline.cancel(key: avatarCacheKey)
        }
        .alert(
            l.tr(zh: "仅本人可见", en: "Private to owner", de: "Nur selbst sichtbar"),
            isPresented: Binding(
                get: { lockedField != nil },
                set: { if !$0 { lockedField = nil } }
            )
        ) {
            Button(l.confirm, role: .cancel) { lockedField = nil }
        } message: {
            if let lockedField {
                Text(appServices.privacy.lockedMessage(for: lockedField))
            }
        }
    }

    private var avatarSourceKey: String {
        "\(human.id.uuidString):\(human.avatarThumbnailSignature)"
    }

    private func prepareAvatar() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        guard human.hasAvatarImageAttachment,
              let data = human.avatarImageData else {
            avatarPipeline.cancel(key: avatarCacheKey)
            avatarSignature = ""
            avatarCacheKey = "human-feature-avatar-empty"
            return
        }

        let signature = human.avatarThumbnailSignature
        let nextKey = "human-feature-avatar-\(human.id.uuidString)-\(signature)"
        if avatarCacheKey != nextKey {
            avatarPipeline.cancel(key: avatarCacheKey)
            avatarCacheKey = nextKey
        }
        avatarSignature = signature
        let payload = FocusWalletAvatarCache.Payload(id: human.id, data: data)
        avatarPipeline.seedPreviewEntries([payload], key: nextKey)
        avatarPipeline.preload(
            payloads: [payload],
            key: nextKey,
            delayMilliseconds: 48
        )
    }

    private func open(_ destination: HumanAllFeatureDestination) {
        guard !human.hasPassedAway || destination.isAvailableInMemorialMode else {
            return
        }
        if let field = destination.privacyField,
           appServices.privacy.isLocked(field, for: human, viewedBy: activeHumanId) {
            lockedField = field
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        onOpenDestination(destination)
    }

    private var headerSubtitle: String {
        if human.hasPassedAway {
            return l.tr(zh: "纪念模式 · 只读", en: "Memorial mode · read-only", de: "Gedenkmodus · nur Lesen")
        }
        let role = localizedRoleText(for: human.role)
        let age = localizedAgeText
        if age.isEmpty { return role }
        return "\(role) · \(age)"
    }

    private var localizedAgeText: String {
        guard let birthday = human.birthday else {
            return l.tr(zh: "年龄未知", en: "Age unknown", de: "Alter unbekannt")
        }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        if years >= 1 {
            return l.tr(
                zh: "\(years)岁", en: "\(years)y", de: "\(years) J.",
                es: "\(years) años", pt: "\(years) anos", fr: "\(years) ans",
                ja: "\(years)歳", ko: "\(years)세", it: "\(years) anni"
            )
        }
        return l.tr(zh: "不满1岁", en: "Under 1", de: "Unter 1")
    }

    private var metrics: [FeatureHubMetric] {
        [
            FeatureHubMetric(
                id: "weight",
                title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                value: lockedValue(.weight, visible: latestWeightText)
            ),
            FeatureHubMetric(
                id: "meds",
                title: l.tr(zh: "今日用药", en: "Meds today", de: "Medikamente"),
                value: lockedValue(.medication, visible: medicationMetric)
            ),
            FeatureHubMetric(
                id: "expense",
                title: l.tr(zh: "本月花费", en: "This month", de: "Diesen Monat"),
                value: lockedValue(.expense, visible: monthlyExpenseText)
            )
        ]
    }

    private var summaryStatusText: String {
        if human.hasPassedAway {
            return l.tr(zh: "纪念模式", en: "Memorial", de: "Gedenken")
        }
        if HumanLocalPrivacyPolicy.isEnabled,
           isViewingOwnProfile,
           !human.privateFields.isEmpty {
            return l.tr(
                zh: "\(human.privateFields.count) 项隐私保护", en: "\(human.privateFields.count) private fields", de: "\(human.privateFields.count) private Felder",
                es: "\(human.privateFields.count) campos privados", pt: "\(human.privateFields.count) campos privados", fr: "\(human.privateFields.count) champs privés",
                ja: "非公開項目\(human.privateFields.count)件", ko: "비공개 항목 \(human.privateFields.count)개", it: "\(human.privateFields.count) campi privati"
            )
        }
        return l.tr(zh: "资料可用", en: "Profile ready", de: "Profil bereit")
    }

    private var summaryStatusTint: Color {
        if human.hasPassedAway {
            return Color.ohanaSecondaryText
        }
        if HumanLocalPrivacyPolicy.isEnabled,
           isViewingOwnProfile,
           !human.privateFields.isEmpty {
            return Color.goPurple
        }
        return Color.goTeal
    }

    private var visibleSections: [FeatureHubSectionData<HumanAllFeatureDestination>] {
        guard human.hasPassedAway else { return sections }
        return sections.compactMap { section in
            let items = section.items.filter(\.destination.isAvailableInMemorialMode)
            guard !items.isEmpty else { return nil }
            return FeatureHubSectionData(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                items: items
            )
        }
    }

    private var sections: [FeatureHubSectionData<HumanAllFeatureDestination>] {
        [
            FeatureHubSectionData(
                id: "body",
                title: l.tr(zh: "身体状态", en: "Body", de: "Körper"),
                subtitle: l.tr(zh: "趋势、指标和报告", en: "Trends, metrics, reports", de: "Trends, Werte, Berichte"),
                items: bodyItems
            ),
            FeatureHubSectionData(
                id: "care",
                title: l.tr(zh: "健康照护", en: "Care", de: "Pflege"),
                subtitle: l.tr(zh: "用药和检查", en: "Meds and checkups", de: "Medikamente und Checks"),
                items: careItems
            ),
            FeatureHubSectionData(
                id: "money",
                title: l.tr(zh: "财务备注", en: "Money & Notes", de: "Geld & Notizen"),
                subtitle: l.tr(zh: "花费、心愿和记录", en: "Expenses, wishes, notes", de: "Ausgaben, Wünsche, Notizen"),
                items: moneyItems
            ),
            FeatureHubSectionData(
                id: "growth",
                title: l.tr(
                    zh: "成长",
                    en: "Growth",
                    de: "Wachstum",
                    es: "Crecimiento",
                    pt: "Crescimento",
                    fr: "Progression",
                    ja: "成長",
                    ko: "성장",
                    it: "Crescita"
                ),
                subtitle: l.tr(
                    zh: "个人、伙伴与全岛里程碑",
                    en: "Personal, companion, and island milestones",
                    de: "Persönliche, Begleiter- und Inselmeilensteine",
                    es: "Hitos personales, de compañeros y de la isla",
                    pt: "Marcos pessoais, de companheiros e da ilha",
                    fr: "Jalons personnels, des compagnons et de l’île",
                    ja: "個人・仲間・島のマイルストーン",
                    ko: "개인·동료·섬 마일스톤",
                    it: "Traguardi personali, dei compagni e dell’isola"
                ),
                items: growthItems
            ),
            FeatureHubSectionData(
                id: "account",
                title: l.tr(
                    zh: "家庭资料", en: "Household profile", de: "Haushaltsprofil",
                    es: "Perfil del hogar", pt: "Perfil da família", fr: "Profil du foyer",
                    ja: "家族プロフィール", ko: "가족 프로필", it: "Profilo familiare"
                ),
                subtitle: l.tr(
                    zh: "身份、资料与本地隐私", en: "Identity, profile, local privacy", de: "Identität, Profil, lokaler Datenschutz",
                    es: "Identidad, perfil y privacidad local", pt: "Identidade, perfil e privacidade local", fr: "Identité, profil et confidentialité locale",
                    ja: "本人情報・プロフィール・ローカルプライバシー", ko: "신원, 프로필 및 로컬 개인정보", it: "Identità, profilo e privacy locale"
                ),
                items: accountItems
            )
        ]
    }

    private var bodyItems: [FeatureHubDestinationItem<HumanAllFeatureDestination>] {
        [
            item(
                id: "weight",
                title: l.tr(zh: "体重追踪", en: "Weight", de: "Gewicht"),
                value: lockedValue(.weight, visible: latestWeightText),
                subtitle: lockedSubtitle(.weight, visible: latestWeightSubtitle),
                icon: "scalemass.fill",
                tint: Color(hex: "16A34A"),
                chart: privacyChart(.weight, points: summary.weightChartPoints, style: .trend),
                destination: .weight
            ),
            item(
                id: "metrics",
                title: l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"),
                value: lockedValue(.weight, visible: healthMetricMetric),
                subtitle: lockedSubtitle(.weight, visible: healthMetricSubtitle),
                icon: "waveform.path.ecg.rectangle.fill",
                tint: Color.goTeal,
                chart: privacyChart(.weight, points: summary.metricsChartPoints),
                destination: .metrics
            ),
            item(
                id: "workout",
                title: l.tr(zh: "运动", en: "Workout", de: "Training"),
                value: lockedValue(.workout, visible: workoutMetric),
                subtitle: lockedSubtitle(.workout, visible: workoutSubtitle),
                icon: "figure.run",
                tint: Color.goOrange,
                chart: privacyChart(.workout, points: summary.workoutChartPoints),
                destination: .workout
            ),
            item(
                id: "report",
                title: l.tr(zh: "健康报告", en: "Reports", de: "Berichte"),
                value: lockedValue(.weight, visible: "\(myReports.count)"),
                subtitle: lockedSubtitle(.weight, visible: reportSubtitle),
                icon: "cross.case.fill",
                tint: Color.goRed,
                chart: privacyChart(.weight, points: summary.reportChartPoints),
                destination: .report
            )
        ]
    }

    private var careItems: [FeatureHubDestinationItem<HumanAllFeatureDestination>] {
        [
            item(
                id: "medication",
                title: l.tr(zh: "用药", en: "Medication", de: "Medikation"),
                value: lockedValue(.medication, visible: medicationMetric),
                subtitle: lockedSubtitle(.medication, visible: medicationSubtitle),
                icon: "pills.fill",
                tint: Color.goPurple,
                chart: privacyChart(.medication, points: summary.medicationChartPoints),
                destination: .medication
            ),
            item(
                id: "basic",
                title: l.tr(zh: "基本信息", en: "Profile", de: "Profil"),
                value: localizedRoleText(for: human.role),
                subtitle: l.tr(zh: "身份、头像、隐私", en: "Identity, avatar, privacy", de: "Identität, Avatar, Datenschutz"),
                icon: "person.crop.circle.fill",
                tint: themeColor,
                chart: FeatureHubMiniChartData(style: .bar, points: summary.profileChartPoints),
                destination: .basicInfo
            )
        ]
    }

    private var moneyItems: [FeatureHubDestinationItem<HumanAllFeatureDestination>] {
        [
            item(
                id: "expense",
                title: l.tr(zh: "花费", en: "Expense", de: "Kosten"),
                value: lockedValue(.expense, visible: monthlyExpenseText),
                subtitle: lockedSubtitle(.expense, visible: expenseSubtitle),
                icon: "creditcard.fill",
                tint: Color(hex: "F59E0B"),
                chart: privacyChart(.expense, points: summary.expenseChartPoints),
                destination: .expense
            ),
            item(
                id: "wishlist",
                title: l.tr(zh: "椰子资产", en: "Coconuts", de: "Kokosnüsse"),
                value: lockedValue(.wishlist, visible: "\(human.coconutBalance)🥥"),
                subtitle: lockedSubtitle(.wishlist, visible: l.tr(zh: "愿望清单和资产", en: "Wishlist and rewards", de: "Wünsche und Belohnungen")),
                icon: "gift.fill",
                tint: Color(hex: "EC4899"),
                chart: privacyChart(.wishlist, points: summary.coconutChartPoints),
                destination: .wishlist
            ),
            item(
                id: "notes",
                title: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                value: lockedValue(.note, visible: noteMetric),
                subtitle: lockedSubtitle(.note, visible: noteSubtitle),
                icon: "note.text",
                tint: Color(hex: "A78BFA"),
                chart: privacyChart(.note, points: summary.noteChartPoints),
                destination: .notes
            )
        ]
    }

    private var accountItems: [FeatureHubDestinationItem<HumanAllFeatureDestination>] {
        [
            item(
                id: "profile",
                title: l.tr(
                    zh: "成员资料", en: "Member profile", de: "Mitgliederprofil",
                    es: "Perfil del miembro", pt: "Perfil do membro", fr: "Profil du membre",
                    ja: "メンバープロフィール", ko: "구성원 프로필", it: "Profilo del membro"
                ),
                value: accountStateText,
                subtitle: accountSubtitle,
                icon: accountIcon,
                tint: Color(hex: "64748B"),
                chart: FeatureHubMiniChartData(style: .bar, points: summary.profileChartPoints),
                destination: .basicInfo
            )
        ]
    }

    private var growthItems: [FeatureHubDestinationItem<HumanAllFeatureDestination>] {
        [
            item(
                id: "achievements",
                title: l.tr(
                    zh: "成就",
                    en: "Achievements",
                    de: "Erfolge",
                    es: "Logros",
                    pt: "Conquistas",
                    fr: "Succès",
                    ja: "実績",
                    ko: "업적",
                    it: "Obiettivi"
                ),
                value: l.tr(
                    zh: "查看",
                    en: "View",
                    de: "Öffnen",
                    es: "Ver",
                    pt: "Ver",
                    fr: "Voir",
                    ja: "表示",
                    ko: "보기",
                    it: "Apri"
                ),
                subtitle: l.tr(
                    zh: "个人、伙伴与全岛进度",
                    en: "Personal, companion, and island progress",
                    de: "Persönlicher, Begleiter- und Inselfortschritt",
                    es: "Progreso personal, de compañeros y de la isla",
                    pt: "Progresso pessoal, de companheiros e da ilha",
                    fr: "Progression personnelle, des compagnons et de l’île",
                    ja: "個人・仲間・島の進捗",
                    ko: "개인·동료·섬 진행도",
                    it: "Progressi personali, dei compagni e dell’isola"
                ),
                icon: "trophy.fill",
                tint: Color.goYellow,
                destination: .achievements
            )
        ]
    }

    private func item(
        id: String,
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        chart: FeatureHubMiniChartData? = nil,
        destination: HumanAllFeatureDestination
    ) -> FeatureHubDestinationItem<HumanAllFeatureDestination> {
        FeatureHubDestinationItem(
            data: FeatureHubTileData(
                id: id,
                title: title,
                value: value,
                subtitle: subtitle,
                icon: icon,
                tint: tint,
                chart: chart
            ),
            destination: destination
        )
    }

    private func privacyChart(
        _ field: HumanPrivateField,
        points: [OhanaMinimalChartPoint],
        style: FeatureHubMiniChartData.Style = .bar
    ) -> FeatureHubMiniChartData? {
        guard !appServices.privacy.isLocked(field, for: human, viewedBy: activeHumanId) else {
            return nil
        }
        return FeatureHubMiniChartData(style: style, points: points)
    }

    private func lockedValue(_ field: HumanPrivateField, visible: String) -> String {
        appServices.privacy.isLocked(field, for: human, viewedBy: activeHumanId)
            ? l.tr(zh: "锁定", en: "Locked", de: "Gesperrt")
            : visible
    }

    private func lockedSubtitle(_ field: HumanPrivateField, visible: String) -> String {
        appServices.privacy.isLocked(field, for: human, viewedBy: activeHumanId)
            ? l.tr(zh: "仅本人可见", en: "Private to owner", de: "Nur selbst sichtbar")
            : visible
    }

    private var latestWeightText: String {
        guard let latestWeightKg = summary.latestWeightKg else {
            return l.tr(zh: "未记录", en: "None", de: "Keine")
        }
        return String(format: "%.1fkg", latestWeightKg)
    }

    private var latestWeightSubtitle: String {
        guard let latestWeightDate = summary.latestWeightDate else {
            return l.tr(zh: "快速记录一次体重", en: "Add a quick weight", de: "Gewicht schnell eintragen")
        }
        return l.tr(
            zh: "上次 \(relativeDayText(latestWeightDate))",
            en: "Last \(relativeDayText(latestWeightDate))",
            de: "Zuletzt \(relativeDayText(latestWeightDate))",
            es: "Último: \(relativeDayText(latestWeightDate))", pt: "Último: \(relativeDayText(latestWeightDate))", fr: "Dernier : \(relativeDayText(latestWeightDate))",
            ja: "前回：\(relativeDayText(latestWeightDate))", ko: "최근: \(relativeDayText(latestWeightDate))", it: "Ultimo: \(relativeDayText(latestWeightDate))"
        )
    }

    private var workoutMetric: String {
        "\(summary.monthlyWorkoutCount)"
    }

    private var workoutSubtitle: String {
        guard let latestWorkoutDate = summary.latestWorkoutDate else {
            return l.tr(zh: "记录运动和共同健康", en: "Track movement and co-health", de: "Bewegung und gemeinsame Gesundheit")
        }
        return l.tr(
            zh: "上次 \(relativeDayText(latestWorkoutDate))",
            en: "Last \(relativeDayText(latestWorkoutDate))",
            de: "Zuletzt \(relativeDayText(latestWorkoutDate))",
            es: "Último: \(relativeDayText(latestWorkoutDate))", pt: "Último: \(relativeDayText(latestWorkoutDate))", fr: "Dernier : \(relativeDayText(latestWorkoutDate))",
            ja: "前回：\(relativeDayText(latestWorkoutDate))", ko: "최근: \(relativeDayText(latestWorkoutDate))", it: "Ultimo: \(relativeDayText(latestWorkoutDate))"
        )
    }

    private var medicationMetric: String {
        let active = myMeds.count
        guard active > 0 else { return l.tr(zh: "无", en: "None", de: "Keine") }
        return "\(active)"
    }

    private var medicationSubtitle: String {
        guard !myMeds.isEmpty else {
            return l.tr(zh: "添加药物和提醒", en: "Add meds and reminders", de: "Medikamente und Erinnerungen")
        }
        if let nextDose = myMeds
            .flatMap({ HumanMedicationSchedulePlan.futureDoses(for: $0, days: 7) })
            .sorted(by: { $0.scheduledTime < $1.scheduledTime })
            .first {
            return l.tr(
                zh: "下次 \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))",
                en: "Next \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))",
                de: "Nächste \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))",
                es: "Próxima: \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))", pt: "Próxima: \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))", fr: "Prochaine : \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))",
                ja: "次回：\(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))", ko: "다음: \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))", it: "Prossima: \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))"
            )
        }
        return l.tr(zh: "按需记录", en: "As needed", de: "Nach Bedarf")
    }

    private var reportSubtitle: String {
        guard let latest = myReports.max(by: { $0.reportDate < $1.reportDate }) else {
            return l.tr(zh: "体检、检查和档案", en: "Checkups and files", de: "Checks und Akten")
        }
        return l.tr(
            zh: "上次 \(relativeDayText(latest.reportDate))",
            en: "Last \(relativeDayText(latest.reportDate))",
            de: "Zuletzt \(relativeDayText(latest.reportDate))",
            es: "Último: \(relativeDayText(latest.reportDate))", pt: "Último: \(relativeDayText(latest.reportDate))", fr: "Dernier : \(relativeDayText(latest.reportDate))",
            ja: "前回：\(relativeDayText(latest.reportDate))", ko: "최근: \(relativeDayText(latest.reportDate))", it: "Ultimo: \(relativeDayText(latest.reportDate))"
        )
    }

    private var healthMetricMetric: String {
        guard summary.trackedHealthMetricCount > 0 else { return l.tr(zh: "未追踪", en: "None", de: "Keine") }
        return "\(summary.trackedHealthMetricCount)"
    }

    private var healthMetricSubtitle: String {
        guard let key = summary.latestHealthMetricKey,
              let unitCode = summary.latestHealthMetricUnitCode,
              let value = summary.latestHealthMetricValue,
              let metric = HealthMetricCatalog.metric(forKey: key),
              let unit = metric.unit(for: unitCode) else {
            return l.tr(zh: "TSH、HbA1c、血压等", en: "TSH, HbA1c, BP, and more", de: "TSH, HbA1c, Blutdruck")
        }
        return "\(metric.displayName(l)) · \(unit.formattedValue(value))"
    }

    private var monthlyExpenseText: String {
        AppCurrency.format(monthlyExpenses.reduce(0) { $0 + $1.amount }, fractionDigits: 0)
    }

    private var expenseSubtitle: String {
        guard let latest = myExpenses.first else {
            return l.tr(zh: "记录这个月花了什么", en: "Track this month's spending", de: "Ausgaben dieses Monats")
        }
        return l.tr(
            zh: "上次 \(relativeDayText(latest.date))",
            en: "Last \(relativeDayText(latest.date))",
            de: "Zuletzt \(relativeDayText(latest.date))",
            es: "Último: \(relativeDayText(latest.date))", pt: "Último: \(relativeDayText(latest.date))", fr: "Dernier : \(relativeDayText(latest.date))",
            ja: "前回：\(relativeDayText(latest.date))", ko: "최근: \(relativeDayText(latest.date))", it: "Ultimo: \(relativeDayText(latest.date))"
        )
    }

    private var noteMetric: String {
        noteEntries.isEmpty ? l.tr(zh: "无", en: "None", de: "Keine") : "\(noteEntries.count)"
    }

    private var noteSubtitle: String {
        noteEntries.isEmpty
            ? l.tr(zh: "记录今天的一句话", en: "Save a quick note", de: "Kurze Notiz speichern")
            : l.tr(zh: "最近有记录", en: "Recent notes", de: "Aktuelle Notizen")
    }

    private var accountStateText: String {
        guard HumanLocalPrivacyPolicy.isEnabled else {
            return localizedRoleText(for: human.role)
        }
        return human.pinHash.isEmpty
            ? l.tr(zh: "未设置", en: "No PIN", de: "Keine PIN")
            : l.tr(zh: "已设置", en: "PIN on", de: "PIN aktiv")
    }

    private var accountSubtitle: String {
        HumanLocalPrivacyPolicy.isEnabled
            ? l.tr(zh: "PIN、公开/隐私", en: "PIN, public/private", de: "PIN, öffentlich/privat")
            : l.tr(zh: "资料与家庭角色", en: "Profile and household role", de: "Profil und Familienrolle")
    }

    private var accountIcon: String {
        guard HumanLocalPrivacyPolicy.isEnabled else { return "person.crop.circle.fill" }
        return human.pinHash.isEmpty ? "lock.open.fill" : "lock.fill"
    }

    private func localizedRoleText(for raw: String) -> String {
        HumanProfileOptions.localizedRoleTitle(raw, l: l)
    }

    private var myMeds: [HumanMedication] {
        allMeds.filter { $0.humanId == human.id.uuidString && $0.isActive && $0.isActiveToday }
    }

    private var myReports: [HumanHealthReport] {
        allReports.filter { $0.humanId == human.id.uuidString }
    }

    private var myExpenses: [PetExpenseLog] {
        allExpenses.filter { $0.executorId == human.id.uuidString }
    }

    private var monthlyExpenses: [PetExpenseLog] {
        myExpenses.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var noteEntries: [String] {
        human.notes
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func relativeDayText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return l.tr(zh: "今天", en: "today", de: "heute") }
        if cal.isDateInYesterday(date) { return l.tr(zh: "昨天", en: "yesterday", de: "gestern") }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct HumanOwnerPrivacyHint: View {
    let appLanguage: String
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 22, height: 22) // a11y: allow decorative non-interactive glyph; hint text is combined by parent
                .accessibilityHidden(true)
            Text(l.tr(zh: "已开启隐私的数据仅自己可见", en: "Private fields are visible only to you", de: "Private Felder sind nur für dich sichtbar"))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct HumanMemorialBanner: View {
    let human: Human
    let appLanguage: String
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPurple)
                .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPurple.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "纪念模式", en: "Memorial mode", de: "Gedenkmodus"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(memorialDetail)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.goPurple.opacity(0.25), lineWidth: 1)
        }
    }

    private var memorialDetail: String {
        let days = human.daysTogetherAtPassing
        if let date = human.passedAwayDate {
            return l.tr(
                zh: "离世 \(date.formatted(.dateTime.year().month().day())) · 相伴 \(days) 天",
                en: "Passed \(date.formatted(.dateTime.year().month().day())) · \(days) days together",
                de: "Verstorben \(date.formatted(.dateTime.year().month().day())) · \(days) Tage zusammen",
                es: "Falleció el \(date.formatted(.dateTime.year().month().day())) · \(days) días juntos",
                pt: "Faleceu em \(date.formatted(.dateTime.year().month().day())) · \(days) dias juntos",
                fr: "Décès le \(date.formatted(.dateTime.year().month().day())) · \(days) jours ensemble",
                ja: "逝去日 \(date.formatted(.dateTime.year().month().day())) · 一緒に過ごした\(days)日",
                ko: "별세일 \(date.formatted(.dateTime.year().month().day())) · 함께한 \(days)일",
                it: "Decesso il \(date.formatted(.dateTime.year().month().day())) · \(days) giorni insieme"
            )
        }
        return l.tr(
            zh: "相伴 \(days) 天", en: "\(days) days together", de: "\(days) Tage zusammen",
            es: "\(days) días juntos", pt: "\(days) dias juntos", fr: "\(days) jours ensemble",
            ja: "一緒に過ごした\(days)日", ko: "함께한 \(days)일", it: "\(days) giorni insieme"
        )
    }
}
