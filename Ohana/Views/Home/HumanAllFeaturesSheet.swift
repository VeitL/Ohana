//
//  HumanAllFeaturesSheet.swift
//  Ohana
//
//  V4 human feature hub.
//

import SwiftUI
import SwiftData

enum HumanAllFeatureDestination: Hashable {
    case basicInfo
    case weight
    case workout
    case medication
    case report
    case expense
    case wishlist
    case notes
}

extension HumanAllFeatureDestination: Identifiable {
    var id: String {
        switch self {
        case .basicInfo: return "basicInfo"
        case .weight: return "weight"
        case .workout: return "workout"
        case .medication: return "medication"
        case .report: return "report"
        case .expense: return "expense"
        case .wishlist: return "wishlist"
        case .notes: return "notes"
        }
    }

    var privacyField: HumanPrivateField? {
        switch self {
        case .basicInfo:
            return nil
        case .weight, .report:
            return .weight
        case .workout:
            return .workout
        case .medication:
            return .medication
        case .expense:
            return .expense
        case .wishlist:
            return .wishlist
        case .notes:
            return .note
        }
    }
}

struct HumanAllFeaturesSheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @Query(sort: \Pet.name) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]
    @Query(sort: \PetExpenseLog.date, order: .reverse) private var allExpenses: [PetExpenseLog]

    @State private var activeDestination: HumanAllFeatureDestination?
    @State private var lockedField: HumanPrivateField?

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var themeColor: Color { Color(hex: human.safeThemeColorHex) }

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
                            imageData: human.avatarImageData,
                            emoji: human.avatarEmoji,
                            fallback: "👤",
                            tint: themeColor
                        )
                    }
                )
            } content: {
                if human.hasPassedAway {
                    HumanMemorialBanner(human: human, appLanguage: appLanguage)
                } else if isViewingOwnProfile && !human.privateFields.isEmpty {
                    HumanOwnerPrivacyHint(appLanguage: appLanguage)
                }

                FeatureHubMetricStrip(metrics: metrics)

                ForEach(sections) { section in
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
        .fullScreenCover(item: $activeDestination) { destination in
            FeatureHubDestinationHost(
                onClose: { activeDestination = nil },
                showsCloseButton: destinationNeedsHostClose(destination)
            ) {
                destinationView(destination)
            }
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
                Text(PrivacyService.lockedMessage(for: lockedField))
            }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: HumanAllFeatureDestination) -> some View {
        switch destination {
        case .basicInfo:
            HumanBasicInfoDetailView(human: human)
        case .weight:
            HumanWeightHistoryView(human: human)
        case .workout:
            CoHealthDashboardFullView(human: human)
        case .medication:
            HumanMedicationView(human: human)
        case .report:
            HumanHealthReportView(human: human)
        case .expense:
            HumanExpenseDetailView(human: human)
        case .wishlist:
            HumanWishlistView(human: human)
        case .notes:
            HumanNoteHistorySheet(human: human)
        }
    }

    private func destinationNeedsHostClose(_ destination: HumanAllFeatureDestination) -> Bool {
        switch destination {
        case .basicInfo, .workout, .report, .wishlist:
            return true
        case .weight, .medication, .expense, .notes:
            return false
        }
    }

    private func open(_ destination: HumanAllFeatureDestination) {
        if let field = destination.privacyField,
           PrivacyService.isLocked(field, for: human, viewedBy: activeHumanId) {
            lockedField = field
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        withAnimation(GoMotion.page) {
            activeDestination = destination
        }
    }

    private var headerSubtitle: String {
        if human.hasPassedAway {
            return l.tr(zh: "纪念模式 · 只读", en: "Memorial mode · read-only", de: "Gedenkmodus · nur Lesen")
        }
        let role = human.roleText
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
            return l.tr(zh: "\(years)岁", en: "\(years)y", de: "\(years) J.")
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

    private var sections: [FeatureHubSectionData<HumanAllFeatureDestination>] {
        [
            FeatureHubSectionData(
                id: "body",
                title: l.tr(zh: "身体状态", en: "Body", de: "Körper"),
                subtitle: l.tr(zh: "趋势、运动和报告", en: "Trends, movement, reports", de: "Trends, Bewegung, Berichte"),
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
                id: "account",
                title: l.tr(zh: "账户隐私", en: "Account", de: "Konto"),
                subtitle: l.tr(zh: "身份、权限和安全", en: "Identity, access, privacy", de: "Identität, Zugriff, Datenschutz"),
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
                destination: .weight
            ),
            item(
                id: "workout",
                title: l.tr(zh: "运动", en: "Workout", de: "Training"),
                value: lockedValue(.workout, visible: workoutMetric),
                subtitle: lockedSubtitle(.workout, visible: workoutSubtitle),
                icon: "figure.run",
                tint: Color.goOrange,
                destination: .workout
            ),
            item(
                id: "report",
                title: l.tr(zh: "健康报告", en: "Reports", de: "Berichte"),
                value: lockedValue(.weight, visible: "\(myReports.count)"),
                subtitle: lockedSubtitle(.weight, visible: reportSubtitle),
                icon: "cross.case.fill",
                tint: Color.goRed,
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
                destination: .medication
            ),
            item(
                id: "basic",
                title: l.tr(zh: "基本信息", en: "Profile", de: "Profil"),
                value: human.roleText,
                subtitle: l.tr(zh: "身份、头像、隐私", en: "Identity, avatar, privacy", de: "Identität, Avatar, Datenschutz"),
                icon: "person.crop.circle.fill",
                tint: themeColor,
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
                destination: .expense
            ),
            item(
                id: "wishlist",
                title: l.tr(zh: "椰子资产", en: "Coconuts", de: "Kokosnüsse"),
                value: lockedValue(.wishlist, visible: "\(human.coconutBalance)🥥"),
                subtitle: lockedSubtitle(.wishlist, visible: l.tr(zh: "愿望清单和资产", en: "Wishlist and rewards", de: "Wünsche und Belohnungen")),
                icon: "gift.fill",
                tint: Color(hex: "EC4899"),
                destination: .wishlist
            ),
            item(
                id: "notes",
                title: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                value: lockedValue(.note, visible: noteMetric),
                subtitle: lockedSubtitle(.note, visible: noteSubtitle),
                icon: "note.text",
                tint: Color(hex: "A78BFA"),
                destination: .notes
            )
        ]
    }

    private var accountItems: [FeatureHubDestinationItem<HumanAllFeatureDestination>] {
        [
            item(
                id: "profile",
                title: l.tr(zh: "账户资料", en: "Account", de: "Konto"),
                value: pinStateText,
                subtitle: l.tr(zh: "PIN、公开/隐私", en: "PIN, public/private", de: "PIN, öffentlich/privat"),
                icon: human.pinHash.isEmpty ? "lock.open.fill" : "lock.fill",
                tint: Color(hex: "64748B"),
                destination: .basicInfo
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
        destination: HumanAllFeatureDestination
    ) -> FeatureHubDestinationItem<HumanAllFeatureDestination> {
        FeatureHubDestinationItem(
            data: FeatureHubTileData(
                id: id,
                title: title,
                value: value,
                subtitle: subtitle,
                icon: icon,
                tint: tint
            ),
            destination: destination
        )
    }

    private func lockedValue(_ field: HumanPrivateField, visible: String) -> String {
        PrivacyService.isLocked(field, for: human, viewedBy: activeHumanId)
            ? l.tr(zh: "锁定", en: "Locked", de: "Gesperrt")
            : visible
    }

    private func lockedSubtitle(_ field: HumanPrivateField, visible: String) -> String {
        PrivacyService.isLocked(field, for: human, viewedBy: activeHumanId)
            ? l.tr(zh: "仅本人可见", en: "Private to owner", de: "Nur selbst sichtbar")
            : visible
    }

    private var latestWeightText: String {
        guard let latest = human.weightLogs.max(by: { $0.date < $1.date }) else {
            return l.tr(zh: "未记录", en: "None", de: "Keine")
        }
        return String(format: "%.1fkg", latest.weight)
    }

    private var latestWeightSubtitle: String {
        guard let latest = human.weightLogs.max(by: { $0.date < $1.date }) else {
            return l.tr(zh: "快速记录一次体重", en: "Add a quick weight", de: "Gewicht schnell eintragen")
        }
        return l.tr(
            zh: "上次 \(relativeDayText(latest.date))",
            en: "Last \(relativeDayText(latest.date))",
            de: "Zuletzt \(relativeDayText(latest.date))"
        )
    }

    private var workoutMetric: String {
        let count = human.workoutLogs.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
        return "\(count)"
    }

    private var workoutSubtitle: String {
        guard let last = human.workoutLogs.max(by: { $0.date < $1.date }) else {
            return l.tr(zh: "记录运动和共同健康", en: "Track movement and co-health", de: "Bewegung und gemeinsame Gesundheit")
        }
        return l.tr(
            zh: "上次 \(relativeDayText(last.date))",
            en: "Last \(relativeDayText(last.date))",
            de: "Zuletzt \(relativeDayText(last.date))"
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
                de: "Nächste \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))"
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
            de: "Zuletzt \(relativeDayText(latest.reportDate))"
        )
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
            de: "Zuletzt \(relativeDayText(latest.date))"
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

    private var pinStateText: String {
        human.pinHash.isEmpty
            ? l.tr(zh: "未设置", en: "No PIN", de: "Keine PIN")
            : l.tr(zh: "已设置", en: "PIN on", de: "PIN aktiv")
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
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text(l.tr(zh: "已开启隐私的数据仅自己可见", en: "Private fields are visible only to you", de: "Private Felder sind nur für dich sichtbar"))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

private struct HumanMemorialBanner: View {
    let human: Human
    let appLanguage: String
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goPurple)
                .frame(width: 40, height: 40)
                .background(Color.goPurple.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "纪念模式", en: "Memorial mode", de: "Gedenkmodus"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(memorialDetail)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goPurple.opacity(0.25), lineWidth: 1)
        }
    }

    private var memorialDetail: String {
        let days = human.daysTogetherAtPassing
        if let date = human.passedAwayDate {
            return l.tr(
                zh: "离世 \(date.formatted(.dateTime.year().month().day())) · 相伴 \(days) 天",
                en: "Passed \(date.formatted(.dateTime.year().month().day())) · \(days) days together",
                de: "Verstorben \(date.formatted(.dateTime.year().month().day())) · \(days) Tage zusammen"
            )
        }
        return l.tr(zh: "相伴 \(days) 天", en: "\(days) days together", de: "\(days) Tage zusammen")
    }
}
