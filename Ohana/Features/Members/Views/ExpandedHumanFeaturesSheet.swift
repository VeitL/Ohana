//
//  ExpandedHumanFeaturesSheet.swift
//  Ohana
//
//  Human feature hub presented from the GO Focus home card.
//

import SwiftData
import SwiftUI

struct ExpandedHumanFeaturesContentSheet: View {
    let human: Human
    let allPets: [Pet]
    let allHumans: [Human]
    let allPendingReminders: [Reminder]
    let allMeds: [HumanMedication]
    let allReports: [HumanHealthReport]

    private enum HumanFeatureRoute: String, Identifiable {
        case basicInfo
        case weight
        case workout
        case metrics
        case medication
        case report
        case expense
        case wishlist
        case notes

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    @State private var showingEditSheet = false
    @State private var showingCoconutLog = false
    @State private var showingDeleteConfirm = false
    @State private var activeFeatureRoute: HumanFeatureRoute?

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var l: L10n { L10n(appLanguage) }
    private var isAllPrivateForViewer: Bool {
        HumanLocalPrivacyPolicy.isEnabled &&
            !isViewingOwnProfile &&
            HumanPrivateField.allCases.allSatisfy { human.privateFields.contains($0.rawValue) }
    }

    private var humanReminders: [Reminder] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allPendingReminders.filter { reminder in
            guard let event = reminder.event else { return false }
            return MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: allMeds
            )
        }
    }

    private var myMeds: [HumanMedication] {
        guard !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allMeds.filter { $0.humanId == human.id.uuidString && $0.isActive && $0.isActiveToday }
    }

    private var myReports: [HumanHealthReport] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.weight, viewedBy: activeHumanId) else { return [] }
        return allReports.filter { $0.humanId == human.id.uuidString }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            activeFeatureRoute = .basicInfo
                        } label: {
                            humanFeatureHero
                        }
                        .buttonStyle(ScaleButtonStyle())

                        if isAllPrivateForViewer {
                            fullPrivacyCard
                        } else {
                            badgesCard
                            ownerPrivateDataNoticeStack
                        }

                        sectionHeader(l.tr(zh: "功能入口", en: "Feature Entry", de: "Funktionszugang"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .weight,
                                route: .weight,
                                lockedTitle: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                                label: {
                                    bentoCard(
                                        icon: "scalemass.fill",
                                        color: .goTeal,
                                        title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                                        value: latestWeightText,
                                        subtitle: l.tr(zh: "趋势与记录", en: "Trends & Records", de: "Trends & Einträge"),
                                        height: 146
                                    )
                                }
                            )
                            featureNavigation(
                                field: .workout,
                                route: .workout,
                                lockedTitle: l.tr(zh: "活动", en: "Activity", de: "Aktivität"),
                                label: {
                                    bentoCard(
                                        icon: "figure.run",
                                        color: Color.goOrange,
                                        title: l.tr(zh: "活动", en: "Activity", de: "Aktivität"),
                                        value: "\(visibleWorkoutCount)",
                                        subtitle: l.tr(zh: "运动与共同健康", en: "Workouts & shared health", de: "Training & gemeinsame Gesundheit"),
                                        height: 146
                                    )
                                }
                            )
                        }

                        featureNavigation(
                            field: .weight,
                            route: .metrics,
                            lockedTitle: l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"),
                            label: {
                                compactBentoCard(
                                    icon: "waveform.path.ecg.rectangle.fill",
                                    color: .goTeal,
                                    title: l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"),
                                    subtitle: healthMetricSubtitle
                                )
                            }
                        )

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .medication,
                                route: .medication,
                                lockedTitle: l.tr(zh: "用药", en: "Medication", de: "Medikamente"),
                                label: {
                                    compactBentoCard(icon: "pills.fill", color: .goPurple, title: l.tr(zh: "用药", en: "Medication", de: "Medikamente"), subtitle: l.tr(zh: "服药与提醒", en: "Doses & reminders", de: "Einnahmen & Erinnerungen"))
                                }
                            )
                            featureNavigation(
                                field: .weight,
                                route: .report,
                                lockedTitle: l.tr(zh: "健康报告", en: "Health Reports", de: "Gesundheitsberichte"),
                                label: {
                                    compactBentoCard(icon: "cross.case.fill", color: .goRed, title: l.tr(zh: "健康报告", en: "Health Reports", de: "Gesundheitsberichte"), subtitle: l.tr(zh: "体检与档案", en: "Checkups & files", de: "Untersuchungen & Akten"))
                                }
                            )
                        }

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .expense,
                                route: .expense,
                                lockedTitle: l.tr(zh: "花费", en: "Expenses", de: "Ausgaben"),
                                label: {
                                    bentoCard(
                                        icon: "creditcard.fill",
                                        color: .goOrange,
                                        title: l.tr(zh: "花费", en: "Expenses", de: "Ausgaben"),
                                        value: l.tr(zh: "账本", en: "Ledger", de: "Buch"),
                                        subtitle: l.tr(zh: "谁花了多少钱", en: "Who paid what", de: "Wer was bezahlt hat"),
                                        height: 132
                                    )
                                }
                            )
                            featureNavigation(
                                field: .wishlist,
                                route: .wishlist,
                                lockedTitle: l.tr(zh: "椰子资产", en: "Coconut Assets", de: "Kokosnussvermögen"),
                                label: {
                                    bentoCard(
                                        icon: "gift.fill",
                                        color: Color(hex: "EC4899"),
                                        title: l.tr(zh: "椰子资产", en: "Coconut Assets", de: "Kokosnussvermögen"),
                                        value: visibleCoconutText,
                                        subtitle: l.tr(zh: "愿望清单和资产", en: "Wishlist and assets", de: "Wunschliste und Vermögen"),
                                        height: 132
                                    )
                                }
                            )
                        }

                        if !isAllPrivateForViewer {
                            sectionHeader(l.tr(zh: "提醒与备注", en: "Reminders & Notes", de: "Erinnerungen & Notizen"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            remindersCard
                            notesCard
                            if isViewingOwnProfile {
                                deleteCard
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(l.tr(zh: "\(human.name) 的功能", en: "\(human.name)'s Features", de: "Funktionen von \(human.name)"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !human.isPrivate(.wishlist, viewedBy: activeHumanId) {
                        CoconutBalanceCapsule(balance: human.coconutBalance) {
                            showingCoconutLog = true
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        if isViewingOwnProfile {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Image(systemName: "pencil") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                                    .font(.system(size: 14, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .frame(width: 30, height: 30) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                                    .background(Color.goPrimary, in: Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) { dismiss() }
                            .font(.system(size: 15, weight: .semibold)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                            .foregroundStyle(Color.goPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) { EditHumanSheet(human: human) }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView(subject: .human(human.id)) }
            .fullScreenCover(item: $activeFeatureRoute) { route in
                humanFeatureRouteView(route)
                    .background(OhanaAppBackground().ignoresSafeArea())
            }
            .alert(l.tr(zh: "确认删除", en: "Confirm Delete", de: "Löschen bestätigen"), isPresented: $showingDeleteConfirm) {
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
                Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                    deleteHumanAndDismiss()
                }
            } message: {
                Text(l.tr(
                    zh: "确定要删除 \(human.name) 吗？此操作不可撤销。",
                    en: "Delete \(human.name)? This cannot be undone.",
                    de: "\(human.name) löschen? Dies kann nicht rückgängig gemacht werden."
                ))
            }
        }
    }

    @ViewBuilder
    private func featureNavigation(
        field: HumanPrivateField,
        route: HumanFeatureRoute,
        lockedTitle: String,
        @ViewBuilder label: () -> some View
    ) -> some View {
        if human.isPrivate(field, viewedBy: activeHumanId) {
            lockedFeatureCard(title: lockedTitle)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                activeFeatureRoute = route
            } label: {
                label()
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @ViewBuilder
    private func humanFeatureRouteView(_ route: HumanFeatureRoute) -> some View {
        switch route {
        case .basicInfo:
            HumanBasicInfoDetailView(human: human)
        case .weight:
            HumanWeightHistoryView(human: human)
        case .workout:
            CoHealthDashboardFullView(human: human)
        case .metrics:
            HumanHealthCheckupView(human: human)
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

    private var visibleWorkoutCount: Int {
        human.isPrivate(.workout, viewedBy: activeHumanId) ? 0 : human.workoutLogs.count
    }

    private var visibleCoconutText: String {
        human.isPrivate(.wishlist, viewedBy: activeHumanId) ? "—" : "\(human.coconutBalance)"
    }

    private var ownerPrivateDataNoticeStack: some View {
        VStack(spacing: 10) {
            ForEach(HumanPrivateField.allCases) { field in
                HumanPrivateDataNotice(human: human, field: field)
            }
        }
    }

    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                humanAvatar(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(human.name)
                        .font(.system(size: 22, weight: .black, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(humanSubtitle.isEmpty ? "OHANA MEMBER" : humanSubtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                        .font(.system(size: 13, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 32, height: 32) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                        .background(Color.goPrimary, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoPill(title: l.tr(zh: "权限", en: "Role", de: "Rolle"), value: localizedRoleText(for: human.role))
                infoPill(title: l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"), value: localizedGenderTitle(for: human.genderRaw))
                infoPill(title: l.tr(zh: "年龄", en: "Age", de: "Alter"), value: human.birthday == nil ? localizedEmptyValue : localizedAgeText)
                infoPill(title: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), value: human.bloodType.isEmpty ? localizedEmptyValue : human.bloodType)
                infoPill(title: l.tr(zh: "身高", en: "Height", de: "Größe"), value: human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f cm", human.heightCm) : localizedEmptyValue)
                infoPill(title: l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), value: human.nationality.isEmpty ? localizedEmptyValue : human.nationality)
                infoPill(title: l.tr(zh: "城市", en: "City", de: "Stadt"), value: human.city.isEmpty ? localizedEmptyValue : human.city)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var badgesCard: some View {
        let badges = human.dynamicBadges(allPets: allPets, allHumans: allHumans)
        return Group {
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                            .foregroundStyle(Color.goYellow)
                        Text(l.tr(zh: "动态称号", en: "Dynamic Badges", de: "Dynamische Abzeichen"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(badges) { badge in
                                HStack(spacing: 5) {
                                    Text(badge.emoji)
                                    Text(badge.title)
                                        .font(OhanaFont.caption(.bold))
                                }
                                .foregroundStyle(Color(hex: badge.color))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(hex: badge.color).opacity(0.16), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: badge.color).opacity(0.28), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
            }
        }
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                    .foregroundStyle(Color.goOrange)
                Text(l.tr(zh: "待办提醒", en: "Pending Reminders", de: "Ausstehende Erinnerungen"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(humanReminders.count)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.goOrange, in: Capsule())
            }

            if humanReminders.isEmpty {
                emptyInlineRow(icon: "checkmark.circle", title: l.tr(zh: "暂无待办提醒", en: "No pending reminders", de: "Keine ausstehenden Erinnerungen"))
            } else {
                ForEach(humanReminders.prefix(4)) { reminder in
                    reminderRow(reminder)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        if human.isPrivate(.note, viewedBy: activeHumanId) {
            lockedWideCard(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"))
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                activeFeatureRoute = .notes
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "note.text") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                        .font(.system(size: 16, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 36, height: 36) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                        .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "备注记录", en: "Note Records", de: "Notizeinträge"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(human.notes.isEmpty ? l.tr(zh: "暂无备注", en: "No notes", de: "Keine Notizen") : human.notes.components(separatedBy: "\n\n").first ?? l.tr(zh: "查看备注", en: "View notes", de: "Notizen ansehen"))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                .padding(14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Label(l.tr(zh: "删除成员", en: "Delete Member", de: "Mitglied löschen"), systemImage: "trash")
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .strokeBorder(Color.goRed.opacity(0.24), lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var fullPrivacyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(.system(size: 34, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                .foregroundStyle(Color.goYellow)
            Text(l.tr(zh: "此成员资料仅本人可见", en: "This member profile is private", de: "Dieses Mitgliederprofil ist privat"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "当前家庭成员无法查看 TA 的体重、运动、吃药、备注、花费和椰子资产等相关数据。",
                en: "Current family members cannot view their weight, workouts, medication, notes, expenses, coconut assets, or related data.",
                de: "Aktuelle Familienmitglieder können Gewicht, Training, Medikamente, Notizen, Ausgaben, Kokosnussvermögen und verwandte Daten nicht sehen."
            ))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(value)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private func lockedFeatureCard(title: String) -> some View {
        lockedWideCard(title: title)
            .frame(maxWidth: .infinity, minHeight: 132)
    }

    private func lockedWideCard(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(l.tr(
                zh: "\(title) · 仅本人可见",
                en: "\(title) · Private to owner",
                de: "\(title) · Nur selbst sichtbar"
            ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func emptyInlineRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(title)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaTertiaryText)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Text(reminder.event?.emoji ?? "📌")
                .font(OhanaFont.title3())
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.event?.title ?? l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(reminder.scheduledAt, style: .date)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button {
                completeReminder(reminder)
            } label: {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            Button {
                skipReminder(reminder)
            } label: {
                Image(systemName: "forward.circle.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goYellow)
            }
        }
        .padding(.vertical, 5)
    }

    private func completeReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ReminderCommandExecutor(context: modelContext, services: appServices).complete(
            reminder,
            by: human.id.uuidString,
            note: "expanded.human.reminder.complete"
        )
    }

    private func skipReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ReminderCommandExecutor(context: modelContext, services: appServices).skip(
            reminder,
            by: human.id.uuidString,
            note: "expanded.human.reminder.skip"
        )
    }

    private func deleteHumanAndDismiss() {
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: human.id, kind: EntityKind.human.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                human,
                activeHumanID: activeHumanID,
                note: "expandedHumanFeatures.delete"
            )
            if result.clearsActiveHumanID {
                activeHumanIdStr = ""
            }
            appServices.notificationRoutes.publishRouteEvent(
                .humanDeleted(
                    requiresReplacementHuman: result.requiresReplacementHuman,
                    requiresAccountSwitch: result.requiresAccountSwitch
                )
            )
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
            .fill(Color.ohanaCardSurface)
    }

    private var humanFeatureHero: some View {
        ZStack(alignment: .topLeading) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.54, 0.32), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: [
                    Color(hex: human.safeThemeColorHex).mix(with: .white, by: 0.2),
                    Color.goTeal.opacity(0.70),
                    Color.goOrange.opacity(0.48),
                    Color(hex: human.safeThemeColorHex),
                    Color(hex: "1A2E8A"),
                    Color(hex: "EC4899").opacity(0.7),
                    Color(hex: "0C1640"),
                    Color(hex: human.safeThemeColorHex).mix(with: .black, by: 0.28),
                    Color(hex: "050816")
                ]
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MEMBER OS")
                            .font(OhanaFont.caption2(.black))
                            .tracking(2.6)
                            .foregroundStyle(Color.ohanaSecondaryText)
                        Text(human.name)
                            .font(.system(size: 32, weight: .black, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(humanSubtitle)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    humanAvatar(size: 54)
                }

                HStack(spacing: 9) {
                    heroChip(title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokosnüsse"), value: privateAwareHeroValue(.wishlist, "\(human.coconutBalance)"))
                    heroChip(title: l.tr(zh: "运动", en: "Workouts", de: "Training"), value: privateAwareHeroValue(.workout, "\(human.workoutLogs.count)"))
                    heroChip(title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"), value: privateAwareHeroValue(.weight, "\(human.weightLogs.count)"))
                }
            }
            .padding(18)

            Image(systemName: "chevron.right.circle.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(.system(size: 22, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(16)

            Image(systemName: "person.crop.circle.badge.checkmark") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(.system(size: 88, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                .foregroundStyle(Color.ohanaTertiaryText.opacity(0.2))
                .offset(x: 246, y: 76)
        }
        .frame(height: 188)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var humanSubtitle: String {
        let zodiac = human.birthday.map { Human.westernZodiacDisplay(for: $0, l: l) }
        return [localizedRoleText(for: human.role), localizedGenderTitle(for: human.genderRaw), zodiac, human.mbti.isEmpty ? nil : human.mbti]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    private var latestWeightText: String {
        guard !human.isPrivate(.weight, viewedBy: activeHumanId) else { return "—" }
        guard let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first else { return "--" }
        return String(format: "%.1f", latest.weight)
    }

    private var healthMetricSubtitle: String {
        guard let latest = human.healthMetricLogs.sorted(by: { $0.date > $1.date }).first,
              let metric = HealthMetricCatalog.metric(forKey: latest.metricKey),
              let unit = metric.unit(for: latest.unitCode) else {
            return l.tr(zh: "TSH / HbA1c / 血压", en: "TSH / HbA1c / Blood Pressure", de: "TSH / HbA1c / Blutdruck")
        }
        return "\(metric.displayName(l)) · \(unit.formattedValue(latest.value))"
    }

    private var localizedEmptyValue: String {
        l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt")
    }

    private var localizedAgeText: String {
        guard let birthday = human.birthday else { return localizedEmptyValue }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return years > 0
            ? l.tr(zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.")
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }

    private func localizedRoleText(for raw: String) -> String {
        switch HumanProfileOptions.normalizedRole(raw) {
        case "owner":
            l.tr(zh: "管理者", en: "Owner", de: "Verwaltung")
        default:
            l.tr(zh: "成员", en: "Member", de: "Mitglied")
        }
    }

    private func localizedGenderTitle(for raw: String) -> String {
        switch HumanProfileOptions.normalizedGender(raw) {
        case "女":
            l.tr(zh: "女", en: "Female", de: "Weiblich")
        case "男":
            l.tr(zh: "男", en: "Male", de: "Männlich")
        case "非二元":
            l.tr(zh: "非二元", en: "Non-binary", de: "Nichtbinär")
        case "不透露":
            l.tr(zh: "不透露", en: "Prefer not to say", de: "Keine Angabe")
        default:
            HumanGenderIdentity.title(for: raw)
        }
    }

    private func privateAwareHeroValue(_ field: HumanPrivateField, _ value: String) -> String {
        human.isPrivate(field, viewedBy: activeHumanId) ? "—" : value
    }

    private func bentoCard(icon: String, color: Color, title: String, value: String, subtitle: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 34, height: 34) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                    .background(color, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                Spacer()
                Image(systemName: "arrow.up.right") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 29, weight: .black, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [color.opacity(0.18), Color.ohanaCardSurface.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func compactBentoCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                .foregroundStyle(color)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaTertiaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    @ViewBuilder
    private func humanAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.ohanaControlFill)
                .frame(width: size, height: size)
            if let data = human.avatarImageData, let ui = UIImage(data: data) { // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: size * 0.48))
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func row(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                .background(color, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(.vertical, 5)
    }
}
