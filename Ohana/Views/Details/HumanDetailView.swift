//
//  HumanDetailView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct HumanDetailView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("activeHumanId") private var activeHumanIdStr = ""

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showWeightHistory = false
    @State private var showingCoconutLog = false
    @State private var showingWishlist = false
    @State private var showingCoHealth = false
    @State private var showingExpenses = false
    @State private var showingMedication = false
    @State private var showingHealthReport = false

    @Query private var allPets: [Pet]
    @Query private var allHumans: [Human]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var allPendingReminders: [Reminder]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]

    private var humanReminders: [Reminder] {
        allPendingReminders.filter {
            $0.event?.relatedEntityType == "Human" &&
            $0.event?.relatedEntityId == human.id.uuidString
        }
    }

    private var myMeds: [HumanMedication] {
        allMeds.filter { $0.humanId == human.id.uuidString && $0.isActive && $0.isActiveToday }
    }

    private var myReports: [HumanHealthReport] {
        allReports.filter { $0.humanId == human.id.uuidString }
    }

    private var themeColor: Color { Color(hex: human.themeColorHex) }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    heroCard
                    badgesCard
                    statsBento
                    showOnHomeCard

                    sectionHeader("健康 & 身体")

                    if human.isPrivate("weight", viewedBy: activeHumanId) {
                        privacyPlaceholderCard(label: "体重记录")
                    } else {
                        weightCard
                    }
                    medicationCard
                    healthReportCard

                    sectionHeader("活动 & 记录")

                    if human.isPrivate("workout", viewedBy: activeHumanId) {
                        privacyPlaceholderCard(label: "运动记录")
                    } else {
                        HumanWorkoutCard(human: human, pets: allPets)
                            .padding(.horizontal, 16)
                    }
                    coHealthCard

                    sectionHeader("财务")

                    if human.isPrivate("expense", viewedBy: activeHumanId) {
                        privacyPlaceholderCard(label: "花费记录")
                    } else {
                        humanExpenseCard
                    }
                    if human.isPrivate("wishlist", viewedBy: activeHumanId) {
                        privacyPlaceholderCard(label: "椰子资产")
                    } else {
                        humanAssetCard
                    }

                    sectionHeader("提醒 & 备注")
                    remindersSection
                    notesSection
                    deleteSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    CoconutBalanceCapsule { showingCoconutLog = true }
                    Button { showingEditSheet = true } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) { EditHumanSheet(human: human) }
        .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
        .sheet(isPresented: $showWeightHistory) {
            NavigationStack { HumanWeightHistoryView(human: human) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showingWishlist) { HumanWishlistView(human: human) }
        .navigationDestination(isPresented: $showingCoHealth) { CoHealthDashboardFullView(human: human) }
        .navigationDestination(isPresented: $showingExpenses) { HumanExpenseDetailView(human: human) }
        .sheet(isPresented: $showingMedication) {
            NavigationStack { HumanMedicationView(human: human) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showingHealthReport) { HumanHealthReportView(human: human) }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                modelContext.delete(human)
                modelContext.safeSave()
                dismiss()
            }
        } message: {
            Text("确定要删除 \(human.name) 吗？此操作不可撤销。")
        }
    }

    // MARK: - Hero Card (iOS 26 Liquid Glass)
    private var heroCard: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [themeColor, themeColor.mix(with: .black, by: 0.25), Color.goDarkBlue],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // 装饰光球 — 模拟 Liquid Glass 折射感
            Circle()
                .fill(themeColor.opacity(0.35))
                .frame(width: 200)
                .blur(radius: 70)
                .offset(x: -80, y: -60)
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 140)
                .blur(radius: 50)
                .offset(x: 90, y: 20)

            VStack(spacing: 20) {
                // Avatar
                ZStack {
                    if let imageData = human.avatarImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 2.5))
                            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
                    } else {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1.5))
                                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                            Text(human.avatarEmoji).font(.system(size: 50))
                        }
                    }
                }

                VStack(spacing: 10) {
                    Text(human.name)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            humanChip(human.roleText, color: themeColor)
                            if human.birthday != nil { humanChip(human.ageText, color: .white.opacity(0.7)) }
                            if !human.bloodType.isEmpty { humanChip("血型 \(human.bloodType)", color: Color.goRed.opacity(0.9)) }
                            if !human.nationality.isEmpty { humanChip("🌍 \(human.nationality)", color: .white.opacity(0.7)) }
                            if !human.city.isEmpty { humanChip("📍 \(human.city)", color: .white.opacity(0.7)) }
                            if human.heightCm > 0 && human.heightCm.isFinite { humanChip(String(format: "%.0f cm", human.heightCm), color: Color.goTeal.opacity(0.9)) }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: themeColor.opacity(0.2), radius: 16, y: 8)
        .padding(.horizontal, 16)
    }

    // MARK: - Stats Bento (iOS 26 Glass Capsules)
    private var statsBento: some View {
        HStack(spacing: 8) {
            bentoStatMini(
                icon: "scalemass.fill",
                value: {
                    guard let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first,
                          latest.weight.isFinite else { return "—" }
                    return String(format: "%.1f", latest.weight)
                }(),
                unit: human.weightLogs.isEmpty ? "" : "kg",
                label: "体重",
                color: Color.goPrimary
            )
            bentoStatMini(
                icon: "pills.fill",
                value: "\(myMeds.count)",
                unit: "种",
                label: "用药",
                color: Color.goRed
            )
            bentoStatMini(
                icon: "bell.badge.fill",
                value: "\(humanReminders.count)",
                unit: "条",
                label: "待办",
                color: Color.goOrange
            )
            bentoStatMini(
                icon: "leaf.fill",
                value: "\(human.coconutBalance)",
                unit: "🥥",
                label: "椰子",
                color: Color.goYellow
            )
        }
        .padding(.horizontal, 16)
    }

    private func bentoStatMini(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(OhanaFont.metric(size: 18)).foregroundStyle(.white)
                if !unit.isEmpty {
                    Text(unit).font(OhanaFont.caption2(.bold)).foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label).font(OhanaFont.caption2(.medium)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Badges Card
    private var badgesCard: some View {
        let badges = human.dynamicBadges(allPets: allPets, allHumans: allHumans)
        return Group {
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goYellow)
                        Text("动态称号")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(.white)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(badges) { badge in
                                HStack(spacing: 6) {
                                    Text(badge.emoji).font(OhanaFont.callout())
                                    Text(badge.title)
                                        .font(OhanaFont.caption(.bold))
                                        .foregroundStyle(Color(hex: badge.color))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(hex: badge.color).opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: badge.color).opacity(0.35), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Medication Card (NEW)
    private var medicationCard: some View {
        Button { showingMedication = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goRed.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "pills.fill")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goRed)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("吃药提醒")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)
                    if myMeds.isEmpty {
                        Text("暂无用药计划")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(myMeds.prefix(3)) { med in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: med.colorHex))
                                            .frame(width: 6, height: 6)
                                        Text(med.name)
                                            .font(OhanaFont.caption(.semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: med.colorHex).opacity(0.15), in: Capsule())
                                }
                                if myMeds.count > 3 {
                                    Text("+\(myMeds.count - 3)")
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                    }
                }
                Spacer()
                if !myMeds.isEmpty {
                    ZStack {
                        Circle().fill(Color.goRed).frame(width: 24, height: 24)
                        Text("\(myMeds.count)")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(.white)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Health Report Card
    private var healthReportCard: some View {
        Button { showingHealthReport = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goTeal.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "stethoscope")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goTeal)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("身体检测报告")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)
                    if myReports.isEmpty {
                        Text("暂无检测报告")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        let abnormal = myReports.filter { $0.conclusion == .abnormal || $0.conclusion == .critical }.count
                        HStack(spacing: 6) {
                            Text("\(myReports.count) 份报告")
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            if abnormal > 0 {
                                Text("· \(abnormal) 项异常")
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(Color.goOrange)
                            }
                        }
                    }
                }
                Spacer()
                if !myReports.isEmpty {
                    ZStack {
                        Circle().fill(Color.goTeal).frame(width: 24, height: 24)
                        Text("\(myReports.count)")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(.white)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Weight Card
    private var weightCard: some View {
        Button { showWeightHistory = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goPrimary.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "scalemass.fill")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("体重记录")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)
                    if let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first {
                        Text(latest.date, style: .date)
                            .font(OhanaFont.caption())
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text("暂无记录")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                if let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", latest.weight))
                            .font(OhanaFont.metric(size: 24))
                            .foregroundStyle(Color.goPrimary)
                        Text("kg")
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(Color.goPrimary.opacity(0.7))
                    }
                }
                Image(systemName: "chevron.right")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Show On Home Card
    private var showOnHomeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.goPrimary.opacity(0.2)).frame(width: 48, height: 48)
                Image(systemName: "rectangle.stack.fill")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("在首页显示")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(.white)
                Text(human.shouldShowOnHome ? "已加入首页卡堆与岛屿统计" : "不在首页卡堆与岛屿体重中显示")
                    .font(OhanaFont.caption())
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { human.shouldShowOnHome },
                set: { human.shouldShowOnHome = $0; modelContext.safeSave() }
            ))
            .tint(Color.goPrimary)
            .labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Asset Card
    private var humanAssetCard: some View {
        Button { showingWishlist = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goYellow.opacity(0.18)).frame(width: 48, height: 48)
                    Text("🥥").font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("椰子资产")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Text("\(human.coconutBalance) 个")
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.goYellow)
                        Text("· 兑换心愿")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Expense Card
    private var humanExpenseCard: some View {
        Button { showingExpenses = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goCardCyan.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "yensign")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goCardCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("账单花费")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)
                    Text("查看经手支出明细")
                        .font(OhanaFont.caption())
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Co-Health Card
    private var coHealthCard: some View {
        Button { showingCoHealth = true } label: {
            CoHealthDashboardView(human: human)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Privacy Placeholder
    private func privacyPlaceholderCard(label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(OhanaFont.headline())
                .foregroundStyle(.white.opacity(0.25))
            Text("🔒 \(label) · 仅本人可见")
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Reminders Section
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.goOrange)
                Text("待办提醒")
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(.white)
                Spacer()
                if !humanReminders.isEmpty {
                    Text("\(humanReminders.count)")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.goOrange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goOrange.opacity(0.15), in: Capsule())
                }
            }

            if humanReminders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(.system(size: 28)).foregroundStyle(.white.opacity(0.15))
                        Text("暂无待办提醒").font(OhanaFont.callout()).foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                ForEach(Array(humanReminders.enumerated()), id: \.element.id) { idx, reminder in
                    if idx > 0 {
                        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                    }
                    reminderRow(reminder)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Text(reminder.event?.emoji ?? "📌").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.event?.title ?? "提醒")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(.white)
                Text(reminder.scheduledAt, style: .date)
                    .font(OhanaFont.caption())
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if let assigneeId = reminder.event?.assigneeId,
               let assignee = allHumans.first(where: { $0.id.uuidString == assigneeId }),
               assignee.id != human.id {
                NudgeButton(targetHuman: assignee)
            }
            Button { completeReminder(reminder) } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            Button { skipReminder(reminder) } label: {
                Image(systemName: "forward.circle.fill")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goYellow)
            }
        }
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        Group {
            if !human.notes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goPrimary)
                        Text("备注")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(.white)
                    }
                    Text(human.notes)
                        .font(OhanaFont.body())
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Delete Section
    private var deleteSection: some View {
        Button(role: .destructive) { showingDeleteConfirm = true } label: {
            Label("删除成员", systemImage: "trash")
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.goRed.opacity(0.2), lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func humanChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.goPrimary)
                .frame(width: 3, height: 16)
            Text(text)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1.2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    // MARK: - Actions
    private func completeReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        modelContext.safeSave()
    }

    private func skipReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        reminder.statusEnum = .skipped
        modelContext.safeSave()
    }
}

