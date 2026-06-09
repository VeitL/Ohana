//
//  PetHealthDetailView.swift
//  Ohana
//
//  健康详情页 — 饮食管理页风格
//  深色背景 + ScrollView卡片 + Swift Charts
//

import SwiftUI
import SwiftData

// MARK: - 健康添加 Sheet 路由
private enum HealthPlusDestination: Identifiable {
    case guided(HealthRecordEntryMode)
    case direct(HealthLogType)
    case medications
    case symptom     // 新增
    case heatCycle   // 新增

    var id: String {
        switch self {
        case .guided(let m):
            return m == .preventive ? "guide_p" : "guide_v"
        case .direct(let t):
            return "dir_\(t.rawValue)"
        case .medications:
            return "meds"
        case .symptom:
            return "symptom"
        case .heatCycle:
            return "heat"
        }
    }

    var usesInlineRecordPopup: Bool {
        switch self {
        case .guided, .direct:
            return true
        case .medications, .symptom, .heatCycle:
            return false
        }
    }
}

// MARK: - Health Scatter Point (散点时间轴)
private struct HealthScatterPoint: Identifiable {
    let id = UUID()
    let date: Date
    let typeName: String
    let typeEnum: HealthLogType
}

private struct HealthActivityItem: Identifiable {
    let id: String
    let date: Date
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private enum ActiveHealthSheet: Identifiable {
    case preventiveOverview
    case medicationOverview
    case symptomVisitOverview

    var id: String {
        switch self {
        case .preventiveOverview: return "preventiveOverview"
        case .medicationOverview: return "medicationOverview"
        case .symptomVisitOverview: return "symptomVisitOverview"
        }
    }
}

private enum HealthFabActionKind: String, Identifiable {
    case preventive
    case visit
    case medication
    case vaccinePassport
    case archive
    case pdf
    case symptom
    case heatCycle

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .preventive: return "shield.checkered"
        case .visit: return "cross.case.fill"
        case .medication: return "pill.fill"
        case .vaccinePassport: return "syringe.fill"
        case .archive: return "folder.fill"
        case .pdf: return "doc.richtext"
        case .symptom: return "exclamationmark.triangle.fill"
        case .heatCycle: return "heart.text.square.fill"
        }
    }

    func label(_ l: L10n, isRenderingPDF: Bool = false) -> String {
        switch self {
        case .preventive:
            return l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge")
        case .visit:
            return l.tr(zh: "就诊记录", en: "Visit record", de: "Besuchseintrag")
        case .medication:
            return l.tr(zh: "添加药物", en: "Add medication", de: "Medikament")
        case .vaccinePassport:
            return l.tr(zh: "疫苗本", en: "Vaccine passport", de: "Impfpass")
        case .archive:
            return l.tr(zh: "完整档案", en: "Full archive", de: "Vollständige Akte")
        case .pdf:
            return isRenderingPDF
                ? l.tr(zh: "PDF 生成中", en: "Rendering PDF", de: "PDF wird erstellt")
                : l.tr(zh: "导出 PDF", en: "Export PDF", de: "PDF exportieren")
        case .symptom:
            return l.tr(zh: "记录异常", en: "Log symptom", de: "Symptom")
        case .heatCycle:
            return l.tr(zh: "生理期", en: "Heat cycle", de: "Läufigkeit")
        }
    }
}

enum PetHealthInitialSection: Hashable {
    case preventive
    case medication
    case symptomVisit
}

private struct PetHealthPreventionItem: Identifiable {
    let type: HealthLogType
    let icon: String
    let title: String
    let cycleDays: Int
    let latestLog: PetHealthLog?
    let dueDate: Date?
    let daysRemaining: Int?

    var id: String { type.rawValue }
}

private struct PetHealthMedicationDoseItem: Identifiable {
    let medication: PetMedication
    let scheduledAt: Date
    let doseIndex: Int
    let isCompleted: Bool

    var id: String {
        "\(medication.id.uuidString)-\(Int(scheduledAt.timeIntervalSince1970 / 60))-\(doseIndex)"
    }
}

struct PetHealthDetailView: View {
    let pet: Pet
    var isModal: Bool = false
    var initialSection: PetHealthInitialSection? = nil
    /// D4: 关闭时额外回调（如需一并关闭父级）
    var onFullDismiss: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    /// 健康页「+」与免疫条点按的路由
    @State private var healthPlusDestination: HealthPlusDestination?
    @State private var activeHealthSheet: ActiveHealthSheet?
    @State private var showingPDFPreview = false
    @State private var pdfURL: URL? = nil
    @State private var isRenderingPDF = false
    @State private var healthAlerts: [HealthAlert] = []
    @State private var scatterRevealProgress: CGFloat = 0.0
    @State private var showingHistory = false
    @State private var showingPassport = false
    @State private var isHealthFabExpanded = false
    @State private var healthFabItemsVisible = false
    @State private var showingMedicationPopup = false
    @State private var medicationDoseRefreshToken = UUID()
    @State private var didOpenInitialSection = false
    @State private var deletingHealthRecordIDs: Set<UUID> = []
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private func playScatterReveal() {
        scatterRevealProgress = 0
        withAnimation(GoMotion.quick) {
            scatterRevealProgress = 1.0
        }
    }

    private var themeColor: Color { pet.themeColor.color }
    private var isDark: Bool { colorScheme == .dark }
    private var l: L10n { L10n(appLanguage) }
    /// 深色：界面结构色统一荧光绿；与宠物相关的记录语义仍用 `themeColor` / `colorForType`
    private var chromeAccent: Color { isDark ? Color.goPrimary : Color.goBlue }

    private var sortedLogs: [PetHealthLog] {
        pet.healthLogs.sorted { $0.date > $1.date }
    }

