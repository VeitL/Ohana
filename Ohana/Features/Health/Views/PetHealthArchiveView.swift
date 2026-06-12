import SwiftData
import SwiftUI

enum PetHealthArchiveFilter: String, CaseIterable {
    case all = "全部"
    case health = "记录"
    case symptom = "异常"
    case heat = "生理"
}

struct PetHealthArchiveItem: Identifiable {
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
        case let .health(log):
            log.id
        case let .symptom(log):
            log.id
        case let .heat(log):
            log.id
        }
    }

    var commandKind: String {
        switch source {
        case .health:
            "health"
        case .symptom:
            "symptom"
        case .heat:
            "heat"
        }
    }
}

struct PetHealthArchiveView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var filter: PetHealthArchiveFilter = .all
    @State private var deletingItemIDs: Set<String> = []
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { isDark ? Color.goPrimary : Color(hex: pet.themeColorHex) }
    private var l: L10n { L10n(appLanguage) }

    private var items: [PetHealthArchiveItem] {
        let healthItems = pet.activeHealthLogs.map { log in
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
        let symptomItems = pet.activeSymptomLogs.map { log in
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
        let heatItems = pet.activeHeatCycleLogs.map { log in
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
        .goIslandModuleCard(cornerRadius: OhanaRadius.input)
    }

    private func archiveRow(_ item: PetHealthArchiveItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(item.tint)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
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
        .goIslandModuleCard(cornerRadius: OhanaRadius.controlLarge)
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
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        case .health: l.tr(zh: "记录", en: "Records", de: "Einträge")
        case .symptom: l.tr(zh: "异常", en: "Symptoms", de: "Symptome")
        case .heat: l.tr(zh: "生理", en: "Heat", de: "Läufigkeit")
        }
    }

    private func healthIcon(for type: HealthLogType) -> String {
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

    private func healthTitle(for type: HealthLogType) -> String {
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

    private func symptomIcon(for category: SymptomCategory) -> String {
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

    private func severityTitle(_ severity: SymptomSeverity) -> String {
        switch severity {
        case .mild: l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case .moderate: l.tr(zh: "中度", en: "Moderate", de: "Mittel")
        case .severe: l.tr(zh: "严重", en: "Severe", de: "Schwer")
        case .critical: l.tr(zh: "紧急", en: "Critical", de: "Kritisch")
        }
    }

    private func color(for type: HealthLogType) -> Color {
        switch type {
        case .vaccine: accent
        case .dewormingInternal, .dewormingExternal, .medication: Color.goTeal
        case .surgery, .emergency: Color.goRed
        case .checkup: Color.goYellow
        default: Color.goBlue
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
            let executor = PetHealthCommandExecutor(context: modelContext, services: appServices)
            switch item.source {
            case let .health(log):
                executor.deleteHealthLog(log, pet: pet, note: "pet.health.archive.delete.health")
            case let .symptom(log):
                executor.deleteSymptomLog(log, pet: pet, note: "pet.health.archive.delete.symptom")
            case let .heat(log):
                executor.deleteHeatCycleLog(log, pet: pet, note: "pet.health.archive.delete.heat")
            }
            deletingItemIDs.remove(item.id)
        }
    }
}
