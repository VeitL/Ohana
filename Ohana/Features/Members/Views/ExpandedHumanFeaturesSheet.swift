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

    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    @State private var showingEditSheet = false
    @State private var showingCoconutLog = false
    @State private var showingDeleteConfirm = false
    @State private var activeFeatureRoute: HumanFeatureRoute?

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isAllPrivateForViewer: Bool {
        !isViewingOwnProfile && HumanPrivateField.allCases.allSatisfy { human.privateFields.contains($0.rawValue) }
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

                        sectionHeader("功能入口")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .weight,
                                route: .weight,
                                lockedTitle: "体重",
                                label: {
                                    bentoCard(
                                        icon: "scalemass.fill",
                                        color: .goTeal,
                                        title: "体重",
                                        value: latestWeightText,
                                        subtitle: "趋势与记录",
                                        height: 146
                                    )
                                }
                            )
                            featureNavigation(
                                field: .workout,
                                route: .workout,
                                lockedTitle: "活动",
                                label: {
                                    bentoCard(
                                        icon: "figure.run",
                                        color: Color.goOrange,
                                        title: "活动",
                                        value: "\(visibleWorkoutCount)",
                                        subtitle: "运动与共同健康",
                                        height: 146
                                    )
                                }
                            )
                        }

                        featureNavigation(
                            field: .weight,
                            route: .metrics,
                            lockedTitle: "体检指标",
                            label: {
                                compactBentoCard(
                                    icon: "waveform.path.ecg.rectangle.fill",
                                    color: .goTeal,
                                    title: "体检指标",
                                    subtitle: healthMetricSubtitle
                                )
                            }
                        )

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .medication,
                                route: .medication,
                                lockedTitle: "用药",
                                label: {
                                    compactBentoCard(icon: "pills.fill", color: .goPurple, title: "用药", subtitle: "服药与提醒")
                                }
                            )
                            featureNavigation(
                                field: .weight,
                                route: .report,
                                lockedTitle: "健康报告",
                                label: {
                                    compactBentoCard(icon: "cross.case.fill", color: .goRed, title: "健康报告", subtitle: "体检与档案")
                                }
                            )
                        }

                        HStack(spacing: 12) {
                            featureNavigation(
                                field: .expense,
                                route: .expense,
                                lockedTitle: "花费",
                                label: {
                                    bentoCard(
                                        icon: "creditcard.fill",
                                        color: .goOrange,
                                        title: "花费",
                                        value: "账本",
                                        subtitle: "谁花了多少钱",
                                        height: 132
                                    )
                                }
                            )
                            featureNavigation(
                                field: .wishlist,
                                route: .wishlist,
                                lockedTitle: "椰子资产",
                                label: {
                                    bentoCard(
                                        icon: "gift.fill",
                                        color: Color(hex: "EC4899"),
                                        title: "椰子资产",
                                        value: visibleCoconutText,
                                        subtitle: "愿望清单和资产",
                                        height: 132
                                    )
                                }
                            )
                        }

                        if !isAllPrivateForViewer {
                            sectionHeader("提醒与备注")
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
            .navigationTitle("\(human.name) 的功能")
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
                        Button("完成") { dismiss() }
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
            .alert("确认删除", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteHumanAndDismiss()
                }
            } message: {
                Text("确定要删除 \(human.name) 吗？此操作不可撤销。")
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
                infoPill(title: "权限", value: human.roleText.isEmpty ? "成员" : human.roleText)
                infoPill(title: "性别/身份", value: HumanGenderIdentity.title(for: human.genderRaw))
                infoPill(title: "年龄", value: human.birthday == nil ? "未设置" : human.ageText)
                infoPill(title: "血型", value: human.bloodType.isEmpty ? "未设置" : human.bloodType)
                infoPill(title: "身高", value: human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f cm", human.heightCm) : "未设置")
                infoPill(title: "国籍", value: human.nationality.isEmpty ? "未设置" : human.nationality)
                infoPill(title: "城市", value: human.city.isEmpty ? "未设置" : human.city)
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
                        Text("动态称号")
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
                Text("待办提醒")
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
                emptyInlineRow(icon: "checkmark.circle", title: "暂无待办提醒")
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
            lockedWideCard(title: "备注")
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
                        Text("备注记录")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(human.notes.isEmpty ? "暂无备注" : human.notes.components(separatedBy: "\n\n").first ?? "查看备注")
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
            Label("删除成员", systemImage: "trash")
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
            Text("此成员资料仅本人可见")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text("当前家庭成员无法查看 TA 的体重、运动、吃药、备注、花费和椰子资产等相关数据。")
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
            Text("\(title) · 仅本人可见")
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
                Text(reminder.event?.title ?? "提醒")
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
                    heroChip(title: "椰子", value: privateAwareHeroValue(.wishlist, "\(human.coconutBalance)"))
                    heroChip(title: "运动", value: privateAwareHeroValue(.workout, "\(human.workoutLogs.count)"))
                    heroChip(title: "体重", value: privateAwareHeroValue(.weight, "\(human.weightLogs.count)"))
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
        let zodiac = human.birthday.map { Human.westernZodiacChinese(for: $0) }
        return [human.roleText, HumanGenderIdentity.title(for: human.genderRaw), zodiac, human.mbti.isEmpty ? nil : human.mbti]
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
            return "TSH / HbA1c / 血压"
        }
        return "\(metric.displayName(L10n(AppLanguage.code))) · \(unit.formattedValue(latest.value))"
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
