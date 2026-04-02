//
//  PetHealthLogCard.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct PetHealthLogCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @State private var showingAllLogs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goRed)
                Text("健康日志")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(pet.healthLogs.count) 条")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
            }

            let recentLogs = pet.healthLogs.sorted { $0.date > $1.date }.prefix(5)
            ForEach(Array(recentLogs)) { log in
                HStack(spacing: 10) {
                    Text(log.healthLogType.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.type)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        if !log.note.isEmpty {
                            Text(log.note)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary.opacity(0.4))
                                .lineLimit(1)
                        }
                        // 显示有效期
                        if let expirationDate = log.expirationDate {
                            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                            let isExpired = daysUntil <= 0
                            let isUrgent = daysUntil <= 7 && daysUntil > 0
                            
                            HStack(spacing: 4) {
                                Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "calendar")
                                    .font(.system(size: 10))
                                Text(isExpired ? "已过期" : (isUrgent ? "剩余\(daysUntil)天" : "有效期至\(expirationDate.formatted(.dateTime.month().day()))"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(isExpired ? Color.goRed : (isUrgent ? Color.goYellow : .primary.opacity(0.5)))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((isExpired ? Color.goRed : (isUrgent ? Color.goYellow : .primary.opacity(0.08))).opacity(0.2), in: Capsule())
                        }
                        
                        // 显示下次体检提醒（仅体检记录）
                        if log.healthLogType == .checkup, let nextCheckupDate = log.nextCheckupDate {
                            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextCheckupDate).day ?? 0
                            let isOverdue = daysUntil <= 0
                            let isSoon = daysUntil <= 30 && daysUntil > 0
                            
                            HStack(spacing: 4) {
                                Image(systemName: "bell.circle")
                                    .font(.system(size: 10))
                                Text(isOverdue ? "体检已过期" : (isSoon ? "体检剩余\(daysUntil)天" : "下次体检\(nextCheckupDate.formatted(.dateTime.month().day()))"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(isOverdue ? Color.goRed : (isSoon ? Color.goYellow : Color.goTeal))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((isOverdue ? Color.goRed : (isSoon ? Color.goYellow : Color.goTeal)).opacity(0.15), in: Capsule())
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(log.date, style: .date)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
                        if log.cost > 0 {
                            Text("¥\(Int(log.cost))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.goYellow)
                        }
                    }
                }
            }

            if pet.healthLogs.isEmpty {
                Text("暂无健康日志")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            if pet.healthLogs.count > 5 {
                Button { showingAllLogs = true } label: {
                    HStack(spacing: 4) {
                        Text("查看全部 \(pet.healthLogs.count) 条")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.goPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
        .navigationDestination(isPresented: $showingAllLogs) {
            HealthLogListView(pet: pet)
        }
    }
}

// MARK: - Full Health Log List
struct HealthLogListView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: HealthLogType? = nil

    private var filteredLogs: [PetHealthLog] {
        let sorted = pet.healthLogs.sorted { $0.date > $1.date }
        guard let type = selectedType else { return sorted }
        return sorted.filter { $0.type == type.rawValue }
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            ScrollView {
                VStack(spacing: 12) {
                    typeFilterChips
                        .padding(.horizontal, 16)
                    ForEach(filteredLogs) { log in
                        healthLogRow(log)
                            .padding(.horizontal, 16)
                    }
                    if filteredLogs.isEmpty {
                        Text("暂无记录")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                            .padding(.top, 40)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle("\(pet.name) 健康日志")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var typeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "全部", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(HealthLogType.allCases, id: \.rawValue) { type in
                    filterChip(label: "\(type.emoji) \(type.rawValue)", isSelected: selectedType == type) {
                        selectedType = (selectedType == type) ? nil : type
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : .primary.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.goPrimary : .clear, in: Capsule())
                .glassEffect(isSelected ? .regular.tint(Color.goPrimary.opacity(0.2)) : .regular, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func healthLogRow(_ log: PetHealthLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goRed.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(log.healthLogType.emoji)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(log.type)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if !log.note.isEmpty {
                    Text(log.note)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.5))
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(log.date, style: .date)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                if log.cost > 0 {
                    Text("¥\(Int(log.cost))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 16)
    }
}
