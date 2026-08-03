//
//  HumanHealthReportView.swift
//  Ohana
//
//  身体检测报告列表 + 添加/编辑

import SwiftData
import SwiftUI
import UIKit

private struct HumanHealthReportEditorDraft: Equatable {
    let reportType: HealthReportType
    let conclusion: ReportConclusion
    let hospitalName: String
    let doctorName: String
    let reportDate: Date
    let hasNextCheck: Bool
    let nextCheckDate: Date
    let summary: String
    let notes: String
    let selectedRecorderID: UUID?
}

private enum HumanHealthReportSheetDestination: Identifiable {
    case create
    case labReportImport
    case personalUpgrade

    var id: String {
        switch self {
        case .create: "create"
        case .labReportImport: "lab-report-import"
        case .personalUpgrade: "personal-upgrade"
        }
    }
}

// MARK: - Main View

struct HumanHealthReportContentView: View {
    let human: Human
    let myReports: [HumanHealthReport]
    let hasMoreReports: Bool
    let isLoadingOlderReports: Bool
    let olderPageLoadFailed: Bool
    let refreshFailed: Bool
    let onRetryLoad: () -> Void
    let onLoadOlderReports: () -> Void

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(AppServices.self) private var appServices

    @State private var sheetDestination: HumanHealthReportSheetDestination?

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var isReadOnly: Bool { human.hasPassedAway }
    private var l: L10n { L10n(appLanguage) }

    init(
        human: Human,
        myReports: [HumanHealthReport],
        hasMoreReports: Bool,
        isLoadingOlderReports: Bool,
        olderPageLoadFailed: Bool,
        refreshFailed: Bool,
        onRetryLoad: @escaping () -> Void,
        onLoadOlderReports: @escaping () -> Void
    ) {
        self.human = human
        self.myReports = myReports
        self.hasMoreReports = hasMoreReports
        self.isLoadingOlderReports = isLoadingOlderReports
        self.olderPageLoadFailed = olderPageLoadFailed
        self.refreshFailed = refreshFailed
        self.onRetryLoad = onRetryLoad
        self.onLoadOlderReports = onLoadOlderReports
    }

    private var upcomingCheckCount: Int {
        latestReportsByType.count(where: {
            if let days = $0.daysUntilNextCheck { return days >= 0 && days <= 30 }
            return false
        })
    }

