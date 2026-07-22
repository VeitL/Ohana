import SwiftData
import SwiftUI

struct FamilyLongTermReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedRange: FamilyLongTermReviewRange = .year
    @State private var snapshot = FamilyLongTermReviewSnapshot.empty()
    @State private var loadTask: Task<Void, Never>?
    @State private var preparedCSV = "month,care_actions,memories"

    private var l: L10n { L10n(appLanguage) }
    private var hasPersonal: Bool { appServices.commerce.ohanaPlanLevel.hasPersonal }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    if hasPersonal {
                        rangeCard
                        metricCard
                        subjectComparisonCard
                    }
                    monthlyReviewCard
                    if snapshot.isTruncated {
                        truncatedNotice
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(l.tr(zh: "长期回顾", en: "Long-term review", de: "Langzeitrückblick"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("family-long-term-review-screen")
        .onAppear { scheduleLoad() }
        .onChange(of: selectedRange) { _, _ in scheduleLoad(force: true) }
        .onChange(of: appServices.commerce.hasPersonalEntitlement) { _, hasEntitlement in
            if !hasEntitlement, selectedRange != .year {
                selectedRange = .year
            } else {
                scheduleLoad(force: true)
            }
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleLoad(force: true)
        }
        .onChange(of: appLanguage) { prepareExport() }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "book.closed.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.goPrimary.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "陪伴留下的年轮", en: "The rings of your time together", de: "Die Jahresringe eurer gemeinsamen Zeit"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(hasPersonal
                        ? l.tr(zh: "长期数据、跨对象比较与导出", en: "Long-range data, comparison, and export", de: "Langzeitdaten, Vergleiche und Export")
                        : l.tr(zh: "按月份回看重要照护与回忆", en: "Review meaningful care and memories by month", de: "Wichtige Pflege und Erinnerungen monatlich ansehen"))
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if hasPersonal, snapshot.hasLoaded {
                ShareLink(item: preparedCSV) {
                    Label(l.tr(zh: "导出", en: "Export", de: "Exportieren"), systemImage: "square.and.arrow.up")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.goPrimary, in: Capsule())
                }
                .accessibilityIdentifier("family-long-term-review-export")
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "范围", en: "Range", de: "Zeitraum"))
                .font(OhanaFont.callout(.black))
            Picker(l.tr(zh: "范围", en: "Range", de: "Zeitraum"), selection: $selectedRange) {
                ForEach(FamilyLongTermReviewRange.allCases) { range in
                    Text(range.title(l: l)).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var metricCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "长期统计", en: "Long-range statistics", de: "Langzeitstatistik"), icon: "chart.xyaxis.line")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                metric(l.tr(zh: "照护操作", en: "Care actions", de: "Pflegeaktionen"), "\(snapshot.operationCount)", .goPrimary)
                metric(l.tr(zh: "活跃月份", en: "Active months", de: "Aktive Monate"), "\(snapshot.activeMonthCount)", .goTeal)
                metric(l.tr(zh: "回忆", en: "Memories", de: "Erinnerungen"), "\(snapshot.memoryCount)", .goYellow)
                metric(l.tr(zh: "体重记录", en: "Weight logs", de: "Gewichtseinträge"), "\(snapshot.weightRecordCount)", .goBlue)
                metric(l.tr(zh: "花费", en: "Expenses", de: "Ausgaben"), AppCurrency.format(snapshot.expenseTotal, fractionDigits: 0), .goOrange)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var subjectComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "对象比较", en: "Subject comparison", de: "Vergleich der Lebewesen"), icon: "person.2.fill")
            if snapshot.subjects.isEmpty {
                emptyText(l.tr(zh: "记录照护后会出现比较", en: "Comparison appears after care is logged", de: "Der Vergleich erscheint nach Pflegeeinträgen"))
            } else {
                ForEach(snapshot.subjects.prefix(8)) { subject in
                    HStack {
                        Text(subject.name)
                            .font(OhanaFont.callout(.bold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(subject.operationCount)")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.goPrimary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var monthlyReviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "月度年轮", en: "Monthly rings", de: "Monatliche Jahresringe"), icon: "calendar")
            if !snapshot.hasLoaded {
                ProgressView()
                    .tint(Color.goPrimary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if snapshot.months.isEmpty {
                emptyText(l.tr(zh: "还没有可以回顾的照护或照片", en: "No care or photos to review yet", de: "Noch keine Pflege oder Fotos für einen Rückblick"))
            } else {
                ForEach(snapshot.months) { month in
                    monthRow(month)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private func monthRow(_ month: FamilyLongTermReviewMonth) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: month.highlightKind?.reviewIcon ?? "photo.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow non-interactive timeline glyph
                .background(Color.goPrimary.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(month.monthStart.formatted(.dateTime.year().month(.wide)))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(monthHighlight(month))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if hasPersonal {
                    Text(l.tr(
                        zh: "\(month.operationCount) 次照护 · \(month.memoryCount) 个回忆",
                        en: "\(month.operationCount) care actions · \(month.memoryCount) memories",
                        de: "\(month.operationCount) Pflegeaktionen · \(month.memoryCount) Erinnerungen"
                    ))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var truncatedNotice: some View {
        Label(
            l.tr(
                zh: "数据很多，本页展示最近的代表记录；原始历史仍完整保留。",
                en: "There is a lot of data, so this page shows recent representative records. Raw history remains intact.",
                de: "Bei vielen Daten zeigt diese Seite aktuelle repräsentative Einträge. Die Rohhistorie bleibt vollständig erhalten."
            ),
            systemImage: "info.circle.fill"
        )
        .font(OhanaFont.callout(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private func monthHighlight(_ month: FamilyLongTermReviewMonth) -> String {
        if let kind = month.highlightKind {
            let subject = month.highlightSubjectName.isEmpty
                ? l.tr(zh: "家里", en: "Your household", de: "Euer Haushalt")
                : month.highlightSubjectName
            return l.tr(
                zh: "\(subject) 留下了\(kind.reviewTitle(l: l))记录",
                en: "\(subject) left a \(kind.reviewTitle(l: l).lowercased()) record",
                de: "Für \(subject) wurde \(kind.reviewTitle(l: l)) festgehalten"
            )
        }
        return l.tr(zh: "留下了照片回忆", en: "Photo memories were saved", de: "Fotoerinnerungen wurden gespeichert")
    }

    private func prepareExport() {
        var lines = ["month,care_actions,memories"]
        let formatter = ISO8601DateFormatter()
        lines.append(contentsOf: snapshot.months.reversed().map {
            "\(formatter.string(from: $0.monthStart)),\($0.operationCount),\($0.memoryCount)"
        })
        preparedCSV = lines.joined(separator: "\n")
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(OhanaFont.title3(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
    }

    private func metric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private func scheduleLoad(force: Bool = false) {
        guard force || !snapshot.hasLoaded else { return }
        loadTask?.cancel()
        // Free keeps the complete month-by-month review. Personal adds range
        // controls, statistics, comparison, and export on top of that history.
        let requestedRange = hasPersonal ? selectedRange : .all
        let container = modelContext.container
        loadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 80)
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await FamilyLongTermReviewDataActor(modelContainer: container)
                    .load(range: requestedRange)
                prepareExport()
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Family long-term review snapshot load failed: \(error.localizedDescription)",
                    category: "FamilyReports"
                )
            }
            loadTask = nil
        }
    }
}

private extension FamilyLongTermReviewRange {
    func title(l: L10n) -> String {
        switch self {
        case .days90: l.tr(zh: "90天", en: "90D", de: "90T")
        case .year: l.tr(zh: "1年", en: "1Y", de: "1J")
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }
}

private extension CareLedgerEventKind {
    func reviewTitle(l: L10n) -> String {
        switch self {
        case .care: l.tr(zh: "照护", en: "Care", de: "Pflege")
        case .potty: l.tr(zh: "如厕", en: "Potty", de: "Toilette")
        case .walk: l.tr(zh: "散步", en: "Walk", de: "Spaziergang")
        case .hygiene: l.tr(zh: "清洁", en: "Hygiene", de: "Hygiene")
        case .health: l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .weight: l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .medication: l.tr(zh: "用药", en: "Medication", de: "Medikamente")
        case .workout: l.tr(zh: "运动", en: "Workout", de: "Training")
        case .expense: l.tr(zh: "花费", en: "Expense", de: "Ausgabe")
        case .reminder: l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung")
        case .plantCare: l.tr(zh: "植物照护", en: "Plant care", de: "Pflanzenpflege")
        case .coconut: l.tr(zh: "椰子", en: "Coconut", de: "Kokosnuss")
        case .milestone: l.tr(zh: "里程碑", en: "Milestone", de: "Meilenstein")
        case .unknown: l.tr(zh: "生活", en: "Life", de: "Alltag")
        }
    }

    var reviewIcon: String {
        switch self {
        case .weight: "scalemass.fill"
        case .expense: "creditcard.fill"
        case .health, .medication: "heart.text.square.fill"
        case .walk, .workout: "figure.walk"
        case .plantCare: "leaf.fill"
        case .milestone: "flag.fill"
        default: "sparkles"
        }
    }
}
