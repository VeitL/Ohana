//
//  QuickPlayDetailSheet.swift
//  Ohana
//
//  逗玩详情半屏 Sheet — 统计 + 7天图表 + 打卡
//

import SwiftUI
import SwiftData

struct QuickPlayDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    @State private var showingPlayPlanEditor = false
    @State private var playPlanIntervalDays = 3
    @State private var playPlanAnchorDate = Date()
    @State private var saveToastMessage: String?

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var petKey: String { pet.id.uuidString }
    private var playPlanTitle: String { "\(pet.name) 陪玩计划" }
    private var playPlanEvent: Event? {
        allEvents
            .filter {
                $0.relatedEntityId == petKey &&
                $0.title == playPlanTitle
            }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private struct DayCount: Identifiable {
        var id: Date { day }
        let day: Date
        let count: Int
    }

    private var monthPlayStrip: [DayCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<28).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = pet.careLogs.filter {
                $0.type == CareType.play.rawValue && cal.isDate($0.date, inSameDayAs: d)
            }.count
            return DayCount(day: d, count: count)
        }
    }

    private var recentLogs: [PetCareLog] {
        pet.careLogs.filter { $0.type == CareType.play.rawValue }
            .sorted { $0.date > $1.date }
            .prefix(15).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        petHeader
                        ExecutorPickerBar(tint: themeColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        playMonthStripCard
                        playPlanModule
                        checkInButton
                        logList
                        removeButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let saveToastMessage {
                    Text(saveToastMessage)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(themeColor, in: Capsule())
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingPlayPlanEditor) {
                NavigationStack {
                    playPlanEditor
                        .navigationTitle(playPlanEvent == nil ? "添加陪玩计划" : "陪玩计划")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showingPlayPlanEditor = false } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .frame(width: 38, height: 34)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                }
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.ohanaCardSurface)
                .presentationCornerRadius(30)
            }
            .onAppear {
                loadPlayPlanDraft()
            }
        }
    }

    private var petHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(themeColor.opacity(0.15)).frame(width: 48, height: 48)
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 48, height: 48).clipShape(Circle())
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 24))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("逗玩记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
            }
            Spacer()
            Image(systemName: "tennisball.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(themeColor)
        }
    }

    private var playMonthStripCard: some View {
        let pts = monthPlayStrip
        let maxH: CGFloat = 22
        return VStack(alignment: .leading, spacing: 8) {
            Text("近 28 天")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 2) {
                ForEach(pts) { pt in
                    let h = min(maxH, 4 + CGFloat(min(pt.count, 4)) * 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(themeColor.opacity(pt.count > 0 ? 0.72 : 0.12))
                        .frame(width: 5, height: h)
                }
            }
            .frame(height: maxH, alignment: .bottom)
        }
        .padding(.vertical, 4)
    }

    private var playPlanModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(themeColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("陪玩计划")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(playPlanSubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                Button {
                    loadPlayPlanDraft()
                    showingPlayPlanEditor = true
                } label: {
                    Text(playPlanEvent == nil ? "添加" : "编辑")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if let event = playPlanEvent {
                HStack(spacing: 8) {
                    planPill("每 \(max(event.recurrenceDays, 1)) 天", icon: "repeat")
                    planPill(nextPlayPlanText(for: event.startDate), icon: "clock")
                }
            }
        }
        .padding(16)
        .background(Color.ohanaControlFill.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var playPlanSubtitle: String {
        guard let event = playPlanEvent else {
            return "默认不再自动创建每日陪玩；需要提醒时手动添加。"
        }
        return "下次 \(nextPlayPlanText(for: event.startDate)) · 可随时修改或关闭"
    }

    private func planPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.ohanaCardSurface.opacity(0.72), in: Capsule())
    }

    private var playPlanEditor: some View {
        ZStack {
            OhanaAppBackground()
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("计划频率")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack {
                        Text("每 \(playPlanIntervalDays) 天")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Stepper("", value: $playPlanIntervalDays, in: 1...30)
                            .labelsHidden()
                    }
                }
                .padding(16)
                .background(Color.ohanaControlFill.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                DatePicker("起算日", selection: $playPlanAnchorDate, displayedComponents: .date)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(16)
                    .background(Color.ohanaControlFill.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack(spacing: 10) {
                    if playPlanEvent != nil {
                        Button(role: .destructive) {
                            deletePlayPlan()
                        } label: {
                            Text("关闭计划")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }

                    Button {
                        savePlayPlan()
                    } label: {
                        Text("保存计划")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeColor, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private var checkInButton: some View {
        Button { commitPlay() } label: {
            HStack(spacing: 8) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("逗玩打卡")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(themeColor, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近记录")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if recentLogs.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentLogs) { log in
                    HStack {
                        Text(log.date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                        Spacer()
                        Button {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.4))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var removeButton: some View {
        Button(role: .destructive) { onRemove(); dismiss() } label: {
            Text("移除此快捷入口")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.goRed)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func commitPlay() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let oat = QuestManager.OhanaActionType.general(humanReward: 10, petReward: 12, emoji: "🎾", title: "\(pet.name) 互动奖励")
        CareEventService.recordCare(pet: pet, type: .play, context: modelContext, executorId: eid, reward: oat)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func loadPlayPlanDraft() {
        if let event = playPlanEvent {
            playPlanIntervalDays = max(1, event.recurrenceDays)
            playPlanAnchorDate = event.startDate
        } else {
            playPlanIntervalDays = 3
            playPlanAnchorDate = Date()
        }
    }

    private func savePlayPlan() {
        CarePlanCalendarSync.syncPlayPlan(
            pet: pet,
            context: modelContext,
            intervalDays: playPlanIntervalDays,
            enabled: true,
            anchor: playPlanAnchorDate
        )
        showingPlayPlanEditor = false
        showToast("陪玩计划已保存")
        Task { @MainActor in
            if let event = fetchPlayPlanEvent() {
                await ReminderSchedulingService.scheduleManyIfNeeded(reminders: event.reminders, context: modelContext, source: .detail)
            }
        }
    }

    private func deletePlayPlan() {
        CarePlanCalendarSync.syncPlayPlan(
            pet: pet,
            context: modelContext,
            intervalDays: 0,
            enabled: false,
            anchor: playPlanAnchorDate
        )
        showingPlayPlanEditor = false
        showToast("陪玩计划已关闭")
    }

    private func fetchPlayPlanEvent() -> Event? {
        let key = petKey
        let title = playPlanTitle
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> {
                $0.relatedEntityId == key && $0.title == title
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func showToast(_ message: String) {
        withAnimation(GoMotion.page) {
            saveToastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(GoMotion.page) {
                if saveToastMessage == message {
                    saveToastMessage = nil
                }
            }
        }
    }

    private func nextPlayPlanText(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInTomorrow(date) { return "明天" }
        return date.formatted(.dateTime.month().day())
    }
}
