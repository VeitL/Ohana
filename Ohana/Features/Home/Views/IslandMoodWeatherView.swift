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
    case celebrate // 解锁成就 / 今日遛狗 >5km / 里程碑日
    case plantBreeze // 植物浇水后的生态联动特效
    case cloudy // 适度焦虑：连断打卡 / 漏药 / 多日未护理
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
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppServices.self) private var appServices
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var shouldRunParticles: Bool {
        mood != .calm &&
            !reduceMotion &&
            workloadPolicy.ambientMotionBudget(isVisible: isVisible).allowsMotion
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(OhanaFont.adaptive(size: 16))
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                isVisible = true
                updateParticles(in: geo.size)
            }
            .onDisappear {
                isVisible = false
                stopParticles()
                particles.removeAll()
            }
            .onChange(of: mood) { _, _ in
                updateParticles(in: geo.size, reset: true)
            }
            .onChange(of: shouldRunParticles) { _, _ in
                updateParticles(in: geo.size, reset: true)
            }
        }
        .allowsHitTesting(false)
    }

    private func updateParticles(in size: CGSize, reset: Bool = false) {
        stopParticles()
        if reset {
            particles.removeAll()
        }
        guard shouldRunParticles else { return }
        startParticles(in: size)
    }

    private func startParticles(in size: CGSize) {
        guard shouldRunParticles, timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.linear(duration: 3)) { // ui-v4: allow AppWorkloadPolicy-gated particle drift uses constant falling motion.
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
        case .breezy: emojis = ["✨", "🌸", "🌺", "🌼"]
        case .storm: emojis = ["⚡️", "🌩️", "💧"]
        case .celebrate: emojis = ["🎉", "🌟", "✨", "🎊", "⭐️", "💫"]
        case .plantBreeze: emojis = ["🍃", "🌿", "🌱", "🍀", "🌸", "💚"]
        case .cloudy: emojis = ["🌥️", "🌫", "☁️", "💭"]
        }

        let particle = WeatherParticle(
            x: CGFloat.random(in: 0 ... size.width),
            y: -20,
            emoji: emojis.randomElement() ?? "✨",
            opacity: Double.random(in: 0.3 ... 0.7),
            scale: CGFloat.random(in: 0.6 ... 1.2),
            speed: CGFloat.random(in: 1 ... 3)
        )
        particles.append(particle)

        // 动画移动到底部
        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
            particles[index].y = size.height + 20
            particles[index].x += CGFloat.random(in: -50 ... 50)
            particles[index].opacity = 0
        }
    }

    private func removeOldParticles() {
        particles.removeAll { $0.opacity <= 0.05 }
    }
}

// MARK: - Mood Calculator
enum IslandMoodCalculator {
    static func calculate(
        pets: [Pet],
        pendingReminders: [Reminder],
        plants: [Plant] = [],
        healthAlerts: PetHealthAlerting
    ) -> IslandMood {
        // 紧急食物不足 → storm
        for pet in pets {
            if pet.dailyPortionGrams > 0, pet.remainingFoodDays <= 3, pet.remainingFoodDays > 0 {
                return .storm
            }
        }

        // 证件即将到期 → storm
        for pet in pets {
            if pet.documents.contains(where: \.isExpired) {
                return .storm
            }
        }

        // 今日遛狗距离 >= 5km → celebrate
        let todayWalkKm = pets.flatMap(\.walkLogs).filter {
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
        let firstEverWalk = pets.flatMap(\.walkLogs)
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
                if homeComps.month == todayComps.month, homeComps.day == todayComps.day,
                   pet.daysTogether > 0 {
                    return .celebrate
                }
            }
        }

