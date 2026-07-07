//
//  FamilyActivityStripView.swift
//  Ohana
//
//  家庭协作差异化展示：首页宠物卡下方的「今日 · 家人」横滑条
//
//  展示当天对该宠物发生过动作的家庭成员头像 + 动作徽章，让用户一眼看到
//  「今天谁给 TA 做了什么」。
//
//  数据来源：route container 将 CareLedgerEvent 投影成 FamilyActivityEntry。
//
//  去重规则：同一(humanId, 动作类别) 取最新一条，最多展示 8 条。
//  空态：当日无数据 → 渲染 EmptyView，避免首页冗余。
//

import SwiftUI

struct FamilyActivityEntry: Identifiable, Equatable {
    let id: String
    let date: Date
    let executorId: String?
    let iconName: String
    let accentHex: String
    let dedupKey: String

    static func entries(
        from ledgerEvents: [CareLedgerEvent],
        petID: UUID,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [FamilyActivityEntry] {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
        return FamilyCareLedgerEntry.entries(
            from: ledgerEvents,
            petIDs: [petID],
            start: dayStart,
            end: dayEnd
        )
        .flatMap { Self.entries(from: $0) }
    }

    private static func entries(from entry: FamilyCareLedgerEntry) -> [FamilyActivityEntry] {
        switch entry.kind {
        case .care:
            guard let type = CareType(rawValue: entry.actionType) else { return [] }
            return expandedEntries(
                from: entry,
                iconName: type.systemIconName,
                accentHex: type.accentColorHex,
                dedupKind: "care_\(type.rawValue)"
            )
        case .potty:
            guard let type = PottyType(rawValue: entry.actionType) else { return [] }
            return expandedEntries(
                from: entry,
                iconName: type.systemIconName,
                accentHex: "FFD93D",
                dedupKind: "potty"
            )
        case .walk:
            return expandedEntries(
                from: entry,
                iconName: "figure.walk",
                accentHex: "7FFF6B",
                dedupKind: "walk"
            )
        case .expense:
            return expandedEntries(
                from: entry,
                iconName: "creditcard.fill",
                accentHex: "FF6B6B",
                dedupKind: "expense"
            )
        }
    }

    private static func expandedEntries(
        from entry: FamilyCareLedgerEntry,
        iconName: String,
        accentHex: String,
        dedupKind: String
    ) -> [FamilyActivityEntry] {
        let executorIds = entry.executorIDs.isEmpty ? [nil] : entry.executorIDs.map(Optional.some)
        return executorIds.enumerated().map { index, executorId in
            FamilyActivityEntry(
                id: "\(entry.id.uuidString)-\(index)-\(executorId ?? "unknown")",
                date: entry.date,
                executorId: executorId,
                iconName: iconName,
                accentHex: accentHex,
                dedupKey: "\(executorId ?? "nil")_\(dedupKind)"
            )
        }
    }
}

struct FamilyActivityStripView: View {
    let petName: String
    let humans: [Human]
    let entries: [FamilyActivityEntry]
    /// 展示样式
    /// - `.full`：原有大条带（头像 + 徽章 + 姓名，约 80pt）
    /// - `.compact`：小胶囊模式（约 30pt），点击展开完整 Sheet
    var style: Style = .full
    var onExpand: () -> Void = {}

    enum Style { case full, compact }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    // MARK: - Data

    private var todayEntries: [FamilyActivityEntry] {
        let sorted = entries.sorted { $0.date > $1.date }
        var seen: Set<String> = []
        var deduped: [FamilyActivityEntry] = []
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
        if humans.count > 1, !entries.isEmpty {
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
    private func compactPill(entries: [FamilyActivityEntry]) -> some View {
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
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 9, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.ohanaCardSurface)
            )
            .overlay(
                Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
    }

    private func uniqueHumanList(from entries: [FamilyActivityEntry]) -> [Human] {
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
            l.tr(zh: "今天 \(actionCount) 次记录", en: "\(actionCount) records today", de: "\(actionCount) Einträge heute")
        } else if uniqueCount == 1 {
            l.tr(zh: "今天已照顾 \(petName) \(actionCount) 次", en: "\(petName) cared for \(actionCount)x today", de: "\(petName) heute \(actionCount)x versorgt")
        } else {
            l.tr(zh: "全家今日一起照顾 \(petName) \(actionCount) 次", en: "Family cared for \(petName) \(actionCount)x today", de: "Familie hat \(petName) heute \(actionCount)x versorgt")
        }
    }

    @ViewBuilder
    private func avatarCircleCompact(for h: Human) -> some View {
        let ring = Color(hex: h.themeColor)
        ZStack {
            Circle().fill(ring.opacity(0.2)).frame(width: 20, height: 20) // a11y: allow decorative non-interactive frame; hit area handled by parent
            FamilyActivityHumanAvatar(human: h, size: 20, fallbackSize: 11)
        }
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Sub-views

    private var headerLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 10, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(l.tr(zh: "今日 · 谁在照顾 \(petName)", en: "Today · Who cared for \(petName)", de: "Heute · Wer versorgt \(petName)"))
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .tracking(0.4)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ohanaPrimaryText.opacity(colorScheme == .dark ? 0.55 : 0.45))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func chip(for entry: FamilyActivityEntry) -> some View {
        let h = human(for: entry.executorId)
        let name = h.map { $0.name.trimmingCharacters(in: .whitespaces) } ?? ""
        let display = name.isEmpty ? (h == nil ? l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugewiesen") : l.tr(zh: "家人", en: "Family", de: "Familie")) : name

        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle(for: h)
                badge(icon: entry.iconName, accent: Color(hex: entry.accentHex))
                    .offset(x: 4, y: 4)
            }
            Text(display)
                .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.65))
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
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            if let h {
                FamilyActivityHumanAvatar(human: h, size: 34, fallbackSize: 17)
            } else {
                Image(systemName: "person.fill.questionmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
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
                .frame(width: 16, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.ohanaCardSurface,
                            lineWidth: 1.6
                        )
                )
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 8, weight: .heavy)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.arkInk.opacity(0.85))
        }
    }
}

private struct FamilyActivityHumanAvatar: View {
    let human: Human
    let size: CGFloat
    let fallbackSize: CGFloat

    var body: some View {
        HumanAvatarPipelineView(
            human: human,
            size: size,
            fallbackScale: fallbackSize / max(size, 1),
            showsBackground: false
        )
    }
}