// MARK: - Edit Human Sheet
struct EditHumanSheet: View {
    let human: Human
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var avatarEmoji: String = ""
    @State private var birthday: Date = Date()
    @State private var hasBirthday = false
    @State private var bloodType: String = ""
    @State private var role: String = "owner"
    @State private var notes: String = ""
    @State private var nationality: String = ""
    @State private var city: String = ""
    // FIX 1: 隐私设置
    @State private var privateWeight = false
    @State private var privateWorkout = false
    @State private var privateWishlist = false
    @State private var privateExpense = false
    
    var body: some View {
        OhanaSheetWrapper(title: "编辑成员", onDismiss: { dismiss() }) {
            VStack(spacing: 16) {
                formField("姓名", text: $name)
                formField("头像 Emoji", text: $avatarEmoji)
                
                Toggle("设置生日", isOn: $hasBirthday)
                    .tint(Color.goPrimary)
                    .padding(.horizontal, 4)
                
                if hasBirthday {
                    DatePicker("生日", selection: $birthday, displayedComponents: .date)
                }
                
                formField("血型", text: $bloodType)
                formField("国籍", text: $nationality)
                formField("城市", text: $city)
                
                Picker("角色", selection: $role) {
                    Text("主人").tag("owner")
                    Text("编辑").tag("editor")
                    Text("查看").tag("viewer")
                }
                .pickerStyle(.segmented)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("备注")
                        .font(OhanaFont.subheadline())
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // FIX 1: 隐私设置 Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("🔒  隐私设置")
                        .font(OhanaFont.subheadline())
                        .foregroundStyle(.secondary)
                    editPrivacyRow("体重记录", binding: $privateWeight)
                    editPrivacyRow("运动记录", binding: $privateWorkout)
                    editPrivacyRow("心愿单", binding: $privateWishlist)
                    editPrivacyRow("花费记录", binding: $privateExpense)
                }

                Button {
                    save()
                } label: {
                    Text("保存")
                        .capsuleButton()
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            name = human.name
            avatarEmoji = human.avatarEmoji
            birthday = human.birthday ?? Date()
            hasBirthday = human.birthday != nil
            bloodType = human.bloodType
            role = human.role
            notes = human.notes
            nationality = human.nationality
            city = human.city
            // FIX 1: 加载隐私设置
            let fields = human.privateFields
            privateWeight   = fields.contains("weight")
            privateWorkout  = fields.contains("workout")
            privateWishlist = fields.contains("wishlist")
            privateExpense  = fields.contains("expense")
        }
    }
    
    private func formField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.subheadline())
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private func save() {
        human.name = name
        human.avatarEmoji = avatarEmoji.isEmpty ? "👤" : avatarEmoji
        human.birthday = hasBirthday ? birthday : nil
        human.bloodType = bloodType
        human.role = role
        human.notes = notes
        human.nationality = nationality
        human.city = city
        // FIX 1: 保存隐私设置
        var privFields: Set<String> = []
        if privateWeight   { privFields.insert("weight") }
        if privateWorkout  { privFields.insert("workout") }
        if privateWishlist { privFields.insert("wishlist") }
        if privateExpense  { privFields.insert("expense") }
        human.privateFields = privFields
        modelContext.safeSave()
        dismiss()
    }

    private func editPrivacyRow(_ title: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: binding).tint(Color.goPrimary).labelsHidden()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
}
