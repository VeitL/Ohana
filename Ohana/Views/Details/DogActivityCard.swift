//
//  DogActivityCard.swift
//  Ohana
//
//  狗狗专属卡片：遛狗 + 陪玩记录
//

import SwiftUI

struct DogActivityCard: View {
    let pet: Pet

    private var recentWalks: [PetWalkLog] {
        pet.walkLogs.sorted { $0.startDate > $1.startDate }.prefix(5).map { $0 }
    }

    private var recentPlays: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.play.rawValue }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    private var totalWalkDistanceToday: Double {
        let cal = Calendar.current
        return pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.reduce(0) { $0 + $1.distanceMeters }
    }

    private var walkCountToday: Int {
        let cal = Calendar.current
        return pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
    }

    private var playCountToday: Int {
        let cal = Calendar.current
        return pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
    }

    private var totalWalks7d: Int {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return pet.walkLogs.filter { $0.startDate >= since }.count
    }

    private var totalPlays7d: Int {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return pet.careLogs.filter { $0.type == CareType.play.rawValue && $0.date >= since }.count
    }

    // merge and sort walk + play records together for timeline
    private var mergedActivity: [(date: Date, isWalk: Bool, walk: PetWalkLog?, play: PetCareLog?)] {
        let walkItems: [(date: Date, isWalk: Bool, walk: PetWalkLog?, play: PetCareLog?)] = recentWalks.map { (date: $0.startDate, isWalk: true, walk: $0, play: nil) }
        let playItems: [(date: Date, isWalk: Bool, walk: PetWalkLog?, play: PetCareLog?)] = recentPlays.map { (date: $0.date, isWalk: false, walk: nil, play: $0) }
        return (walkItems + playItems).sorted { $0.date > $1.date }.prefix(6).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ── 标题行
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.goLime)
                    Text("遛狗 & 陪玩")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("近7天")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }

            // ── 今日统计
            HStack(spacing: 10) {
                statPill(
                    icon: "figure.walk",
                    color: Color.goLime,
                    title: walkCountToday > 0 ? "遛 \(walkCountToday) 次" : "今日未遛",
                    subtitle: walkCountToday > 0 ? distText(totalWalkDistanceToday) : nil
                )
                statPill(
                    icon: "tennisball.fill",
                    color: Color(hex: "FF6B6B"),
                    title: playCountToday > 0 ? "逗 \(playCountToday) 次" : "今日未逗玩",
                    subtitle: nil
                )
                statPill(
                    icon: "7.circle.fill",
                    color: Color(hex: "A78BFA"),
                    title: "近7天",
                    subtitle: "遛\(totalWalks7d)·玩\(totalPlays7d)"
                )
            }

            // ── 活动时间轴
            if mergedActivity.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("🐾").font(.system(size: 28))
                        Text("还没有遛狗或陪玩记录")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mergedActivity.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 12) {
                            // icon + line
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(item.isWalk ? Color.goLime.opacity(0.18) : Color(hex: "FF6B6B").opacity(0.18))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: item.isWalk ? "figure.walk" : "tennisball.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(item.isWalk ? Color.goLime : Color(hex: "FF6B6B"))
                                }
                                if idx < mergedActivity.count - 1 {
                                    Rectangle()
                                        .fill(.white.opacity(0.08))
                                        .frame(width: 1.5, height: 18)
                                }
                            }

                            // detail
                            VStack(alignment: .leading, spacing: 2) {
                                if item.isWalk, let walk = item.walk {
                                    Text(walk.distanceText + (walk.endDate != nil ? " · " + walk.durationText : ""))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("逗玩")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }

                                Text(timeAgoText(item.date))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            Spacer()

                            if item.isWalk, let walk = item.walk, walk.coconutsEarned > 0 {
                                Text("+\(walk.coconutsEarned)🥥")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.goLime.opacity(0.8))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.goLime.opacity(0.1), in: Capsule())
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goLime.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statPill(icon: String, color: Color, title: String, subtitle: String?) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let s = subtitle {
                Text(s)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(color.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func distText(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : String(format: "%.0f m", meters)
    }

    private func timeAgoText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            return fmt.string(from: date)
        }
        if cal.isDateInYesterday(date) { return "昨天" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        return "\(days)天前"
    }
}
