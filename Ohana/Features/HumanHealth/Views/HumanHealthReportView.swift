//
//  HumanHealthReportView.swift
//  Ohana
//
//  身体检测报告列表 + 添加/编辑

import SwiftData
import SwiftUI

// MARK: - Main View

struct HumanHealthReportContentView: View {
    let human: Human
    let myReports: [HumanHealthReport]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var showAddSheet = false
    @State private var editingReport: HumanHealthReport? = nil

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var l: L10n { L10n(appLanguage) }

    init(human: Human, myReports: [HumanHealthReport]) {
        self.human = human
        self.myReports = myReports
    }

    private var upcomingCheckCount: Int {
        myReports.count(where: {
            if let days = $0.daysUntilNextCheck { return days >= 0 && days <= 30 }
            return false
        })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        summaryBento
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        HumanPrivateDataNotice(human: human, field: .weight)
                            .padding(.horizontal, 16)

                        if !myReports.isEmpty {
                            sectionLabel(l.tr(zh: "检测报告", en: "Health Reports", de: "Gesundheitsberichte"))
                            ForEach(myReports) { report in
                                reportRow(report)
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
            if !isPrivacyLocked {
                Button { showAddSheet = true } label: {
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
        .navigationTitle(l.tr(zh: "🏥 身体检测报告", en: "🏥 Health Reports", de: "🏥 Gesundheitsberichte"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddHumanHealthReportSheet(human: human)
                .ohanaSheetPagePresentation() // ui-v4: allow complex report editor uses full-height system sheet
        }
        .sheet(item: $editingReport) { report in
            AddHumanHealthReportSheet(human: human, editing: report)
                .ohanaSheetPagePresentation() // ui-v4: allow complex report editor uses full-height system sheet
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

    // MARK: - Summary Bento

    private var summaryBento: some View {
        humanReportSurface {
            HStack(spacing: 12) {
                bentoStat(icon: "doc.text.fill", label: l.tr(zh: "报告总数", en: "Reports", de: "Berichte"), value: "\(myReports.count)", color: Color.goTeal)
                divider
                bentoStat(icon: "exclamationmark.triangle.fill", label: l.tr(zh: "异常项", en: "Abnormal", de: "Auffällig"), value: "\(abnormalCount)", color: Color.goOrange)
                divider
                bentoStat(icon: "calendar.badge.clock", label: l.tr(zh: "近期复查", en: "Follow-ups", de: "Kontrollen"), value: "\(upcomingCheckCount)", color: Color.goYellow)
            }
            .padding(16)
        }
    }

    private var abnormalCount: Int {
        myReports.count(where: { $0.conclusion == .abnormal || $0.conclusion == .critical })
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
    }

    // MARK: - Report Row

    private func reportRow(_ report: HumanHealthReport) -> some View {
        Button { editingReport = report } label: {
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
        .buttonStyle(ScaleButtonStyle())
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
                Text(l.tr(zh: "点击下方按钮添加第一条身体检测报告", en: "Use the button below to add the first report.", de: "Füge den ersten Bericht über die Schaltfläche unten hinzu.")).font(OhanaFont.callout()).foregroundStyle(Color.ohanaSecondaryText)
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

    private func humanReportSurface(@ViewBuilder content: () -> some View) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

// MARK: - Add / Edit Sheet

struct AddHumanHealthReportSheet: View {
    let human: Human
    var editing: HumanHealthReport?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

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
    @State private var isSaving = false
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Text(editing == nil ? l.tr(zh: "添加检测报告", en: "Add Health Report", de: "Gesundheitsbericht hinzufügen") : l.tr(zh: "编辑报告", en: "Edit Report", de: "Bericht bearbeiten"))
                            .font(OhanaFont.title2(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 15, weight: .black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Card 1: Report Type
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "doc.text.fill", color: Color.goTeal, title: l.tr(zh: "报告类型", en: "Report Type", de: "Berichtstyp"))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HealthReportType.allCases) { type in
                                        Button {
                                            withAnimation(GoMotion.feedback) { reportType = type }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(type.emoji)
                                                Text(type.localizedTitle(l))
                                                    .font(OhanaFont.caption(.bold))
                                            }
                                            .foregroundStyle(reportType == type ? Color.arkInk : Color.ohanaPrimaryText)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(reportType == type ? Color.goTeal : Color.ohanaControlFill, in: Capsule())
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

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
                                        .background(conclusion == c ? c.color : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Card 3: Details
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "building.2.fill", color: Color.goCardCyan, title: l.tr(zh: "检测详情", en: "Visit Details", de: "Untersuchungsdetails"))

                            fieldRow(icon: "building.2", label: l.tr(zh: "医院名称", en: "Hospital", de: "Klinik")) {
                                TextField(l.tr(zh: "如：北京协和医院", en: "e.g. City Hospital", de: "z. B. Stadtklinik"), text: $hospitalName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .accessibilityIdentifier("add-human-health-report-hospital-input")
                            }
                            fieldRow(icon: "person.fill", label: l.tr(zh: "医生姓名", en: "Doctor", de: "Ärztin/Arzt")) {
                                TextField(l.tr(zh: "如：张医生", en: "e.g. Dr. Lee", de: "z. B. Dr. Lee"), text: $doctorName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .accessibilityIdentifier("add-human-health-report-doctor-input")
                            }

                            HStack {
                                Label(l.tr(zh: "检测日期", en: "Report Date", de: "Berichtsdatum"), systemImage: "calendar")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                Spacer()
                                DatePicker("", selection: $reportDate, displayedComponents: .date)
                                    .labelsHidden()
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
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

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
                                    .accessibilityIdentifier("add-human-health-report-notes-input")
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Delete button if editing
                    if let report = editing {
                        Button {
                            delete(report)
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
                    .disabled(isSaving)
                    .accessibilityIdentifier("add-human-health-report-save-action")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { loadEditing() }
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

    private func loadEditing() {
        guard let r = editing else { return }
        reportType = r.reportType
        conclusion = r.conclusion
        hospitalName = r.hospitalName
        doctorName = r.doctorName
        reportDate = r.reportDate
        hasNextCheck = r.nextCheckDate != nil
        nextCheckDate = r.nextCheckDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        summary = r.summary
        notes = r.notes
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let input = HumanHealthReportCommandInput(
            reportType: reportType,
            conclusion: conclusion,
            hospitalName: hospitalName,
            doctorName: doctorName,
            reportDate: reportDate,
            nextCheckDate: hasNextCheck ? nextCheckDate : nil,
            summary: summary,
            notes: notes
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if let report = editing {
            commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: report.id, action: "update")) {
                HumanHealthReportCommandExecutor(context: modelContext, services: appServices).updateReport(
                    report,
                    human: human,
                    input: input,
                    note: "humanHealthReport.update"
                )
                dismiss()
            }
        } else {
            commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: nil, action: "create")) {
                HumanHealthReportCommandExecutor(context: modelContext, services: appServices).createReport(
                    human: human,
                    input: input,
                    note: "humanHealthReport.create"
                )
                dismiss()
            }
        }
    }

    private func delete(_ report: HumanHealthReport) {
        guard !isSaving else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: report.id, action: "delete")) {
            HumanHealthReportCommandExecutor(context: modelContext, services: appServices).deleteReport(
                report,
                human: human,
                note: "humanHealthReport.delete"
            )
            dismiss()
        }
    }
}
