//
//  QuickWaterChangeDetailSheet.swift
//  Ohana
//
//  换水 + 滤芯管理详情半屏 Sheet
//

import SwiftUI
import SwiftData

struct QuickWaterChangeDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var waterIntervalDays: Int = 3
    @State private var filterCleanIntervalDays: Int = 14
    @State private var filterReplaceIntervalDays: Int = 90
    @State private var waterReminderOn = false
    @State private var filterReminderOn = false

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    private var lastWaterChange: PetCareLog? {
        pet.careLogs.filter { $0.type == CareType.waterChange.rawValue }.sorted { $0.date > $1.date }.first
    }

    private var lastFilterClean: PetCareLog? {
        pet.careLogs.filter { $0.type == CareType.filterClean.rawValue }.sorted { $0.date > $1.date }.first
    }

    private var recentLogs: [PetCareLog] {
        pet.careLogs.filter {
            $0.type == CareType.waterChange.rawValue || $0.type == CareType.filterClean.rawValue
        }.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    private func daysSince(_ log: PetCareLog?) -> Int? {
        guard let l = log else { return nil }
        return Calendar.current.dateComponents([.day], from: l.date, to: Date()).day
    }

    private var petKey: String { pet.id.uuidString }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        petHeader
                        ExecutorPickerBar(tint: themeColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        waterChangeSection
                        filterSection
                        historySection
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
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { loadSettings() }
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
                    .foregroundStyle(.primary)
                Text("水质管理")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Text("🪣").font(.system(size: 28))
        }
    }

    // MARK: - Water Change
    private var waterChangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("💧").font(.system(size: 14))
                Text("换水")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack {
                if let d = daysSince(lastWaterChange) {
                    statusPill(d == 0 ? "今天已换" : "\(d)天前", isOverdue: d >= waterIntervalDays)
                } else {
                    statusPill("未记录", isOverdue: false)
                }
                Spacer()
                Button { doWaterChange() } label: {
                    Text("立即换水")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("换水间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $waterIntervalDays, in: 1...30) {
                    Text("\(waterIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .onChange(of: waterIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "waterInterval_\(petKey)")
                }
            }

            Toggle(isOn: $waterReminderOn) {
                Text("到期提醒")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(themeColor)
            .onChange(of: waterReminderOn) { _, on in
                UserDefaults.standard.set(on, forKey: "waterReminder_\(petKey)")
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("🔧").font(.system(size: 14))
                Text("滤芯管理")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack {
                if let d = daysSince(lastFilterClean) {
                    statusPill(d == 0 ? "今天已清" : "\(d)天前清洗", isOverdue: d >= filterCleanIntervalDays)
                } else {
                    statusPill("未记录", isOverdue: false)
                }
                Spacer()
                Button { doFilterClean() } label: {
                    Text("清理滤芯")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("清洗间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $filterCleanIntervalDays, in: 1...60) {
                    Text("\(filterCleanIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .onChange(of: filterCleanIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "filterCleanInterval_\(petKey)")
                }
            }

            HStack {
                Text("更换间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $filterReplaceIntervalDays, in: 7...365) {
                    Text("\(filterReplaceIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .onChange(of: filterReplaceIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "filterReplaceInterval_\(petKey)")
                }
            }

            Toggle(isOn: $filterReminderOn) {
                Text("到期提醒")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(themeColor)
            .onChange(of: filterReminderOn) { _, on in
                UserDefaults.standard.set(on, forKey: "filterReminder_\(petKey)")
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近记录")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            if recentLogs.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentLogs) { log in
                    HStack {
                        Text(log.careType.emoji).font(.system(size: 14))
                        Text(log.careType.label)
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

    private var removeButton: some View {
        Button(role: .destructive) { onRemove(); dismiss() } label: {
            Text("移除此快捷入口")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.goRed)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private func statusPill(_ text: String, isOverdue: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(isOverdue ? Color.goRed : themeColor)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background((isOverdue ? Color.goRed : themeColor).opacity(0.12), in: Capsule())
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        waterIntervalDays = max(1, d.integer(forKey: "waterInterval_\(petKey)"))
        if waterIntervalDays == 0 { waterIntervalDays = 3 }
        filterCleanIntervalDays = max(1, d.integer(forKey: "filterCleanInterval_\(petKey)"))
        if filterCleanIntervalDays == 0 { filterCleanIntervalDays = 14 }
        filterReplaceIntervalDays = max(7, d.integer(forKey: "filterReplaceInterval_\(petKey)"))
        if filterReplaceIntervalDays == 0 { filterReplaceIntervalDays = 90 }
        waterReminderOn = d.bool(forKey: "waterReminder_\(petKey)")
        filterReminderOn = d.bool(forKey: "filterReminder_\(petKey)")
    }

    private func doWaterChange() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordCare(
            pet: pet,
            type: .waterChange,
            context: modelContext,
            executorId: eid,
            reward: .general(humanReward: 15, petReward: 20, emoji: CareType.waterChange.emoji, title: "\(pet.name) 换水奖励")
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func doFilterClean() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordCare(
            pet: pet,
            type: .filterClean,
            context: modelContext,
            executorId: eid,
            reward: .general(humanReward: 25, petReward: 40, emoji: CareType.filterClean.emoji, title: "\(pet.name) 清理滤材报酬")
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
