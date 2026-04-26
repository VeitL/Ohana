//
//  QuickLitterDetailSheet.swift
//  Ohana
//
//  铲屎详情页 — 铲屎打卡 + 猫砂更换管理 + 提醒
//

import SwiftUI
import SwiftData

struct QuickLitterDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var petKey: String { pet.id.uuidString }

    @State private var litterChangeIntervalDays: Int = 14
    @State private var litterReminderOn = false
    @State private var litterCycleAnchorDate: Date = Date()
    @State private var hasLitterEndDate: Bool = false
    @State private var litterPlanEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var scoopIntervalDays: Int = 1
    @State private var scoopAnchorDate: Date = Date()
    @State private var scoopReminderOn = false
    @State private var hasScoopEndDate: Bool = false
    @State private var scoopPlanEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    private var todayLitterCount: Int {
        pet.careLogs.filter { $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }

    private var recentLitterLogs: [PetCareLog] {
        Array(pet.careLogs.filter { $0.type == CareType.litter.rawValue }.sorted { $0.date > $1.date }.prefix(15))
    }

    private var lastFullChange: Date? {
        let key = "lastLitterChangeDate_\(petKey)"
        let ti = UserDefaults.standard.double(forKey: key)
        return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
    }

    private var daysSinceFullChange: Int? {
        guard let d = lastFullChange else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        petHeader
                        ExecutorPickerBar(tint: themeColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        todayStats
                        scoopButton
                        scoopPlanSection
                        litterChangeSection
                        recentLogList
                        removeQuickActionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaPadding(.bottom, 28)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Header
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
                    .foregroundStyle(.primary)
                Text("猫砂管理")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Image(systemName: "tray.full.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(themeColor)
        }
    }

    // MARK: - Today Stats
    private var todayStats: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(todayLitterCount)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(themeColor)
                Text("今日铲屎次数")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Scoop Button
    private var scoopButton: some View {
        Button { doScoop() } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("铲屎打卡")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(themeColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scoop Plan (间隔 + 起算日 + 日历)
    private var scoopPlanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text("铲屎计划")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text("从「起算日」开始按间隔推算下次铲屎；设置会立即写入本机，并可在下方打开「同步到日历」后在日历页查看。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("铲屎间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $scoopIntervalDays, in: 1...14) {
                    Text("\(scoopIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .onChange(of: scoopIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "scoopIntervalDays_\(petKey)")
                }
            }

            DatePicker("起算日", selection: $scoopAnchorDate, displayedComponents: .date)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .onChange(of: scoopAnchorDate) { _, d in
                    UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "scoopAnchorDate_\(petKey)")
                }

            Toggle(isOn: $hasScoopEndDate) {
                Text("设置截止日期")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(themeColor)
            if hasScoopEndDate {
                DatePicker("截止日期", selection: $scoopPlanEndDate, in: scoopAnchorDate..., displayedComponents: .date)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tint(themeColor)
                    .onChange(of: scoopPlanEndDate) { _, d in
                        UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "scoopEndDate_\(petKey)")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Toggle(isOn: $scoopReminderOn) {
                Text("同步铲屎计划到日历")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(themeColor)
            .onChange(of: scoopReminderOn) { _, on in
                UserDefaults.standard.set(on, forKey: "scoopReminder_\(petKey)")
            }

            planSaveButton(title: "保存并同步日历") { saveScoopPlanToCalendar() }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Litter Change Section
    private var litterChangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text("彻底换砂")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack {
                if let d = daysSinceFullChange {
                    statusPill(d == 0 ? "今天已换" : "\(d)天前", isOverdue: d >= litterChangeIntervalDays)
                } else {
                    statusPill("未记录", isOverdue: false)
                }
                Spacer()
                Button { doFullChange() } label: {
                    Text("立即换砂")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("换砂周期从「起算日」累计；点「立即换砂」会同时更新上次换砂与起算日。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DatePicker("换砂周期起算日", selection: $litterCycleAnchorDate, displayedComponents: .date)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .onChange(of: litterCycleAnchorDate) { _, d in
                    UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(petKey)")
                }

            Toggle(isOn: $hasLitterEndDate) {
                Text("设置截止日期")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(themeColor)
            if hasLitterEndDate {
                DatePicker("截止日期", selection: $litterPlanEndDate, in: litterCycleAnchorDate..., displayedComponents: .date)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tint(themeColor)
                    .onChange(of: litterPlanEndDate) { _, d in
                        UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "litterEndDate_\(petKey)")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack {
                Text("换砂间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $litterChangeIntervalDays, in: 3...60) {
                    Text("\(litterChangeIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .onChange(of: litterChangeIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "litterChangeInterval_\(petKey)")
                }
            }

            Toggle(isOn: $litterReminderOn) {
                Text("同步换砂计划到日历")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(themeColor)
            .onChange(of: litterReminderOn) { _, on in
                UserDefaults.standard.set(on, forKey: "litterReminder_\(petKey)")
            }

            planSaveButton(title: "保存并同步日历") { saveLitterChangePlanToCalendar() }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Recent Logs
    private var recentLogList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近铲屎记录")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            if recentLitterLogs.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentLitterLogs) { log in
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeColor)
                        Text("铲屎")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(log.date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Button {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        } label: {
                            Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Remove Footer
    private var removeQuickActionFooter: some View {
        VStack(spacing: 14) {
            Divider().opacity(0.35)
            Button(role: .destructive) { onRemove(); dismiss() } label: {
                Text("移除此快捷入口")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.goRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers
    private func planSaveButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func saveScoopPlanToCalendar() {
        let d = UserDefaults.standard
        d.set(scoopIntervalDays, forKey: "scoopIntervalDays_\(petKey)")
        d.set(scoopAnchorDate.timeIntervalSince1970, forKey: "scoopAnchorDate_\(petKey)")
        d.set(scoopReminderOn, forKey: "scoopReminder_\(petKey)")
        CarePlanCalendarSync.syncScoopPlan(
            pet: pet, context: modelContext,
            intervalDays: scoopIntervalDays, enabled: scoopReminderOn, anchor: scoopAnchorDate
        )
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveLitterChangePlanToCalendar() {
        let d = UserDefaults.standard
        d.set(litterChangeIntervalDays, forKey: "litterChangeInterval_\(petKey)")
        d.set(litterCycleAnchorDate.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(petKey)")
        d.set(litterReminderOn, forKey: "litterReminder_\(petKey)")
        CarePlanCalendarSync.syncLitterFullChangePlan(
            pet: pet, context: modelContext,
            intervalDays: litterChangeIntervalDays, enabled: litterReminderOn,
            cycleAnchor: litterCycleAnchorDate
        )
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func statusPill(_ text: String, isOverdue: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(isOverdue ? Color.goRed : .primary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background((isOverdue ? Color.goRed : themeColor).opacity(0.12), in: Capsule())
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        let li = d.integer(forKey: "litterChangeInterval_\(petKey)")
        litterChangeIntervalDays = li > 0 ? li : 14
        litterReminderOn = d.bool(forKey: "litterReminder_\(petKey)")
        let lca = d.double(forKey: "litterChangeCycleAnchor_\(petKey)")
        if lca > 0 {
            litterCycleAnchorDate = Date(timeIntervalSince1970: lca)
        } else if let lf = lastFullChange {
            litterCycleAnchorDate = Calendar.current.startOfDay(for: lf)
        } else {
            litterCycleAnchorDate = Calendar.current.startOfDay(for: Date())
        }

        let si = d.integer(forKey: "scoopIntervalDays_\(petKey)")
        scoopIntervalDays = si > 0 ? si : 1
        let sa = d.double(forKey: "scoopAnchorDate_\(petKey)")
        scoopAnchorDate = sa > 0 ? Date(timeIntervalSince1970: sa) : Calendar.current.startOfDay(for: Date())
        scoopReminderOn = d.bool(forKey: "scoopReminder_\(petKey)")

    }

    // MARK: - Actions
    private func doScoop() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: eid, reward: .potty(isLitter: true))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func doFullChange() {
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: "lastLitterChangeDate_\(petKey)")
        UserDefaults.standard.set(now, forKey: "litterChangeCycleAnchor_\(petKey)")
        litterCycleAnchorDate = Calendar.current.startOfDay(for: Date())
        doScoop()
        CarePlanCalendarSync.syncLitterFullChangePlan(
            pet: pet, context: modelContext,
            intervalDays: litterChangeIntervalDays, enabled: litterReminderOn,
            cycleAnchor: litterCycleAnchorDate
        )
    }
}
