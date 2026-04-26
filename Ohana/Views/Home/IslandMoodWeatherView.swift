//
//  IslandMoodWeatherView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

enum IslandMood: Equatable {
    case calm
    case breezy
    case storm
    case celebrate   // 解锁成就 / 今日遛狗 >5km / 里程碑日
    case plantBreeze // 植物浇水后的生态联动特效
    case cloudy      // 适度焦虑：连断打卡 / 漏药 / 多日未护理
}

struct WeatherParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var emoji: String
    var opacity: Double
    var scale: CGFloat
    var speed: CGFloat
}

struct IslandMoodWeatherView: View {
    let mood: IslandMood
    
    @State private var particles: [WeatherParticle] = []
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: 16))
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                startParticles(in: geo.size)
            }
            .onDisappear {
                stopParticles()
            }
            .onChange(of: mood) { _, newMood in
                stopParticles()
                particles.removeAll()
                if newMood != .calm {
                    startParticles(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func startParticles(in size: CGSize) {
        guard mood != .calm else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.linear(duration: 3)) {
                addParticle(in: size)
                removeOldParticles()
            }
        }
    }
    
    private func stopParticles() {
        timer?.invalidate()
        timer = nil
    }
    
    private func addParticle(in size: CGSize) {
        guard particles.count < 20 else { return }
        
        let emojis: [String]
        switch mood {
        case .calm: return
        case .breezy:      emojis = ["✨", "🌸", "🌺", "🌼"]
        case .storm:       emojis = ["⚡️", "🌩️", "💧"]
        case .celebrate:   emojis = ["🎉", "🌟", "✨", "🎊", "⭐️", "💫"]
        case .plantBreeze: emojis = ["🍃", "🌿", "🌱", "🍀", "🌸", "💚"]
        case .cloudy:      emojis = ["🌥️", "🌫", "☁️", "💭"]
        }
        
        let particle = WeatherParticle(
            x: CGFloat.random(in: 0...size.width),
            y: -20,
            emoji: emojis.randomElement() ?? "✨",
            opacity: Double.random(in: 0.3...0.7),
            scale: CGFloat.random(in: 0.6...1.2),
            speed: CGFloat.random(in: 1...3)
        )
        particles.append(particle)
        
        // 动画移动到底部
        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
            particles[index].y = size.height + 20
            particles[index].x += CGFloat.random(in: -50...50)
            particles[index].opacity = 0
        }
    }
    
    private func removeOldParticles() {
        particles.removeAll { $0.opacity <= 0.05 }
    }
}

// MARK: - Mood Calculator
struct IslandMoodCalculator {
    static func calculate(pets: [Pet], pendingReminders: [Reminder], plants: [Plant] = []) -> IslandMood {
        // 紧急食物不足 → storm
        for pet in pets {
            if pet.dailyPortionGrams > 0 && pet.remainingFoodDays <= 3 && pet.remainingFoodDays > 0 {
                return .storm
            }
        }

        // 证件即将到期 → storm
        for pet in pets {
            if pet.documents.contains(where: { $0.isExpired }) {
                return .storm
            }
        }

        // 今日遛狗距离 >= 5km → celebrate
        let todayWalkKm = pets.flatMap { $0.walkLogs }.filter {
            Calendar.current.isDateInToday($0.startDate)
        }.reduce(0.0) { $0 + $1.distanceMeters }
        if todayWalkKm >= 5000 {
            return .celebrate
        }

        // 今天是某宠物的 homeDate 里程碑日（100/365/500/730/1000 天）→ celebrate
        let milestones = [100, 365, 500, 730, 1000, 1095]
        for pet in pets {
            if milestones.contains(pet.daysTogether) {
                return .celebrate
            }
        }

        // 今天刚有第一次遛狗记录 → celebrate
        let firstEverWalk = pets.flatMap { $0.walkLogs }
            .sorted(by: { $0.startDate < $1.startDate })
            .first
        if let first = firstEverWalk, Calendar.current.isDateInToday(first.startDate) {
            return .celebrate
        }

        // 今天是某只宠物的到家纪念日（homeDate 周年）→ celebrate
        let today = Date()
        let todayComps = Calendar.current.dateComponents([.month, .day], from: today)
        for pet in pets {
            if let homeDate = pet.homeDate {
                let homeComps = Calendar.current.dateComponents([.month, .day], from: homeDate)
                if homeComps.month == todayComps.month && homeComps.day == todayComps.day
                    && pet.daysTogether > 0 {
                    return .celebrate
                }
            }
        }

        // 今日所有待完成提醒都已完成（至少有1条）→ celebrate
        let allReminders = pendingReminders
        let todayReminders = allReminders.filter {
            Calendar.current.isDateInToday($0.scheduledAt)
        }
        if !todayReminders.isEmpty && todayReminders.allSatisfy({ $0.isCompleted }) {
            return .celebrate
        }

        // 今日任意植物浇水 → plantBreeze（绿叶/花瓣粒子，生态联动）
        let wateredToday = plants.contains { plant in
            if let d = plant.lastWateredDate { return Calendar.current.isDateInToday(d) }
            return false
        }
        if wateredToday {
            return .plantBreeze
        }

        // 今日有已完成提醒 → breezy
        let todayCompleted = pendingReminders.contains { reminder in
            reminder.isCompleted && Calendar.current.isDateInToday(reminder.completedAt ?? .distantPast)
        }
        if todayCompleted {
            return .breezy
        }

        // 负反馈：漏药 / 连断 / 长期无护理 → cloudy（适度焦虑）
        if IslandNegativeFeedback.hasAnyNegativeSignal(pets: pets, plants: plants) {
            return .cloudy
        }

        return .calm
    }
}

