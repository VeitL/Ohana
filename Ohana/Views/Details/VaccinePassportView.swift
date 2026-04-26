//
//  VaccinePassportView.swift
//  Ohana
//
//  N1: 疫苗本 — 管理宠物所有疫苗记录，支持添加/到期提醒
//

import SwiftUI
import SwiftData
import UserNotifications

struct VaccinePassportView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingAdd = false

    private var vaccineLogs: [PetHealthLog] {
        pet.healthLogs
            .filter { $0.type == HealthLogType.vaccine.rawValue }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            Color(hex: "0D0638").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header 卡
                    headerCard
                        .padding(.horizontal, 16)

                    if vaccineLogs.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(vaccineLogs) { log in
                                VaccineRow(log: log, pet: pet, onDelete: {
                                    modelContext.delete(log)
                                    modelContext.safeSave()
                                })
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("疫苗本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddVaccineSheet(pet: pet)
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: pet.themeColorHex).opacity(0.25))
                    .frame(width: 52, height: 52)
                if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 52, height: 52).clipShape(Circle())
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 28))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("共 \(vaccineLogs.count) 条疫苗记录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Text("💉").font(.system(size: 36))
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("💉").font(.system(size: 48))
            Text("还没有疫苗记录")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.6))
            Text("点击右上角 + 开始记录第一针疫苗")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Vaccine Row
private struct VaccineRow: View {
    let log: PetHealthLog
    let pet: Pet
    let onDelete: () -> Void

    private var daysUntilExpiry: Int? {
        guard let exp = log.expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }

    private var expiryColor: Color {
        guard let days = daysUntilExpiry else { return .primary.opacity(0.3) }
        if days < 0 { return Color.goRed }
        if days <= 30 { return Color.goYellow }
        return Color.goTeal
    }

    private var expiryLabel: String {
        guard let days = daysUntilExpiry else { return "" }
        if days < 0 { return "已过期" }
        if days == 0 { return "今日到期" }
        if days <= 30 { return "\(days) 天后到期" }
        if let exp = log.expirationDate {
            return exp.formatted(.dateTime.year().month().day())
        }
        return ""
    }

    var body: some View {
        HStack(spacing: 14) {
            // 日期竖轴
            VStack(spacing: 3) {
                Text(log.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Text(log.date.formatted(.dateTime.year()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            .frame(width: 42)

            // 竖线
            Rectangle()
                .fill(.primary.opacity(0.1))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            // 内容
            VStack(alignment: .leading, spacing: 5) {
                Text(log.note.isEmpty ? "疫苗接种" : log.note)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    if !log.vetName.isEmpty {
                        Label(log.vetName, systemImage: "stethoscope")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    if log.cost > 0 {
                        Label(String(format: "¥%.0f", log.cost), systemImage: "yensign.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }

                if log.expirationDate != nil {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(expiryColor)
                            .frame(width: 6, height: 6)
                        Text(expiryLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(expiryColor)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("删除记录", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Vaccine Sheet
struct AddVaccineSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vaccineName: String = ""
    @State private var date: Date = Date()
    @State private var hasExpiry: Bool = true
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var vetName: String = ""
    @State private var costText: String = ""
    @State private var reminderDaysBefore: Int = 7
    @State private var enableReminder: Bool = true

    private let reminderOptions = [3, 7, 14, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // 宠物行
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color(hex: pet.themeColorHex).opacity(0.25))
                                    .frame(width: 44, height: 44)
                                if let d = pet.avatarImageData, let ui = UIImage(data: d) {
                                    Image(uiImage: ui).resizable().scaledToFill()
                                        .frame(width: 44, height: 44).clipShape(Circle())
                                } else {
                                    Text(pet.avatarEmoji).font(.system(size: 24))
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.name)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("添加疫苗记录")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.goTeal)
                            }
                            Spacer()
                            Text("💉").font(.system(size: 28))
                        }
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // 疫苗名称
                        fieldCard {
                            HStack {
                                Image(systemName: "syringe")
                                    .foregroundStyle(Color.goCardCyan).frame(width: 22)
                                TextField("疫苗名称（如：狂犬病疫苗）", text: $vaccineName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 接种日期
                        fieldCard {
                            DatePicker("接种日期", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(Color.goPrimary)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        // 有效期
                        fieldCard {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("设置有效期")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Toggle("", isOn: $hasExpiry)
                                        .tint(Color.goPrimary).labelsHidden()
                                }
                                if hasExpiry {
                                    DatePicker("有效期至", selection: $expiryDate,
                                               in: date..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .tint(Color.goYellow)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.8))
                                }
                            }
                        }

                        // 到期提醒
                        if hasExpiry {
                            fieldCard {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "bell.badge")
                                            .foregroundStyle(Color.goYellow).frame(width: 22)
                                        Text("到期提醒")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Toggle("", isOn: $enableReminder)
                                            .tint(Color.goYellow).labelsHidden()
                                    }
                                    if enableReminder {
                                        HStack(spacing: 8) {
                                            Text("提前")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.primary.opacity(0.5))
                                            ForEach(reminderOptions, id: \.self) { days in
                                                Button {
                                                    reminderDaysBefore = days
                                                } label: {
                                                    Text("\(days)天")
                                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                                        .foregroundStyle(reminderDaysBefore == days ? Color.arkInk : .primary.opacity(0.5))
                                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                                        .background(
                                                            reminderDaysBefore == days ? Color.goYellow : .clear,
                                                            in: Capsule()
                                                        )
                                                        .glassEffect(reminderDaysBefore == days ? .regular.tint(Color.goYellow.opacity(0.4)) : .regular, in: Capsule())
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 医生/诊所
                        fieldCard {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundStyle(Color.goTeal).frame(width: 22)
                                TextField("医生 / 诊所（可选）", text: $vetName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 费用
                        fieldCard {
                            HStack {
                                Image(systemName: "yensign.circle")
                                    .foregroundStyle(Color.goYellow).frame(width: 22)
                                TextField("费用（可选）", text: $costText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 保存
                        Button(action: save) {
                            Text("保存疫苗记录")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("添加疫苗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
        }
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func save() {
        let log = PetHealthLog(date: date, type: .vaccine,
                               note: vaccineName.isEmpty ? "疫苗接种" : vaccineName,
                               pet: pet)
        log.vetName = vetName
        log.cost = Double(costText) ?? 0
        if hasExpiry { log.expirationDate = expiryDate }
        modelContext.insert(log)

        // 费用同步
        if let amount = Double(costText), amount > 0 {
            let expense = PetExpenseLog(date: date, amount: amount, category: .medical,
                                        note: vaccineName.isEmpty ? "疫苗接种" : vaccineName, pet: pet)
            modelContext.insert(expense)
        }

        // 到期提醒
        var reminderToSchedule: Reminder?
        if hasExpiry && enableReminder {
            let reminderDate = Calendar.current.date(
                byAdding: .day, value: -reminderDaysBefore, to: expiryDate
            ) ?? expiryDate
            if reminderDate > Date() {
                let event = Event(
                    title: "\(pet.name)疫苗即将到期",
                    startDate: reminderDate,
                    eventType: EventType.health.rawValue,
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: pet.id.uuidString
                )
                modelContext.insert(event)
                let reminder = Reminder(event: event, scheduledAt: reminderDate)
                reminder.status = "pending"
                modelContext.insert(reminder)
                reminderToSchedule = reminder
            }
        }

        modelContext.safeSave()
        if let reminderToSchedule {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(reminder: reminderToSchedule, context: modelContext, source: .detail)
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