    private var latestReportsByType: [HumanHealthReport] {
        var seenTypes = Set<String>()
        return myReports.filter { report in
            let type = report.reportTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            return seenTypes.insert(type.isEmpty ? "__other__" : type).inserted
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if refreshFailed {
                            refreshFailureNotice
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }

                        summaryBento
                            .padding(.horizontal, 16)
                            .padding(.top, refreshFailed ? 0 : 16)

                        HumanPrivateDataNotice(human: human, field: .weight)
                            .padding(.horizontal, 16)

                        if !isReadOnly {
                            labReportImportEntry
                                .padding(.horizontal, 16)
                        }

                        if isReadOnly {
                            memorialReadOnlyNotice
                                .padding(.horizontal, 16)
                        }

                        if !myReports.isEmpty {
                            sectionLabel(l.tr(zh: "检测报告", en: "Health Reports", de: "Gesundheitsberichte"))
                            ForEach(myReports) { report in
                                reportRow(report)
                                    .padding(.horizontal, 16)
                            }
                            if hasMoreReports || olderPageLoadFailed {
                                olderReportsControl
                                    .padding(.horizontal, 16)
                            }
                        }

                        if myReports.isEmpty {
                            emptyState
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 100)
                    }
                }
            }

            // FAB
            if !isPrivacyLocked && !isReadOnly {
                Button { sheetDestination = .create } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").accessibilityHidden(true)
                            .font(OhanaFont.headline(.black))
                        Text(l.tr(zh: "添加报告", en: "Add Report", de: "Bericht hinzufügen"))
                            .font(OhanaFont.headline(.black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.goTeal, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-health-report-add-action")
                .padding(.bottom, 28)
            }
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .create:
                AddHumanHealthReportSheet(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow complex report editor uses full-height system sheet
            case .labReportImport:
                HumanLabResultImportView(human: human)
                    .ohanaSheetPagePresentation()
            case .personalUpgrade:
                PersonalPlanView(prompt: PersonalUpgradePrompt(feature: .documentScanning))
                    .ohanaSheetPagePresentation()
            }
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                sheetDestination = nil
            }
        }
    }

    private var privacyLockedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill").accessibilityHidden(true)
                .font(OhanaFont.metric(size: 44))
                .foregroundStyle(Color.goYellow)
            Text(l.tr(zh: "身体数据仅本人可见", en: "Health data is private", de: "Gesundheitsdaten sind privat"))
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this profile to view it.", de: "Wechsle zu diesem Profil, um es zu sehen."))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var refreshFailureNotice: some View {
        humanReportSurface {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goOrange)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 5) {
                    Text(l.tr(
                        zh: "刷新失败，已保留上次内容",
                        en: "Refresh failed; previous content kept",
                        de: "Aktualisierung fehlgeschlagen; vorherige Inhalte bleiben erhalten"
                    ))
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "当前报告来自上一次成功读取。你可以再次尝试刷新。",
                        en: "These reports are from the last successful load. You can try refreshing again.",
                        de: "Diese Berichte stammen aus dem letzten erfolgreichen Laden. Du kannst die Aktualisierung erneut versuchen."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: onRetryLoad) {
                    Image(systemName: "arrow.clockwise").accessibilityHidden(true)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.goTeal)
                .accessibilityLabel(l.tr(zh: "重试刷新", en: "Retry refresh", de: "Aktualisierung erneut versuchen"))
                .accessibilityIdentifier("human-health-report-refresh-retry-action")
            }
            .padding(14)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("human-health-report-refresh-failed-notice")
    }

    private var memorialReadOnlyNotice: some View {
        humanReportSurface {
            Label {
                Text(l.tr(
                    zh: "纪念档案为只读模式，既有检测报告会保留，但不能新增、编辑或删除。",
                    en: "Memorial profiles are read-only. Existing reports remain visible but cannot be added, edited, or deleted.",
                    de: "Gedenkprofile sind schreibgeschützt. Vorhandene Berichte bleiben sichtbar, können aber nicht hinzugefügt, bearbeitet oder gelöscht werden."
                ))
                .font(OhanaFont.callout(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goYellow)
            }
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(14)
        }
        .accessibilityIdentifier("human-health-report-memorial-read-only-notice")
    }

    // MARK: - Summary Bento

    private var summaryBento: some View {
        humanReportSurface {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    bentoStat(
                        icon: "doc.text.fill",
                        label: hasMoreReports
                            ? l.tr(zh: "最近报告", en: "Recent", de: "Neueste")
                            : l.tr(zh: "报告总数", en: "Reports", de: "Berichte"),
                        value: boundedCountValue(myReports.count),
                        color: Color.goTeal
                    )
                    divider
                    bentoStat(icon: "exclamationmark.triangle.fill", label: l.tr(zh: "异常报告", en: "Abnormal", de: "Auffällig"), value: boundedCountValue(abnormalCount), color: Color.goOrange)
                    divider
                    bentoStat(icon: "calendar.badge.clock", label: l.tr(zh: "近期复查", en: "Follow-ups", de: "Kontrollen"), value: boundedCountValue(upcomingCheckCount), color: Color.goYellow)
                }

                if hasMoreReports {
                    Text(l.tr(
                        zh: "仍有更早报告未载入；统计仅为当前已载入记录的下界。可在列表底部继续加载。",
                        en: "Older reports remain unloaded; counts are lower bounds for loaded records. Load more at the end of the list.",
                        de: "Ältere Berichte sind noch nicht geladen; die Zahlen sind Untergrenzen der geladenen Einträge. Am Listenende können weitere geladen werden."
                    ))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }

    private var abnormalCount: Int {
        myReports.count(where: { $0.conclusion == .abnormal || $0.conclusion == .critical })
    }

    private func boundedCountValue(_ count: Int) -> String {
        guard hasMoreReports else { return "\(count)" }
        return count > 0 ? "\(count)+" : l.tr(zh: "未完整", en: "Partial", de: "Teilw.")
    }

    private var olderReportsControl: some View {
        Button(action: onLoadOlderReports) {
            HStack(spacing: 10) {
                if isLoadingOlderReports {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: olderPageLoadFailed ? "arrow.clockwise" : "clock.arrow.circlepath")
                        .accessibilityHidden(true)
                }
                Text(olderPageLoadFailed
                    ? l.tr(zh: "重试载入更早报告", en: "Retry older reports", de: "Ältere Berichte erneut laden")
                    : l.tr(zh: "载入更早报告", en: "Load older reports", de: "Ältere Berichte laden"))
                    .font(OhanaFont.callout(.bold))
                Spacer(minLength: 0)
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 14)
            .foregroundStyle(olderPageLoadFailed ? Color.goOrange : Color.goPrimary)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoadingOlderReports || !hasMoreReports)
        .accessibilityIdentifier("human-health-report-load-older-action")
    }

    private var divider: some View {
        Rectangle().fill(Color.ohanaDivider).frame(width: 1, height: 40) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
    }

    private func bentoStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(OhanaFont.title3(.bold)).foregroundStyle(color)
            Text(value).font(OhanaFont.metric(size: 24)).foregroundStyle(Color.ohanaPrimaryText)
            Text(label).font(OhanaFont.caption()).foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Report Row

    private func reportRow(_ report: HumanHealthReport) -> some View {
        NavigationLink {
            HumanHealthReportDetailView(human: human, report: report)
        } label: {
            reportRowContent(report)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(reportRowAccessibilityLabel(report))
        .accessibilityHint(l.tr(
            zh: "打开只读详情",
            en: "Opens read-only details",
            de: "Öffnet die schreibgeschützten Details"
        ))
        .accessibilityIdentifier("human-health-report-row")
    }

    private func reportRowContent(_ report: HumanHealthReport) -> some View {
        humanReportSurface {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(report.conclusion.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: report.reportType.systemImage)
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(report.conclusion.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(report.reportType.emoji + " " + report.reportType.localizedTitle(l))
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(report.conclusion.localizedTitle(l))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(report.conclusion.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(report.conclusion.color.opacity(0.15), in: Capsule())
                    }

                    HStack(spacing: 6) {
                        if !report.hospitalName.isEmpty {
                            Text(report.hospitalName)
                                .font(OhanaFont.caption())
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Text(report.reportDate, style: .date)
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }

                    if !report.summary.isEmpty {
                        Text(report.summary)
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                    }

                    if let days = report.daysUntilNextCheck {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock").accessibilityHidden(true)
                                .font(OhanaFont.caption2())
                                .foregroundStyle(Color.ohanaTertiaryText)
                            Text(nextCheckText(days))
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(days <= 7 ? Color.goOrange : Color.ohanaSecondaryText)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(14)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        humanReportSurface {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.goTeal.opacity(0.12)).frame(width: 72, height: 72)
                    Image(systemName: "stethoscope").accessibilityHidden(true).font(OhanaFont.adaptive(size: 32)).foregroundStyle(Color.goTeal)
                }
                Text(l.tr(zh: "还没有检测报告", en: "No health reports yet", de: "Noch keine Gesundheitsberichte")).font(OhanaFont.title3(.bold)).foregroundStyle(Color.ohanaPrimaryText)
                Text(isReadOnly
                    ? l.tr(
                        zh: "这个纪念档案中没有已保存的检测报告。",
                        en: "No saved health reports are available in this memorial profile.",
                        de: "In diesem Gedenkprofil sind keine Gesundheitsberichte gespeichert."
                    )
                    : HumanLabScanCopy.text(.reportEmptyStateDetail, l: l))
                    .font(OhanaFont.callout())
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .textCase(.uppercase)
            .tracking(1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    private func nextCheckText(_ days: Int) -> String {
        if days > 0 {
            return l.tr(zh: "距复查还有 \(days) 天", en: "\(days) days until follow-up", de: "Noch \(days) Tage bis zur Kontrolle")
        }
        if days == 0 {
            return l.tr(zh: "今天复查", en: "Follow-up today", de: "Kontrolle heute")
        }
        return l.tr(zh: "已逾期 \(-days) 天", en: "\(-days) days overdue", de: "\(-days) Tage überfällig")
    }

    private var labReportImportEntry: some View {
        Button {
            sheetDestination = appServices.commerce.allows(.documentScanning)
                ? .labReportImport
                : .personalUpgrade
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.viewfinder.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(HumanLabScanCopy.text(.scanLabReport, l: l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(HumanLabScanCopy.text(.reportEntryDetail, l: l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.goTeal.opacity(0.32), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(HumanLabScanCopy.text(.entryAccessibility, l: l))
        .accessibilityIdentifier("human-health-report-lab-import-action")
    }

    private func reportRowAccessibilityLabel(_ report: HumanHealthReport) -> String {
        let date = report.reportDate.formatted(date: .abbreviated, time: .omitted)
        return l.tr(
            zh: "\(report.reportType.localizedTitle(l))，\(report.conclusion.localizedTitle(l))，\(date)",
            en: "\(report.reportType.localizedTitle(l)), \(report.conclusion.localizedTitle(l)), \(date)",
            de: "\(report.reportType.localizedTitle(l)), \(report.conclusion.localizedTitle(l)), \(date)"
        )
    }

    private func humanReportSurface(@ViewBuilder content: () -> some View) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

// MARK: - Read-only Detail

struct HumanHealthReportDetailView: View {
    let human: Human
    let report: HumanHealthReport

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var showingEditor = false
    @State private var wasDeleted = false

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanID: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanID) }
    private var isReadOnly: Bool { human.hasPassedAway }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            if wasDeleted {
                ProgressView()
                    .tint(Color.goTeal)
                    .accessibilityLabel(l.tr(
                        zh: "报告已删除，正在返回",
                        en: "Report deleted, returning",
                        de: "Bericht gelöscht, zurück zur Übersicht"
                    ))
            } else if isPrivacyLocked {
                HumanModulePrivacyLockedView(
                    title: l.tr(zh: "身体数据仅本人可见", en: "Health data is private", de: "Gesundheitsdaten sind privat"),
                    message: l.tr(zh: "请切换到本人档案后再查看报告详情。", en: "Switch to this profile to view report details.", de: "Wechsle zu diesem Profil, um die Berichtdetails zu sehen.")
                )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        detailHero
                        visitDetails
                        if report.captureSource == .documentScan {
                            HumanHealthReportLinkedMetricsView(
                                humanID: human.id,
                                reportID: report.id
                            )
                        }
                        followUpCard
                        if !report.summary.isEmpty {
                            textCard(
                                title: l.tr(zh: "检测摘要", en: "Summary", de: "Zusammenfassung"),
                                text: report.summary,
                                icon: "text.alignleft"
                            )
                        }
                        if !report.notes.isEmpty {
                            textCard(
                                title: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                                text: report.notes,
                                icon: "note.text"
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(l.tr(zh: "报告详情", en: "Report Details", de: "Berichtdetails"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReadOnly && !isPrivacyLocked && !wasDeleted {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten")) {
                        showingEditor = true
                    }
                    .font(OhanaFont.callout(.bold))
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint(l.tr(
                        zh: "打开报告编辑表单",
                        en: "Opens the report editor",
                        de: "Öffnet den Berichtseditor"
                    ))
                    .accessibilityIdentifier("human-health-report-detail-edit-action")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            AddHumanHealthReportSheet(
                human: human,
                editing: report,
                onDeleted: {
                    wasDeleted = true
                }
            )
            .ohanaSheetPagePresentation()
        }
        .onChange(of: wasDeleted) { _, deleted in
            guard deleted else { return }
            Task { @MainActor in
                await Task.yield()
                dismiss()
            }
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                showingEditor = false
            }
        }
        .accessibilityIdentifier("human-health-report-detail")
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: report.reportType.systemImage).accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 21, weight: .black))
                    .foregroundStyle(report.conclusion.color)
                    .frame(width: 52, height: 52)
                    .background(report.conclusion.color.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.reportType.emoji + " " + report.reportType.localizedTitle(l))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(report.conclusion.localizedTitle(l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(report.conclusion.color)
                }
                Spacer(minLength: 0)
            }

            Label(
                report.captureSource == .documentScan
                    ? l.tr(zh: "由本机化验单识别导入", en: "Imported with on-device lab recognition", de: "Mit lokaler Laborbericht-Erkennung importiert")
                    : l.tr(zh: "手动录入", en: "Entered manually", de: "Manuell erfasst"),
                systemImage: report.captureSource == .documentScan ? "doc.viewfinder" : "square.and.pencil"
            )
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var visitDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailRow(
                label: l.tr(zh: "检测日期", en: "Report Date", de: "Berichtsdatum"),
                value: report.reportDate.formatted(date: .long, time: .omitted),
                icon: "calendar"
            )
            if !report.hospitalName.isEmpty {
                Divider().padding(.leading, 42)
                detailRow(
                    label: l.tr(zh: "医院", en: "Hospital", de: "Klinik"),
                    value: report.hospitalName,
                    icon: "building.2"
                )
            }
            if !report.doctorName.isEmpty {
                Divider().padding(.leading, 42)
                detailRow(
                    label: l.tr(zh: "医生", en: "Doctor", de: "Ärztin/Arzt"),
                    value: report.doctorName,
                    icon: "person.fill"
                )
            }
        }
        .padding(.horizontal, 14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var followUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(l.tr(zh: "复查计划", en: "Follow-up", de: "Kontrolle"), systemImage: "calendar.badge.clock")
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if let nextCheckDate = report.nextCheckDate {
                Text(nextCheckDate, format: .dateTime.year().month().day())
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(followUpColor)
                Text(followUpStatusText)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                Text(l.tr(zh: "尚未设置复查日期", en: "No follow-up date set", de: "Kein Kontrolldatum festgelegt"))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if !isReadOnly {
                Button {
                    showingEditor = true
                } label: {
                    Label(
                        report.nextCheckDate == nil
                            ? l.tr(zh: "设置复查日期", en: "Set Follow-up Date", de: "Kontrolldatum festlegen")
                            : l.tr(zh: "调整复查日期", en: "Adjust Follow-up Date", de: "Kontrolldatum ändern"),
                        systemImage: "calendar.badge.plus"
                    )
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.goYellow, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityHint(l.tr(
                    zh: "在编辑表单中更新复查日期",
                    en: "Updates the follow-up date in the editor",
                    de: "Aktualisiert das Kontrolldatum im Editor"
                ))
                .accessibilityIdentifier("human-health-report-follow-up-action")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var followUpColor: Color {
        guard let days = report.daysUntilNextCheck else { return Color.ohanaPrimaryText }
        return days <= 7 ? Color.goOrange : Color.ohanaPrimaryText
    }

    private var followUpStatusText: String {
        guard let days = report.daysUntilNextCheck else { return "" }
        if days > 0 {
            return l.tr(zh: "距复查还有 \(days) 天", en: "\(days) days until follow-up", de: "Noch \(days) Tage bis zur Kontrolle")
        }
        if days == 0 {
            return l.tr(zh: "今天需要复查", en: "Follow-up is due today", de: "Kontrolle ist heute fällig")
        }
        return l.tr(zh: "已逾期 \(-days) 天", en: "\(-days) days overdue", de: "\(-days) Tage überfällig")
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).accessibilityHidden(true)
                .foregroundStyle(Color.goTeal)
                .frame(width: 30, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                Text(value)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private func textCard(title: String, text: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(text)
                .font(OhanaFont.body())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add / Edit Sheet

struct AddHumanHealthReportSheet: View {
    let human: Human
    var editing: HumanHealthReport?
    var onDeleted: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var reportType: HealthReportType = .physical
    @State private var conclusion: ReportConclusion = .normal
    @State private var hospitalName = ""
    @State private var doctorName = ""
    @State private var reportDate = Date()
    @State private var hasNextCheck = false
    @State private var nextCheckDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var summary = ""
    @State private var notes = ""
    @State private var selectedRecorderID: UUID?
    @State private var requiresRecorderSelection = false
    @State private var mutationState = HumanHealthReportMutationState()
    @State private var reportPendingDeletion: HumanHealthReport?
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var baselineDraft: HumanHealthReportEditorDraft?

    private var l: L10n { L10n(appLanguage) }
    private var isReadOnly: Bool { human.hasPassedAway }
    private var isSaving: Bool { mutationState.isSaving }
    private var isScannedReport: Bool { editing?.captureSource == .documentScan }
    private var currentDraft: HumanHealthReportEditorDraft {
        HumanHealthReportEditorDraft(
            reportType: reportType,
            conclusion: conclusion,
            hospitalName: hospitalName,
            doctorName: doctorName,
            reportDate: reportDate,
            hasNextCheck: hasNextCheck,
            nextCheckDate: nextCheckDate,
            summary: summary,
            notes: notes,
            selectedRecorderID: selectedRecorderID
        )
    }
    private var hasUnsavedChanges: Bool {
        baselineDraft.map { $0 != currentDraft } ?? false
    }
    private var sheetTitle: String {
        if isReadOnly {
            return l.tr(zh: "检测报告详情", en: "Health Report Details", de: "Details zum Gesundheitsbericht")
        }
        return editing == nil
            ? l.tr(zh: "添加检测报告", en: "Add Health Report", de: "Gesundheitsbericht hinzufügen")
            : l.tr(zh: "编辑报告", en: "Edit Report", de: "Bericht bearbeiten")
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Text(sheetTitle)
                            .font(OhanaFont.title2(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Button(action: requestClose) {
                            Image(systemName: "xmark").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 15, weight: .black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isSaving)
                        .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    if isReadOnly {
                        sheetMemorialReadOnlyNotice
                            .padding(.horizontal, 16)
                    }

                    if let failedAction = mutationState.failedAction {
                        mutationFailureNotice(for: failedAction)
                            .padding(.horizontal, 16)
                    }

                    // Card 1: Report Type
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "doc.text.fill", color: Color.goTeal, title: l.tr(zh: "报告类型", en: "Report Type", de: "Berichtstyp"))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HealthReportType.allCases) { type in
                                        Button {
                                            guard !isScannedReport else { return }
                                            withAnimation(GoMotion.feedback) { reportType = type }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(type.emoji)
                                                Text(type.localizedTitle(l))
                                                    .font(OhanaFont.caption(.bold))
                                            }
                                            .foregroundStyle(reportType == type ? Color.arkInk : Color.ohanaPrimaryText)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .frame(minHeight: 44)
                                            .background(reportType == type ? Color.goTeal : Color.ohanaControlFill, in: Capsule())
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .accessibilityLabel(type.localizedTitle(l))
                                        .accessibilityAddTraits(reportType == type ? .isSelected : [])
                                        .disabled(isScannedReport)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)
                    .disabled(isReadOnly)

                    // Card 2: Conclusion
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "checkmark.seal.fill", color: conclusion.color, title: l.tr(zh: "报告结论", en: "Conclusion", de: "Ergebnis"))

                            HStack(spacing: 8) {
                                ForEach(ReportConclusion.allCases) { c in
                                    Button {
                                        withAnimation(GoMotion.feedback) { conclusion = c }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(c.emoji)
                                                .font(OhanaFont.adaptive(size: 20))
                                            Text(c.localizedTitle(l))
                                                .font(OhanaFont.caption2(.bold))
                                        }
                                        .foregroundStyle(conclusion == c ? Color.arkInk : Color.ohanaPrimaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .frame(minHeight: 54)
                                        .background(conclusion == c ? c.color : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .accessibilityLabel(c.localizedTitle(l))
                                    .accessibilityAddTraits(conclusion == c ? .isSelected : [])
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)
                    .disabled(isReadOnly)

                    // Card 3: Details
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "building.2.fill", color: Color.goCardCyan, title: l.tr(zh: "检测详情", en: "Visit Details", de: "Untersuchungsdetails"))

                            fieldRow(icon: "building.2", label: l.tr(zh: "医院名称", en: "Hospital", de: "Klinik")) {
                                TextField(l.tr(zh: "如：北京协和医院", en: "e.g. City Hospital", de: "z. B. Stadtklinik"), text: $hospitalName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .accessibilityLabel(l.tr(zh: "医院名称", en: "Hospital", de: "Klinik"))
                                    .accessibilityIdentifier("add-human-health-report-hospital-input")
                            }
                            fieldRow(icon: "person.fill", label: l.tr(zh: "医生姓名", en: "Doctor", de: "Ärztin/Arzt")) {
                                TextField(l.tr(zh: "如：张医生", en: "e.g. Dr. Lee", de: "z. B. Dr. Lee"), text: $doctorName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .accessibilityLabel(l.tr(zh: "医生姓名", en: "Doctor", de: "Ärztin oder Arzt"))
                                    .accessibilityIdentifier("add-human-health-report-doctor-input")
                            }

                            HStack {
                                Label(l.tr(zh: "检测日期", en: "Report Date", de: "Berichtsdatum"), systemImage: "calendar")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                Spacer()
                                DatePicker("", selection: $reportDate, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                                    .accessibilityLabel(l.tr(zh: "检测日期", en: "Report Date", de: "Berichtsdatum"))
                            }

                            Toggle(isOn: $hasNextCheck) {
                                Label(l.tr(zh: "设置复查日期", en: "Set Follow-up Date", de: "Kontrolldatum setzen"), systemImage: "calendar.badge.checkmark")
                                    .font(OhanaFont.callout(.bold))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                            .tint(Color.goTeal)

                            if hasNextCheck {
                                HStack {
                                    Label(l.tr(zh: "复查日期", en: "Follow-up Date", de: "Kontrolldatum"), systemImage: "calendar.badge.clock")
                                        .font(OhanaFont.caption(.bold))
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                    Spacer()
                                    DatePicker("", selection: $nextCheckDate, in: reportDate..., displayedComponents: .date)
                                        .labelsHidden()
                                        .accessibilityLabel(l.tr(zh: "复查日期", en: "Follow-up Date", de: "Kontrolldatum"))
                                }
                            }

                            QuickCareActionHumanPickerContainer(
                                selectedHumanID: $selectedRecorderID,
                                requiresSelection: $requiresRecorderSelection,
                                role: .recorder,
                                tint: .goTeal
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)
                    .disabled(isReadOnly)

                    // Card 4: Summary & Notes
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "note.text", color: Color.goYellow, title: l.tr(zh: "摘要 & 备注", en: "Summary & Notes", de: "Zusammenfassung & Notizen"))

                            VStack(alignment: .leading, spacing: 6) {
                                Label(l.tr(zh: "检测摘要", en: "Summary", de: "Zusammenfassung"), systemImage: "text.alignleft")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                TextEditor(text: $summary)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 60)
                                    .padding(10)
                                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.badge))
                                    .accessibilityLabel(l.tr(zh: "检测摘要", en: "Summary", de: "Zusammenfassung"))
                                    .accessibilityIdentifier("add-human-health-report-summary-input")
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Label(l.tr(zh: "备注", en: "Notes", de: "Notizen"), systemImage: "note.text")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                TextEditor(text: $notes)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 60)
                                    .padding(10)
                                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.badge))
                                    .accessibilityLabel(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                                    .accessibilityIdentifier("add-human-health-report-notes-input")
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)
                    .disabled(isReadOnly)

                    if !isReadOnly {
                        // Delete button if editing
                        if let report = editing {
                            Button {
                                reportPendingDeletion = report
                                showingDeleteConfirmation = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label(l.tr(zh: "删除这条报告", en: "Delete this report", de: "Diesen Bericht löschen"), systemImage: "trash")
                                    .font(OhanaFont.callout(.semibold))
                                    .foregroundStyle(Color.goRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.goRed.opacity(0.1), in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isSaving)
                            .accessibilityHint(l.tr(
                                zh: "需要再次确认",
                                en: "Requires confirmation",
                                de: "Erfordert eine Bestätigung"
                            ))
                            .accessibilityIdentifier("add-human-health-report-delete-action")
                            .padding(.horizontal, 16)
                        }

                        // Save
                        Button { save() } label: {
                            Text(editing == nil ? l.tr(zh: "保存报告", en: "Save Report", de: "Bericht sichern") : l.tr(zh: "更新", en: "Update", de: "Aktualisieren"))
                                .font(OhanaFont.headline(.bold))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.goTeal, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isSaving || requiresRecorderSelection)
                        .accessibilityIdentifier("add-human-health-report-save-action")
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear { loadEditing() }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .interactiveDismissDisabled(isSaving || hasUnsavedChanges)
        .confirmationDialog(
            l.tr(zh: "删除这份健康报告？", en: "Delete this health report?", de: "Diesen Gesundheitsbericht löschen?"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: reportPendingDeletion
        ) { report in
            Button(
                l.tr(zh: "删除报告", en: "Delete Report", de: "Bericht löschen"),
                role: .destructive
            ) {
                reportPendingDeletion = nil
                delete(report)
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                reportPendingDeletion = nil
            }
        } message: { _ in
            Text(l.tr(
                zh: "删除后无法撤销。由该报告导入的指标历史会保留，但不再关联这份报告。",
                en: "This cannot be undone. Metrics imported from it remain in history but are no longer linked to this report.",
                de: "Dies kann nicht rückgängig gemacht werden. Importierte Messwerte bleiben in der Historie, sind aber nicht mehr mit diesem Bericht verknüpft."
            ))
        }
        .confirmationDialog(
            l.tr(zh: "放弃未保存的更改？", en: "Discard unsaved changes?", de: "Ungespeicherte Änderungen verwerfen?"),
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                l.tr(zh: "放弃更改", en: "Discard Changes", de: "Änderungen verwerfen"),
                role: .destructive
            ) {
                dismiss()
            }
            Button(l.tr(zh: "继续编辑", en: "Keep Editing", de: "Weiter bearbeiten"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "当前报告草稿尚未保存。",
                en: "The current report draft has not been saved.",
                de: "Der aktuelle Berichtsentwurf wurde noch nicht gespeichert."
            ))
        }
        .accessibilityIdentifier("add-human-health-report-sheet")
    }

    private func cardHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                Image(systemName: icon).font(OhanaFont.callout(.bold)).foregroundStyle(color)
            }
            Text(title).font(OhanaFont.headline(.bold)).foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
        }
    }

    private func fieldRow(icon: String, label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack { content() }
                .padding(12)
                .frame(minHeight: 44)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
        }
    }

    private func reportSheetCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }

    private var sheetMemorialReadOnlyNotice: some View {
        reportSheetCard {
            Label {
                Text(l.tr(
                    zh: "纪念档案为只读模式。你可以查看既有报告，但不能新增、编辑或删除。",
                    en: "Memorial profiles are read-only. You can review existing reports, but cannot add, edit, or delete them.",
                    de: "Gedenkprofile sind schreibgeschützt. Vorhandene Berichte können angesehen, aber nicht hinzugefügt, bearbeitet oder gelöscht werden."
                ))
                .font(OhanaFont.callout(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goYellow)
            }
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(14)
        }
        .accessibilityIdentifier("add-human-health-report-memorial-read-only-notice")
    }

    private func mutationFailureNotice(for action: HumanHealthReportMutationAction) -> some View {
        reportSheetCard {
            Label {
                Text(mutationFailureMessage(for: action))
                    .font(OhanaFont.callout(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goRed)
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(14)
        }
        .accessibilityIdentifier("add-human-health-report-command-error")
    }

    private func mutationFailureMessage(for action: HumanHealthReportMutationAction) -> String {
        switch action {
        case .create, .update:
            l.tr(
                zh: "报告未能保存。你填写的内容仍在此处，请重试。",
                en: "The report could not be saved. Your entries are still here; please try again.",
                de: "Der Bericht konnte nicht gespeichert werden. Deine Eingaben sind weiterhin vorhanden; bitte versuche es erneut."
            )
        case .delete:
            l.tr(
                zh: "报告未能删除，现有报告仍然保留。请重试。",
                en: "The report could not be deleted and remains available. Please try again.",
                de: "Der Bericht konnte nicht gelöscht werden und bleibt erhalten. Bitte versuche es erneut."
            )
        }
    }

    private func loadEditing() {
        if let r = editing {
            reportType = r.captureSource == .documentScan ? .bloodTest : r.reportType
            conclusion = r.conclusion
            hospitalName = r.hospitalName
            doctorName = r.doctorName
            reportDate = r.reportDate
            hasNextCheck = r.nextCheckDate != nil
            nextCheckDate = r.nextCheckDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
            summary = r.summary
            notes = r.notes
            selectedRecorderID = r.recordedByHumanId.flatMap(UUID.init(uuidString:))
        }
        baselineDraft = currentDraft
    }

    private func requestClose() {
        guard !isSaving else { return }
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard !isReadOnly, !isSaving, !requiresRecorderSelection else { return }
        let action: HumanHealthReportMutationAction = editing == nil ? .create : .update
        mutationState = HumanHealthReportMutationStateReducer.reduce(
            mutationState,
            event: .started(action)
        )
        let input = HumanHealthReportCommandInput(
            reportType: reportType,
            conclusion: conclusion,
            hospitalName: hospitalName,
            doctorName: doctorName,
            reportDate: reportDate,
            nextCheckDate: hasNextCheck ? nextCheckDate : nil,
            summary: summary,
            notes: notes,
            recordedByHumanId: selectedRecorderID?.uuidString
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if let report = editing {
            commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: report.id, action: "update")) {
                let result = HumanHealthReportCommandExecutor(context: modelContext, services: appServices).updateReport(
                    report,
                    human: human,
                    input: input,
                    note: "humanHealthReport.update"
                )
                completeMutation(.update, result: result)
            }
        } else {
            commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: nil, action: "create")) {
                let result = HumanHealthReportCommandExecutor(context: modelContext, services: appServices).createReport(
                    human: human,
                    input: input,
                    note: "humanHealthReport.create"
                )
                completeMutation(.create, result: result)
            }
        }
    }

    private func delete(_ report: HumanHealthReport) {
        guard !isReadOnly, !isSaving else { return }
        mutationState = HumanHealthReportMutationStateReducer.reduce(
            mutationState,
            event: .started(.delete)
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: report.id, action: "delete")) {
            let result = HumanHealthReportCommandExecutor(context: modelContext, services: appServices).deleteReport(
                report,
                human: human,
                note: "humanHealthReport.delete"
            )
            completeMutation(.delete, result: result)
        }
    }

    private func completeMutation(
        _ action: HumanHealthReportMutationAction,
        result: HumanHealthReportCommandResult
    ) {
        let succeeded = result.didChange && result.persistenceErrorDescription == nil
        mutationState = HumanHealthReportMutationStateReducer.reduce(
            mutationState,
            event: .completed(action, succeeded: succeeded)
        )
        guard succeeded else {
            let reason = result.persistenceErrorDescription ?? "command returned didChange=false"
            OhanaLog.warning(
                "Human health report \(mutationLogName(for: action)) failed: \(reason)",
                category: "HumanHealth"
            )
            UIAccessibility.post(
                notification: .announcement,
                argument: mutationFailureMessage(for: action)
            )
            return
        }
        if action == .delete {
            onDeleted?()
        }
        dismiss()
    }

    private func mutationLogName(for action: HumanHealthReportMutationAction) -> String {
        switch action {
        case .create: "create"
        case .update: "update"
        case .delete: "delete"
        }
    }
}
