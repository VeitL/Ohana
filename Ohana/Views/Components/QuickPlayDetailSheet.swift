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

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

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
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        petHeader
                        ExecutorPickerBar(tint: themeColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        playMonthStripCard
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
                            .foregroundStyle(.secondary)
                    }
                }
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
                    .foregroundStyle(.primary)
                Text("逗玩记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
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
                .foregroundStyle(.secondary)
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
        .buttonStyle(.plain)
    }

    private var logList: some View {
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
                        Text(log.date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                        Button {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.4))
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

    private func commitPlay() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let oat = QuestManager.OhanaActionType.general(humanReward: 10, petReward: 12, emoji: "🎾", title: "\(pet.name) 互动奖励")
        CareEventService.recordCare(pet: pet, type: .play, context: modelContext, executorId: eid, reward: oat)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