        // 今日所有待完成提醒都已完成（至少有1条）→ celebrate
        let allReminders = pendingReminders
        let todayReminders = allReminders.filter {
            Calendar.current.isDateInToday($0.scheduledAt)
        }
        if !todayReminders.isEmpty, todayReminders.allSatisfy(\.isCompleted) {
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
        if IslandNegativeFeedback.hasAnyNegativeSignal(pets: pets, plants: plants, healthAlerts: healthAlerts) {
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
nonisolated struct IslandNegativeSignal: Identifiable, Equatable, Sendable {
    let id: String
    let iconName: String // SF Symbol
    let emoji: String // fallback emoji
    let title: String
    let detail: String
    let severity: Severity
    let petId: UUID?
    let plantId: UUID?
    let healthAlertType: HealthAlert.AlertType?

    enum Severity: Sendable {
        case warning // 黄色 - 可缓冲
        case critical // 红色 - 紧急

        var identityToken: String {
            switch self {
            case .warning: "warning"
            case .critical: "critical"
            }
        }
    }

    init(
        id: String? = nil,
        iconName: String,
        emoji: String,
        title: String,
        detail: String,
        severity: Severity,
        petId: UUID? = nil,
        plantId: UUID? = nil,
        healthAlertType: HealthAlert.AlertType? = nil
    ) {
        self.id = id ?? Self.identityKey(
            title: title,
            detail: detail,
            severity: severity,
            petId: petId,
            plantId: plantId,
            healthAlertType: healthAlertType
        )
        self.iconName = iconName
        self.emoji = emoji
        self.title = title
        self.detail = detail
        self.severity = severity
        self.petId = petId
        self.plantId = plantId
        self.healthAlertType = healthAlertType
    }

    private static func identityKey(
        title: String,
        detail: String,
        severity: Severity,
        petId: UUID?,
        plantId: UUID?,
        healthAlertType: HealthAlert.AlertType?
    ) -> String {
        let subject = if let petId {
            "pet:\(petId.uuidString)"
        } else if let plantId {
            "plant:\(plantId.uuidString)"
        } else {
            "household"
        }
        let alert = healthAlertType.map { ":health:\($0.rawValue)" } ?? ""
        return [
            "negative",
            subject + alert,
            severity.identityToken,
            stableHash(title),
            stableHash(detail)
        ].joined(separator: ":")
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 5381
        for scalar in value.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        return String(hash, radix: 16)
    }
}

nonisolated enum IslandNegativeFeedback {
    /// 返回所有负反馈信号，按严重程度排序（critical 在前）
    @MainActor
    static func signals(
        pets: [Pet],
        plants: [Plant] = [],
        healthAlerts: PetHealthAlerting
    ) -> [IslandNegativeSignal] {
        signals(
            pets: pets,
            plants: plants,
            clinicalAlerts: healthAlerts.scanAlerts(pets: pets)
        )
    }

    static func signals(
        pets: [Pet],
        plants: [Plant] = [],
        clinicalAlerts: [HealthAlert]
    ) -> [IslandNegativeSignal] {
        var result: [IslandNegativeSignal] = []
        let cal = Calendar.current
        let now = Date()

        // 0. 健康异常引擎：疫苗/驱虫/体重/症状/证件等风险优先进入 Today Focus。
        let filteredClinicalAlerts = clinicalAlerts
            .filter { alert in
                switch alert.type {
                case .noCheckIn, .noWalk, .noPotty:
                    false
                default:
                    true
                }
            }
        for alert in filteredClinicalAlerts.prefix(2) {
            result.append(IslandNegativeSignal(
                iconName: iconName(for: alert),
                emoji: alert.emoji,
                title: localized(
                    zh: "\(alert.petName)：\(alert.title)",
                    en: "\(alert.petName): \(clinicalTitle(for: alert))"
                ),
                detail: localized(
                    zh: alert.detail,
                    en: clinicalDetail(for: alert)
                ),
                severity: alert.severity == .urgent ? .critical : .warning,
                petId: alert.petId,
                healthAlertType: alert.type
            ))
        }

        for pet in pets where !pet.hasPassedAway {
            if let signal = appetiteTrendSignal(for: pet, calendar: cal, now: now) {
                result.append(signal)
            }
            if let signal = abnormalPottyTrendSignal(for: pet, calendar: cal, now: now) {
                result.append(signal)
            }
            if let signal = drinkingTrendSignal(for: pet, calendar: cal, now: now) {
                result.append(signal)
            }
        }

        // 1. 连断打卡：以真实照护日志为准，避免派生 streak 字段未同步时误报。
        let brokenStreakPets = pets.filter { pet in
            !pet.hasPassedAway
                && pet.currentStreak == 0
                && !hasAnyPetCheckInToday(pet, calendar: cal)
        }
        if !brokenStreakPets.isEmpty {
            let names = joinedNames(brokenStreakPets.prefix(2).map(\.name))
            result.append(IslandNegativeSignal(
                iconName: "cloud.fill",
                emoji: "🌥",
                title: localized(zh: "今日还未打卡", en: "No check-in yet today"),
                detail: localized(
                    zh: "给 \(names.zh) 完成一次喂食、喂水或遛狗打卡即可",
                    en: "Log a feeding, water, or walk check-in for \(names.en)"
                ),
                severity: .warning
            ))
        }

        // 2. 用药遗漏（最近 3 天有用药计划但今日未服用）
        for pet in pets {
            for med in pet.medications where med.isActiveToday {
                let need = med.frequency.dosesPerDay
                guard need > 0 else { continue }
                let taken = MedicationDoseProgressStore.dosesTakenToday(for: med.id)
                let hour = cal.component(.hour, from: now)
                // 过了晚上 22:00 还未吃完 → 视为今日漏药
                if hour >= 22, taken < need {
                    result.append(IslandNegativeSignal(
                        iconName: "pills.fill",
                        emoji: "💊",
                        title: localized(zh: "\(pet.name) 今日漏药", en: "\(pet.name) missed medication today"),
                        detail: localized(
                            zh: "\(med.name) 还差 \(need - taken) 次",
                            en: "\(med.name) has \(need - taken) dose\(need - taken == 1 ? "" : "s") left"
                        ),
                        severity: .critical,
                        petId: pet.id
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
                    title: localized(zh: "\(pet.name) 喂食超期", en: "\(pet.name)'s feeding is overdue"),
                    detail: localized(
                        zh: "距离上次已 \(hours) 小时，建议先记录一次喂食",
                        en: "\(hours) hour\(hours == 1 ? "" : "s") since the last feeding. Log one first."
                    ),
                    severity: .warning,
                    petId: pet.id
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
                    title: localized(zh: "\(plant.name) 叶子发黄", en: "\(plant.name)'s leaves are yellowing"),
                    detail: localized(
                        zh: "已 \(Int(now.timeIntervalSince(last) / 86400)) 天未浇水",
                        en: "\(Int(now.timeIntervalSince(last) / 86400)) day(s) since watering"
                    ),
                    severity: .warning,
                    plantId: plant.id
                ))
                break
            }
        }

        return result.sorted {
            if $0.severity == $1.severity { return false }
            return $0.severity == .critical
        }
    }

    @MainActor
    static func hasAnyNegativeSignal(
        pets: [Pet],
        plants: [Plant] = [],
        healthAlerts: PetHealthAlerting
    ) -> Bool {
        !signals(pets: pets, plants: plants, healthAlerts: healthAlerts).isEmpty
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

    private static func localized(zh: String, en: String) -> String {
        AppLocalizedText(zh: zh, en: en).resolve()
    }

    private static func joinedNames(_ names: some Sequence<String>) -> (zh: String, en: String) {
        let values = names.map { $0.isEmpty ? localized(zh: "伙伴", en: "companion") : $0 }
        return (
            zh: values.joined(separator: "、"),
            en: values.joined(separator: ", ")
        )
    }

    private static func clinicalTitle(for alert: HealthAlert) -> String {
        switch alert.type {
        case .vaccineExpired: "Vaccination expired"
        case .vaccineExpiringSoon: "Vaccination expiring soon"
        case .dewormingDue: "Deworming due"
        case .weightGainAlert: "Weight increased noticeably"
        case .weightLossAlert: "Weight dropped noticeably"
        case .noCheckIn: "No care check-in"
        case .noPotty: "Potty tracking overdue"
        case .noWalk: "Walk overdue"
        case .checkupOverdue: "Checkup overdue"
        case .documentExpiringSoon: "Document expiring soon"
        case .activeSymptom: "Active symptom needs attention"
        case .heatCycleAlert: "Heat cycle alert"
        case .pregnancyCountdown: "Pregnancy countdown"
        case .drinkingWeightAlert: "Drinking and weight change"
        case .lowActivityAlert: "Low activity"
        }
    }

    private static func clinicalDetail(for alert: HealthAlert) -> String {
        switch alert.type {
        case .vaccineExpired:
            "A vaccination record has expired. Schedule a booster soon."
        case .vaccineExpiringSoon:
            "A vaccination record is nearing expiry. Consider booking ahead."
        case .dewormingDue:
            "Deworming is due soon. Keep the preventive care plan on track."
        case .weightGainAlert:
            "Recent weight is trending up. Review feeding and activity."
        case .weightLossAlert:
            "Recent weight is trending down. Check appetite and health signs."
        case .noCheckIn:
            "No recent feeding or water check-in has been recorded."
        case .noPotty:
            "Potty tracking is overdue. Watch elimination patterns."
        case .noWalk:
            "Walk activity is overdue. Add a walk when possible."
        case .checkupOverdue:
            "A health checkup is overdue or missing."
        case .documentExpiringSoon:
            "A document is expiring soon. Review it before the due date."
        case .activeSymptom:
            "A recent symptom was marked severe. Consider contacting a vet."
        case .heatCycleAlert:
            "Heat-cycle care needs extra attention."
        case .pregnancyCountdown:
            "Pregnancy care is approaching a key date."
        case .drinkingWeightAlert:
            "Drinking changes and weight movement appeared together."
        case .lowActivityAlert:
            "Recent activity is very low. Watch comfort and mobility."
        }
    }

    private static func iconName(for alert: HealthAlert) -> String {
        switch alert.type {
        case .vaccineExpired, .vaccineExpiringSoon:
            "syringe.fill"
        case .dewormingDue:
            "pills.fill"
        case .weightGainAlert, .weightLossAlert:
            "scalemass.fill"
        case .checkupOverdue, .activeSymptom:
            "cross.case.fill"
        case .documentExpiringSoon:
            "doc.badge.clock.fill"
        case .drinkingWeightAlert:
            "drop.triangle.fill"
        case .lowActivityAlert:
            "chart.line.downtrend.xyaxis"
        case .heatCycleAlert:
            "heart.text.square.fill"
        case .pregnancyCountdown:
            "figure.2.and.child.holdinghands"
        case .noCheckIn, .noPotty, .noWalk:
            "exclamationmark.triangle.fill"
        }
    }

    private static func appetiteTrendSignal(for pet: Pet, calendar: Calendar, now: Date) -> IslandNegativeSignal? {
        let feedLogs = pet.careLogs.filter { $0.careType == .feeding && $0.amountGrams > 0 }
        guard feedLogs.count >= 4 else { return nil }
        let recent = dailyAverageAmount(feedLogs, amount: \.amountGrams, daysAgo: 0 ..< 3, calendar: calendar, now: now)
        let previous = dailyAverageAmount(feedLogs, amount: \.amountGrams, daysAgo: 3 ..< 6, calendar: calendar, now: now)
        guard previous > 0, recent > 0, recent < previous * 0.65 else { return nil }
        return IslandNegativeSignal(
            iconName: "fork.knife.circle.fill",
            emoji: "🍽️",
            title: localized(zh: "\(pet.name) 食欲下降", en: "\(pet.name)'s appetite dropped"),
            detail: localized(
                zh: "近 3 天喂食量比前 3 天低约 \(Int((1 - recent / previous) * 100))%，建议观察精神和便便",
                en: "Feeding volume is about \(Int((1 - recent / previous) * 100))% lower than the previous 3 days. Watch energy and stool."
            ),
            severity: .warning,
            petId: pet.id
        )
    }

    private static func abnormalPottyTrendSignal(for pet: Pet, calendar: Calendar, now: Date) -> IslandNegativeSignal? {
        let start = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let abnormal = pet.pottyLogs.filter {
            $0.date >= start && ($0.pottyType == .softPoop || $0.pottyType == .liquidPoop)
        }
        guard abnormal.count >= 2 else { return nil }
        return IslandNegativeSignal(
            iconName: "exclamationmark.triangle.fill",
            emoji: "🚽",
            title: localized(zh: "\(pet.name) 便便异常", en: "\(pet.name)'s stool looks unusual"),
            detail: localized(
                zh: "近 3 天记录到 \(abnormal.count) 次软便/水便，建议留意饮食变化",
                en: "\(abnormal.count) soft or liquid stool record(s) in the last 3 days. Watch diet changes."
            ),
            severity: abnormal.contains { $0.pottyType == .liquidPoop } ? .critical : .warning,
            petId: pet.id
        )
    }

    private static func drinkingTrendSignal(for pet: Pet, calendar: Calendar, now: Date) -> IslandNegativeSignal? {
        let waterLogs = pet.careLogs.filter { $0.careType == .watering && $0.amountMl > 0 }
        guard waterLogs.count >= 4 else { return nil }
        let recent = dailyAverageAmount(waterLogs, amount: \.amountMl, daysAgo: 0 ..< 3, calendar: calendar, now: now)
        let previous = dailyAverageAmount(waterLogs, amount: \.amountMl, daysAgo: 3 ..< 6, calendar: calendar, now: now)
        guard previous > 0, recent > 0 else { return nil }
        if recent > previous * 1.7 {
            return IslandNegativeSignal(
                iconName: "drop.triangle.fill",
                emoji: "💧",
                title: localized(zh: "\(pet.name) 喝水增多", en: "\(pet.name) is drinking more"),
                detail: localized(
                    zh: "近 3 天饮水量明显高于之前，建议结合体重和尿尿观察",
                    en: "Water intake is much higher over the last 3 days. Compare with weight and pee patterns."
                ),
                severity: .warning,
                petId: pet.id
            )
        }
        if recent < previous * 0.45 {
            return IslandNegativeSignal(
                iconName: "drop.triangle.fill",
                emoji: "💧",
                title: localized(zh: "\(pet.name) 喝水减少", en: "\(pet.name) is drinking less"),
                detail: localized(
                    zh: "近 3 天饮水量明显偏低，建议检查水碗和精神状态",
                    en: "Water intake is low over the last 3 days. Check the bowl and energy level."
                ),
                severity: .warning,
                petId: pet.id
            )
        }
        return nil
    }

    private static func dailyAverageAmount(
        _ logs: [PetCareLog],
        amount: KeyPath<PetCareLog, Double>,
        daysAgo: Range<Int>,
        calendar: Calendar,
        now: Date
    ) -> Double {
        let values = daysAgo.map { dayOffset -> Double in
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return 0 }
            return logs
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1[keyPath: amount] }
        }
        let nonZero = values.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0, +) / Double(nonZero.count)
    }
}
