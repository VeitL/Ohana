//
//  PetWeightDashboardContent.swift
//  Ohana
//
//  Dashboard content split from WeightExpenseDashboardComponents.
//

import SwiftData
import SwiftUI
import UIKit

struct PetWeightLedgerEntry: Identifiable, Hashable {
    let id: UUID
    let legacyLogId: UUID?
    let date: Date
    let weightKilograms: Double

    static func entries(
        from events: [CareLedgerEvent],
        legacyLogs: [PetWeightLog] = [],
        petId: UUID
    ) -> [PetWeightLedgerEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let weightKind = CareLedgerEventKind.weight.rawValue
        let petWeightAction = "petWeight"
        let petIdString = petId.uuidString
        let ledgerEntries: [PetWeightLedgerEntry] = events.compactMap { event -> PetWeightLedgerEntry? in
            guard event.subjectKind == petSubject,
                  event.subjectId == petIdString,
                  event.eventKind == weightKind,
                  event.actionType == petWeightAction,
                  event.amountValue > 0 else { return nil }

            let legacyLogId = event.legacyModelName == "PetWeightLog"
                ? event.legacyModelId.flatMap(UUID.init(uuidString:))
                : nil
            return PetWeightLedgerEntry(
                id: event.id,
                legacyLogId: legacyLogId,
                date: event.occurredAt,
                weightKilograms: event.amountValue
            )
        }
        let projectedLogIDs: Set<UUID> = Set(ledgerEntries.compactMap(\.legacyLogId))
        // Legacy logs remain the durable fact for records created before the
        // quick-entry route started emitting its matching ledger projection.
        let orphanLogEntries = legacyLogs.compactMap { log -> PetWeightLedgerEntry? in
            guard log.pet?.id == petId,
                  log.weightInKg > 0,
                  !projectedLogIDs.contains(log.id) else { return nil }
            return PetWeightLedgerEntry(
                id: log.id,
                legacyLogId: log.id,
                date: log.date,
                weightKilograms: log.weightInKg
            )
        }
        return (ledgerEntries + orphanLogEntries).sorted { lhs, rhs in
            lhs.date > rhs.date
        }
    }
}

struct PetWeightDashboardContent: View {
    let pet: Pet
    var showsCloseButton = true
    var onClose: () -> Void
    var onAdd: () -> Void
    var onRemove: (() -> Void)?
    let weightLedgerEvents: [CareLedgerEvent]
    let legacyWeightDeleteLogs: [PetWeightLog]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var selectedRange: WeightRange = .days30
    @State private var showingPersonalPlan = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    enum WeightRange: Hashable, CaseIterable {
        case days7, days30, days90, all

        var requiresPersonal: Bool {
            self == .days90 || self == .all
        }

        func title(_ l: L10n) -> String {
            switch self {
            case .days7: l.tr(zh: "7天", en: "7D", de: "7T")
            case .days30: l.tr(zh: "30天", en: "30D", de: "30T")
            case .days90: l.tr(zh: "90天", en: "90D", de: "90T")
            case .all: l.tr(zh: "全部", en: "All", de: "Alle")
            }
        }

        func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
            switch self {
            case .days7: calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
            case .days30: calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
            case .days90: calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
            case .all: nil
            }
        }

