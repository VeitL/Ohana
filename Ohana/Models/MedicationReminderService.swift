//
//  MedicationReminderService.swift
//  Ohana
//
//  P0: 用药提醒服务 — 按频次注册每日定时推送，并跟踪今日服药进度
//

import Foundation
import UserNotifications

// MARK: - 今日服药进度追踪 Key

extension MedicationReminderService {
    /// UserDefaults key for today's dose log: "med_doses_YYYY-MM-dd_<medicationId>"
    static func dosesKey(medicationId: UUID) -> String {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return "med_doses_\(today)_\(medicationId.uuidString)"
    }

    /// 今日已服次数
    static func dosesTakenToday(for medicationId: UUID) -> Int {
        UserDefaults.standard.integer(forKey: dosesKey(medicationId: medicationId))
    }

    /// 记录一次服药
    static func recordDose(for medicationId: UUID) {
        let key = dosesKey(medicationId: medicationId)
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }

    /// 撤销最后一次服药（undo）
    static func undoDose(for medicationId: UUID) {
        let key = dosesKey(medicationId: medicationId)
        let current = UserDefaults.standard.integer(forKey: key)
        if current > 0 {
            UserDefaults.standard.set(current - 1, forKey: key)
        }
    }
}

// MARK: - 频次 → 每日次数

extension PetMedicationFrequency {
    /// 每日应服次数（asNeeded / custom = 0 表示按需，不自动调度）
    var dosesPerDay: Int {
        switch self {
        case .daily:             return 1
        case .twiceDaily:        return 2
        case .threeTimesDaily:   return 3
        case .everyOtherDay:     return 1  // 隔天算作1次
        case .weekly:            return 1  // 每周
        case .asNeeded:          return 0
        case .custom:            return 0
        }
    }
}

extension MedicationFrequency {
    var dosesPerDay: Int {
        switch self {
        case .daily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .weekly: return 1
        case .asNeeded: return 0
        case .custom: return 0
        }
    }
}

// MARK: - Reminder Service

final class MedicationReminderService {

    static let shared = MedicationReminderService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - 调度单个宠物的用药通知（覆盖替换）

    func scheduleMedicationReminders(for pet: Pet) {
        let meds = pet.medications.filter { $0.isActiveToday }

        // 先移除该宠物旧的用药通知
        let prefix = "medreminder_\(pet.id.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            // 重新调度
            for med in meds {
                self.scheduleRemindersForMedication(med, pet: pet)
            }
        }
    }

    // MARK: - 调度单个药物的通知（未来14天窗口）

    private func scheduleRemindersForMedication(_ med: PetMedication, pet: Pet) {
        let dosesPerDay = med.frequency.dosesPerDay
        guard dosesPerDay > 0 else { return } // asNeeded / custom 不推送

        // 每次提醒之间的小时间隔
        let intervalHours = 24.0 / Double(dosesPerDay)
        let calendar = Calendar.current
        let now = Date()

        // 起始基准时间：今天 08:00
        var baseComponents = calendar.dateComponents([.year, .month, .day], from: now)
        baseComponents.hour = 8
        baseComponents.minute = 0
        baseComponents.second = 0
        guard let baseTime = calendar.date(from: baseComponents) else { return }

        var scheduled = 0
        let maxNotifications = 14 * dosesPerDay // 14天窗口

        outerLoop: for day in 0..<14 {
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: baseTime) else { continue }

            // 检查 everyOtherDay：只有奇数天调度（从startDate算起）
            if med.frequency == .everyOtherDay {
                let daysSinceStart = calendar.dateComponents([.day], from: med.startDate, to: dayDate).day ?? 0
                if daysSinceStart % 2 != 0 { continue }
            }

            for doseIdx in 0..<dosesPerDay {
                let fireDate = dayDate.addingTimeInterval(Double(doseIdx) * intervalHours * 3600)
                guard fireDate > now else { continue }
                if let endDate = med.endDate, fireDate > endDate { break outerLoop }

                let content = UNMutableNotificationContent()
                content.title = "💊 \(pet.name)服药提醒"
                content.body = "\(med.name) · \(med.dosage)"
                content.sound = .default
                content.userInfo = [
                    "medicationId": med.id.uuidString,
                    "petId": pet.id.uuidString
                ]
                content.categoryIdentifier = "MED_REMINDER"

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "medreminder_\(pet.id.uuidString)_\(med.id.uuidString)_d\(day)_i\(doseIdx)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                center.add(request) { _ in }
                scheduled += 1
                if scheduled >= maxNotifications { break outerLoop }
            }
        }

        // 疗程结束前3天提醒
        scheduleEndReminder(for: med, pet: pet)
    }

    // MARK: - 疗程结束前3天提醒

    private func scheduleEndReminder(for med: PetMedication, pet: Pet) {
        guard let endDate = med.endDate else { return }
        guard let alertDate = Calendar.current.date(byAdding: .day, value: -3, to: endDate) else { return }
        guard alertDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⏳ \(pet.name)用药即将结束"
        content.body = "\(med.name) 疗程还剩 3 天，请确认是否续药"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "medend_\(pet.id.uuidString)_\(med.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    // MARK: - 取消某只宠物所有用药通知

    func cancelMedicationReminders(for petId: UUID) {
        let prefix = "medreminder_\(petId.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - 调度单个人的用药通知

    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication]) {
        let activeMeds = meds.filter { $0.isActiveToday }

        let prefix = "humanmedreminder_\(human.id.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            for med in activeMeds {
                self.scheduleRemindersForHumanMedication(med, human: human)
            }
        }
    }

    private func scheduleRemindersForHumanMedication(_ med: HumanMedication, human: Human) {
        let dosesPerDay = med.frequency.dosesPerDay
        guard dosesPerDay > 0 else { return }

        let intervalHours = 24.0 / Double(dosesPerDay)
        let calendar = Calendar.current
        let now = Date()

        var baseComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: med.firstDoseTime)
        baseComponents.hour = timeComponents.hour ?? 8
        baseComponents.minute = timeComponents.minute ?? 0
        baseComponents.second = 0
        guard let baseTime = calendar.date(from: baseComponents) else { return }

        var scheduled = 0
        let maxNotifications = 14 * dosesPerDay

        outerLoop: for day in 0..<14 {
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: baseTime) else { continue }

            if med.frequency == .weekly {
                let daysSinceStart = calendar.dateComponents([.day], from: med.startDate, to: dayDate).day ?? 0
                if daysSinceStart % 7 != 0 { continue }
            }

            for doseIdx in 0..<dosesPerDay {
                let fireDate = dayDate.addingTimeInterval(Double(doseIdx) * intervalHours * 3600)
                guard fireDate > now else { continue }
                if let endDate = med.endDate, fireDate > endDate { break outerLoop }

                let content = UNMutableNotificationContent()
                content.title = "💊 吃药提醒"
                content.body = "\(med.name) · \(med.dosage)"
                content.sound = .default
                content.userInfo = [
                    "humanMedicationId": med.id.uuidString,
                    "humanId": human.id.uuidString
                ]
                content.categoryIdentifier = "HUMAN_MED_REMINDER"

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "humanmedreminder_\(human.id.uuidString)_\(med.id.uuidString)_d\(day)_i\(doseIdx)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                center.add(request) { _ in }
                scheduled += 1
                if scheduled >= maxNotifications { break outerLoop }
            }
        }
    }

    // MARK: - 取消某个人的所有用药通知

    func cancelHumanMedicationReminders(for humanId: UUID) {
        let prefix = "humanmedreminder_\(humanId.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}

// MARK: - DateFormatter helper

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
