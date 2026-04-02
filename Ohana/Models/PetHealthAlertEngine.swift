//
//  PetHealthAlertEngine.swift
//  Ohana
//
//  TASK 7: 宠物健康异常检测引擎
//  检测疫苗过期、体重异常、久未打卡、体内驱虫到期等异常，生成 HealthAlert 列表
//

import Foundation
import SwiftData

// MARK: - HealthAlert

struct HealthAlert: Identifiable, Equatable {
    let id: UUID
    let petId: UUID
    let petName: String
    let petEmoji: String
    let type: AlertType
    let title: String
    let detail: String
    let severity: Severity
    let generatedAt: Date

    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1
        case urgent = 2
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum AlertType: String {
        case vaccineExpired      = "vaccine_expired"
        case vaccineExpiringSoon = "vaccine_expiring_soon"
        case dewormingDue        = "deworming_due"
        case weightGainAlert     = "weight_gain"
        case weightLossAlert     = "weight_loss"
        case noCheckIn           = "no_checkin"
        case noPotty             = "no_potty"
        case noWalk              = "no_walk"
        case checkupOverdue      = "checkup_overdue"
        case documentExpiringSoon = "document_expiring_soon"
        
        // 新增预警类型
        case activeSymptom       = "active_symptom"
        case heatCycleAlert      = "heat_cycle_alert"
        case pregnancyCountdown  = "pregnancy_countdown"
        case drinkingWeightAlert = "drinking_weight_alert"
        case lowActivityAlert    = "low_activity_alert"
    }

    var emoji: String {
        switch type {
        case .vaccineExpired:       return "💉"
        case .vaccineExpiringSoon:  return "⚠️"
        case .dewormingDue:         return "🪱"
        case .weightGainAlert:      return "⚖️"
        case .weightLossAlert:      return "⚖️"
        case .noCheckIn:            return "📅"
        case .noPotty:              return "🚽"
        case .noWalk:               return "🐾"
        case .checkupOverdue:       return "🩺"
        case .documentExpiringSoon: return "📄"
        case .activeSymptom:        return "🚨"
        case .heatCycleAlert:       return "💖"
        case .pregnancyCountdown:   return "🍼"
        case .drinkingWeightAlert:  return "💧"
        case .lowActivityAlert:     return "📉"
        }
    }
}

// MARK: - PetHealthAlertEngine

final class PetHealthAlertEngine {
    static let shared = PetHealthAlertEngine()
    private init() {}

    // MARK: - 主入口

    /// 扫描所有宠物，返回按严重程度排序的警报列表
    func scanAlerts(pets: [Pet]) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let now = Date()
        let cal = Calendar.current

        for pet in pets where !pet.hasPassedAway {
            alerts += checkVaccines(pet: pet, now: now, cal: cal)
            alerts += checkDeworming(pet: pet, now: now, cal: cal)
            alerts += checkWeight(pet: pet, now: now, cal: cal)
            alerts += checkCheckIn(pet: pet, now: now, cal: cal)
            alerts += checkPotty(pet: pet, now: now, cal: cal)
            alerts += checkWalk(pet: pet, now: now, cal: cal)
            alerts += checkCheckup(pet: pet, now: now, cal: cal)
            alerts += checkDocuments(pet: pet, now: now, cal: cal)
            
            // 新增检查项目
            alerts += checkSymptoms(pet: pet, now: now, cal: cal)
            alerts += checkReproductiveHealth(pet: pet, now: now, cal: cal)
            alerts += checkCrossCorrelation(pet: pet, now: now, cal: cal)
        }

