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

nonisolated struct HealthAlert: Identifiable, Equatable, Sendable {
    let id: UUID
    let petId: UUID
    let petName: String
    let petEmoji: String
    let type: AlertType
    let title: String
    let detail: String
    let severity: Severity
    let generatedAt: Date

    enum Severity: Int, Comparable, Sendable {
        case info = 0
        case warning = 1
        case urgent = 2
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum AlertType: String, Sendable {
        case vaccineExpired = "vaccine_expired"
        case vaccineExpiringSoon = "vaccine_expiring_soon"
        case dewormingDue = "deworming_due"
        case weightGainAlert = "weight_gain"
        case weightLossAlert = "weight_loss"
        case noCheckIn = "no_checkin"
        case noPotty = "no_potty"
        case noWalk = "no_walk"
        case checkupOverdue = "checkup_overdue"
        case documentExpiringSoon = "document_expiring_soon"

        // 新增预警类型
        case activeSymptom = "active_symptom"
        case heatCycleAlert = "heat_cycle_alert"
        case pregnancyCountdown = "pregnancy_countdown"
        case drinkingWeightAlert = "drinking_weight_alert"
        case lowActivityAlert = "low_activity_alert"
    }

    var emoji: String {
        switch type {
        case .vaccineExpired: "💉"
        case .vaccineExpiringSoon: "⚠️"
        case .dewormingDue: "🪱"
        case .weightGainAlert: "⚖️"
        case .weightLossAlert: "⚖️"
        case .noCheckIn: "📅"
        case .noPotty: "🚽"
        case .noWalk: "🐾"
        case .checkupOverdue: "🩺"
        case .documentExpiringSoon: "📄"
        case .activeSymptom: "🚨"
        case .heatCycleAlert: "💖"
        case .pregnancyCountdown: "🍼"
        case .drinkingWeightAlert: "💧"
        case .lowActivityAlert: "📉"
        }
    }
}

nonisolated struct PetHealthAlertSource {
    let petId: UUID
    let petName: String
    let petEmoji: String
    let species: String
    let birthday: Date?
    let isNeutered: Bool
    let canWriteHealthFacts: Bool
    let healthLogs: [PetHealthLog]
    let weightLogs: [PetWeightLog]
    let careLogs: [PetCareLog]
    let pottyLogs: [PetPottyLog]
    let walkLogs: [PetWalkLog]
    let documents: [PetDocument]
    let symptomLogs: [SymptomLog]
    let heatCycleLogs: [HeatCycleLog]

    init(
        pet: Pet,
        healthLogs: [PetHealthLog],
        weightLogs: [PetWeightLog],
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        walkLogs: [PetWalkLog],
        documents: [PetDocument],
        symptomLogs: [SymptomLog],
        heatCycleLogs: [HeatCycleLog]
    ) {
        self.petId = pet.id
        self.petName = pet.name
        self.petEmoji = pet.avatarEmoji
        self.species = pet.species
        self.birthday = pet.birthday
        self.isNeutered = pet.isNeutered
        self.canWriteHealthFacts = pet.canWriteHealthFacts
        self.healthLogs = healthLogs
        self.weightLogs = weightLogs
        self.careLogs = careLogs
        self.pottyLogs = pottyLogs
        self.walkLogs = walkLogs
        self.documents = documents
        self.symptomLogs = symptomLogs
        self.heatCycleLogs = heatCycleLogs
    }

    init(pet: Pet) {
        self.init(
            pet: pet,
            healthLogs: pet.activeHealthLogs,
            weightLogs: pet.weightLogs,
            careLogs: pet.careLogs,
            pottyLogs: pet.pottyLogs,
            walkLogs: pet.walkLogs,
            documents: pet.documents,
            symptomLogs: pet.activeSymptomLogs,
            heatCycleLogs: pet.activeHeatCycleLogs
        )
    }
}

// MARK: - PetHealthAlertEngine

final nonisolated class PetHealthAlertEngine {
    init() {}

    // MARK: - 主入口

    /// 扫描所有宠物，返回按严重程度排序的警报列表
    func scanAlerts(pets: [Pet], localization l: L10n = L10n()) -> [HealthAlert] {
        scanAlerts(sources: pets.map(PetHealthAlertSource.init(pet:)), localization: l)
    }

    func scanAlerts(sources: [PetHealthAlertSource], localization l: L10n = L10n()) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let now = Date()
        let cal = Calendar.current

        for source in sources where source.canWriteHealthFacts {
            alerts += checkVaccines(source: source, now: now, cal: cal, localization: l)
            alerts += checkDeworming(source: source, now: now, cal: cal, localization: l)
            alerts += checkWeight(source: source, now: now, cal: cal, localization: l)
            alerts += checkCheckIn(source: source, now: now, cal: cal, localization: l)
            alerts += checkPotty(source: source, now: now, cal: cal, localization: l)
            alerts += checkWalk(source: source, now: now, cal: cal, localization: l)
            alerts += checkCheckup(source: source, now: now, cal: cal, localization: l)
            alerts += checkDocuments(source: source, now: now, cal: cal, localization: l)

            // 新增检查项目
            alerts += checkSymptoms(source: source, now: now, cal: cal, localization: l)
            alerts += checkReproductiveHealth(source: source, now: now, cal: cal, localization: l)
            alerts += checkCrossCorrelation(source: source, now: now, cal: cal, localization: l)
        }

        return alerts.sorted { $0.severity > $1.severity }
    }

    // MARK: - 疫苗检测

    private func checkVaccines(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let vaccineLogs = source.healthLogs.filter { $0.healthLogType == .vaccine && $0.expirationDate != nil }

        for log in vaccineLogs {
            guard let expiry = log.expirationDate else { continue }
            let days = cal.dateComponents([.day], from: now, to: expiry).day ?? 0
            if expiry < now {
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .vaccineExpired,
                    title: l.tr(zh: "疫苗已过期", en: "Vaccine expired", de: "Impfung abgelaufen"),
                    detail: l.tr(
                        zh: "「\(log.note.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : log.note)」已于 \(expiry.formatted(.dateTime.month().day())) 过期，请尽快补种。",
                        en: "\"\(log.note.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : log.note)\" expired on \(expiry.formatted(.dateTime.month().day())). Please schedule a booster soon.",
                        de: "\"\(log.note.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : log.note)\" ist am \(expiry.formatted(.dateTime.month().day())) abgelaufen. Bitte bald auffrischen."
                    ),
                    severity: .urgent,
                    generatedAt: now
                ))
            } else if days <= 30 {
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .vaccineExpiringSoon,
                    title: l.tr(zh: "疫苗即将到期", en: "Vaccine expiring soon", de: "Impfung läuft bald ab"),
                    detail: l.tr(
                        zh: "「\(log.note.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : log.note)」将在 \(days) 天后到期，建议提前预约。",
                        en: "\"\(log.note.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : log.note)\" expires in \(days) days. Consider booking ahead.",
                        de: "\"\(log.note.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : log.note)\" läuft in \(days) Tagen ab. Plane am besten frühzeitig."
                    ),
                    severity: .warning,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    // MARK: - 驱虫检测

    private func checkDeworming(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let dewormLogs = source.healthLogs.filter {
            ($0.healthLogType == .dewormingInternal || $0.healthLogType == .dewormingExternal)
                && $0.expirationDate != nil
        }
        for log in dewormLogs {
            guard let expiry = log.expirationDate else { continue }
            let days = cal.dateComponents([.day], from: now, to: expiry).day ?? 0
            if days <= 14 {
                let label = log.healthLogType == .dewormingInternal
                    ? l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
                    : l.tr(zh: "体外驱虫", en: "External parasite care", de: "Äußerer Parasitenschutz")
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .dewormingDue,
                    title: l.tr(zh: "\(label)即将到期", en: "\(label) due soon", de: "\(label) bald fällig"),
                    detail: l.tr(
                        zh: "\(label) 将在 \(max(0, days)) 天后到期，记得按时补充。",
                        en: "\(label) is due in \(max(0, days)) days.",
                        de: "\(label) ist in \(max(0, days)) Tagen fällig."
                    ),
                    severity: days <= 3 ? .urgent : .warning,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    // MARK: - 体重异常检测

    private func checkWeight(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        let sorted = source.weightLogs.sorted { $0.date > $1.date }
        guard sorted.count >= 2, let latestLog = sorted.first else { return [] }
        let cutoff = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let baselineLog = sorted
            .last { $0.date >= cutoff } ?? sorted[1]
        let latest = latestLog.weightInKg
        let baseline = baselineLog.weightInKg
        guard baseline > 0 else { return [] }
        let changePct = (latest - baseline) / baseline * 100
        let days = max(1, cal.dateComponents([.day], from: baselineLog.date, to: latestLog.date).day ?? 1)

        if changePct >= 10 {
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .weightGainAlert,
                title: l.tr(zh: "体重明显增加", en: "Weight increased", de: "Gewicht deutlich gestiegen"),
                detail: l.tr(
                    zh: String(format: "近 %d 天体重增加了 %.1f%%（%.1f → %.1f kg），需注意饮食控制。", days, changePct, baseline, latest),
                    en: String(format: "Weight rose %.1f%% over %d days (%.1f → %.1f kg). Consider reviewing diet portions.", changePct, days, baseline, latest),
                    de: String(format: "Das Gewicht stieg in %d Tagen um %.1f%% (%.1f → %.1f kg). Prüfe die Futtermenge.", days, changePct, baseline, latest)
                ),
                severity: changePct >= 15 ? .urgent : .warning,
                generatedAt: now
            )]
        } else if changePct <= -10 {
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .weightLossAlert,
                title: l.tr(zh: "体重明显减轻", en: "Weight decreased", de: "Gewicht deutlich gesunken"),
                detail: l.tr(
                    zh: String(format: "近 %d 天体重减少了 %.1f%%（%.1f → %.1f kg），建议排查健康原因。", days, abs(changePct), baseline, latest),
                    en: String(format: "Weight dropped %.1f%% over %d days (%.1f → %.1f kg). Consider checking for health causes.", abs(changePct), days, baseline, latest),
                    de: String(format: "Das Gewicht sank in %d Tagen um %.1f%% (%.1f → %.1f kg). Bitte gesundheitliche Ursachen prüfen.", days, abs(changePct), baseline, latest)
                ),
                severity: changePct <= -15 ? .urgent : .warning,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 打卡检测（喂食 / 喂水）

    private func checkCheckIn(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        let careLogs = source.careLogs.filter {
            $0.careType == .feeding ||
                $0.careType == .watering ||
                $0.careType == .waterChange
        }
        guard let last = careLogs.map(\.date).max() else {
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .noCheckIn,
                title: l.tr(zh: "未记录喂食/喂水", en: "No food or water logs", de: "Keine Futter- oder Wassereinträge"),
                detail: l.tr(
                    zh: "尚未记录任何喂食、喂水或换水，请养成每日打卡习惯。",
                    en: "No feeding, water, or water-change logs yet. Daily check-ins keep care visible.",
                    de: "Noch keine Futter-, Wasser- oder Wasserwechsel-Einträge. Tägliche Einträge halten die Pflege sichtbar."
                ),
                severity: .info,
                generatedAt: now
            )]
        }
        let days = cal.dateComponents([.day], from: last, to: now).day ?? 0
        if days >= 2 {
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .noCheckIn,
                title: l.tr(zh: "已 \(days) 天未打卡", en: "\(days) days without check-ins", de: "\(days) Tage ohne Eintrag"),
                detail: l.tr(
                    zh: "距上次喂食、喂水或换水记录已超过 \(days) 天，请保持日常照料记录。",
                    en: "It has been over \(days) days since the last food, water, or water-change log.",
                    de: "Seit dem letzten Futter-, Wasser- oder Wasserwechsel-Eintrag sind über \(days) Tage vergangen."
                ),
                severity: days >= 5 ? .warning : .info,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 便便检测

    private func checkPotty(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        guard !Pet.isCatSpecies(source.species),
              !Pet.isRabbitSpecies(source.species),
              !Pet.isSmallMammalSpecies(source.species)
        else { return [] }
        guard let last = source.pottyLogs.map(\.date).max() else { return [] }
        let hours = cal.dateComponents([.hour], from: last, to: now).hour ?? 0
        if hours >= 36 {
            let elapsedText = hours < 48
                ? l.tr(zh: "\(hours) 小时", en: "\(hours) hours", de: "\(hours) Stunden")
                : l.tr(zh: "\(max(1, hours / 24)) 天", en: "\(max(1, hours / 24)) days", de: "\(max(1, hours / 24)) Tage")
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .noPotty,
                title: l.tr(zh: "长时间未记录便便", en: "No potty log for a while", de: "Lange kein Häufchen-Eintrag"),
                detail: l.tr(
                    zh: "距上次便便记录已超过 \(elapsedText)，注意观察宠物排便状况。",
                    en: "It has been more than \(elapsedText) since the last potty log. Keep an eye on elimination.",
                    de: "Seit dem letzten Häufchen-Eintrag sind über \(elapsedText) vergangen. Bitte die Verdauung beobachten."
                ),
                severity: hours >= 72 ? .urgent : .warning,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 遛狗检测

    private func checkWalk(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        guard Pet.isDogSpecies(source.species) else { return [] }
        guard let last = source.walkLogs.map(\.startDate).max() else { return [] }
        let days = cal.dateComponents([.day], from: last, to: now).day ?? 0
        if days >= 3 {
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .noWalk,
                title: l.tr(zh: "\(days) 天未遛狗", en: "\(days) days without a walk", de: "\(days) Tage ohne Gassi"),
                detail: l.tr(
                    zh: "距上次遛狗已过 \(days) 天，建议每天至少遛一次。",
                    en: "It has been \(days) days since the last walk. A daily walk is recommended.",
                    de: "Seit dem letzten Spaziergang sind \(days) Tage vergangen. Tägliches Gassi ist empfehlenswert."
                ),
                severity: days >= 7 ? .warning : .info,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 年度体检检测

    private func checkCheckup(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        let checkups = source.healthLogs.filter { $0.healthLogType == .checkup }
        guard let last = checkups.map(\.date).max() else {
            guard let birthday = source.birthday,
                  (cal.dateComponents([.year], from: birthday, to: now).year ?? 0) >= 1 else { return [] }
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .checkupOverdue,
                title: l.tr(zh: "建议进行年度体检", en: "Annual checkup recommended", de: "Jährlicher Check-up empfohlen"),
                detail: l.tr(
                    zh: "尚未记录体检，建议每年带宠物做一次全面体检。",
                    en: "No checkup has been logged yet. A full annual exam is recommended.",
                    de: "Noch kein Check-up erfasst. Eine jährliche Untersuchung ist empfehlenswert."
                ),
                severity: .info,
                generatedAt: now
            )]
        }
        let days = cal.dateComponents([.day], from: last, to: now).day ?? 0
        if days >= 365 {
            return [HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .checkupOverdue,
                title: l.tr(zh: "年度体检已逾期", en: "Annual checkup overdue", de: "Jährlicher Check-up überfällig"),
                detail: l.tr(
                    zh: "上次体检距今已 \(days / 30) 个月，建议尽快安排复查。",
                    en: "The last checkup was \(days / 30) months ago. Consider scheduling a follow-up soon.",
                    de: "Der letzte Check-up war vor \(days / 30) Monaten. Plane bald eine Kontrolle."
                ),
                severity: days >= 548 ? .warning : .info,
                generatedAt: now
            )]
        }
        return []
    }

    // MARK: - 证件到期检测

    private func checkDocuments(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        for doc in source.documents {
            guard let expiry = doc.expiryDate else { continue }
            let days = cal.dateComponents([.day], from: now, to: expiry).day ?? 0
            if days <= 30, expiry >= now {
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .documentExpiringSoon,
                    title: l.tr(zh: "证件即将到期", en: "Document expiring soon", de: "Dokument läuft bald ab"),
                    detail: l.tr(
                        zh: "「\(doc.title)」将在 \(days) 天后到期，请提前续期。",
                        en: "\"\(doc.title)\" expires in \(days) days. Renew it ahead of time.",
                        de: "\"\(doc.title)\" läuft in \(days) Tagen ab. Bitte rechtzeitig verlängern."
                    ),
                    severity: days <= 7 ? .urgent : .warning,
                    generatedAt: now
                ))
            } else if expiry < now {
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .documentExpiringSoon,
                    title: l.tr(zh: "证件已过期", en: "Document expired", de: "Dokument abgelaufen"),
                    detail: l.tr(
                        zh: "「\(doc.title)」已于 \(expiry.formatted(.dateTime.month().day())) 过期，请尽快处理。",
                        en: "\"\(doc.title)\" expired on \(expiry.formatted(.dateTime.month().day())). Please handle it soon.",
                        de: "\"\(doc.title)\" ist am \(expiry.formatted(.dateTime.month().day())) abgelaufen. Bitte bald bearbeiten."
                    ),
                    severity: .urgent,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    // MARK: - 新增异常与生理期检测

    private func checkSymptoms(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let recentSymptoms = source.symptomLogs.filter { cal.dateComponents([.day], from: $0.date, to: now).day ?? 0 <= 3 }

        let severeSymptoms = recentSymptoms.filter { $0.severity == .critical || $0.severity == .severe }
        for symptom in severeSymptoms {
            alerts.append(HealthAlert(
                id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                type: .activeSymptom,
                title: l.tr(zh: "严重异常症状", en: "Serious symptom logged", de: "Schweres Symptom erfasst"),
                detail: l.tr(
                    zh: "近期记录了【\(symptom.symptomName)】，由于情况被标记为\(symptom.severity.label)，建议尽快就医！",
                    en: "\"\(symptom.symptomName)\" was recently marked \(symptom.severity.label). Consider contacting a vet soon.",
                    de: "\"\(symptom.symptomName)\" wurde kürzlich als \(symptom.severity.label) markiert. Bitte bald tierärztlich abklären."
                ),
                severity: .urgent,
                generatedAt: now
            ))
        }
        return alerts
    }

    private func checkReproductiveHealth(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        // 只对未绝育的宠物生效
        guard !source.isNeutered else { return alerts }

        if let latestCycle = source.heatCycleLogs.sorted(by: { $0.startDate > $1.startDate }).first {
            let activeHeat = latestCycle.endDate == nil || latestCycle.endDate! > now

            // 孕期倒计时
            if latestCycle.status == .pregnant, activeHeat, let expected = latestCycle.expectedDeliveryDate {
                let daysToDeliver = cal.dateComponents([.day], from: now, to: expected).day ?? 0
                if daysToDeliver > 0, daysToDeliver <= 7 {
                    alerts.append(HealthAlert(
                        id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                        type: .pregnancyCountdown,
                        title: l.tr(zh: "待产预警", en: "Delivery approaching", de: "Geburt rückt näher"),
                        detail: l.tr(
                            zh: "预计将在 \(daysToDeliver) 天后生产，请准备好产房和应急物资。",
                            en: "Delivery is expected in \(daysToDeliver) days. Prepare a nesting area and emergency supplies.",
                            de: "Die Geburt wird in \(daysToDeliver) Tagen erwartet. Bereite Wurfplatz und Notfallmaterial vor."
                        ),
                        severity: .urgent,
                        generatedAt: now
                    ))
                } else if daysToDeliver <= 0 {
                    alerts.append(HealthAlert(
                        id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                        type: .pregnancyCountdown,
                        title: l.tr(zh: "进入预产期", en: "Due date reached", de: "Geburtstermin erreicht"),
                        detail: l.tr(
                            zh: "已经到达预产期，请密切关注主子状况并联系兽医备用！",
                            en: "The expected delivery date has arrived. Monitor closely and keep a vet contact ready.",
                            de: "Der erwartete Geburtstermin ist erreicht. Beobachte genau und halte den Tierarztkontakt bereit."
                        ),
                        severity: .urgent,
                        generatedAt: now
                    ))
                }
            } else if latestCycle.status == .proestrus || latestCycle.status == .estrus, activeHeat {
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .heatCycleAlert,
                    title: l.tr(zh: "正在发情期", en: "In heat", de: "Läufigkeit aktiv"),
                    detail: l.tr(
                        zh: "当前处于发情期，请注意门窗关闭，外出务必牵好牵引绳。",
                        en: "Heat cycle is active. Keep doors and windows secure, and use a leash outdoors.",
                        de: "Die Läufigkeit ist aktiv. Türen und Fenster sichern und draußen unbedingt anleinen."
                    ),
                    severity: .warning,
                    generatedAt: now
                ))
            }
        }
        return alerts
    }

    private func checkCrossCorrelation(source: PetHealthAlertSource, now: Date, cal: Calendar, localization l: L10n) -> [HealthAlert] {
        var alerts: [HealthAlert] = []

        // 饮水激增 + 体重下降 -> 潜在肾脏或糖尿病风险
        let sortedWeights = source.weightLogs.sorted { $0.date > $1.date }
        if sortedWeights.count >= 2 {
            let lastW = sortedWeights[0]
            let prevW = sortedWeights[1]
            let weightDropped = lastW.weight < prevW.weight * 0.95 // 掉了 5% 以上

            if weightDropped {
                // 检查过去三天的饮水记录总次数，是否超过历史平均很多（这里做一个简化版：近期日均饮水次数>10）
                let recentWaterLogs = source.careLogs.filter { $0.type == CareType.watering.rawValue && cal.dateComponents([.day], from: $0.date, to: now).day ?? 0 <= 3 }
                if recentWaterLogs.count >= 20 { // 3天内喝了20次以上
                    alerts.append(HealthAlert(
                        id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                        type: .drinkingWeightAlert,
                        title: l.tr(zh: "多饮且体重下降", en: "More drinking with weight loss", de: "Mehr Trinken und Gewichtsverlust"),
                        detail: l.tr(
                            zh: "近期饮水频率异常升高且伴随明显体重下降，建议检查肾脏或内分泌健康。",
                            en: "Recent water frequency is unusually high while weight is dropping. Consider checking kidney or endocrine health.",
                            de: "Die Trinkhäufigkeit ist ungewöhnlich hoch und das Gewicht sinkt. Nieren- oder Hormonwerte prüfen lassen."
                        ),
                        severity: .warning,
                        generatedAt: now
                    ))
                }
            }
        }

        // 连续几天步数严重不达标（狗特有）
        if Pet.isDogSpecies(source.species) {
            let past7DaysWalks = source.walkLogs.filter { cal.dateComponents([.day], from: $0.startDate, to: now).day ?? 0 <= 7 }
            if past7DaysWalks.count <= 1 {
                alerts.append(HealthAlert(
                    id: UUID(), petId: source.petId, petName: source.petName, petEmoji: source.petEmoji,
                    type: .lowActivityAlert,
                    title: l.tr(zh: "近期活动量极低", en: "Very low activity", de: "Sehr wenig Aktivität"),
                    detail: l.tr(
                        zh: "过去 7 天几乎没有出门活动，请留意是否有关节不适或抑郁倾向。",
                        en: "There has been almost no outdoor activity in the past 7 days. Watch for joint discomfort or low mood.",
                        de: "In den letzten 7 Tagen gab es kaum Aktivität draußen. Achte auf Gelenkbeschwerden oder gedrückte Stimmung."
                    ),
                    severity: .info,
                    generatedAt: now
                ))
            }
        }

        return alerts
    }
}
