//
//  MemoryDropCard.swift
//  Ohana
//
//  记忆碎片卡：从历史数据中随机挖掘一条「被动惊喜」回忆，零压力正反馈

import SwiftUI

// MARK: - Memory Fragment Model
struct MemoryFragment: Identifiable {
    let id = UUID()
    let emoji: String
    let headline: String        // 大标题，如"这是你们相伴的第 500 天"
    let subline: String         // 副标题
    let mapSnapshotData: Data?  // 可选地图截图
    let accentColor: Color
    var rewardCoconuts: Int = 0 // U9: 回忆奖励椰子数
    var petName: String? = nil  // U9: 关联的宠物名
}

// MARK: - Memory Engine
struct MemoryEngine {
    /// 从所有历史数据中随机挖掘一条值得回顾的记忆
    /// - Returns: nil 表示数据太少，不展示
    static func pickFragment(pets: [Pet], plants: [Plant]) -> MemoryFragment? {
        let cal = Calendar.current
        let today = Date()
        var candidates: [MemoryFragment] = []

        for pet in pets {
            // 1. 去年同期的遛狗记录（±3天窗口）
            let yearAgoWalks = pet.walkLogs.filter { log in
                guard let yearAgo = cal.date(byAdding: .year, value: -1, to: today) else { return false }
                let diff = abs(cal.dateComponents([.day], from: log.startDate, to: yearAgo).day ?? 999)
                return diff <= 3 && log.distanceMeters > 200
            }
            if let walk = yearAgoWalks.first {
                let km = walk.distanceMeters >= 1000
                    ? String(format: "%.1f km", walk.distanceMeters / 1000)
                    : String(format: "%.0f m", walk.distanceMeters)
                let dateStr = walk.startDate.formatted(.dateTime.month().day())
                candidates.append(MemoryFragment(
                    emoji: "🗺️",
                    headline: "去年的 \(dateStr)",
                    subline: "你和 \(pet.name) 在外面走了 \(km)，那天一定很开心",
                    mapSnapshotData: walk.mapSnapshotData,
                    accentColor: Color.goTeal,
                    rewardCoconuts: 2,
                    petName: pet.name
                ))
            }

            // 2. 里程碑纪念日（daysTogether 整百/整千）
            let days = pet.daysTogether
            let milestones = [100, 200, 365, 500, 730, 1000, 1095, 1460, 1825]
            if milestones.contains(days) {
                candidates.append(MemoryFragment(
                    emoji: "🎂",
                    headline: "今天是你们相伴第 \(days) 天",
                    subline: "\(pet.name) 一定很感激有你陪着",
                    mapSnapshotData: nil,
                    accentColor: Color.goPrimary,
                    rewardCoconuts: 5,
                    petName: pet.name
                ))
            }

            // 3. 到家纪念日（homeDate 周年 ±0天）
            if let homeDate = pet.homeDate {
                let homeComps = cal.dateComponents([.month, .day], from: homeDate)
                let todayComps = cal.dateComponents([.month, .day], from: today)
                let years = cal.dateComponents([.year], from: homeDate, to: today).year ?? 0
                if homeComps.month == todayComps.month && homeComps.day == todayComps.day && years > 0 {
                    candidates.append(MemoryFragment(
                        emoji: "🏠",
                        headline: "\(pet.name) 来家里整整 \(years) 年了",
                        subline: "这一天，你们的故事正式开始",
                        mapSnapshotData: nil,
                        accentColor: Color.goOrange,
                        rewardCoconuts: 3,
                        petName: pet.name
                    ))
                }
            }

            // 4. 第一条健康记录回顾（仅限有记录且记录超过 90 天前）
            if let firstHealth = pet.healthLogs.sorted(by: { $0.date < $1.date }).first {
                let ageDays = cal.dateComponents([.day], from: firstHealth.date, to: today).day ?? 0
                if ageDays > 90 {
                    let dateStr = firstHealth.date.formatted(.dateTime.month().day().year())
                    let typeName = firstHealth.type
                    candidates.append(MemoryFragment(
                        emoji: "💉",
                        headline: "你第一次带 \(pet.name) 去看医生",
                        subline: "\(dateStr) · \(typeName)。从那天起你就是最好的铲屎官",
                        mapSnapshotData: nil,
                        accentColor: Color.goCardCyan,
                        rewardCoconuts: 2,
                        petName: pet.name
                    ))
                }
            }
        }

        // 5. 植物纪念日（植物创建超过 30/100/365 天）
        for plant in plants {
            let ageDays = cal.dateComponents([.day], from: plant.createdAt, to: today).day ?? 0
            let plantMilestones = [30, 100, 180, 365]
            if plantMilestones.contains(ageDays) {
                candidates.append(MemoryFragment(
                    emoji: plant.avatarEmoji,
                    headline: "\(plant.name) 在你家里已经 \(ageDays) 天了",
                    subline: "一棵植物也是一个小生命，谢谢你的照料",
                    mapSnapshotData: nil,
                    accentColor: Color.goMint
                ))
            }
        }

        guard !candidates.isEmpty else { return nil }

        // 用今日日期做种子，同一天始终显示同一条（稳定性 > 随机性）
        let seed = cal.ordinality(of: .day, in: .year, for: today) ?? 1
        return candidates[seed % candidates.count]
    }
}

// MARK: - Memory Drop Card View
struct MemoryDropCard: View {
    let fragment: MemoryFragment
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 地图截图（如果有）
            if let data = fragment.mapSnapshotData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, fragment.accentColor.mix(with: .black, by: 0.4).opacity(0.85)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                // 标签行
                HStack(spacing: 6) {
                    Text("✨")
                        .font(.system(size: 11))
                    Text("记忆碎片")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    Spacer()
                    // 闪光扫光效果提示
                    Text("今日回忆")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(shimmer ? 0.7 : 0.25))
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: shimmer)
                        .onAppear { shimmer = true }
                }

                // 主标题
                HStack(alignment: .top, spacing: 10) {
                    Text(fragment.emoji)
                        .font(.system(size: 28))
                    Text(fragment.headline)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 副标题
                Text(fragment.subline)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // U9: 宠物奖励信息
                if fragment.rewardCoconuts > 0 {
                    HStack(spacing: 6) {
                        if let name = fragment.petName {
                            Text(name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text("+\(fragment.rewardCoconuts)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goLime)
                            Text("🥥")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goLime.opacity(0.15), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, fragment.mapSnapshotData != nil ? 12 : 16)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    fragment.accentColor.mix(with: .black, by: 0.35).opacity(0.9),
                    fragment.accentColor.mix(with: .black, by: 0.55)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(fragment.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
