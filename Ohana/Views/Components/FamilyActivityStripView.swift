//
//  FamilyActivityStripView.swift
//  Ohana
//
//  家庭协作差异化展示：首页宠物卡下方的「今日 · 家人」横滑条
//
//  展示当天对该宠物发生过动作的家庭成员头像 + 动作徽章，让用户一眼看到
//  「今天谁给 TA 做了什么」。
//
//  数据来源（均含 executorId 字段）：
//  - PetCareLog（喂食 / 喂水 / 换水 / 滤材 / 铲屎 / 逗玩 / ...）
//  - PetPottyLog（便便 / 尿尿）
//  - PetWalkLog（遛狗）
//  - PetExpenseLog（花费）
//
//  去重规则：同一(humanId, 动作类别) 取最新一条，最多展示 8 条。
//  空态：当日无数据 → 渲染 EmptyView，避免首页冗余。
//

import SwiftUI
import SwiftData

struct FamilyActivityStripView: View {
    let pet: Pet
    /// 展示样式
    /// - `.full`：原有大条带（头像 + 徽章 + 姓名，约 80pt）
    /// - `.compact`：小胶囊模式（约 30pt），点击展开完整 Sheet
    var style: Style = .full
    var onExpand: () -> Void = {}

    enum Style { case full, compact }

    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Entry model

    private struct ActivityEntry: Identifiable {
        let id = UUID()
        let date: Date
        let executorId: String?
        let iconName: String      // SF Symbol
        let accent: Color         // 徽章底色
        let dedupKey: String
    }

    // MARK: - Data

    private var todayEntries: [ActivityEntry] {
        let cal = Calendar.current
        let today = Date()
        var entries: [ActivityEntry] = []

        for log in pet.careLogs where cal.isDate(log.date, inSameDayAs: today) {
            entries.append(ActivityEntry(
                date: log.date,
                executorId: log.executorId,
                iconName: log.careType.systemIconName,
                accent: Color(hex: log.careType.accentColorHex),
                dedupKey: "\(log.executorId ?? "nil")_care_\(log.type)"
            ))
        }
        for log in pet.pottyLogs where cal.isDate(log.date, inSameDayAs: today) {
            entries.append(ActivityEntry(
                date: log.date,
                executorId: log.executorId,
                iconName: log.pottyType.systemIconName,
                accent: Color(hex: "FFD93D"),
                dedupKey: "\(log.executorId ?? "nil")_potty"
            ))
        }
        for log in pet.walkLogs where cal.isDate(log.startDate, inSameDayAs: today) {
            entries.append(ActivityEntry(
                date: log.startDate,
                executorId: log.executorId,
                iconName: "figure.walk",
                accent: Color(hex: "7FFF6B"),
                dedupKey: "\(log.executorId ?? "nil")_walk"
            ))
        }
        for log in pet.expenseLogs where cal.isDate(log.date, inSameDayAs: today) {
            entries.append(ActivityEntry(
                date: log.date,
                executorId: log.executorId,
                iconName: "creditcard.fill",
                accent: Color(hex: "FF6B6B"),
                dedupKey: "\(log.executorId ?? "nil")_expense"
            ))
        }

        let sorted = entries.sorted { $0.date > $1.date }
        var seen: Set<String> = []
        var deduped: [ActivityEntry] = []
        for e in sorted where seen.insert(e.dedupKey).inserted {
            deduped.append(e)
        }
        return Array(deduped.prefix(8))
    }

    private func human(for id: String?) -> Human? {
        guard let id, !id.isEmpty else { return nil }
        return humans.first { $0.id.uuidString == id }
    }

    // MARK: - Body

    var body: some View {
        let entries = todayEntries
        if !entries.isEmpty {
            switch style {
            case .full:
                VStack(alignment: .leading, spacing: 6) {
                    headerLabel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(entries) { entry in
                                chip(for: entry)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.top, 4)
            case .compact:
                compactPill(entries: entries)
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Compact Pill

    @ViewBuilder
    private func compactPill(entries: [ActivityEntry]) -> some View {
        let uniqueHumans = uniqueHumanList(from: entries)
        Button(action: onExpand) {
            HStack(spacing: 8) {
                // 家人头像堆叠
                HStack(spacing: -8) {
                    ForEach(uniqueHumans.prefix(3), id: \.self) { h in
                        avatarCircleCompact(for: h)
                    }
                }
                .padding(.leading, 2)

                // 描述文本
                Text(compactDescription(uniqueCount: uniqueHumans.count, actionCount: entries.count))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(.thinMaterial)
            )
            .overlay(
                Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func uniqueHumanList(from entries: [ActivityEntry]) -> [Human] {
        var seen = Set<String>()
        var list: [Human] = []
        for e in entries {
            if let id = e.executorId, !id.isEmpty, seen.insert(id).inserted,
               let h = humans.first(where: { $0.id.uuidString == id }) {
                list.append(h)
            }
        }
        return list
    }

    private func compactDescription(uniqueCount: Int, actionCount: Int) -> String {
        if uniqueCount == 0 {
            return "今天 \(actionCount) 次记录"
        } else if uniqueCount == 1 {
            return "今天已照顾 \(pet.name) \(actionCount) 次"
        } else {
            return "全家今日一起照顾 \(pet.name) \(actionCount) 次"
        }
    }

    @ViewBuilder
    private func avatarCircleCompact(for h: Human) -> some View {
        let ring = Color(hex: h.themeColor)
        ZStack {
            Circle().fill(ring.opacity(0.2)).frame(width: 20, height: 20)
            if let data = h.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            } else {
                Text(h.avatarEmoji).font(.system(size: 11))
            }
        }
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Sub-views

    private var headerLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .bold))
            Text("今日 · 谁在照顾 \(pet.name)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.4)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary.opacity(colorScheme == .dark ? 0.55 : 0.45))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func chip(for entry: ActivityEntry) -> some View {
        let h = human(for: entry.executorId)
        let name = h.map { $0.name.trimmingCharacters(in: .whitespaces) } ?? ""
        let display = name.isEmpty ? (h == nil ? "未指定" : "家人") : name

        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle(for: h)
                badge(icon: entry.iconName, accent: entry.accent)
                    .offset(x: 4, y: 4)
            }
            Text(display)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.65))
                .lineLimit(1)
                .frame(maxWidth: 44)
        }
    }

    @ViewBuilder
    private func avatarCircle(for h: Human?) -> some View {
        let ring = h.map { Color(hex: $0.themeColor) } ?? Color.secondary
        ZStack {
            Circle()
                .fill(ring.opacity(0.18))
                .frame(width: 34, height: 34)
            if let h {
                if let data = h.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                } else {
                    Text(h.avatarEmoji)
                        .font(.system(size: 17))
                }
            } else {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(ring.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func badge(icon: String, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(accent)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .strokeBorder(
                            colorScheme == .dark ? Color.black.opacity(0.9) : Color.white,
                            lineWidth: 1.6
                        )
                )
            Image(systemName: icon)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.85))
        }
    }
}
