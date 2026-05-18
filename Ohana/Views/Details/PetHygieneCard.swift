//
//  PetHygieneCard.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct PetHygieneCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    @State private var longPressedType: HygieneType? = nil
    @State private var showHygieneDetail = false
    @State private var undoLog: PetHygieneLog? = nil
    @State private var undoLabel: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                // Header — NavigationLink 进入护理详情页
                NavigationLink(destination: PetHygieneDetailView(pet: pet)) {
                    HStack {
                        Text("✨").font(.system(size: 14))
                        Text("护理打卡")
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                    // Only show items with records
                    let recordedTypes = HygieneType.allCases.filter { type in
                        pet.hygieneLogs.contains { $0.type == type.rawValue }
                    }

                    if recordedTypes.isEmpty {
                        Text("暂无记录")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            .padding(.vertical, 4)
                    } else {
                        let cols = Array(repeating: GridItem(.flexible()), count: min(recordedTypes.count, 5))
                        LazyVGrid(columns: cols, spacing: 8) {
                            ForEach(recordedTypes, id: \.rawValue) { type in
                                HygieneCheckButton(pet: pet, type: type, households: households, onUndo: { log in
                                    undoLog = log
                                    undoLabel = type.rawValue
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        if undoLog?.id == log.id {
                                            withAnimation(GoMotion.feedback) { undoLog = nil }
                                        }
                                    }
                                }) {
                                    longPressedType = type
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 4)

            // U16: 3秒撤回 toast
            if undoLog != nil {
                HStack(spacing: 8) {
                    Text("✨ \(undoLabel) 已打卡")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Button {
                        if let log = undoLog {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        }
                        withAnimation(GoMotion.feedback) { undoLog = nil }
                    } label: {
                        Text("撤回")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.arkInk.opacity(0.8), in: Capsule())
                .padding(.horizontal, 8).padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            }
            .animation(GoMotion.feedback, value: undoLog != nil)
            .sheet(item: $longPressedType) { type in
                HygieneTodoSheet(pet: pet, type: type, accent: Color(hex: pet.safeThemeColorHex))
                    .presentationDetents([.height(520)])
                    .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - U16 护理详情 Sheet（GO Club 沉浸式重构）
private struct HygieneDetailSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var isLitterPet: Bool {
        ["猫", "兔子", "仓鼠", "龙猫", "豚鼠"].contains(pet.species)
    }

    private func daysSince(_ type: HygieneType) -> Int? {
        let last = pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }.first
        guard let d = last else { return nil }
        return Calendar.current.dateComponents([.day], from: d.date, to: Date()).day
    }
    private func statusColor(_ type: HygieneType) -> Color {
        guard let d = daysSince(type) else { return .primary.opacity(0.25) }
        let p = Double(d) / Double(type.cycleDays)
        if p < 0.5 { return Color.goTeal }
        if p < 0.85 { return Color.goYellow }
        return Color.goRed
    }
    private func last7(_ type: HygieneType) -> [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return pet.hygieneLogs.filter { $0.type == type.rawValue && cal.isDate($0.date, inSameDayAs: d) }.count
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground()

            VStack(spacing: 0) {
                // ── 顶栏
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .goGlassBackground(Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("护理打卡")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(pet.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    }
                    Spacer()
                    // 占位保持居中
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 14)

                // ── 5图标状态横排（带环形进度）
                HStack(spacing: 0) {
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        let color = statusColor(type)
                        let days = daysSince(type)
                        let progress: Double = {
                            guard let d = days else { return 0 }
                            return min(1, Double(d) / Double(type.cycleDays))
                        }()
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().stroke(color.opacity(0.2), lineWidth: 4)
                                    .frame(width: 52, height: 52)
                                Circle()
                                    .trim(from: 0, to: 1 - progress)
                                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 52, height: 52)
                                    .rotationEffect(.degrees(-90))
                                Image(systemName: type.systemIconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(color)
                            }
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                            if let d = days {
                                Text(d == 0 ? "今天" : "\(d)天前")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(color)
                            } else {
                                Text("未记录")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)

                // ── 下层白色面板
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(hex: "F2F0F5"))
                        .ignoresSafeArea(edges: .bottom)

                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.arkInk.opacity(0.1))
                            .frame(width: 36, height: 4)
                            .padding(.top, 10).padding(.bottom, 12)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 14) {
                                ForEach(HygieneType.allCases, id: \.rawValue) { type in
                                    hygieneSectionCard(type)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 48)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func hygieneSectionCard(_ type: HygieneType) -> some View {
        let logs = pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
        let color = statusColor(type)
        let bars = last7(type)
        let maxBar = max(bars.max() ?? 1, 1)
        let days = daysSince(type)

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: type.systemIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                Spacer()
                if let d = days {
                    Text(d == 0 ? "今天已打卡" : "\(d)天前 · 每\(type.cycleDays)天一次")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(color.opacity(0.1), in: Capsule())
                }
            }

            // 7天 mini bar
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                    let h = max(4, CGFloat(v) / CGFloat(maxBar) * 28)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(v > 0 ? color : Color.arkInk.opacity(0.06))
                        .frame(maxWidth: .infinity, minHeight: 4, maxHeight: h)
                }
            }
            .frame(height: 28)

            // 近期记录
            if logs.isEmpty {
                Text("暂无记录").font(.system(size: 12)).foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 4)
            } else {
                VStack(spacing: 5) {
                    ForEach(logs.prefix(3)) { log in
                        HStack {
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.arkInk.opacity(0.7))
                            Spacer()
                            Button {
                                modelContext.delete(log); modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.goCardWhite, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - C6 Hygiene Check Button（仅打卡按钮，状态颜色+长按设置）
private struct HygieneCheckButton: View {
    let pet: Pet
    let type: HygieneType
    let households: [Household]
    var onUndo: ((PetHygieneLog) -> Void)? = nil  // U16: 撤回回调
    let onLongPress: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var justChecked = false

    private var logs: [PetHygieneLog] {
        pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
    }
    private var daysSince: Int {
        logs.first.map { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 } ?? 999
    }
    private var progress: Double { min(1.0, Double(daysSince) / Double(type.cycleDays)) }
    private var statusColor: Color {
        progress < 0.5 ? Color.goTeal : (progress < 0.85 ? Color.goYellow : Color.goRed)
    }
    private var isDoneToday: Bool {
        logs.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }

    var body: some View {
        Button { checkIn() } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(justChecked || isDoneToday ? statusColor : statusColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(statusColor.opacity(0.3), lineWidth: 1))
                    Image(systemName: type.systemIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(justChecked || isDoneToday ? .white : statusColor)
                }
                Text(type.rawValue)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDoneToday ? statusColor : .primary.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLongPress()
            }
        )
    }

    private func checkIn() {
        guard !isDoneToday else { return }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet, executorId: executorId)
        modelContext.insert(log)
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(GoMotion.feedback) { justChecked = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { justChecked = false }
        }
        // U16: 通知父视图显示撤回 toast
        onUndo?(log)
    }
}

// MARK: - Hygiene Todo Sheet (长按弹出：开始时间 + 结束时间 + 重复频率 → 自动写入日历)
struct HygieneTodoSheet: View {
    let pet: Pet
    let type: HygieneType
    /// 与护理页、钱包卡一致：传入 `Color(hex: pet.themeColorHex)`
    var accent: Color = Color.goPrimary
    var onSave: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Date()
    @State private var isAllDay: Bool = true
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var hasEndDate: Bool = false
    @State private var repeatDays: Int = 0
    @State private var customNote: String = ""

    private var repeatDescription: String {
        switch repeatDays {
        case 0: return "只安排这一次"
        case 1: return "每天重复"
        default: return "每 \(repeatDays) 天重复"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 18)

            // 标题
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: type.systemIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("设置护理计划")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("\(pet.name) · \(type.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent.opacity(0.85))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // ── 开始日期（提醒默认当天 9:00）
                    settingRow(icon: "calendar", iconColor: accent, label: "开始日期") {
                        DatePicker("", selection: $startDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .tint(accent)
                            .labelsHidden()
                    }

                    settingRow(icon: "sun.max", iconColor: accent.opacity(0.9), label: "全天日程") {
                        Toggle("", isOn: $isAllDay)
                            .tint(accent)
                            .labelsHidden()
                    }

                    if !isAllDay {
                        settingRow(icon: "clock", iconColor: accent.opacity(0.85), label: "时间") {
                            DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(accent)
                                .labelsHidden()
                        }
                    }

                    // ── 结束日期（可选）
                    settingRow(icon: "calendar.badge.checkmark", iconColor: accent.opacity(0.9), label: "结束日期") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $hasEndDate)
                                .tint(accent)
                                .labelsHidden()
                            if hasEndDate {
                                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .tint(accent)
                                    .labelsHidden()
                            }
                        }
                    }

                    // ── 护理周期
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat").font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                            Text("护理周期").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText)
                        }
                        .padding(.horizontal, 4)
                        HStack(spacing: 14) {
                            Button {
                                repeatDays = max(0, repeatDays - 1)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(repeatDays == 0 ? .secondary : accent)
                                    .frame(width: 38, height: 38)
                                    .background(Color(.systemBackground).opacity(0.82), in: Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(repeatDays == 0)

                            VStack(spacing: 2) {
                                Text(repeatDays == 0 ? "不重复" : "\(repeatDays) 天")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(repeatDescription)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            .frame(maxWidth: .infinity)

                            Button {
                                repeatDays = min(365, repeatDays + 1)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(accent)
                                    .frame(width: 38, height: 38)
                                    .background(Color(.systemBackground).opacity(0.82), in: Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // ── 备注
                    settingRow(icon: "note.text", iconColor: accent.opacity(0.65), label: "备注") {
                        TextField("可选备注", text: $customNote)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tint(accent)
                    }
                }
                .padding(.bottom, 24)
            }

            // ── 保存按钮
            Button { save() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                    Text("添加到日历")
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helper row builder
    private func settingRow<V: View>(icon: String, iconColor: Color, label: String, @ViewBuilder content: () -> V) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Save（写单个 Event + recurrenceDays，不展开实例）
    private func save() {
        let cal = Calendar.current
        let title = "\(pet.name) — \(type.rawValue)"
        let fullTitle = customNote.isEmpty ? title : "\(title) — \(customNote)"

        let dayStart = cal.startOfDay(for: startDate)
        let time = cal.dateComponents([.hour, .minute], from: startTime)
        let eventStart = isAllDay
        ? dayStart
        : (cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: dayStart) ?? dayStart)
        let reminderTime = isAllDay
        ? (cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart)
        : eventStart
        var eventEndDate: Date? = nil
        if hasEndDate {
            let endDay = cal.startOfDay(for: endDate)
            eventEndDate = isAllDay
            ? endDay
            : (cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: endDay) ?? endDay)
        }

        let event = Event(
            title: fullTitle,
            startDate: eventStart,
            endDate: eventEndDate,
            isAllDay: isAllDay,
            eventType: EventType.grooming.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = repeatDays
        if hasEndDate {
            event.recurrenceEndDate = cal.startOfDay(for: endDate)
        } else if repeatDays > 0 {
            event.recurrenceEndDate = cal.date(byAdding: .year, value: 1, to: dayStart)
        }
        if repeatDays > 0 {
            CarePlanCalendarSync.suppressDefaultPlan(kind: "groom", pet: pet, context: modelContext)
            HygieneType.setCustomCycleDays(repeatDays, for: type, petId: pet.id)
        }
        modelContext.insert(event)

        let reminder = Reminder(event: event, scheduledAt: reminderTime)
        reminder.status = "pending"
        modelContext.insert(reminder)

        modelContext.safeSave()
        Task { @MainActor in
            await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: modelContext, source: .detail)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSave?()
        dismiss()
    }
}

extension HygieneType: Identifiable {
    public var id: String { rawValue }
}
