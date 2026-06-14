//
//  PetHealthDetailView.swift
//  Ohana
//
//  健康详情页 — 饮食管理页风格
//  深色背景 + ScrollView卡片 + Swift Charts
//

import SwiftData
import SwiftUI

struct PetHealthDetailContentView: View {
    let pet: Pet
    let allEvents: [Event]
    var isModal: Bool = false
    var initialSection: PetHealthInitialSection?
    /// D4: 关闭时额外回调（如需一并关闭父级）
    var onFullDismiss: (() -> Void)?
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = "zh"
    /// 健康页「+」与免疫条点按的路由
    @State var healthPlusDestination: HealthPlusDestination?
    @State var activeHealthSheet: ActiveHealthSheet?
    @State var showingPDFPreview = false
    @State var pdfURL: URL? = nil
    @State var isRenderingPDF = false
    @State var healthAlerts: [HealthAlert] = []
    @State var scatterRevealProgress: CGFloat = 0.0
    @State var showingHistory = false
    @State var showingPassport = false
    @State var isHealthFabExpanded = false
    @State var healthFabItemsVisible = false
    @State var showingMedicationPopup = false
    @State var medicationDoseRefreshToken = UUID()
    @State var didOpenInitialSection = false
    @State var deletingHealthRecordIDs: Set<UUID> = []
    @StateObject var commandQueue = DeferredDomainCommandQueue()

    func playScatterReveal() {
        scatterRevealProgress = 0
        withAnimation(GoMotion.quick) {
            scatterRevealProgress = 1.0
        }
    }

    var themeColor: Color { pet.themeColor.color }
    var isDark: Bool { colorScheme == .dark }
    var l: L10n { L10n(appLanguage) }
    /// 深色：界面结构色统一荧光绿；与宠物相关的记录语义仍用 `themeColor` / `colorForType`
    var chromeAccent: Color { isDark ? Color.goPrimary : Color.goBlue }

    var sortedLogs: [PetHealthLog] {
        pet.activeHealthLogs.sorted { $0.date > $1.date }
    }

