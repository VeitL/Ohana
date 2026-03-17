//
//  WeeklyReportCard.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

struct WeeklyReportCard: View {
    let pet: Pet
    @State private var isRendering = false
    @State private var isSharing = false
    @State private var shareImage: UIImage? = nil
    @State private var pulseShare = false
    
    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }
    
    private var weekEnd: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
    }
    
    private var weekWalks: [PetWalkLog] {
        pet.walkLogs.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
    }
    
    private var weekPotties: [PetPottyLog] {
        pet.pottyLogs.filter { $0.date >= weekStart && $0.date < weekEnd }
    }
    
    private var weekExpenses: Double {
        pet.expenseLogs
            .filter { $0.date >= weekStart && $0.date < weekEnd }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalWalkDistance: Double {
        weekWalks.reduce(0) { $0 + $1.distanceMeters }
    }
    
    private var totalWalkDuration: TimeInterval {
        weekWalks.reduce(0) { $0 + TimeInterval($1.durationSeconds) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.goPrimary)
                Text("本周小报")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(weekStart, format: .dateTime.month().day()) - \(weekEnd, format: .dateTime.month().day())")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                Button {
                    Task { await renderAndShare() }
                } label: {
                    if isRendering {
                        ProgressView().tint(Color.goLime).scaleEffect(0.75)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text("分享")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.goLime, in: Capsule())
                        .scaleEffect(pulseShare ? 1.06 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulseShare)
                        .onAppear { pulseShare = true }
                    }
                }
                .disabled(isRendering)
            }
            
            // 统计网格
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                statBubble(emoji: "🚶", value: "\(weekWalks.count)", label: "巡岛")
                statBubble(emoji: "📏", value: distanceFormatted, label: "距离")
                statBubble(emoji: "⏱️", value: durationFormatted, label: "时长")
                statBubble(emoji: "💩", value: "\(weekPotties.count)", label: "便便")
                statBubble(emoji: "💰", value: "¥\(Int(weekExpenses))", label: "花费")
                statBubble(emoji: "⚖️", value: latestWeight, label: "体重")
            }
            
            // 7天活跃热力图
            VStack(alignment: .leading, spacing: 6) {
                Text("活跃天数")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart) ?? Date()
                        let hasActivity = hasActivityOn(date)
                        
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hasActivity ? Color.purple.opacity(0.6) : Color.gray.opacity(0.15))
                                .frame(height: 24)
                            
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
        .sheet(isPresented: $isSharing) {
            if let img = shareImage {
                ShareSheet(image: img)
            }
        }
    }
    
    private func statBubble(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var distanceFormatted: String {
        if totalWalkDistance >= 1000 {
            return String(format: "%.1fkm", totalWalkDistance / 1000)
        }
        return String(format: "%.0fm", totalWalkDistance)
    }
    
    private var durationFormatted: String {
        let minutes = Int(totalWalkDuration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h\(minutes % 60)m"
        }
        return "\(minutes)min"
    }
    
    private var latestWeight: String {
        if let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
            return String(format: "%.1fkg", w.weight)
        }
        return "--"
    }
    
    private func hasActivityOn(_ date: Date) -> Bool {
        let cal = Calendar.current
        let hasWalk = weekWalks.contains { cal.isDate($0.startDate, inSameDayAs: date) }
        let hasPotty = weekPotties.contains { cal.isDate($0.date, inSameDayAs: date) }
        let hasHygiene = pet.hygieneLogs.contains { cal.isDate($0.date, inSameDayAs: date) }
        return hasWalk || hasPotty || hasHygiene
    }

    // MARK: - Share Poster
    @MainActor
    private func renderAndShare() async {
        isRendering = true
        defer { isRendering = false }
        let poster = weeklyPoster
        let renderer = ImageRenderer(content:
            poster
                .frame(width: 360)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        if let img = renderer.uiImage {
            shareImage = img
            isSharing = true
        }
    }

    // MARK: - Poster Layout（独立视图，供 ImageRenderer 渲染）
    private var weeklyPoster: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部品牌条
            HStack {
                Text("🏝️ Ohana 周报")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goLime)
                Spacer()
                Text("\(weekStart, format: .dateTime.month().day()) — \(weekEnd, format: .dateTime.month().day())")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 宠物 Hero
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: pet.themeColorHex).opacity(0.25))
                        .frame(width: 64, height: 64)
                    if let data = pet.avatarImageData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 56, height: 56).clipShape(Circle())
                    } else {
                        Text(pet.avatarEmoji).font(.system(size: 32))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("本周战绩")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Spacer()
                // 活跃天数大字
                let activeDays = (0..<7).filter { i in
                    let d = Calendar.current.date(byAdding: .day, value: i, to: weekStart) ?? Date()
                    return hasActivityOn(d)
                }.count
                VStack(spacing: 2) {
                    Text("\(activeDays)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("活跃天")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // 数据网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                posterStat(emoji: "🚶", value: "\(weekWalks.count)次", label: "巡岛")
                posterStat(emoji: "📏", value: distanceFormatted, label: "距离")
                posterStat(emoji: "⏱️", value: durationFormatted, label: "时长")
                posterStat(emoji: "💩", value: "\(weekPotties.count)次", label: "便便")
                posterStat(emoji: "💰", value: "¥\(Int(weekExpenses))", label: "花费")
                posterStat(emoji: "⚖️", value: latestWeight, label: "体重")
            }
            .padding(.horizontal, 16)

            // 热力图
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let d = Calendar.current.date(byAdding: .day, value: i, to: weekStart) ?? Date()
                    let active = hasActivityOn(d)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(active ? Color.goLime.opacity(0.7) : Color.primary.opacity(0.08))
                            .frame(height: 20)
                        Text(d, format: .dateTime.weekday(.narrow))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // 底部水印
            HStack {
                Spacer()
                Text("Made with Ohana 🏝️")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.18))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "2A1F6B"), Color(hex: "1A0E4B")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.25), lineWidth: 1.5)
        )
    }

    private func posterStat(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 18))
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