        return alerts.sorted { $0.severity > $1.severity }
    }

    // MARK: - 疫苗检测

    private func checkVaccines(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let vaccineLogs = pet.healthLogs.filter { $0.healthLogType == .vaccine && $0.expirationDate != nil }

        for log in vaccineLogs {
            guard let expiry = log.expirationDate else { continue }
            let days = cal.dateComponents([.day], from: now, to: expiry).day ?? 0
            if expiry < now {
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .vaccineExpired,
                    title: "疫苗已过期",
                    detail: "「\(log.note.isEmpty ? "疫苗" : log.note)」已于 \(expiry.formatted(.dateTime.month().day())) 过期，请尽快补种。",
                    severity: .urgent,
                    generatedAt: now
                ))
            } else if days <= 30 {
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .vaccineExpiringSoon,
                    title: "疫苗即将到期",
                    detail: "「\(log.note.isEmpty ? "疫苗" : log.note)」将在 \(days) 天后到期，建议提前预约。",
                    severity: .warning,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    // MARK: - 驱虫检测

    private func checkDeworming(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let dewormLogs = pet.healthLogs.filter {
            ($0.healthLogType == .dewormingInternal || $0.healthLogType == .dewormingExternal)
            && $0.expirationDate != nil
        }
        for log in dewormLogs {
            guard let expiry = log.expirationDate else { continue }
            let days = cal.dateComponents([.day], from: now, to: expiry).day ?? 0
            if days <= 14 {
                let label = log.healthLogType == .dewormingInternal ? "体内驱虫" : "体外驱虫"
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .dewormingDue,
                    title: "\(label)即将到期",
                    detail: "\(label) 将在 \(max(0, days)) 天后到期，记得按时补充。",
                    severity: days <= 3 ? .urgent : .warning,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    // MARK: - 体重异常检测

    private func checkWeight(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        let sorted = pet.weightLogs.sorted { $0.date > $1.date }
        guard sorted.count >= 2 else { return [] }
        let latest = sorted[0].weight
        let prev   = sorted[1].weight
        guard prev > 0 else { return [] }
        let changePct = (latest - prev) / prev * 100

        if changePct >= 10 {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .weightGainAlert,
                title: "体重明显增加",
                detail: String(format: "最近体重增加了 %.1f%%（%.1f → %.1f kg），需注意饮食控制。", changePct, prev, latest),
                severity: .warning,
                generatedAt: now
            )]
        } else if changePct <= -10 {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .weightLossAlert,
                title: "体重明显减轻",
                detail: String(format: "最近体重减少了 %.1f%%（%.1f → %.1f kg），建议排查健康原因。", abs(changePct), prev, latest),
                severity: .warning,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 打卡检测（喂食 / 喂水）

    private func checkCheckIn(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        let careLogs = pet.careLogs.filter { $0.careType == .feeding || $0.careType == .watering }
        guard let last = careLogs.map(\.date).max() else {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .noCheckIn,
                title: "未记录喂食/喂水",
                detail: "尚未记录任何喂食或喂水，请养成每日打卡习惯。",
                severity: .info,
                generatedAt: now
            )]
        }
        let days = cal.dateComponents([.day], from: last, to: now).day ?? 0
        if days >= 2 {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .noCheckIn,
                title: "已 \(days) 天未打卡",
                detail: "距上次喂食/喂水记录已超过 \(days) 天，请保持日常照料记录。",
                severity: days >= 5 ? .warning : .info,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 便便检测

    private func checkPotty(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        guard !["猫", "兔子", "仓鼠"].contains(pet.species) else { return [] }
        guard let last = pet.pottyLogs.map(\.date).max() else { return [] }
        let hours = cal.dateComponents([.hour], from: last, to: now).hour ?? 0
        if hours >= 36 {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .noPotty,
                title: "长时间未记录便便",
                detail: "距上次便便记录已超过 \(hours / 24) 天，注意观察宠物排便状况。",
                severity: hours >= 72 ? .urgent : .warning,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 遛狗检测

    private func checkWalk(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        guard pet.species == "狗" else { return [] }
        guard let last = pet.walkLogs.map(\.startDate).max() else { return [] }
        let days = cal.dateComponents([.day], from: last, to: now).day ?? 0
        if days >= 3 {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .noWalk,
                title: "\(days) 天未遛狗",
                detail: "距上次遛狗已过 \(days) 天，建议每天至少遛一次。",
                severity: days >= 7 ? .warning : .info,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 年度体检检测

    private func checkCheckup(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        let checkups = pet.healthLogs.filter { $0.healthLogType == .checkup }
        guard let last = checkups.map(\.date).max() else {
            guard let birthday = pet.birthday,
                  (cal.dateComponents([.year], from: birthday, to: now).year ?? 0) >= 1 else { return [] }
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .checkupOverdue,
                title: "建议进行年度体检",
                detail: "尚未记录体检，建议每年带宠物做一次全面体检。",
                severity: .info,
                generatedAt: now
            )]
        }
        let days = cal.dateComponents([.day], from: last, to: now).day ?? 0
        if days >= 365 {
            return [HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .checkupOverdue,
                title: "年度体检已逾期",
                detail: "上次体检距今已 \(days / 30) 个月，建议尽快安排复查。",
                severity: days >= 548 ? .warning : .info,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 证件到期检测

    private func checkDocuments(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        for doc in pet.documents {
            guard let expiry = doc.expiryDate else { continue }
            let days = cal.dateComponents([.day], from: now, to: expiry).day ?? 0
            if days <= 30 && expiry >= now {
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .documentExpiringSoon,
                    title: "证件即将到期",
                    detail: "「\(doc.title)」将在 \(days) 天后到期，请提前续期。",
                    severity: days <= 7 ? .urgent : .warning,
                    generatedAt: now
                ))
            } else if expiry < now {
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .documentExpiringSoon,
                    title: "证件已过期",
                    detail: "「\(doc.title)」已于 \(expiry.formatted(.dateTime.month().day())) 过期，请尽快处理。",
                    severity: .urgent,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    // MARK: - 新增异常与生理期检测

    private func checkSymptoms(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let recentSymptoms = pet.symptomLogs.filter { cal.dateComponents([.day], from: $0.date, to: now).day ?? 0 <= 3 }
        
        let severeSymptoms = recentSymptoms.filter { $0.severity == .critical || $0.severity == .severe }
        for symptom in severeSymptoms {
            alerts.append(HealthAlert(
                id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                type: .activeSymptom,
                title: "严重异常症状",
                detail: "近期记录了【\(symptom.symptomName)】，由于情况被标记为\(symptom.severity.label)，建议尽快就医！",
                severity: .urgent,
                generatedAt: now
            ))
        }
        return alerts
    }

    private func checkReproductiveHealth(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        // 只对未绝育的宠物生效
        guard !pet.isNeutered else { return alerts }
        
        if let latestCycle = pet.heatCycleLogs.sorted(by: { $0.startDate > $1.startDate }).first {
            let activeHeat = latestCycle.endDate == nil || latestCycle.endDate! > now
            
            // 孕期倒计时
            if latestCycle.status == .pregnant, activeHeat, let expected = latestCycle.expectedDeliveryDate {
                let daysToDeliver = cal.dateComponents([.day], from: now, to: expected).day ?? 0
                if daysToDeliver > 0 && daysToDeliver <= 7 {
                    alerts.append(HealthAlert(
                        id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                        type: .pregnancyCountdown,
                        title: "待产预警",
                        detail: "预计将在 \(daysToDeliver) 天后生产，请准备好产房和应急物资。",
                        severity: .urgent,
                        generatedAt: now
                    ))
                } else if daysToDeliver <= 0 {
                    alerts.append(HealthAlert(
                        id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                        type: .pregnancyCountdown,
                        title: "进入预产期",
                        detail: "已经到达预产期，请密切关注主子状况并联系兽医备用！",
                        severity: .urgent,
                        generatedAt: now
                    ))
                }
            } else if (latestCycle.status == .proestrus || latestCycle.status == .estrus) && activeHeat {
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .heatCycleAlert,
                    title: "正在发情期",
                    detail: "当前处于发情期，请注意门窗关闭，外出务必牵好牵引绳。",
                    severity: .warning,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    private func checkCrossCorrelation(pet: Pet, now: Date, cal: Calendar) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        
        // 饮水激增 + 体重下降 -> 潜在肾脏或糖尿病风险
        let sortedWeights = pet.weightLogs.sorted { $0.date > $1.date }
        if sortedWeights.count >= 2 {
            let lastW = sortedWeights[0]
            let prevW = sortedWeights[1]
            let weightDropped = lastW.weight < prevW.weight * 0.95 // 掉了 5% 以上
            
            if weightDropped {
                // 检查过去三天的饮水记录总次数，是否超过历史平均很多（这里做一个简化版：近期日均饮水次数>10）
                let recentWaterLogs = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.dateComponents([.day], from: $0.date, to: now).day ?? 0 <= 3 }
                if recentWaterLogs.count >= 20 { // 3天内喝了20次以上
                    alerts.append(HealthAlert(
                        id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                        type: .drinkingWeightAlert,
                        title: "多饮且体重下降",
                        detail: "近期饮水频率异常升高且伴随明显体重下降，建议检查肾脏或内分泌健康。",
                        severity: .warning,
                        generatedAt: now
                    ))
                }
            }
        }
        
        // 连续几天步数严重不达标（狗特有）
        if pet.species.lowercased().contains("dog") || pet.species.lowercased().contains("狗") {
            let past7DaysWalks = pet.walkLogs.filter { cal.dateComponents([.day], from: $0.startDate, to: now).day ?? 0 <= 7 }
            if past7DaysWalks.count <= 1 {
                alerts.append(HealthAlert(
                    id: UUID(), petId: pet.id, petName: pet.name, petEmoji: pet.avatarEmoji,
                    type: .lowActivityAlert,
                    title: "近期活动量极低",
                    detail: "过去 7 天几乎没有出门活动，请留意是否有关节不适或抑郁倾向。",
                    severity: .info,
                    generatedAt: now
                ))
            }
        }
        
        return alerts
    }
}
