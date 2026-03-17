//
//  PottyOverviewView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct PottyOverviewView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]
    @State private var showingAddLog = false

    private var sortedLogs: [PetPottyLog] {
        pet.pottyLogs.sorted(by: { $0.date > $1.date })
    }

    private var todayCount: Int {
        pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    private var last7DaysCounts: [(date: Date, count: Int)] {
        (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let count = pet.pottyLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count
            return (date, count)
        }.reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArkBackgroundView()

                VStack(spacing: 0) {
                    // ── 顶部深色图表区 ──
                    chartSection
                        .frame(maxHeight: .infinity)

                    // ── 下部白色前置卡片 ──
                    recordListLayer
                        .frame(height: UIScreen.main.bounds.height * 0.52)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("💩 噗噗电台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
            }
        }
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("便便追踪")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(todayCount)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("次")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.brown.opacity(0.9))
                        Text("· 今日")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }
                Spacer()
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 2))
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 40))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 7日趋势柱状图
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7DaysCounts, id: \.date) { item in
                    VStack(spacing: 4) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                Calendar.current.isDateInToday(item.date)
                                    ? Color(red: 0.6, green: 0.4, blue: 0.2)
                                    : (item.count > 0
                                       ? Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.4)
                                       : Color.primary.opacity(0.08))
                            )
                            .frame(height: max(6, CGFloat(item.count) * 18))
                        Text(item.date, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90, alignment: .bottom)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // 快速打卡按钮行
            HStack(spacing: 10) {
                ForEach(PottyType.allCases, id: \.rawValue) { type in
                    Button { logPotty(type: type) } label: {
                        VStack(spacing: 4) {
                            Text(type.emoji).font(.system(size: 22))
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)

            Spacer()
        }
    }

    // MARK: - Record List Layer
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                HStack {
                    Text("历史记录")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(sortedLogs.count) 条")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedLogs) { log in
                            pottyRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text("还没有记录\n点击上方按钮开始打卡")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func pottyRow(log: PetPottyLog) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                    .frame(width: 36, height: 36)
                Text(log.pottyType.emoji).font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(log.pottyType.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                Text(log.date, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(log.date, format: .dateTime.hour().minute())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.6, green: 0.4, blue: 0.2))

            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions
    private func logPotty(type: PottyType) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let log = PetPottyLog(date: Date(), type: type, pet: pet)
        modelContext.insert(log)
        if let h = households.first { IslandProsperityEXP.addEXP(source: .potty, household: h, context: modelContext) }
        modelContext.safeSave()
    }
}