// MARK: - Island Negative Feedback（岛屿负反馈系统）
//
// P0 留存：连断天气变阴 / 护理超期 / 用药遗漏叶发黄
// 统一作为 mood/banner 的数据源，避免到处散落的零散判断
//
struct IslandNegativeSignal: Identifiable {
    let id = UUID()
    let iconName: String      // SF Symbol
    let emoji: String         // fallback emoji
    let title: String
    let detail: String
    let severity: Severity

    enum Severity {
        case warning       // 黄色 - 可缓冲
        case critical      // 红色 - 紧急
    }
}

struct IslandNegativeFeedback {
    /// 返回所有负反馈信号，按严重程度排序（critical 在前）
    static func signals(pets: [Pet], plants: [Plant] = []) -> [IslandNegativeSignal] {
        var result: [IslandNegativeSignal] = []
        let cal = Calendar.current
        let now = Date()

        // 1. 连断打卡：以真实照护日志为准，避免派生 streak 字段未同步时误报。
        let brokenStreakPets = pets.filter { pet in
            !pet.hasPassedAway
                && pet.currentStreak == 0
                && !hasAnyPetCheckInToday(pet, calendar: cal)
        }
        if !brokenStreakPets.isEmpty {
            let names = brokenStreakPets.prefix(2).map(\.name).joined(separator: "、")
            result.append(IslandNegativeSignal(
                iconName: "cloud.fill",
                emoji: "🌥",
                title: "今日还未打卡",
                detail: "给 \(names) 完成一次喂食、喂水或遛狗打卡即可",
                severity: .warning
            ))
        }

        // 2. 用药遗漏（最近 3 天有用药计划但今日未服用）
        for pet in pets {
            for med in pet.medications where med.isActiveToday {
                let need = med.frequency.dosesPerDay
                guard need > 0 else { continue }
                let taken = MedicationReminderService.dosesTakenToday(for: med.id)
                let hour = cal.component(.hour, from: now)
                // 过了晚上 22:00 还未吃完 → 视为今日漏药
                if hour >= 22 && taken < need {
                    result.append(IslandNegativeSignal(
                        iconName: "pills.fill",
                        emoji: "💊",
                        title: "\(pet.name) 今日漏药",
                        detail: "\(med.name) 还差 \(need - taken) 次",
                        severity: .critical
                    ))
                    break
                }
            }
        }

        // 3. 护理超期（超过 72 小时未喂食）
        for pet in pets where !pet.hasPassedAway {
            let lastFeed = pet.careLogs
                .filter { $0.type == CareType.feeding.rawValue }
                .map(\.date)
                .max()
            if let last = lastFeed, now.timeIntervalSince(last) > 72 * 3600 {
                let hours = Int(now.timeIntervalSince(last) / 3600)
                result.append(IslandNegativeSignal(
                    iconName: "fork.knife",
                    emoji: "🍗",
                    title: "\(pet.name) 喂食超期",
                    detail: "距离上次已 \(hours) 小时，建议先记录一次喂食",
                    severity: .warning
                ))
                break
            }
        }

        // 4. 植物缺水（7 天没浇水）
        for plant in plants {
            if let last = plant.lastWateredDate, now.timeIntervalSince(last) > 7 * 86400 {
                result.append(IslandNegativeSignal(
                    iconName: "drop.triangle.fill",
                    emoji: "🥀",
                    title: "\(plant.name) 叶子发黄",
                    detail: "已 \(Int(now.timeIntervalSince(last) / 86400)) 天未浇水",
                    severity: .warning
                ))
                break
            }
        }

        return result.sorted {
            if $0.severity == $1.severity { return false }
            return $0.severity == .critical
        }
    }

    static func hasAnyNegativeSignal(pets: [Pet], plants: [Plant] = []) -> Bool {
        !signals(pets: pets, plants: plants).isEmpty
    }

    private static func hasAnyPetCheckInToday(_ pet: Pet, calendar: Calendar) -> Bool {
        if let lastCheckInDate = pet.lastCheckInDate, calendar.isDateInToday(lastCheckInDate) {
            return true
        }

        if pet.careLogs.contains(where: { calendar.isDateInToday($0.date) }) {
            return true
        }
        if pet.walkLogs.contains(where: { calendar.isDateInToday($0.startDate) }) {
            return true
        }
        if pet.pottyLogs.contains(where: { calendar.isDateInToday($0.date) }) {
            return true
        }
        if pet.hygieneLogs.contains(where: { calendar.isDateInToday($0.date) }) {
            return true
        }

        return false
    }
}