    private func latestLog(type: HealthLogType) -> PetHealthLog? {
        pet.healthLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }.first
    }

    private func dueDate(for type: HealthLogType) -> Date? {
        guard let last = latestLog(type: type) else { return nil }
        if let expirationDate = last.expirationDate {
            return expirationDate
        }
        if type == .checkup, let nextCheckupDate = last.nextCheckupDate {
            return nextCheckupDate
        }
        switch type {
        case .vaccine:    return Calendar.current.date(byAdding: .year,  value: 1, to: last.date)
        case .medication, .dewormingExternal:
                          return Calendar.current.date(byAdding: .month, value: 1, to: last.date)
        case .dewormingInternal:
                          return Calendar.current.date(byAdding: .month, value: 3, to: last.date)
        case .checkup:    return Calendar.current.date(byAdding: .year,  value: 1, to: last.date)
        default:          return nil
        }
    }

    private func daysUntil(_ date: Date?) -> Int? {
        guard let d = date else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }

    private func deleteHealthLog(_ log: PetHealthLog) {
        deleteHealthRecord(
            recordID: log.id,
            kind: "health"
        ) {
            PetHealthCommandExecutor(context: modelContext).deleteHealthLog(
                log,
                pet: pet,
                note: "pet.health.delete.health"
            )
        }
    }

    private func deleteSymptomLog(_ log: SymptomLog) {
        deleteHealthRecord(
            recordID: log.id,
            kind: "symptom"
        ) {
            PetHealthCommandExecutor(context: modelContext).deleteSymptomLog(
                log,
                pet: pet,
                note: "pet.health.delete.symptom"
            )
        }
    }

    private func deleteHeatCycleLog(_ log: HeatCycleLog) {
        deleteHealthRecord(
            recordID: log.id,
            kind: "heat"
        ) {
            PetHealthCommandExecutor(context: modelContext).deleteHeatCycleLog(
                log,
                pet: pet,
                note: "pet.health.delete.heat"
            )
        }
    }

    private func deleteHealthRecord(
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

    private func colorForType(_ type: HealthLogType) -> Color {
        switch type {
        case .vaccine: return themeColor
        case .medication, .dewormingInternal, .dewormingExternal:
            return isDark ? Color.goPrimary.opacity(0.92) : Color.goTeal
        case .checkup:
            return isDark ? themeColor.opacity(0.9) : Color.goYellow
        case .surgery, .emergency:
            return isDark ? Color.goPrimary.opacity(0.85) : Color.goRed
        default:
            return isDark ? Color.goPrimary.opacity(0.78) : Color.goCardCyan
        }
    }

    private func healthIcon(for type: HealthLogType) -> String {
        switch type {
        case .general: return "clipboard.fill"
        case .vaccine: return "syringe.fill"
        case .medication: return "pill.fill"
        case .dewormingInternal: return "pills.fill"
        case .dewormingExternal: return "shield.lefthalf.filled"
        case .surgery: return "cross.case.fill"
        case .dental: return "mouth.fill"
        case .checkup: return "stethoscope"
        case .emergency: return "cross.circle.fill"
        case .other: return "doc.text.fill"
        }
    }

    private func healthTypeTitle(_ type: HealthLogType) -> String {
        switch type {
        case .general: return l.tr(zh: "常规记录", en: "General", de: "Allgemein")
        case .vaccine: return l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .medication: return l.tr(zh: "用药", en: "Medication", de: "Medikament")
        case .dewormingInternal: return l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: return l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .surgery: return l.tr(zh: "手术", en: "Surgery", de: "Operation")
        case .dental: return l.tr(zh: "牙科", en: "Dental", de: "Zahnmedizin")
        case .checkup: return l.tr(zh: "体检", en: "Checkup", de: "Check-up")
        case .emergency: return l.tr(zh: "急诊", en: "Emergency", de: "Notfall")
        case .other: return l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }

    private func symptomCategoryIcon(_ category: SymptomCategory) -> String {
        switch category {
        case .digestive: return "stomach.fill"
        case .respiratory: return "lungs.fill"
        case .mobility: return "figure.walk"
        case .appetite: return "fork.knife"
        case .skin: return "bandage.fill"
        case .behavior: return "moon.zzz.fill"
        case .other: return "magnifyingglass"
        }
    }

    private func localizedSeverityLabel(_ severity: SymptomSeverity) -> String {
        switch severity {
        case .mild: return l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case .moderate: return l.tr(zh: "中度", en: "Moderate", de: "Mittel")
        case .severe: return l.tr(zh: "严重", en: "Severe", de: "Schwer")
        case .critical: return l.tr(zh: "紧急", en: "Critical", de: "Kritisch")
        }
    }

    private func alertIcon(for type: HealthAlert.AlertType) -> String {
        switch type {
        case .vaccineExpired, .vaccineExpiringSoon: return "syringe.fill"
        case .dewormingDue: return "pills.fill"
        case .weightGainAlert, .weightLossAlert: return "scalemass.fill"
        case .noCheckIn: return "calendar.badge.exclamationmark"
        case .noPotty: return "toilet.fill"
        case .noWalk: return "figure.walk"
        case .checkupOverdue: return "stethoscope"
        case .documentExpiringSoon: return "doc.text.fill"
        case .activeSymptom: return "waveform.path.ecg"
        case .heatCycleAlert: return "heart.text.square.fill"
        case .pregnancyCountdown: return "cross.case.fill"
        case .drinkingWeightAlert: return "drop.fill"
        case .lowActivityAlert: return "chart.line.downtrend.xyaxis"
        }
    }

    // 散点数据：最近 12 个月每条记录一个点
    private var scatterPoints: [HealthScatterPoint] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        return pet.healthLogs
            .filter { $0.date >= cutoff }
            .map { HealthScatterPoint(date: $0.date, typeName: $0.type,
                                     typeEnum: HealthLogType(rawValue: $0.type) ?? .general) }
    }

    // 图表 X 轴范围
    private var chartXDomain: ClosedRange<Date> {
        let start = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        return start...Date()
    }

    // 颜色映射 domain / range（固定顺序供 chartColorScale 使用）
    private var colorDomain: [String] {
        HealthLogType.allCases.map(\.rawValue)
    }
    private var colorRange: [Color] {
        HealthLogType.allCases.map { colorForType($0) }
    }

    // 图例：当前数据中出现的类型（已排序，稳定）
    private var presentTypes: [HealthLogType] {
        var seen = Set<String>()
        return scatterPoints.compactMap { pt -> HealthLogType? in
            guard seen.insert(pt.typeName).inserted else { return nil }
            return pt.typeEnum
        }
    }

    private var activeMedications: [PetMedication] {
        pet.medications.filter(\.isActiveToday)
    }

    private var medicationDoseEvents: [Event] {
        allEvents.filter {
            $0.eventType == EventType.petMedicationDose.rawValue
            && $0.relatedEntityType == PetMedicationDoseLogging.relatedEntityTypeMedication
        }
    }

    private var totalMedicationDosesToday: Int {
        activeMedications.reduce(0) { total, med in
            total + PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
        }
    }

    private var takenMedicationDosesToday: Int {
        let _ = medicationDoseRefreshToken
        return activeMedications.reduce(0) { total, med in
            let need = PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
            let count = PetMedicationDoseLogging.todayDoseCount(events: medicationDoseEvents, medicationId: med.id)
            return total + min(count, need)
        }
    }

    private var preventionItems: [PetHealthPreventionItem] {
        [
            preventionItem(type: .vaccine, icon: "syringe.fill", title: l.tr(zh: "疫苗", en: "Vaccines", de: "Impfungen"), cycleDays: 365),
            preventionItem(type: .dewormingInternal, icon: "pills.fill", title: l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung"), cycleDays: 90),
            preventionItem(type: .dewormingExternal, icon: "shield.lefthalf.filled", title: l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung"), cycleDays: 90),
            preventionItem(type: .checkup, icon: "stethoscope", title: l.tr(zh: "体检", en: "Checkup", de: "Check-up"), cycleDays: 365)
        ]
    }

    private func preventionItem(type: HealthLogType, icon: String, title: String, cycleDays: Int) -> PetHealthPreventionItem {
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

    private var todayMedicationDoseItems: [PetHealthMedicationDoseItem] {
        medicationDoseItems(from: Date(), through: Date())
    }

    private var next48HourMedicationDoseItems: [PetHealthMedicationDoseItem] {
        let end = Calendar.current.date(byAdding: .hour, value: 48, to: Date()) ?? Date()
        return medicationDoseItems(from: Date(), through: end)
            .filter { $0.scheduledAt >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var actionableMedicationDose: PetHealthMedicationDoseItem? {
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

    private var nextMedicationDoseText: String {
        guard let item = next48HourMedicationDoseItems.first(where: { !$0.isCompleted }) else {
            return l.tr(zh: "今日完成", en: "Done today", de: "Heute fertig")
        }
        return "\(item.medication.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : item.medication.name) · \(relativeDoseTime(item.scheduledAt))"
    }

    private var latestSymptomLog: SymptomLog? {
        pet.symptomLogs.sorted { $0.date > $1.date }.first
    }

    private var preventiveTypes: [HealthLogType] {
        [.vaccine, .dewormingInternal, .dewormingExternal, .checkup]
    }

    private var duePreventiveCount: Int {
        preventiveTypes.reduce(0) { count, type in
            guard latestLog(type: type) != nil else { return count + 1 }
            guard let days = daysUntil(dueDate(for: type)) else { return count }
            return days <= 30 ? count + 1 : count
        }
    }

    private var urgentPreventiveCount: Int {
        preventiveTypes.reduce(0) { count, type in
            guard let days = daysUntil(dueDate(for: type)) else { return count }
            return days < 0 ? count + 1 : count
        }
    }

    private var nextPreventiveStatusText: String {
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

    private var medicationStatusText: String {
        if activeMedications.isEmpty { return l.tr(zh: "无进行中", en: "None active", de: "Keine aktiv") }
        if totalMedicationDosesToday == 0 {
            return l.tr(zh: "\(activeMedications.count) 项", en: "\(activeMedications.count) active", de: "\(activeMedications.count) aktiv")
        }
        return "\(takenMedicationDosesToday)/\(totalMedicationDosesToday)"
    }

    private var symptomStatusText: String {
        guard let symptom = latestSymptomLog else { return l.tr(zh: "无异常", en: "No symptoms", de: "Keine Symptome") }
        if Calendar.current.isDateInToday(symptom.date) { return symptom.severity.label }
        let days = Calendar.current.dateComponents([.day], from: symptom.date, to: Date()).day ?? 0
        return days <= 0
        ? symptom.severity.label
        : l.tr(zh: "\(days) 天前", en: "\(days)d ago", de: "vor \(days) Tagen")
    }

    private var archiveStatusText: String {
        let count = pet.healthLogs.count + pet.symptomLogs.count + pet.heatCycleLogs.count
        return count == 0 ? l.tr(zh: "空", en: "Empty", de: "Leer") : l.tr(zh: "\(count) 条", en: "\(count) items", de: "\(count) Einträge")
    }

    private var healthStatusTitle: String {
        if healthAlerts.contains(where: { $0.severity == .urgent }) || urgentPreventiveCount > 0 {
            return l.tr(zh: "需要关注", en: "Needs attention", de: "Braucht Aufmerksamkeit")
        }
        if !healthAlerts.isEmpty || duePreventiveCount > 0 {
            return l.tr(zh: "近期留意", en: "Watch soon", de: "Bald beachten")
        }
        return l.tr(zh: "状态稳定", en: "Stable", de: "Stabil")
    }

    private var healthStatusSubtitle: String {
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

    private var healthStatusColor: Color {
        if healthAlerts.contains(where: { $0.severity == .urgent }) || urgentPreventiveCount > 0 {
            return Color.goRed
        }
        if !healthAlerts.isEmpty || duePreventiveCount > 0 {
            return isDark ? Color.goPrimary : Color.goYellow
        }
        return isDark ? Color.goPrimary : Color.goTeal
    }

    private var preventionTint: Color {
        urgentPreventiveCount > 0 ? Color.goRed : chromeAccent
    }

    private var medicationTint: Color {
        isDark ? Color.goPrimary : Color.goBlue
    }

    private var symptomVisitTint: Color {
        latestSymptomLog == nil ? chromeAccent : Color.goOrange
    }

    private var preventiveDashboardDetail: String {
        if urgentPreventiveCount > 0 {
            return l.tr(zh: "\(urgentPreventiveCount) 项已逾期", en: "\(urgentPreventiveCount) overdue", de: "\(urgentPreventiveCount) überfällig")
        }
        if duePreventiveCount > 0 {
            return l.tr(zh: "\(duePreventiveCount) 项临近或待补录", en: "\(duePreventiveCount) due soon or missing", de: "\(duePreventiveCount) bald fällig oder fehlt")
        }
        return l.tr(zh: "疫苗、驱虫、体检状态正常", en: "Vaccines, deworming, and checkups look good", de: "Impfungen, Entwurmung und Check-ups passen")
    }

    private var medicationPrimaryButtonTitle: String {
        guard !activeMedications.isEmpty else {
            return l.tr(zh: "添加", en: "Add", de: "Hinzufügen")
        }
        if let item = actionableMedicationDose, item.scheduledAt <= Date() {
            return l.tr(zh: "补记", en: "Catch up", de: "Nachtragen")
        }
        return l.tr(zh: "完成", en: "Done", de: "Erledigt")
    }

    private var symptomVisitDashboardDetail: String {
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

    private var latestVisitLog: PetHealthLog? {
        pet.healthLogs
            .filter { visitTypes.contains($0.healthLogType) }
            .sorted { $0.date > $1.date }
            .first
    }

    private var visitTypes: Set<HealthLogType> {
        [.general, .checkup, .surgery, .dental, .emergency, .other]
    }

    private var recentHealthActivities: [HealthActivityItem] {
        let logItems = pet.healthLogs.map { log in
            HealthActivityItem(
                id: "health-\(log.id.uuidString)",
                date: log.date,
                icon: healthIcon(for: log.healthLogType),
                title: log.note.isEmpty ? healthTypeTitle(log.healthLogType) : log.note,
                detail: log.note.isEmpty ? log.date.formatted(.dateTime.month().day()) : log.note,
                tint: colorForType(log.healthLogType)
            )
        }
        let symptomItems = pet.symptomLogs.map { log in
            HealthActivityItem(
                id: "symptom-\(log.id.uuidString)",
                date: log.date,
                icon: symptomCategoryIcon(log.category),
                title: log.symptomName.isEmpty ? l.tr(zh: "异常症状", en: "Symptom", de: "Symptom") : log.symptomName,
                detail: localizedSeverityLabel(log.severity),
                tint: log.severity == .severe || log.severity == .critical ? Color.goRed : Color.goOrange
            )
        }
        let heatItems = pet.heatCycleLogs.map { log in
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
            .map { $0 }
    }

    private func handleMedicationPrimaryAction() {
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
    private func recordMedicationDose(_ item: PetHealthMedicationDoseItem) {
        PetMedicationDoseLogging.recordDose(
            medication: item.medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true
        )
        MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
        OhanaFeedback.success()
        medicationDoseRefreshToken = UUID()
    }

    private func medicationDoseItems(from start: Date, through end: Date) -> [PetHealthMedicationDoseItem] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let dayCount = max(0, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
        var items: [PetHealthMedicationDoseItem] = []

        for offset in 0...dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            for medication in activeMedications {
                let required = PetMedicationDoseLogging.requiredDoses(on: day, for: medication)
                guard required > 0 else { continue }
                let completedCount = medicationDoseCount(on: day, for: medication)
                let minutes = PetMedicationSchedulePlan.doseMinutes(for: medication, required: required)
                for index in 0..<required {
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

    private func medicationDoseCount(on day: Date, for medication: PetMedication) -> Int {
        let calendar = Calendar.current
        return medicationDoseEvents.filter {
            $0.relatedEntityId == medication.id.uuidString
            && calendar.isDate($0.startDate, inSameDayAs: day)
        }.count
    }

    private func relativeDoseTime(_ date: Date) -> String {
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
                healthAlerts = PetHealthAlertEngine.shared.scanAlerts(pets: [pet])
                openInitialSectionIfNeeded()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if healthPlusDestination == nil && !showingMedicationPopup {
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

    private var sheetHealthPlusDestination: Binding<HealthPlusDestination?> {
        Binding(
            get: {
                guard healthPlusDestination?.usesInlineRecordPopup != true else { return nil }
                return healthPlusDestination
            },
            set: { newValue in
                if newValue == nil, healthPlusDestination?.usesInlineRecordPopup != true {
                    healthPlusDestination = nil
                } else if newValue?.usesInlineRecordPopup != true {
                    healthPlusDestination = newValue
                }
            }
        )
    }

    private func openInitialSectionIfNeeded() {
        guard !didOpenInitialSection, let initialSection else { return }
        didOpenInitialSection = true
        DispatchQueue.main.async {
            switch initialSection {
            case .preventive:
                activeHealthSheet = .preventiveOverview
            case .medication:
                activeHealthSheet = .medicationOverview
            case .symptomVisit:
                activeHealthSheet = .symptomVisitOverview
            }
        }
    }

    @ViewBuilder
    private func healthRecordInlineOverlay(_ destination: HealthPlusDestination) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(isDark ? 0.18 : 0.08), // ui-v4: allow modal scrim
                        Color.black.opacity(isDark ? 0.42 : 0.22) // ui-v4: allow modal scrim
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    closeHealthRecordPopup()
                }

                PetHealthRecordInlinePopup(
                    pet: pet,
                    initialType: healthRecordInitialType(for: destination),
                    entryMode: healthRecordEntryMode(for: destination),
                    onClose: {
                        closeHealthRecordPopup()
                    },
                    onSaved: {
                        healthAlerts = PetHealthAlertEngine.shared.scanAlerts(pets: [pet])
                        OhanaFeedback.success()
                        closeHealthRecordPopup(feedback: false)
                    }
                )
                .frame(maxHeight: min(proxy.size.height * 0.86, 680))
                .padding(.horizontal, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 6)
                .transition(healthInlinePopupTransition)
            }
            .animation(GoMotion.sheet, value: healthPlusDestination?.id)
        }
        .ignoresSafeArea()
        .zIndex(40)
    }

    private func healthRecordInitialType(for destination: HealthPlusDestination) -> HealthLogType {
        switch destination {
        case .guided(let mode):
            return mode == .preventive ? .vaccine : .surgery
        case .direct(let type):
            return type
        default:
            return .general
        }
    }

    private func healthRecordEntryMode(for destination: HealthPlusDestination) -> HealthRecordEntryMode? {
        if case .guided(let mode) = destination { return mode }
        return nil
    }

    private var medicationInlineOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(isDark ? 0.16 : 0.08), // ui-v4: allow modal scrim
                        Color.black.opacity(isDark ? 0.42 : 0.22) // ui-v4: allow modal scrim
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    closeMedicationPopup()
                }

                AddPetMedicationSheet(
                    pet: pet,
                    isInlinePopup: true,
                    onClose: {
                        closeMedicationPopup()
                    },
                    onSaved: {
                        medicationDoseRefreshToken = UUID()
                        MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
                        OhanaFeedback.success()
                        closeMedicationPopup(feedback: false)
                    }
                )
                .frame(maxHeight: min(proxy.size.height * 0.88, 690))
                .padding(.horizontal, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 6)
                .transition(healthInlinePopupTransition)
            }
            .animation(GoMotion.sheet, value: showingMedicationPopup)
        }
        .ignoresSafeArea()
        .zIndex(42)
    }

    // MARK: - Guided Health Home
    private var healthHeader: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: chromeAccent,
                size: 46,
                backgroundOpacity: isDark ? 0.18 : 0.12
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "健康", en: "Health", de: "Gesundheit"))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button {
                OhanaFeedback.light()
                dismiss()
                onFullDismiss?()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 40, height: 40) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 4)
    }

    private var healthAddMenu: some View {
        VStack(alignment: .trailing, spacing: 14) {
            if isHealthFabExpanded {
                ForEach(Array(healthFabActionKinds.enumerated()), id: \.element.id) { index, action in
                    HomeFabActionRow(
                        item: HomeFabFunctionShortcut(
                            label: action.label(l, isRenderingPDF: isRenderingPDF),
                            icon: action.icon,
                            isAvailable: action != .pdf || !isRenderingPDF
                        ),
                        rowHeight: 48
                    )
                    .ohanaStaggeredMenuItem(isVisible: healthFabItemsVisible, index: index, total: healthFabActionKinds.count)
                    .onTapGesture {
                        performHealthFabAction(action)
                    }
                    .allowsHitTesting(healthFabItemsVisible && (action != .pdf || !isRenderingPDF))
                    .accessibilityHidden(!healthFabItemsVisible)
                }
            }

            HomeFabMainButton(
                isExpanded: isHealthFabExpanded,
                accessibilityLabel: isHealthFabExpanded
                    ? l.tr(zh: "收起健康菜单", en: "Collapse health menu", de: "Gesundheitsmenü schließen")
                    : l.tr(zh: "展开健康菜单", en: "Open health menu", de: "Gesundheitsmenü öffnen"),
                action: toggleHealthFabMenu
            )
        }
    }

    private var healthFabActionKinds: [HealthFabActionKind] {
        var actions: [HealthFabActionKind] = [
            .preventive,
            .visit,
            .medication,
            .vaccinePassport,
            .archive,
            .pdf,
            .symptom
        ]
        if !pet.isNeutered {
            actions.append(.heatCycle)
        }
        return actions
    }

    private func openHealthFabMenu() {
        guard !isHealthFabExpanded else { return }
        healthFabItemsVisible = false
        withAnimation(GoMotion.fab) {
            isHealthFabExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(GoMotion.fab) {
                healthFabItemsVisible = true
            }
        }
    }

    private func closeHealthFabMenu() {
        guard isHealthFabExpanded else { return }
        withAnimation(GoMotion.fab) {
            healthFabItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if isHealthFabExpanded && !healthFabItemsVisible {
                withAnimation(GoMotion.fab) {
                    isHealthFabExpanded = false
                }
            }
        }
    }

    private func toggleHealthFabMenu() {
        OhanaFeedback.medium()
        isHealthFabExpanded ? closeHealthFabMenu() : openHealthFabMenu()
    }

    private func performHealthFabAction(_ action: HealthFabActionKind) {
        guard action != .pdf || !isRenderingPDF else { return }
        OhanaFeedback.light()
        healthFabItemsVisible = false
        withAnimation(GoMotion.fab) {
            isHealthFabExpanded = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
            switch action {
            case .preventive:
                openHealthRecord(.guided(.preventive), feedback: false)
            case .visit:
                openHealthRecord(.guided(.visit), feedback: false)
            case .medication:
                openMedicationPopup(feedback: false)
            case .vaccinePassport:
                showingPassport = true
            case .archive:
                showingHistory = true
            case .pdf:
                renderHealthPDF()
            case .symptom:
                openHealthRecord(.symptom, feedback: false)
            case .heatCycle:
                openHealthRecord(.heatCycle, feedback: false)
            }
        }
    }

    private var healthInlinePopupTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.965, anchor: .bottom)),
            removal: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.985, anchor: .bottom))
        )
    }

    private func openHealthRecord(_ destination: HealthPlusDestination, feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        activeHealthSheet = nil
        withAnimation(GoMotion.sheet) {
            healthPlusDestination = destination
        }
    }

    private func closeHealthRecordPopup(feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        withAnimation(GoMotion.sheet) {
            healthPlusDestination = nil
        }
    }

    private func openHealthOverview(_ sheet: ActiveHealthSheet, feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        withAnimation(GoMotion.page) {
            activeHealthSheet = sheet
        }
    }

    private func closeHealthOverview() {
        OhanaFeedback.light()
        withAnimation(GoMotion.page) {
            activeHealthSheet = nil
        }
    }

    private func openMedicationPopup(feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        activeHealthSheet = nil
        healthPlusDestination = nil
        withAnimation(GoMotion.sheet) {
            showingMedicationPopup = true
        }
    }

    private func closeMedicationPopup(feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        withAnimation(GoMotion.sheet) {
            showingMedicationPopup = false
        }
    }

    private func renderHealthPDF() {
        guard !isRenderingPDF else { return }
        isRenderingPDF = true
        Task {
            pdfURL = await PetVetSummaryPDFRenderer.render(pet: pet)
            isRenderingPDF = false
            if pdfURL != nil { showingPDFPreview = true }
        }
    }

    private var healthHeroCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(healthStatusTitle)
                    .font(OhanaFont.adaptive(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(healthStatusSubtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(healthStatusColor)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    statusPill(icon: "shield.checkered", value: "\(max(0, preventiveTypes.count - duePreventiveCount))/\(preventiveTypes.count)")
                    statusPill(icon: "pill.fill", value: medicationStatusText)
                }
            }
            Spacer()
            Image(systemName: (healthAlerts.isEmpty && duePreventiveCount == 0) ? "checkmark.seal.fill" : "heart.text.square.fill")
                .font(OhanaFont.adaptive(size: 28, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(healthStatusColor)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private func statusPill(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
            Text(value)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(isDark ? 0.10 : 0.06), in: Capsule())
    }

    private var compactAlertsCard: some View {
        VStack(spacing: 10) {
            ForEach(healthAlerts.prefix(2)) { alert in
                HStack(spacing: 10) {
                    Image(systemName: alertIcon(for: alert.type))
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(alertColor(alert))
                        .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .background(alertColor(alert).opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(alert.detail)
                            .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    severityBadge(alert.severity)
                }
            }
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: 20)
    }

    private var healthDashboardCards: some View {
        VStack(spacing: 12) {
            healthDashboardCard(
                title: l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge"),
                value: nextPreventiveStatusText,
                detail: preventiveDashboardDetail,
                icon: "shield.checkered",
                tint: preventionTint,
                primaryTitle: l.tr(zh: "记录", en: "Log", de: "Eintragen"),
                secondaryTitle: l.tr(zh: "疫苗本", en: "Passport", de: "Impfpass"),
                primaryAction: { openHealthRecord(.guided(.preventive)) },
                secondaryAction: {
                    OhanaFeedback.light()
                    showingPassport = true
                },
                cardAction: { openHealthOverview(.preventiveOverview) }
            )
            healthDashboardCard(
                title: l.tr(zh: "用药", en: "Medication", de: "Medikamente"),
                value: medicationStatusText,
                detail: nextMedicationDoseText,
                icon: "pill.fill",
                tint: medicationTint,
                primaryTitle: medicationPrimaryButtonTitle,
                secondaryTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
                primaryAction: handleMedicationPrimaryAction,
                secondaryAction: {
                    OhanaFeedback.light()
                    healthPlusDestination = .medications
                },
                cardAction: { openHealthOverview(.medicationOverview) }
            )
            healthDashboardCard(
                title: l.tr(zh: "异常/就诊", en: "Symptoms & visits", de: "Auffälligkeiten & Besuche"),
                value: symptomStatusText,
                detail: symptomVisitDashboardDetail,
                icon: "waveform.path.ecg",
                tint: symptomVisitTint,
                primaryTitle: l.tr(zh: "症状", en: "Symptom", de: "Symptom"),
                secondaryTitle: l.tr(zh: "就诊", en: "Visit", de: "Besuch"),
                primaryAction: { openHealthRecord(.symptom) },
                secondaryAction: { openHealthRecord(.guided(.visit)) },
                cardAction: { openHealthOverview(.symptomVisitOverview) }
            )
        }
    }

    private func healthDashboardCard(
        title: String,
        value: String,
        detail: String,
        icon: String,
        tint: Color,
        primaryTitle: String,
        secondaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        cardAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(isDark ? 0.20 : 0.13))
                    .frame(width: 58, height: 58)
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button {
                    primaryAction()
                } label: {
                    Text(primaryTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 64, height: 34)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    secondaryAction()
                } label: {
                    Text(secondaryTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 64, height: 34)
                        .background(Color.primary.opacity(isDark ? 0.10 : 0.07), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .goIslandModuleCard(cornerRadius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: cardAction)
    }

    @ViewBuilder
    private func healthOverviewSheet(_ sheet: ActiveHealthSheet) -> some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch sheet {
                        case .preventiveOverview:
                            preventiveOverviewContent
                        case .medicationOverview:
                            medicationOverviewContent
                        case .symptomVisitOverview:
                            symptomVisitOverviewContent
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        closeHealthOverview()
                    } label: {
                        Image(systemName: "xmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 14, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
            }
        }
    }

    private var preventiveOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewTitle(
                icon: "shield.checkered",
                title: l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge"),
                subtitle: preventiveDashboardDetail,
                tint: preventionTint
            )

            VStack(spacing: 10) {
                ForEach(preventionItems) { item in
                    preventiveStatusRow(item)
                }
            }

            HStack(spacing: 10) {
                overviewActionButton(l.tr(zh: "添加预防", en: "Add preventive", de: "Vorsorge hinzufügen"), icon: "plus") {
                    activeHealthSheet = nil
                    openHealthRecord(.guided(.preventive), feedback: false)
                }
                overviewActionButton(l.tr(zh: "疫苗本", en: "Passport", de: "Impfpass"), icon: "syringe.fill") {
                    activeHealthSheet = nil
                    showingPassport = true
                }
            }

            overviewSectionTitle(l.tr(zh: "最近记录", en: "Recent", de: "Zuletzt"))
            let preventiveLogs = pet.healthLogs
                .filter { preventiveTypes.contains($0.healthLogType) }
                .sorted { $0.date > $1.date }
                .prefix(6)
            if preventiveLogs.isEmpty {
                emptyOverviewRow(l.tr(zh: "还没有预防护理记录", en: "No preventive records yet", de: "Noch keine Vorsorgeeinträge"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(preventiveLogs)) { log in
                        overviewHistoryRow(
                            icon: healthIcon(for: log.healthLogType),
                            title: log.note.isEmpty ? healthTypeTitle(log.healthLogType) : log.note,
                            detail: log.date.formatted(.dateTime.year().month().day()),
                            tint: colorForType(log.healthLogType)
                        )
                    }
                }
            }
        }
    }

    private var medicationOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewTitle(
                icon: "pill.fill",
                title: l.tr(zh: "用药", en: "Medication", de: "Medikamente"),
                subtitle: nextMedicationDoseText,
                tint: medicationTint
            )

            HStack(spacing: 12) {
                overviewMetric(
                    title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                    value: medicationStatusText,
                    tint: medicationTint
                )
                overviewMetric(
                    title: l.tr(zh: "进行中", en: "Active", de: "Aktiv"),
                    value: "\(activeMedications.count)",
                    tint: Color.goPurple
                )
            }

            overviewSectionTitle(l.tr(zh: "未来 48 小时", en: "Next 48 hours", de: "Nächste 48 Stunden"))
            let futureItems = next48HourMedicationDoseItems.prefix(8)
            if futureItems.isEmpty {
                emptyOverviewRow(l.tr(zh: "没有固定剂量", en: "No scheduled doses", de: "Keine geplanten Dosen"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(futureItems)) { item in
                        medicationDoseRow(item)
                    }
                }
            }

            overviewSectionTitle(l.tr(zh: "最近服药", en: "Recent doses", de: "Letzte Dosen"))
            let recentEvents = medicationDoseEvents
                .filter { event in activeMedications.contains { $0.id.uuidString == event.relatedEntityId } || pet.medications.contains { $0.id.uuidString == event.relatedEntityId } }
                .sorted { $0.startDate > $1.startDate }
                .prefix(8)
            if recentEvents.isEmpty {
                emptyOverviewRow(l.tr(zh: "还没有服药记录", en: "No dose history yet", de: "Noch keine Einnahmen"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentEvents)) { event in
                        overviewHistoryRow(
                            icon: "pill.fill",
                            title: medicationName(for: event),
                            detail: event.startDate.formatted(.dateTime.month().day().hour().minute()),
                            tint: medicationTint
                        )
                    }
                }
            }

            overviewActionButton(l.tr(zh: "管理用药", en: "Manage medication", de: "Medikamente verwalten"), icon: "slider.horizontal.3") {
                activeHealthSheet = nil
                withAnimation(GoMotion.sheet) {
                    healthPlusDestination = .medications
                }
            }
        }
    }

    private var symptomVisitOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewTitle(
                icon: "waveform.path.ecg",
                title: l.tr(zh: "异常/就诊", en: "Symptoms & visits", de: "Auffälligkeiten & Besuche"),
                subtitle: symptomVisitDashboardDetail,
                tint: symptomVisitTint
            )

            if !pet.symptomLogs.isEmpty {
                overviewSectionTitle(l.tr(zh: "严重程度", en: "Severity", de: "Schweregrad"))
                symptomSeverityDistribution
            }

            HStack(spacing: 10) {
                overviewActionButton(l.tr(zh: "记录症状", en: "Log symptom", de: "Symptom eintragen"), icon: "exclamationmark.triangle.fill") {
                    activeHealthSheet = nil
                    openHealthRecord(.symptom, feedback: false)
                }
                overviewActionButton(l.tr(zh: "记录就诊", en: "Log visit", de: "Besuch eintragen"), icon: "cross.case.fill") {
                    activeHealthSheet = nil
                    openHealthRecord(.guided(.visit), feedback: false)
                }
            }

            overviewSectionTitle(l.tr(zh: "症状", en: "Symptoms", de: "Symptome"))
            let symptoms = pet.symptomLogs.sorted { $0.date > $1.date }.prefix(6)
            if symptoms.isEmpty {
                emptyOverviewRow(l.tr(zh: "没有异常症状", en: "No symptoms", de: "Keine Symptome"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(symptoms)) { log in
                        overviewHistoryRow(
                            icon: symptomCategoryIcon(log.category),
                            title: log.symptomName.isEmpty ? l.tr(zh: "异常症状", en: "Symptom", de: "Symptom") : log.symptomName,
                            detail: "\(localizedSeverityLabel(log.severity)) · \(log.date.formatted(.dateTime.month().day()))",
                            tint: log.severity == .severe || log.severity == .critical ? Color.goRed : Color.goOrange
                        )
                    }
                }
            }

            overviewSectionTitle(l.tr(zh: "就诊/检查", en: "Visits & procedures", de: "Besuche & Eingriffe"))
            let visits = pet.healthLogs
                .filter { visitTypes.contains($0.healthLogType) }
                .sorted { $0.date > $1.date }
                .prefix(6)
            if visits.isEmpty {
                emptyOverviewRow(l.tr(zh: "没有就诊记录", en: "No visit records", de: "Keine Besuchseinträge"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visits)) { log in
                        overviewHistoryRow(
                            icon: healthIcon(for: log.healthLogType),
                            title: log.note.isEmpty ? healthTypeTitle(log.healthLogType) : log.note,
                            detail: log.date.formatted(.dateTime.year().month().day()),
                            tint: colorForType(log.healthLogType)
                        )
                    }
                }
            }
        }
    }

    private func overviewTitle(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 22, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(isDark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    private func overviewSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.top, 4)
    }

    private func overviewMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func overviewActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(chromeAccent, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func preventiveStatusRow(_ item: PetHealthPreventionItem) -> some View {
        let tint: Color = {
            guard let days = item.daysRemaining else { return Color.goOrange }
            if days < 0 { return Color.goRed }
            if days <= 30 { return Color.goYellow }
            return chromeAccent
        }()
        let status: String = {
            guard let days = item.daysRemaining else {
                return l.tr(zh: "待补录", en: "Missing", de: "Fehlt")
            }
            if days < 0 {
                return l.tr(zh: "逾期 \(abs(days)) 天", en: "\(abs(days)) days overdue", de: "\(abs(days)) Tage überfällig")
            }
            if days == 0 {
                return l.tr(zh: "今天到期", en: "Due today", de: "Heute fällig")
            }
            return l.tr(zh: "\(days) 天后", en: "In \(days) days", de: "In \(days) Tagen")
        }()

        return HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.latestLog?.date.formatted(.dateTime.year().month().day()) ?? l.tr(zh: "未记录", en: "Not logged", de: "Nicht erfasst"))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(status)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func medicationDoseRow(_ item: PetHealthMedicationDoseItem) -> some View {
        let isPast = item.scheduledAt <= Date()
        return HStack(spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : (isPast ? "clock.badge.exclamationmark.fill" : "clock.fill"))
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(item.isCompleted ? Color.goTeal : (isPast ? Color.goOrange : medicationTint))
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.medication.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : item.medication.name)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(relativeDoseTime(item.scheduledAt))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if item.isCompleted {
                Text(l.tr(zh: "已服", en: "Taken", de: "Genommen"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
            } else if Calendar.current.isDateInToday(item.scheduledAt) {
                Button {
                    recordMedicationDose(item)
                } label: {
                    Text(isPast ? l.tr(zh: "补记", en: "Catch up", de: "Nachtragen") : l.tr(zh: "提前", en: "Early", de: "Früh"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(medicationTint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Text(l.tr(zh: "待服", en: "Planned", de: "Geplant"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overviewHistoryRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint.opacity(isDark ? 0.16 : 0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func emptyOverviewRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tray").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var symptomSeverityDistribution: some View {
        let severities = SymptomSeverity.allCases
        let total = max(1, pet.symptomLogs.count)
        return VStack(spacing: 9) {
            ForEach(severities, id: \.rawValue) { severity in
                let count = pet.symptomLogs.filter { $0.severity == severity }.count
                HStack(spacing: 10) {
                    Text(severity.label)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(severityColor(severity).opacity(0.18))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(severityColor(severity))
                                    .frame(width: max(6, proxy.size.width * CGFloat(count) / CGFloat(total)))
                            }
                    }
                    .frame(height: 9)
                    Text("\(count)")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func severityColor(_ severity: SymptomSeverity) -> Color {
        switch severity {
        case .mild: return Color.goTeal
        case .moderate: return Color.goYellow
        case .severe: return Color.goOrange
        case .critical: return Color.goRed
        }
    }

    private func medicationName(for event: Event) -> String {
        pet.medications.first { $0.id.uuidString == event.relatedEntityId }?.name
        ?? l.tr(zh: "服药记录", en: "Medication dose", de: "Medikamenteneinnahme")
    }

    private var healthCoreGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            healthCoreCard(
                title: "预防",
                value: nextPreventiveStatusText,
                icon: "shield.checkered",
                tint: isDark ? Color.goPrimary : Color.goTeal
            ) {
                openHealthRecord(.guided(.preventive))
            }
            healthCoreCard(
                title: "用药",
                value: medicationStatusText,
                icon: "pill.fill",
                tint: Color(hex: "FF8A3D")
            ) {
                OhanaFeedback.light()
                healthPlusDestination = .medications
            }
            healthCoreCard(
                title: "异常",
                value: symptomStatusText,
                icon: "waveform.path.ecg",
                tint: latestSymptomLog == nil ? (isDark ? Color.goPrimary : Color.goTeal) : Color.goRed
            ) {
                openHealthRecord(.symptom)
            }
            healthCoreCard(
                title: "档案",
                value: archiveStatusText,
                icon: "folder.fill",
                tint: Color.goPurple
            ) {
                OhanaFeedback.light()
                showingHistory = true
            }
        }
    }

    private func healthCoreCard(
        title: String,
        value: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            OhanaFeedback.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 19, weight: .black))
                        .foregroundStyle(tint)
                        .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(title)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .padding(14)
            .goIslandModuleCard(cornerRadius: 22)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var preventiveRingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("防护")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    OhanaFeedback.light()
                    showingPassport = true
                } label: {
                    Image(systemName: "syringe.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(chromeAccent)
                        .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
                .buttonStyle(ScaleButtonStyle())
            }
            immunityOverviewRow
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: 20)
    }

    private var quickToolsRow: some View {
        HStack(spacing: 10) {
            healthToolButton(title: "就诊", icon: "cross.case.fill", tint: Color.goRed) {
                healthPlusDestination = .guided(.visit)
            }
            healthToolButton(title: "疫苗本", icon: "syringe.fill", tint: Color.goTeal) {
                showingPassport = true
            }
            if !pet.isNeutered {
                healthToolButton(title: "生理期", icon: "heart.text.square.fill", tint: Color.pink) {
                    healthPlusDestination = .heatCycle
                }
            }
            healthToolButton(title: "PDF", icon: "doc.richtext", tint: chromeAccent) {
                guard !isRenderingPDF else { return }
                isRenderingPDF = true
                Task {
                    pdfURL = await PetVetSummaryPDFRenderer.render(pet: pet)
                    isRenderingPDF = false
                    if pdfURL != nil { showingPDFPreview = true }
                }
            }
        }
    }

    private func healthToolButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.light()
            action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .goIslandModuleCard(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    OhanaFeedback.light()
                    showingHistory = true
                } label: {
                    Text(l.tr(zh: "全部", en: "All", de: "Alle"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(chromeAccent)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if recentHealthActivities.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 22, weight: .bold))
                        .foregroundStyle(chromeAccent)
                    Text(l.tr(zh: "还没有健康记录", en: "No health records yet", de: "Noch keine Gesundheitseinträge"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(recentHealthActivities) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(item.tint)
                            .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .background(item.tint.opacity(isDark ? 0.20 : 0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(item.detail)
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(item.date.formatted(.dateTime.month().day()))
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: 20)
    }

    // MARK: - 免疫状态总览条
    private var immunityOverviewRow: some View {
        let items: [(HealthLogType, String, String, Int)] = [
            (.vaccine,           "syringe.fill", l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung"),  365),
            (.dewormingInternal, "pills.fill", l.tr(zh: "体内", en: "Internal", de: "Innen"), 90),
            (.dewormingExternal, "shield.lefthalf.filled", l.tr(zh: "体外", en: "External", de: "Außen"), 90),
            (.checkup,           "stethoscope", l.tr(zh: "体检", en: "Checkup", de: "Check-up"),  365),
        ]
        return HStack(spacing: 0) {
            ForEach(items, id: \.0) { type, icon, label, cycle in
                let last = latestLog(type: type)
                let due  = dueDate(for: type)
                let days = daysUntil(due)
                let color: Color = {
                    guard let d = days else { return .primary.opacity(0.3) }
                    if d < 0 { return Color.goRed }
                    if d < 30 { return isDark ? Color.goPrimary : Color.goYellow }
                    return themeColor
                }()
                VStack(spacing: 5) {
                    ZStack {
                        Circle().stroke(color.opacity(0.18), lineWidth: 3).frame(width: 44, height: 44)
                        if let last = last {
                            let elapsed = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                            let progress = min(1.0, Double(elapsed) / Double(cycle))
                            Circle()
                                .trim(from: 0, to: 1 - progress)
                                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                        }
                        Image(systemName: icon)
                            .font(OhanaFont.adaptive(size: 16, weight: .black))
                            .foregroundStyle(color)
                    }
                    Text(label)
                        .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    if let d = days {
                        Text(d < 0 ? "逾期" : "\(d)天")
                            .font(OhanaFont.adaptive(size: 8, weight: .semibold)).foregroundStyle(color)
                    } else {
                        Text("未记录")
                            .font(OhanaFont.adaptive(size: 8)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    openHealthRecord(.direct(type))
                }
            }
        }
    }

    // MARK: - 散点图主体
    private var scatterChart: some View {
        GeometryReader { proxy in
            let rows = HealthLogType.allCases
            let start = chartXDomain.lowerBound.timeIntervalSinceReferenceDate
            let span = max(chartXDomain.upperBound.timeIntervalSinceReferenceDate - start, 1)
            ZStack {
                ForEach(Array(rows.enumerated()), id: \.element.rawValue) { index, _ in
                    let y = rowY(index: index, count: rows.count, height: proxy.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(Color.ohanaPrimaryText.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                }

                ForEach(scatterPoints) { pt in
                    let xRatio = (pt.date.timeIntervalSinceReferenceDate - start) / span
                    let rowIndex = rows.firstIndex(of: pt.typeEnum) ?? 0
                    Circle()
                        .fill(colorForType(pt.typeEnum))
                        .frame(width: 11, height: 11) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .position(
                            x: min(max(CGFloat(xRatio) * proxy.size.width * scatterRevealProgress, 0), proxy.size.width),
                            y: rowY(index: rowIndex, count: rows.count, height: proxy.size.height)
                        )
                }
            }
        }
        .frame(height: 160)
        .onAppear { playScatterReveal() }
    }

    private func rowY(index: Int, count: Int, height: CGFloat) -> CGFloat {
        guard count > 1 else { return height / 2 }
        let topInset: CGFloat = 12
        let bottomInset: CGFloat = 12
        let usable = max(1, height - topInset - bottomInset)
        return topInset + usable * CGFloat(index) / CGFloat(count - 1)
    }

    // MARK: - 图例视图
    private var trendLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presentTypes, id: \.rawValue) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForType(type))
                            .frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Text(type.rawValue)
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - 健康记录趋势（散点时间轴）
    private var healthTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("健康记录趋势", systemImage: "waveform.path.ecg")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(chromeAccent)
                Spacer()
                Text("最近 12 个月")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            scatterChart
            trendLegend
        }
    }

    // MARK: - 健康记录列表卡
    private var healthLogsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("健康时间轴", systemImage: "list.bullet.clipboard.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(chromeAccent)
                Spacer()
                Text("\(sortedLogs.count) 条")
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            if sortedLogs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "heart.text.square").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 34, weight: .black))
                        .foregroundStyle(chromeAccent)
                    Text(l.tr(zh: "暂无健康记录", en: "No health records yet", de: "Noch keine Gesundheitseinträge"))
                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(sortedLogs) { log in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(colorForType(log.healthLogType).opacity(0.15)).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            Image(systemName: healthIcon(for: log.healthLogType))
                                .font(OhanaFont.adaptive(size: 15, weight: .black))
                                .foregroundStyle(colorForType(log.healthLogType))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(log.type)
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            HStack(spacing: 6) {
                                Text(log.date, format: .dateTime.year().month().day())
                                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                if !log.note.isEmpty {
                                    Text(log.note)
                                        .font(OhanaFont.adaptive(size: 11))
                                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            if log.cost > 0 {
                                Text(AppCurrency.format(log.cost, fractionDigits: 0))
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                            }
                            Button {
                                deleteHealthLog(log)
                            } label: {
                                Image(systemName: deletingHealthRecordIDs.contains(log.id) ? "hourglass" : "trash")
                                    .font(OhanaFont.adaptive(size: 11))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            }
                            .disabled(deletingHealthRecordIDs.contains(log.id))
                        }
                    }
                    .padding(.vertical, 6)
                    if log.id != sortedLogs.last?.id {
                    Divider()
                }
                }
            }
        }
    }

    // MARK: - 异常症状记录卡
    private var symptomsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("异常症状记录", systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.red)
                Spacer()
                Text("\(pet.symptomLogs.count) 条")
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            ForEach(pet.symptomLogs.sorted(by: { $0.date > $1.date })) { log in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.15)).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Image(systemName: symptomCategoryIcon(log.category))
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(Color.goRed)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.symptomName)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        HStack(spacing: 6) {
                            Text(log.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            Text(log.severity.label)
                                .font(OhanaFont.adaptive(size: 10, weight: .bold))
                                .foregroundStyle(log.severity == .critical || log.severity == .severe ? Color.red : Color.orange)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background((log.severity == .critical || log.severity == .severe ? Color.red : Color.orange).opacity(0.15), in: Capsule())
                        }
                        if !log.note.isEmpty {
                            Text(log.note)
                                .font(OhanaFont.adaptive(size: 11))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button {
                        deleteSymptomLog(log)
                    } label: {
                        Image(systemName: deletingHealthRecordIDs.contains(log.id) ? "hourglass" : "trash")
                            .font(OhanaFont.adaptive(size: 11))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                    .disabled(deletingHealthRecordIDs.contains(log.id))
                }
                .padding(.vertical, 6)
                if log.id != pet.symptomLogs.sorted(by: { $0.date > $1.date }).last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - 生理期记录卡
    private var heatCycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("生理期与繁育", systemImage: "heart.text.square.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.pink)
                Spacer()
                Text("\(pet.heatCycleLogs.count) 条")
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            ForEach(pet.heatCycleLogs.sorted(by: { $0.startDate > $1.startDate })) { log in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: log.status.colorHex).opacity(0.15)).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Image(systemName: "heart.text.square.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(Color(hex: log.status.colorHex))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.status.rawValue)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        HStack(spacing: 6) {
                            Text(log.startDate, format: .dateTime.year().month().day())
                                .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            if log.isMated {
                                Text("已交配")
                                    .font(OhanaFont.adaptive(size: 10, weight: .bold))
                                    .foregroundStyle(Color.pink)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color.pink.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                    Spacer()
                    Button {
                        deleteHeatCycleLog(log)
                    } label: {
                        Image(systemName: deletingHealthRecordIDs.contains(log.id) ? "hourglass" : "trash")
                            .font(OhanaFont.adaptive(size: 11))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                    .disabled(deletingHealthRecordIDs.contains(log.id))
                }
                .padding(.vertical, 6)
                if log.id != pet.heatCycleLogs.sorted(by: { $0.startDate > $1.startDate }).last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Alerts Section（TASK 7）
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(isDark ? Color.goPrimary : Color.goOrange)
                Text("健康预警")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                Spacer()
                Text("\(healthAlerts.count) 条")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
            }

            ForEach(healthAlerts.prefix(5)) { alert in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(alertColor(alert).opacity(0.15))
                            .frame(width: 32, height: 32) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Image(systemName: alertIcon(for: alert.type))
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                            .foregroundStyle(alertColor(alert))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(alert.detail)
                            .font(OhanaFont.adaptive(size: 11, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                            .lineLimit(2)
                    }
                    Spacer()
                    severityBadge(alert.severity)
                }
                .padding(.vertical, 4)
                if alert.id != healthAlerts.prefix(5).last?.id {
                    Divider()
                }
            }
        }
    }

    private func alertColor(_ alert: HealthAlert) -> Color {
        switch alert.severity {
        case .urgent:  return isDark ? Color.goPrimary : Color.goOrange
        case .warning: return isDark ? Color.goPrimary.opacity(0.85) : Color.goYellow
        case .info:    return isDark ? Color.goPrimary.opacity(0.7) : Color.goTeal
        }
    }

    @ViewBuilder
    private func severityBadge(_ severity: HealthAlert.Severity) -> some View {
        let (label, color): (String, Color) = {
            switch severity {
            case .urgent:  return ("紧急", isDark ? Color.goPrimary : Color.goOrange)
            case .warning: return ("注意", isDark ? Color.goPrimary.opacity(0.9) : Color.goYellow)
            case .info:    return ("提示", isDark ? Color.goPrimary.opacity(0.75) : Color.goTeal)
            }
        }()
        Text(label)
            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

private struct PetHealthRecordInlinePopup: View {
    let pet: Pet
    let entryMode: HealthRecordEntryMode?
    let onClose: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var selectedType: HealthLogType
    @State private var date = Date()
    @State private var name = ""
    @State private var note = ""
    @State private var vetName = ""
    @State private var cost = ""
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasNextCheckup = false
    @State private var nextCheckupDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        pet: Pet,
        initialType: HealthLogType,
        entryMode: HealthRecordEntryMode?,
        onClose: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.pet = pet
        self.entryMode = entryMode
        self.onClose = onClose
        self.onSaved = onSaved
        _selectedType = State(initialValue: initialType)
    }

    private var l: L10n { L10n(appLanguage) }
    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { isDark ? Color.goPrimary : Color.goBlue }
    private var activeExecutorID: String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }

    private var showsNameField: Bool {
        selectedType == .vaccine || selectedType == .dewormingInternal || selectedType == .dewormingExternal || selectedType == .medication
    }
    private var showsExpiration: Bool { selectedType.needsExpiration }
    private var showsNextCheckup: Bool { selectedType == .checkup }

    private var typeLabel: String {
        switch selectedType {
        case .vaccine: return l.tr(zh: "疫苗接种", en: "Vaccine", de: "Impfung")
        case .dewormingInternal: return l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: return l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .checkup: return l.tr(zh: "体检记录", en: "Checkup", de: "Check-up")
        case .surgery: return l.tr(zh: "就诊记录", en: "Visit", de: "Besuch")
        default: return selectedType.rawValue
        }
    }

    private func healthIcon(for type: HealthLogType) -> String {
        switch type {
        case .general: return "clipboard.fill"
        case .vaccine: return "syringe.fill"
        case .medication: return "pill.fill"
        case .dewormingInternal: return "pills.fill"
        case .dewormingExternal: return "shield.lefthalf.filled"
        case .surgery: return "cross.case.fill"
        case .dental: return "mouth.fill"
        case .checkup: return "stethoscope"
        case .emergency: return "cross.circle.fill"
        case .other: return "doc.text.fill"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.ohanaPrimaryText.opacity(0.26))
                .frame(width: 48, height: 5)
                .padding(.top, 8)

            HStack(spacing: 12) {
                Image(systemName: healthIcon(for: selectedType))
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(typeLabel)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pet.name)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                    guard !isSaving else { return }
                    onClose()
                }
            }
            .padding(.horizontal, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if let entryMode {
                        healthSubtypeSelector(mode: entryMode)
                    }

                    if showsNameField {
                        inlineField(icon: "pencil.line", tint: accent) {
                            TextField(l.tr(zh: "名称（可选）", en: "Name (optional)", de: "Name (optional)"), text: $name)
                                .font(OhanaFont.subheadline(.semibold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                    }

                    inlineField(icon: "calendar", tint: accent) {
                        DatePicker(l.tr(zh: "记录日期", en: "Date", de: "Datum"), selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(accent)
                    }

                    if showsExpiration {
                        inlineToggleDateBlock(
                            title: l.tr(zh: "有效期提醒", en: "Expiry reminder", de: "Ablauf-Erinnerung"),
                            isOn: $hasExpiration,
                            date: $expirationDate,
                            range: date...,
                            tint: Color.goTeal
                        )
                    }

                    if showsNextCheckup {
                        inlineToggleDateBlock(
                            title: l.tr(zh: "下次体检提醒", en: "Next checkup reminder", de: "Nächster Check-up"),
                            isOn: $hasNextCheckup,
                            date: $nextCheckupDate,
                            range: date...,
                            tint: Color.goTeal
                        )
                    }

                    inlineField(icon: "stethoscope", tint: Color.goTeal) {
                        TextField(l.tr(zh: "医生 / 诊所（可选）", en: "Vet / clinic (optional)", de: "Tierarzt / Klinik (optional)"), text: $vetName)
                            .font(OhanaFont.subheadline(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }

                    inlineField(icon: AppCurrency.systemIconName, tint: Color.goYellow) {
                        InlineNumericInput(
                            text: $cost,
                            placeholder: l.tr(zh: "费用（可选）", en: "Cost (optional)", de: "Kosten (optional)"),
                            maxFractionDigits: 2,
                            accent: Color.goYellow,
                            step: 10,
                            valueFont: OhanaFont.subheadline(.semibold),
                            valueAlignment: .leading,
                            fill: Color.clear,
                            cornerRadius: 12,
                            horizontalPadding: 4,
                            verticalPadding: 0
                        )
                    }

                    inlineField(icon: "note.text", tint: Color.ohanaSecondaryText) {
                        TextField(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"), text: $note, axis: .vertical)
                            .font(OhanaFont.subheadline(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
            }

            Button(action: save) {
                HStack(spacing: 8) {
                    Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    Text(isSaving
                        ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                        : l.tr(zh: "保存记录", en: "Save record", de: "Eintrag speichern")
                    )
                }
                .font(OhanaFont.body(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isSaving ? Color.ohanaControlFill : accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isSaving)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            FeedInlineSheetGlassSurface(cornerRadius: 52, glassMode: .regular)
        }
        .onAppear(perform: applyDefaultsForSelectedType)
        .onChange(of: selectedType) { _, _ in applyDefaultsForSelectedType() }
        .onChange(of: date) { _, newDate in
            if hasExpiration {
                expirationDate = defaultExpirationDate(from: newDate)
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private func healthSubtypeSelector(mode: HealthRecordEntryMode) -> some View {
        let options: [(HealthLogType, String)] = {
            switch mode {
            case .preventive:
                return [(.vaccine, "疫苗"), (.dewormingInternal, "体内"), (.dewormingExternal, "体外"), (.checkup, "体检")]
            case .visit:
                return [(.surgery, "就诊"), (.general, "常规")]
            }
        }()

        return HStack(spacing: 8) {
            ForEach(options, id: \.0) { type, title in
                Button {
                    withAnimation(GoMotion.selection) { selectedType = type }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: healthIcon(for: type))
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                        Text(title)
                            .font(OhanaFont.caption(.black))
                    }
                    .foregroundStyle(selectedType == type ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedType == type ? accent : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func inlineField<Content: View>(
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 22)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func inlineToggleDateBlock(
        title: String,
        isOn: Binding<Bool>,
        date: Binding<Date>,
        range: PartialRangeFrom<Date>,
        tint: Color
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(tint)
            }
            if isOn.wrappedValue {
                DatePicker("", selection: date, in: range, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(tint)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func defaultExpirationDate(from base: Date) -> Date {
        let cal = Calendar.current
        switch selectedType {
        case .vaccine:
            return cal.date(byAdding: .year, value: 1, to: base) ?? base
        case .dewormingInternal:
            return cal.date(byAdding: .month, value: 3, to: base) ?? base
        case .dewormingExternal, .medication:
            return cal.date(byAdding: .month, value: 1, to: base) ?? base
        default:
            return cal.date(byAdding: .year, value: 1, to: base) ?? base
        }
    }

    private func applyDefaultsForSelectedType() {
        switch selectedType {
        case .vaccine:
            if name.isEmpty { name = "\(pet.name)疫苗" }
            hasExpiration = true
            expirationDate = defaultExpirationDate(from: date)
        case .dewormingInternal, .dewormingExternal, .medication:
            if name.isEmpty { name = "\(pet.name)\(typeLabel)" }
            hasExpiration = true
            expirationDate = defaultExpirationDate(from: date)
        case .checkup:
            hasNextCheckup = true
            nextCheckupDate = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
        default:
            break
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let input = PetHealthRecordCommandInput(
            type: selectedType,
            date: date,
            name: name,
            note: note,
            vetName: vetName,
            cost: CountryDecimalInput.parse(cost, countryCode: AppCountry.code) ?? 0,
            expirationDate: (showsExpiration && hasExpiration) ? expirationDate : nil,
            nextCheckupDate: (showsNextCheckup && hasNextCheckup) ? nextCheckupDate : nil,
            executorId: activeExecutorID,
            source: .detail,
            includesNameInNote: showsNameField
        )
        let command = DomainCommand.petHealthRecord(petID: pet.id, type: selectedType.rawValue)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(command) {
            PetHealthCommandExecutor(context: modelContext).recordHealth(
                pet: pet,
                input: input,
                note: "pet.health.inline.record"
            )
            onSaved()
        }
    }
}

private enum PetHealthArchiveFilter: String, CaseIterable {
    case all = "全部"
    case health = "记录"
    case symptom = "异常"
    case heat = "生理"
}

private struct PetHealthArchiveItem: Identifiable {
    enum Source {
        case health(PetHealthLog)
        case symptom(SymptomLog)
        case heat(HeatCycleLog)
    }

    let id: String
    let date: Date
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let filter: PetHealthArchiveFilter
    let source: Source

    var recordID: UUID {
        switch source {
        case .health(let log):
            return log.id
        case .symptom(let log):
            return log.id
        case .heat(let log):
            return log.id
        }
    }

    var commandKind: String {
        switch source {
        case .health:
            return "health"
        case .symptom:
            return "symptom"
        case .heat:
            return "heat"
        }
    }
}

private struct PetHealthArchiveView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var filter: PetHealthArchiveFilter = .all
    @State private var deletingItemIDs: Set<String> = []
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { isDark ? Color.goPrimary : Color(hex: pet.themeColorHex) }
    private var l: L10n { L10n(appLanguage) }

    private var items: [PetHealthArchiveItem] {
        let healthItems = pet.healthLogs.map { log in
            PetHealthArchiveItem(
                id: "health-\(log.id.uuidString)",
                date: log.date,
                icon: healthIcon(for: log.healthLogType),
                title: log.note.isEmpty ? healthTitle(for: log.healthLogType) : log.note,
                detail: archiveDetail(for: log),
                tint: color(for: log.healthLogType),
                filter: .health,
                source: .health(log)
            )
        }
        let symptomItems = pet.symptomLogs.map { log in
            PetHealthArchiveItem(
                id: "symptom-\(log.id.uuidString)",
                date: log.date,
                icon: symptomIcon(for: log.category),
                title: log.symptomName.isEmpty ? l.tr(zh: "异常症状", en: "Symptom", de: "Symptom") : log.symptomName,
                detail: severityTitle(log.severity),
                tint: log.severity == .severe || log.severity == .critical ? Color.goRed : Color.goOrange,
                filter: .symptom,
                source: .symptom(log)
            )
        }
        let heatItems = pet.heatCycleLogs.map { log in
            PetHealthArchiveItem(
                id: "heat-\(log.id.uuidString)",
                date: log.startDate,
                icon: "heart.text.square.fill",
                title: log.status.rawValue,
                detail: log.isMated ? l.tr(zh: "已交配", en: "Mated", de: "Gedeckt") : log.startDate.formatted(.dateTime.month().day()),
                tint: Color(hex: log.status.colorHex),
                filter: .heat,
                source: .heat(log)
            )
        }
        return (healthItems + symptomItems + heatItems)
            .filter { filter == .all || $0.filter == filter }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    filterBar
                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(items) { item in
                            archiveRow(item)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(l.tr(zh: "健康档案", en: "Health archive", de: "Gesundheitsakte"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(PetHealthArchiveFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text(filterTitle(option))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(filter == option ? Color.arkInk : .primary.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(filter == option ? accent : Color.primary.opacity(isDark ? 0.10 : 0.06), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 34, weight: .bold))
                .foregroundStyle(accent)
            Text(l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge"))
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .goIslandModuleCard(cornerRadius: 20)
    }

    private func archiveRow(_ item: PetHealthArchiveItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(item.tint.opacity(isDark ? 0.20 : 0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(item.detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(item.date.formatted(.dateTime.month().day()))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.tertiary)
                Button(role: .destructive) {
                    delete(item)
                } label: {
                    Image(systemName: deletingItemIDs.contains(item.id) ? "hourglass" : "trash")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(deletingItemIDs.contains(item.id))
            }
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: 18)
    }

    private func archiveDetail(for log: PetHealthLog) -> String {
        if !log.note.isEmpty { return log.note }
        if let expiration = log.expirationDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
            if days < 0 { return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen") }
            return days == 0
                ? l.tr(zh: "今天到期", en: "Due today", de: "Heute fällig")
                : l.tr(zh: "\(days) 天后到期", en: "Due in \(days)d", de: "In \(days)T fällig")
        }
        if log.cost > 0 { return AppCurrency.format(log.cost, fractionDigits: 0) }
        return log.date.formatted(.dateTime.year().month().day())
    }

    private func filterTitle(_ filter: PetHealthArchiveFilter) -> String {
        switch filter {
        case .all: return l.tr(zh: "全部", en: "All", de: "Alle")
        case .health: return l.tr(zh: "记录", en: "Records", de: "Einträge")
        case .symptom: return l.tr(zh: "异常", en: "Symptoms", de: "Symptome")
        case .heat: return l.tr(zh: "生理", en: "Heat", de: "Läufigkeit")
        }
    }

    private func healthIcon(for type: HealthLogType) -> String {
        switch type {
        case .general: return "clipboard.fill"
        case .vaccine: return "syringe.fill"
        case .medication: return "pill.fill"
        case .dewormingInternal: return "pills.fill"
        case .dewormingExternal: return "shield.lefthalf.filled"
        case .surgery: return "cross.case.fill"
        case .dental: return "mouth.fill"
        case .checkup: return "stethoscope"
        case .emergency: return "cross.circle.fill"
        case .other: return "doc.text.fill"
        }
    }

    private func healthTitle(for type: HealthLogType) -> String {
        switch type {
        case .general: return l.tr(zh: "常规记录", en: "General", de: "Allgemein")
        case .vaccine: return l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .medication: return l.tr(zh: "用药", en: "Medication", de: "Medikament")
        case .dewormingInternal: return l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: return l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .surgery: return l.tr(zh: "手术", en: "Surgery", de: "Operation")
        case .dental: return l.tr(zh: "牙科", en: "Dental", de: "Zahnmedizin")
        case .checkup: return l.tr(zh: "体检", en: "Checkup", de: "Check-up")
        case .emergency: return l.tr(zh: "急诊", en: "Emergency", de: "Notfall")
        case .other: return l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }

    private func symptomIcon(for category: SymptomCategory) -> String {
        switch category {
        case .digestive: return "stomach.fill"
        case .respiratory: return "lungs.fill"
        case .mobility: return "figure.walk"
        case .appetite: return "fork.knife"
        case .skin: return "bandage.fill"
        case .behavior: return "moon.zzz.fill"
        case .other: return "magnifyingglass"
        }
    }

    private func severityTitle(_ severity: SymptomSeverity) -> String {
        switch severity {
        case .mild: return l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case .moderate: return l.tr(zh: "中度", en: "Moderate", de: "Mittel")
        case .severe: return l.tr(zh: "严重", en: "Severe", de: "Schwer")
        case .critical: return l.tr(zh: "紧急", en: "Critical", de: "Kritisch")
        }
    }

    private func color(for type: HealthLogType) -> Color {
        switch type {
        case .vaccine: return accent
        case .dewormingInternal, .dewormingExternal, .medication: return Color.goTeal
        case .surgery, .emergency: return Color.goRed
        case .checkup: return Color.goYellow
        default: return Color.goBlue
        }
    }

    private func delete(_ item: PetHealthArchiveItem) {
        guard !deletingItemIDs.contains(item.id) else { return }
        deletingItemIDs.insert(item.id)
        let command = DomainCommand.petHealthDelete(
            petID: pet.id,
            kind: item.commandKind,
            recordID: item.recordID
        )

        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            let executor = PetHealthCommandExecutor(context: modelContext)
            switch item.source {
            case .health(let log):
                executor.deleteHealthLog(log, pet: pet, note: "pet.health.archive.delete.health")
            case .symptom(let log):
                executor.deleteSymptomLog(log, pet: pet, note: "pet.health.archive.delete.symptom")
            case .heat(let log):
                executor.deleteHeatCycleLog(log, pet: pet, note: "pet.health.archive.delete.heat")
            }
            deletingItemIDs.remove(item.id)
        }
    }
}
