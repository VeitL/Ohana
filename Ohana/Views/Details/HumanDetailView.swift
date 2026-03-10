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

    @Query private var allPets: [Pet]
    @Query private var allHumans: [Human]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var allPendingReminders: [Reminder]
    
    private var humanReminders: [Reminder] {
        allPendingReminders.filter {
            $0.event?.relatedEntityType == "Human" &&
            $0.event?.relatedEntityId == human.id.uuidString
        }
    }
    
    var body: some View {
        ZStack {
            ArkBackgroundView()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    heroCard
                    badgesCard
                    // FIX 1: 隐私判断
                    if human.isPrivate("weight", viewedBy: activeHumanId) {
                        privacyPlaceholderCard(label: "体重记录")
                    } else {
                        weightCard
                    }
                    showOnHomeCard
                    if human.isPrivate("workout", viewedBy: activeHumanId) {
                        privacyPlaceholderCard(label: "运动记录")
                    } else {
                        HumanWorkoutCard(human: human, pets: allPets)
                            .padding(.horizontal, 16)
                    }
                    // 模块1：心愿单卡
                    if !human.isPrivate("wishlist", viewedBy: activeHumanId) {
                        wishlistBentoCard
                    }
                    // 模块5：人宠共健
                    coHealthCard
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
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHumanSheet(human: human)
        }
        .sheet(isPresented: $showingCoconutLog) {
            CoconutLogView()
        }
        .sheet(isPresented: $showWeightHistory) {
            NavigationStack { HumanWeightHistoryView(human: human) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showingWishlist) {
            HumanWishlistView(human: human)
        }
        .navigationDestination(isPresented: $showingCoHealth) {
            CoHealthDashboardFullView(human: human)
        }
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
    
    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 16) {
            if let imageData = human.avatarImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 2))
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    Text(human.avatarEmoji)
                        .font(.system(size: 52))
                }
            }
            
            VStack(spacing: 8) {
                Text(human.name)
                    .font(OhanaFont.largeTitle(.heavy))
                    .foregroundStyle(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        humanChip(human.roleText)
                        if human.birthday != nil { humanChip(human.ageText) }
                        if !human.bloodType.isEmpty { humanChip("血型 \(human.bloodType)") }
                        if !human.nationality.isEmpty { humanChip("🌍 \(human.nationality)") }
                        if !human.city.isEmpty { humanChip("📍 \(human.city)") }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .ohanaStandardCard(cornerRadius: 28)
        .padding(.horizontal, 16)
    }

    // MARK: - 模块3：动态称号卡
    private var badgesCard: some View {
        let badges = human.dynamicBadges(allPets: allPets, allHumans: allHumans)
        return Group {
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("动态称号")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                        .textCase(.uppercase)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(badges) { badge in
                                HStack(spacing: 6) {
                                    Text(badge.emoji).font(.system(size: 14))
                                    Text(badge.title)
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundStyle(Color(hex: badge.color))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(hex: badge.color).opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: badge.color).opacity(0.35), lineWidth: 1))
                                .shadow(color: Color(hex: badge.color).opacity(0.25), radius: 6, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - 模块1：心愿单 Bento 卡
    private var wishlistBentoCard: some View {
        Button { showingWishlist = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goYellow.opacity(0.18)).frame(width: 44, height: 44)
                    Text("🎁").font(.system(size: 24))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("椰子心愿单")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Text("🥥 \(human.coconutBalance) 个椰子")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.goYellow)
                        Text("· 点击许愿")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .ohanaStandardCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - 模块5：人宠共健卡
    private var coHealthCard: some View {
        Button { showingCoHealth = true } label: {
            CoHealthDashboardView(human: human)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func humanChip(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: - FIX 1: 隐私占位卡
    private func privacyPlaceholderCard(label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary.opacity(0.3))
            Text("🔒 \(label)·仅本人可见")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .ohanaStandardCard(cornerRadius: 20)
        .padding(.horizontal, 16)
    }

    // MARK: - Weight Card
    private var weightCard: some View {
        Button { showWeightHistory = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.goLime.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "scalemass.fill")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goLime)
                    }
                    Text("体重记录")
                        .font(OhanaFont.headline())
                        .foregroundStyle(.primary)
                    Spacer()
                    if let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", latest.weight))
                                .font(OhanaFont.title2(.black))
                                .foregroundStyle(Color.goLime)
                            Text("kg")
                                .font(OhanaFont.footnote(.bold))
                                .foregroundStyle(Color.goLime.opacity(0.7))
                        }
                    } else {
                        Text("暂无记录")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                    Image(systemName: "chevron.right")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .ohanaStandardCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 模块5b：首页卡堆显示开关
    private var showOnHomeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.goPrimary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("在首页卡堆显示")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(human.shouldShowOnHome ? "已加入首页宠物卡堆" : "仅在家庭成员列表显示")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
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
        .ohanaStandardCard(cornerRadius: 20)
        .padding(.horizontal, 16)
    }

    // MARK: - Reminders Section
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.orange)
                Text("待办提醒")
                    .font(OhanaFont.headline())
                Spacer()
                Text("\(humanReminders.count)")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(.secondary)
            }
            
            if humanReminders.isEmpty {
                Text("暂无待办提醒")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(humanReminders) { reminder in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(reminder.event?.emoji ?? "📌")
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.event?.title ?? "提醒")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text(reminder.scheduledAt, style: .date)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.4))
                            }
                            Spacer()
                            // 模块4：催办 NudgeButton
                            if let assigneeId = reminder.event?.assigneeId,
                               let assignee = allHumans.first(where: { $0.id.uuidString == assigneeId }),
                               assignee.id != human.id {
                                NudgeButton(targetHuman: assignee)
                            }
                            Button { completeReminder(reminder) } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.goLime)
                            }
                            Button { skipReminder(reminder) } label: {
                                Image(systemName: "forward.circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.goYellow)
                            }
                        }
                        // 模块4：指派人头像 chip
                        if let assigneeId = reminder.event?.assigneeId {
                            AssigneeChip(assigneeId: assigneeId, allHumans: allHumans)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .ohanaStandardCard(cornerRadius: 20)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        Group {
            if !human.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(Color.goLime)
                        Text("备注")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    Text(human.notes)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .padding(16)
                .ohanaStandardCard(cornerRadius: 20)
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Delete Section
    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除成员")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Actions
    private func completeReminder(_ reminder: Reminder) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        modelContext.safeSave()
    }
    
    private func skipReminder(_ reminder: Reminder) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
                    .tint(Color.goLime)
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