    func latestLog(type: HealthLogType) -> PetHealthLog? {
        pet.activeHealthLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }.first
    }

    func dueDate(for type: HealthLogType) -> Date? {
        guard let last = latestLog(type: type) else { return nil }
        if let expirationDate = last.expirationDate {
            return expirationDate
        }
        if type == .checkup, let nextCheckupDate = last.nextCheckupDate {
            return nextCheckupDate
        }
        switch type {
        case .vaccine: return Calendar.current.date(byAdding: .year, value: 1, to: last.date)
        case .medication, .dewormingExternal:
            return Calendar.current.date(byAdding: .month, value: 1, to: last.date)
        case .dewormingInternal:
            return Calendar.current.date(byAdding: .month, value: 3, to: last.date)
        case .checkup: return Calendar.current.date(byAdding: .year, value: 1, to: last.date)
        default: return nil
        }
    }

    func daysUntil(_ date: Date?) -> Int? {
        guard let d = date else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }

    func deleteHealthLog(_ log: PetHealthLog) {
        deleteHealthRecord(
            recordID: log.id,
            kind: "health"
        ) {
            PetHealthCommandExecutor(context: modelContext, services: appServices).deleteHealthLog(
                log,
                pet: pet,
                note: "pet.health.delete.health"
            )
        }
    }

    func deleteSymptomLog(_ log: SymptomLog) {
        deleteHealthRecord(
            recordID: log.id,
            kind: "symptom"
        ) {
            PetHealthCommandExecutor(context: modelContext, services: appServices).deleteSymptomLog(
                log,
                pet: pet,
                note: "pet.health.delete.symptom"
            )
        }
    }

    func deleteHeatCycleLog(_ log: HeatCycleLog) {
        deleteHealthRecord(
            recordID: log.id,
            kind: "heat"
        ) {
            PetHealthCommandExecutor(context: modelContext, services: appServices).deleteHeatCycleLog(
                log,
                pet: pet,
                note: "pet.health.delete.heat"
            )
        }
    }

    func deleteHealthRecord(
        recordID: UUID,
        kind: String,
        operation: @escaping @MainActor () -> PetHealthDeleteResult
    ) {
        guard !deletingHealthRecordIDs.contains(recordID) else { return }
        deletingHealthRecordIDs.insert(recordID)
        let command = DomainCommand.petHealthDelete(petID: pet.id, kind: kind, recordID: recordID)

        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            _ = operation()
            deletingHealthRecordIDs.remove(recordID)
        }
    }

    func colorForType(_ type: HealthLogType) -> Color {
        switch type {
        case .vaccine: themeColor
        case .medication, .dewormingInternal, .dewormingExternal:
            isDark ? Color.goPrimary.opacity(0.92) : Color.goTeal
        case .checkup:
            isDark ? themeColor.opacity(0.9) : Color.goYellow
        case .surgery, .emergency:
            isDark ? Color.goPrimary.opacity(0.85) : Color.goRed
        default:
            isDark ? Color.goPrimary.opacity(0.78) : Color.goCardCyan
        }
    }

    func healthIcon(for type: HealthLogType) -> String {
        switch type {
        case .general: "clipboard.fill"
        case .vaccine: "syringe.fill"
        case .medication: "pill.fill"
        case .dewormingInternal: "pills.fill"
        case .dewormingExternal: "shield.lefthalf.filled"
        case .surgery: "cross.case.fill"
        case .dental: "mouth.fill"
        case .checkup: "stethoscope"
        case .emergency: "cross.circle.fill"
        case .other: "doc.text.fill"
        }
    }

    func healthTypeTitle(_ type: HealthLogType) -> String {
        switch type {
        case .general: l.tr(zh: "常规记录", en: "General", de: "Allgemein")
        case .vaccine: l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .medication: l.tr(zh: "用药", en: "Medication", de: "Medikament")
        case .dewormingInternal: l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .surgery: l.tr(zh: "手术", en: "Surgery", de: "Operation")
        case .dental: l.tr(zh: "牙科", en: "Dental", de: "Zahnmedizin")
        case .checkup: l.tr(zh: "体检", en: "Checkup", de: "Check-up")
        case .emergency: l.tr(zh: "急诊", en: "Emergency", de: "Notfall")
        case .other: l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }

    func symptomCategoryIcon(_ category: SymptomCategory) -> String {
        switch category {
        case .digestive: "stomach.fill"
        case .respiratory: "lungs.fill"
        case .mobility: "figure.walk"
        case .appetite: "fork.knife"
        case .skin: "bandage.fill"
        case .behavior: "moon.zzz.fill"
        case .other: "magnifyingglass"
        }
    }

    func localizedSeverityLabel(_ severity: SymptomSeverity) -> String {
        switch severity {
        case .mild: l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case .moderate: l.tr(zh: "中度", en: "Moderate", de: "Mittel")
        case .severe: l.tr(zh: "严重", en: "Severe", de: "Schwer")
        case .critical: l.tr(zh: "紧急", en: "Critical", de: "Kritisch")
        }
    }

    func alertIcon(for type: HealthAlert.AlertType) -> String {
        switch type {
        case .vaccineExpired, .vaccineExpiringSoon: "syringe.fill"
        case .dewormingDue: "pills.fill"
        case .weightGainAlert, .weightLossAlert: "scalemass.fill"
        case .noCheckIn: "calendar.badge.exclamationmark"
        case .noPotty: "toilet.fill"
        case .noWalk: "figure.walk"
        case .checkupOverdue: "stethoscope"
        case .documentExpiringSoon: "doc.text.fill"
        case .activeSymptom: "waveform.path.ecg"
        case .heatCycleAlert: "heart.text.square.fill"
        case .pregnancyCountdown: "cross.case.fill"
        case .drinkingWeightAlert: "drop.fill"
        case .lowActivityAlert: "chart.line.downtrend.xyaxis"
        }
    }

    // 散点数据：最近 12 个月每条记录一个点
    var scatterPoints: [HealthScatterPoint] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        return pet.activeHealthLogs
            .filter { $0.date >= cutoff }
            .map { HealthScatterPoint(date: $0.date, typeName: $0.type,
                                      typeEnum: HealthLogType(rawValue: $0.type) ?? .general) }
    }

    // 图表 X 轴范围
    var chartXDomain: ClosedRange<Date> {
        let start = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        return start ... Date()
    }

    // 颜色映射 domain / range（固定顺序供 chartColorScale 使用）
    var colorDomain: [String] {
        HealthLogType.allCases.map(\.rawValue)
    }

    var colorRange: [Color] {
        HealthLogType.allCases.map { colorForType($0) }
    }

    // 图例：当前数据中出现的类型（已排序，稳定）
    var presentTypes: [HealthLogType] {
        var seen = Set<String>()
        return scatterPoints.compactMap { pt -> HealthLogType? in
            guard seen.insert(pt.typeName).inserted else { return nil }
            return pt.typeEnum
        }
    }

    var activeMedications: [PetMedication] {
        pet.medications.filter(\.isActiveToday)
    }

    var medicationDoseEvents: [Event] {
        allEvents.filter {
            $0.eventType == EventType.petMedicationDose.rawValue
                && $0.relatedEntityType == PetMedicationDoseLogging.relatedEntityTypeMedication
        }
    }

    var totalMedicationDosesToday: Int {
        activeMedications.reduce(0) { total, med in
            total + PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
        }
    }

    var takenMedicationDosesToday: Int {
        _ = medicationDoseRefreshToken
        return activeMedications.reduce(0) { total, med in
            let need = PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
            let count = PetMedicationDoseLogging.todayDoseCount(events: medicationDoseEvents, medicationId: med.id)
            return total + min(count, need)
        }
    }

    var preventionItems: [PetHealthPreventionItem] {
        [
            preventionItem(type: .vaccine, icon: "syringe.fill", title: l.tr(zh: "疫苗", en: "Vaccines", de: "Impfungen"), cycleDays: 365),
            preventionItem(type: .dewormingInternal, icon: "pills.fill", title: l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung"), cycleDays: 90),
            preventionItem(type: .dewormingExternal, icon: "shield.lefthalf.filled", title: l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung"), cycleDays: 90),
            preventionItem(type: .checkup, icon: "stethoscope", title: l.tr(zh: "体检", en: "Checkup", de: "Check-up"), cycleDays: 365)
        ]
    }

    func preventionItem(type: HealthLogType, icon: String, title: String, cycleDays: Int) -> PetHealthPreventionItem {
        let due = dueDate(for: type)
        return PetHealthPreventionItem(
            type: type,
            icon: icon,
            title: title,
            cycleDays: cycleDays,
            latestLog: latestLog(type: type),
            dueDate: due,
            daysRemaining: daysUntil(due)
        )
    }

    var todayMedicationDoseItems: [PetHealthMedicationDoseItem] {
        medicationDoseItems(from: Date(), through: Date())
    }

    var next48HourMedicationDoseItems: [PetHealthMedicationDoseItem] {
        let end = Calendar.current.date(byAdding: .hour, value: 48, to: Date()) ?? Date()
        return medicationDoseItems(from: Date(), through: end)
            .filter { $0.scheduledAt >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var actionableMedicationDose: PetHealthMedicationDoseItem? {
        let now = Date()
        return todayMedicationDoseItems
            .filter { !$0.isCompleted && $0.scheduledAt <= now }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
            ?? todayMedicationDoseItems
            .filter { !$0.isCompleted }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }

    var nextMedicationDoseText: String {
        guard let item = next48HourMedicationDoseItems.first(where: { !$0.isCompleted }) else {
            return l.tr(zh: "今日完成", en: "Done today", de: "Heute fertig")
        }
        return "\(item.medication.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : item.medication.name) · \(relativeDoseTime(item.scheduledAt))"
    }

    var latestSymptomLog: SymptomLog? {
        pet.activeSymptomLogs.sorted { $0.date > $1.date }.first
    }

    var preventiveTypes: [HealthLogType] {
        [.vaccine, .dewormingInternal, .dewormingExternal, .checkup]
    }

    var duePreventiveCount: Int {
        preventiveTypes.reduce(0) { count, type in
            guard latestLog(type: type) != nil else { return count + 1 }
            guard let days = daysUntil(dueDate(for: type)) else { return count }
            return days <= 30 ? count + 1 : count
        }
    }

    var urgentPreventiveCount: Int {
        preventiveTypes.reduce(0) { count, type in
            guard let days = daysUntil(dueDate(for: type)) else { return count }
            return days < 0 ? count + 1 : count
        }
    }

    var nextPreventiveStatusText: String {
        let items = preventiveTypes.compactMap { type -> (HealthLogType, Int?)? in
            if latestLog(type: type) == nil { return (type, nil) }
            return (type, daysUntil(dueDate(for: type)))
        }
        if let overdue = items.compactMap({ item -> Int? in
            guard let days = item.1, days < 0 else { return nil }
            return days
        }).min() {
            return overdue == 0
                ? l.tr(zh: "今天", en: "Today", de: "Heute")
                : l.tr(zh: "逾期 \(abs(overdue)) 天", en: "\(abs(overdue)) days overdue", de: "\(abs(overdue)) Tage überfällig")
        }
        if items.contains(where: { $0.1 == nil }) {
            return l.tr(zh: "待补录", en: "Missing", de: "Fehlt")
        }
        if let next = items.compactMap(\.1).min() {
            return next <= 0
                ? l.tr(zh: "今天", en: "Today", de: "Heute")
                : l.tr(zh: "\(next) 天", en: "\(next) days", de: "\(next) Tage")
        }
        return l.tr(zh: "正常", en: "OK", de: "OK")
    }

    var medicationStatusText: String {
        if activeMedications.isEmpty { return l.tr(zh: "无进行中", en: "None active", de: "Keine aktiv") }
        if totalMedicationDosesToday == 0 {
            return l.tr(zh: "\(activeMedications.count) 项", en: "\(activeMedications.count) active", de: "\(activeMedications.count) aktiv")
        }
        return "\(takenMedicationDosesToday)/\(totalMedicationDosesToday)"
    }

    var symptomStatusText: String {
        guard let symptom = latestSymptomLog else { return l.tr(zh: "无异常", en: "No symptoms", de: "Keine Symptome") }
        if Calendar.current.isDateInToday(symptom.date) { return symptom.severity.label }
        let days = Calendar.current.dateComponents([.day], from: symptom.date, to: Date()).day ?? 0
        return days <= 0
            ? symptom.severity.label
            : l.tr(zh: "\(days) 天前", en: "\(days)d ago", de: "vor \(days) Tagen")
    }

    var archiveStatusText: String {
        let count = pet.activeHealthLogs.count + pet.activeSymptomLogs.count + pet.activeHeatCycleLogs.count
        return count == 0 ? l.tr(zh: "空", en: "Empty", de: "Leer") : l.tr(zh: "\(count) 条", en: "\(count) items", de: "\(count) Einträge")
    }

    var healthStatusTitle: String {
        if healthAlerts.contains(where: { $0.severity == .urgent }) || urgentPreventiveCount > 0 {
            return l.tr(zh: "需要关注", en: "Needs attention", de: "Braucht Aufmerksamkeit")
        }
        if !healthAlerts.isEmpty || duePreventiveCount > 0 {
            return l.tr(zh: "近期留意", en: "Watch soon", de: "Bald beachten")
        }
        return l.tr(zh: "状态稳定", en: "Stable", de: "Stabil")
    }

    var healthStatusSubtitle: String {
        if healthAlerts.contains(where: { $0.severity == .urgent }) {
            return l.tr(zh: "有紧急预警", en: "Urgent alert", de: "Dringende Warnung")
        }
        if urgentPreventiveCount > 0 {
            return l.tr(zh: "\(urgentPreventiveCount) 项已逾期", en: "\(urgentPreventiveCount) overdue", de: "\(urgentPreventiveCount) überfällig")
        }
        if duePreventiveCount > 0 {
            return l.tr(zh: "\(duePreventiveCount) 项待处理", en: "\(duePreventiveCount) due", de: "\(duePreventiveCount) fällig")
        }
        if activeMedications.isEmpty {
            return l.tr(zh: "预防与记录正常", en: "Care records look good", de: "Pflegeeinträge sehen gut aus")
        }
        return l.tr(zh: "今日用药 \(medicationStatusText)", en: "Medication today \(medicationStatusText)", de: "Medikamente heute \(medicationStatusText)")
    }

    var healthStatusColor: Color {
        if healthAlerts.contains(where: { $0.severity == .urgent }) || urgentPreventiveCount > 0 {
            return Color.goRed
        }
        if !healthAlerts.isEmpty || duePreventiveCount > 0 {
            return isDark ? Color.goPrimary : Color.goYellow
        }
        return isDark ? Color.goPrimary : Color.goTeal
    }

    var preventionTint: Color {
        urgentPreventiveCount > 0 ? Color.goRed : chromeAccent
    }

    var medicationTint: Color {
        isDark ? Color.goPrimary : Color.goBlue
    }

    var symptomVisitTint: Color {
        latestSymptomLog == nil ? chromeAccent : Color.goOrange
    }

    var preventiveDashboardDetail: String {
        if urgentPreventiveCount > 0 {
            return l.tr(zh: "\(urgentPreventiveCount) 项已逾期", en: "\(urgentPreventiveCount) overdue", de: "\(urgentPreventiveCount) überfällig")
        }
        if duePreventiveCount > 0 {
            return l.tr(zh: "\(duePreventiveCount) 项临近或待补录", en: "\(duePreventiveCount) due soon or missing", de: "\(duePreventiveCount) bald fällig oder fehlt")
        }
        return l.tr(zh: "疫苗、驱虫、体检状态正常", en: "Vaccines, deworming, and checkups look good", de: "Impfungen, Entwurmung und Check-ups passen")
    }

    var medicationPrimaryButtonTitle: String {
        guard !activeMedications.isEmpty else {
            return l.tr(zh: "添加", en: "Add", de: "Hinzufügen")
        }
        if let item = actionableMedicationDose, item.scheduledAt <= Date() {
            return l.tr(zh: "补记", en: "Catch up", de: "Nachtragen")
        }
        return l.tr(zh: "完成", en: "Done", de: "Erledigt")
    }

    var symptomVisitDashboardDetail: String {
        let visit = latestVisitLog
        if let symptom = latestSymptomLog, let visit, symptom.date > visit.date {
            return l.tr(zh: "最近异常：\(symptom.symptomName.isEmpty ? symptom.severity.label : symptom.symptomName)", en: "Latest symptom: \(symptom.symptomName.isEmpty ? symptom.severity.label : symptom.symptomName)", de: "Letztes Symptom: \(symptom.symptomName.isEmpty ? symptom.severity.label : symptom.symptomName)")
        }
        if let visit {
            return l.tr(zh: "最近就诊：\(visit.date.formatted(.dateTime.month().day()))", en: "Latest visit: \(visit.date.formatted(.dateTime.month().day()))", de: "Letzter Besuch: \(visit.date.formatted(.dateTime.month().day()))")
        }
        if latestSymptomLog != nil {
            return symptomStatusText
        }
        return l.tr(zh: "没有异常记录", en: "No symptom records", de: "Keine Auffälligkeiten")
    }

    var latestVisitLog: PetHealthLog? {
        pet.activeHealthLogs
            .filter { visitTypes.contains($0.healthLogType) }
            .sorted { $0.date > $1.date }
            .first
    }

    var visitTypes: Set<HealthLogType> {
        [.general, .checkup, .surgery, .dental, .emergency, .other]
    }

    var recentHealthActivities: [HealthActivityItem] {
        let logItems = pet.activeHealthLogs.map { log in
            HealthActivityItem(
                id: "health-\(log.id.uuidString)",
                date: log.date,
                icon: healthIcon(for: log.healthLogType),
                title: log.note.isEmpty ? healthTypeTitle(log.healthLogType) : log.note,
                detail: log.note.isEmpty ? log.date.formatted(.dateTime.month().day()) : log.note,
                tint: colorForType(log.healthLogType)
            )
        }
        let symptomItems = pet.activeSymptomLogs.map { log in
            HealthActivityItem(
                id: "symptom-\(log.id.uuidString)",
                date: log.date,
                icon: symptomCategoryIcon(log.category),
                title: log.symptomName.isEmpty ? l.tr(zh: "异常症状", en: "Symptom", de: "Symptom") : log.symptomName,
                detail: localizedSeverityLabel(log.severity),
                tint: log.severity == .severe || log.severity == .critical ? Color.goRed : Color.goOrange
            )
        }
        let heatItems = pet.activeHeatCycleLogs.map { log in
            HealthActivityItem(
                id: "heat-\(log.id.uuidString)",
                date: log.startDate,
                icon: "heart.text.square.fill",
                title: log.status.rawValue,
                detail: log.isMated ? l.tr(zh: "已交配", en: "Mated", de: "Gedeckt") : log.startDate.formatted(.dateTime.month().day()),
                tint: Color(hex: log.status.colorHex)
            )
        }
        return (logItems + symptomItems + heatItems)
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map(\.self)
    }

    func handleMedicationPrimaryAction() {
        guard !activeMedications.isEmpty else {
            openMedicationPopup()
            return
        }
        guard let item = actionableMedicationDose else {
            openHealthOverview(.medicationOverview)
            return
        }
        recordMedicationDose(item)
    }

    @MainActor
    func recordMedicationDose(_ item: PetHealthMedicationDoseItem) {
        let result = PetMedicationCommandExecutor(context: modelContext, services: appServices).recordDose(
            medication: item.medication,
            pet: pet,
            awardCoconut: true,
            note: "pet.health.medication.dose"
        )
        guard result.didRecord, result.allowsDerivedEffects else { return }
        appServices.medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
        OhanaFeedback.success()
        medicationDoseRefreshToken = UUID()
    }

    func medicationDoseItems(from start: Date, through end: Date) -> [PetHealthMedicationDoseItem] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let dayCount = max(0, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
        var items: [PetHealthMedicationDoseItem] = []

        for offset in 0 ... dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            for medication in activeMedications {
                let required = PetMedicationDoseLogging.requiredDoses(on: day, for: medication)
                guard required > 0 else { continue }
                let completedCount = medicationDoseCount(on: day, for: medication)
                let minutes = PetMedicationSchedulePlan.doseMinutes(for: medication, required: required)
                for index in 0 ..< required {
                    let minute = minutes.indices.contains(index) ? minutes[index] : 8 * 60
                    guard let scheduled = calendar.date(byAdding: .minute, value: minute, to: day) else { continue }
                    items.append(
                        PetHealthMedicationDoseItem(
                            medication: medication,
                            scheduledAt: scheduled,
                            doseIndex: index,
                            isCompleted: index < completedCount
                        )
                    )
                }
            }
        }
        return items.filter { $0.scheduledAt <= end && $0.scheduledAt >= startDay }
    }

    func medicationDoseCount(on day: Date, for medication: PetMedication) -> Int {
        let calendar = Calendar.current
        return medicationDoseEvents.count(where: {
            $0.relatedEntityId == medication.id.uuidString
                && calendar.isDate($0.startDate, inSameDayAs: day)
        })
    }

    func relativeDoseTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return l.tr(zh: "今天 \(date.formatted(.dateTime.hour().minute()))", en: "Today \(date.formatted(.dateTime.hour().minute()))", de: "Heute \(date.formatted(.dateTime.hour().minute()))")
        }
        if calendar.isDateInTomorrow(date) {
            return l.tr(zh: "明天 \(date.formatted(.dateTime.hour().minute()))", en: "Tomorrow \(date.formatted(.dateTime.hour().minute()))", de: "Morgen \(date.formatted(.dateTime.hour().minute()))")
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    healthHeader
                    healthHeroCard
                    if !healthAlerts.isEmpty {
                        compactAlertsCard
                    }
                    healthDashboardCards
                    recentActivityCard
                    Spacer(minLength: 108)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .onAppear {
                healthAlerts = appServices.healthAlerts.scanAlerts(pets: [pet])
                openInitialSectionIfNeeded()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if healthPlusDestination == nil, !showingMedicationPopup {
                        healthAddMenu
                            .padding(.trailing, 18)
                            .padding(.bottom, 24)
                    }
                }
            }
            .zIndex(12)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if let dest = healthPlusDestination, dest.usesInlineRecordPopup {
                healthRecordInlineOverlay(dest)
            }
            if showingMedicationPopup {
                medicationInlineOverlay
            }
        }
        .sheet(item: sheetHealthPlusDestination) { dest in
            switch dest {
            case .guided:
                EmptyView()
            case .direct:
                EmptyView()
            case .medications:
                PetMedicationView(pet: pet)
            case .symptom:
                AddSymptomSheet(pet: pet)
            case .heatCycle:
                AddHeatCycleSheet(pet: pet)
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let url = pdfURL {
                PetVetPDFShareSheet(pdfURL: url, pet: pet)
            }
        }
        .sheet(item: $activeHealthSheet) { sheet in
            healthOverviewSheet(sheet)
                .ohanaSheetPagePresentation() // ui-v4: allow long health overview sheet
        }
        .navigationDestination(isPresented: $showingHistory) {
            PetHealthArchiveView(pet: pet)
        }
        .navigationDestination(isPresented: $showingPassport) {
            VaccinePassportView(pet: pet)
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }
}