        func xDomain(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
            guard let start = startDate(now: now, calendar: calendar) else { return nil }
            return start ... now
        }
    }

    init(
        pet: Pet,
        showsCloseButton: Bool = true,
        weightLedgerEvents: [CareLedgerEvent] = [],
        legacyWeightDeleteLogs: [PetWeightLog] = [],
        onClose: @escaping () -> Void,
        onAdd: @escaping () -> Void,
        onRemove: (() -> Void)? = nil
    ) {
        self.pet = pet
        self.showsCloseButton = showsCloseButton
        self.weightLedgerEvents = weightLedgerEvents
        self.legacyWeightDeleteLogs = legacyWeightDeleteLogs
        self.onClose = onClose
        self.onAdd = onAdd
        self.onRemove = onRemove
    }

    private var l: L10n { L10n(appLanguage) }
    private var entries: [PetWeightLedgerEntry] {
        PetWeightLedgerEntry.entries(
            from: weightLedgerEvents,
            legacyLogs: legacyWeightDeleteLogs,
            petId: pet.id
        )
    }

    private func trendPoints(now: Date = Date()) -> [WeightTrendPoint] {
        WeightTrendDataBuilder.points(
            from: entries.map { (date: $0.date, kilograms: $0.weightKilograms) },
            rangeStart: selectedRange.startDate(now: now),
            rangeEnd: now
        )
    }

    var body: some View {
        OhanaSheetPageScaffold(
            title: l.tr(zh: "体重趋势", en: "Weight Trend", de: "Gewicht"),
            subtitle: pet.name,
            showsCloseButton: showsCloseButton,
            onClose: onClose,
            leading: {
                FeatureHubAvatar(
                    imageCacheID: "pet-weight-dashboard-\(pet.id.uuidString)",
                    imageSignature: pet.avatarThumbnailSignature,
                    petModelID: pet.persistentModelID,
                    emoji: pet.avatarEmoji,
                    fallback: pet.speciesEmoji,
                    tint: Color(hex: pet.safeThemeColorHex)
                )
            },
            trailing: { EmptyView() },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    metrics
                    chartBlock
                    historyBlock
                }
            },
            floating: {
                addButton
            }
        )
        .sheet(isPresented: $showingPersonalPlan) {
            PersonalPlanView()
                .ohanaSheetPagePresentation()
        }
        .onChange(of: appServices.commerce.hasPersonalEntitlement) { _, _ in
            if selectedRange.requiresPersonal, !appServices.commerce.allows(.extendedTrends) {
                selectedRange = .days30
            }
        }
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(
                id: "latest",
                title: l.tr(zh: "当前", en: "Current", de: "Aktuell"),
                value: latestWeightText
            ),
            FeatureHubMetric(
                id: "change",
                title: l.tr(zh: "变化", en: "Change", de: "Änderung"),
                value: weightDeltaText
            ),
            FeatureHubMetric(
                id: "count",
                title: l.tr(zh: "记录", en: "Logs", de: "Einträge"),
                value: "\(entries.count)"
            )
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "趋势", en: "Trend", de: "Trend"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(
                    ranges: WeightRange.allCases,
                    selection: personalRangeSelection,
                    isLocked: { $0.requiresPersonal && !appServices.commerce.allows(.extendedTrends) }
                ) {
                    $0.title(l)
                }
            }

            let now = Date()
            let points = trendPoints(now: now)
            if !points.isEmpty {
                UnifiedWeightTrendChart(points: points, xDomain: selectedRange.xDomain(now: now), accent: .goPrimary)
                    .frame(height: 190)
            } else {
                emptyState(
                    icon: "chart.xyaxis.line",
                    text: l.tr(zh: "记录 2 次后显示趋势", en: "Add 2 logs to show a trend", de: "2 Einträge zeigen einen Trend")
                )
            }
        }
    }

    private var personalRangeSelection: Binding<WeightRange> {
        Binding(
            get: { selectedRange },
            set: { range in
                guard !range.requiresPersonal || appServices.commerce.allows(.extendedTrends) else {
                    showingPersonalPlan = true
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                selectedRange = range
            }
        )
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if entries.isEmpty {
                emptyState(
                    icon: "scalemass.fill",
                    text: l.tr(zh: "还没有体重记录", en: "No weight logs yet", de: "Noch keine Gewichtseinträge")
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(entries) { entry in
                        weightRow(entry)
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加体重", en: "Add weight", de: "Gewicht hinzufügen"))
    }

    private var latestWeightText: String {
        guard let latest = entries.first else { return "—" }
        return AppMeasurementSystem.formatWeightKilograms(latest.weightKilograms)
    }

    private var weightDeltaText: String {
        guard let latest = entries.first, let previous = entries.dropFirst().first else { return "—" }
        let delta = latest.weightKilograms - previous.weightKilograms
        return formatWeightDelta(delta)
    }

    private func weightRow(_ entry: PetWeightLedgerEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "scalemass.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(AppMeasurementSystem.formatWeightKilograms(entry.weightKilograms))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if let legacyLogId = entry.legacyLogId {
                Button {
                    commandQueue.enqueue(
                        .weightDelete(entityID: pet.id, entityKind: EntityKind.pet.rawValue, recordID: legacyLogId)
                    ) {
                        guard let log = legacyWeightDeleteLogs.first(where: { $0.id == legacyLogId }) else { return }
                        do {
                            try DashboardRecordCommandExecutor(context: modelContext, services: appServices).deletePetWeight(
                                log,
                                pet: pet,
                                note: "dashboard.weight.delete.\(EntityKind.pet.rawValue)"
                            )
                        } catch {
                            appServices.domainRevisions.publishFailure(
                                command: .weightDelete(
                                    entityID: pet.id,
                                    entityKind: EntityKind.pet.rawValue,
                                    recordID: legacyLogId
                                ),
                                error: error
                            )
                        }
                    }
                } label: {
                    Image(systemName: "trash").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func formatWeightDelta(_ kilograms: Double) -> String {
        let converted = AppMeasurementSystem.code == "imperial" ? kilograms * 2.2046226218 : kilograms
        let unit = AppMeasurementSystem.code == "imperial" ? "lb" : "kg"
        return String(format: "%+.1f %@", converted, unit)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }
}
