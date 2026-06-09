//
//  HumanHealthReportView.swift
//  Ohana
//
//  身体检测报告列表 + 添加/编辑

import SwiftUI
import SwiftData

// MARK: - Main View

struct HumanHealthReportView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Query private var myReports: [HumanHealthReport]

    @State private var showAddSheet = false
    @State private var editingReport: HumanHealthReport? = nil

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }

    init(human: Human) {
        self.human = human
        let humanId = human.id.uuidString
        _myReports = Query(
            filter: #Predicate<HumanHealthReport> { $0.humanId == humanId },
            sort: \HumanHealthReport.reportDate,
            order: .reverse
        )
    }

    private var upcomingCheckCount: Int {
        myReports.filter {
            if let days = $0.daysUntilNextCheck { return days >= 0 && days <= 30 }
            return false
        }.count
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
                            sectionLabel("检测报告")
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
                        Image(systemName: "plus")
                            .font(OhanaFont.headline(.black))
                        Text("添加报告")
                            .font(OhanaFont.headline(.black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.goTeal, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("🏥 身体检测报告")
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
            Image(systemName: "lock.shield.fill")
                .font(OhanaFont.metric(size: 44))
                .foregroundStyle(Color.goYellow)
            Text("身体数据仅本人可见")
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text("请切换到本人档案后再查看。")
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
                bentoStat(icon: "doc.text.fill", label: "报告总数", value: "\(myReports.count)", color: Color.goTeal)
                divider
                bentoStat(icon: "exclamationmark.triangle.fill", label: "异常项", value: "\(abnormalCount)", color: Color.goOrange)
                divider
                bentoStat(icon: "calendar.badge.clock", label: "近期复查", value: "\(upcomingCheckCount)", color: Color.goYellow)
            }
            .padding(16)
        }
    }

    private var abnormalCount: Int {
        myReports.filter { $0.conclusion == .abnormal || $0.conclusion == .critical }.count
    }

    private var divider: some View {
        Rectangle().fill(Color.ohanaDivider).frame(width: 1, height: 40)
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
                            Text(report.reportType.emoji + " " + report.reportType.rawValue)
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(report.conclusion.rawValue)
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
                                Image(systemName: "calendar.badge.clock")
                                    .font(OhanaFont.caption2())
                                    .foregroundStyle(Color.ohanaTertiaryText)
                                Text(days > 0 ? "距复查还有 \(days) 天" : days == 0 ? "今天复查" : "已逾期 \(-days) 天")
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(days <= 7 ? Color.goOrange : Color.ohanaSecondaryText)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
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
                    Image(systemName: "stethoscope").font(.system(size: 32)).foregroundStyle(Color.goTeal)
                }
                Text("还没有检测报告").font(OhanaFont.title3(.bold)).foregroundStyle(Color.ohanaPrimaryText)
                Text("点击下方按钮添加第一条身体检测报告").font(OhanaFont.callout()).foregroundStyle(Color.ohanaSecondaryText)
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

    private func humanReportSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

// MARK: - Add / Edit Sheet

struct AddHumanHealthReportSheet: View {
    let human: Human
    var editing: HumanHealthReport? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Text(editing == nil ? "添加检测报告" : "编辑报告")
                            .font(OhanaFont.title2(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("关闭")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Card 1: Report Type
                    reportSheetCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "doc.text.fill", color: Color.goTeal, title: "报告类型")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HealthReportType.allCases) { type in
                                        Button {
                                            withAnimation(GoMotion.feedback) { reportType = type }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(type.emoji)
                                                Text(type.rawValue)
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
                            cardHeader(icon: "checkmark.seal.fill", color: conclusion.color, title: "报告结论")

                            HStack(spacing: 8) {
                                ForEach(ReportConclusion.allCases) { c in
                                    Button {
                                        withAnimation(GoMotion.feedback) { conclusion = c }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(c.emoji)
                                                .font(.system(size: 20))
                                            Text(c.rawValue)
                                                .font(OhanaFont.caption2(.bold))
                                        }
                                        .foregroundStyle(conclusion == c ? Color.arkInk : Color.ohanaPrimaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(conclusion == c ? c.color : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 12))
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
                            cardHeader(icon: "building.2.fill", color: Color.goCardCyan, title: "检测详情")

                            fieldRow(icon: "building.2", label: "医院名称") {
                                TextField("如：北京协和医院", text: $hospitalName)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                            fieldRow(icon: "person.fill", label: "医生姓名") {
                                TextField("如：张医生", text: $doctorName)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }

                            HStack {
                                Label("检测日期", systemImage: "calendar")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                Spacer()
                                DatePicker("", selection: $reportDate, displayedComponents: .date)
                                    .labelsHidden()
                            }

                            Toggle(isOn: $hasNextCheck) {
                                Label("设置复查日期", systemImage: "calendar.badge.checkmark")
                                    .font(OhanaFont.callout(.bold))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                            .tint(Color.goTeal)

                            if hasNextCheck {
                                HStack {
                                    Label("复查日期", systemImage: "calendar.badge.clock")
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
                            cardHeader(icon: "note.text", color: Color.goYellow, title: "摘要 & 备注")

                            VStack(alignment: .leading, spacing: 6) {
                                Label("检测摘要", systemImage: "text.alignleft")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                TextEditor(text: $summary)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 60)
                                    .padding(10)
                                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 10))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Label("备注", systemImage: "note.text")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                TextEditor(text: $notes)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 60)
                                    .padding(10)
                                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 10))
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
                            Label("删除这条报告", systemImage: "trash")
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
                        Text(editing == nil ? "保存报告" : "更新")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.goTeal, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { loadEditing() }
    }

    private func cardHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 36, height: 36)
                Image(systemName: icon).font(OhanaFont.callout(.bold)).foregroundStyle(color)
            }
            Text(title).font(OhanaFont.headline(.bold)).foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
        }
    }

    private func fieldRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack { content() }
                .padding(12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func reportSheetCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                HumanHealthReportCommandExecutor(context: modelContext).updateReport(
                    report,
                    human: human,
                    input: input,
                    note: "humanHealthReport.update"
                )
                dismiss()
            }
        } else {
            commandQueue.enqueue(.humanHealthReport(humanID: human.id, reportID: nil, action: "create")) {
                HumanHealthReportCommandExecutor(context: modelContext).createReport(
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
            HumanHealthReportCommandExecutor(context: modelContext).deleteReport(
                report,
                human: human,
                note: "humanHealthReport.delete"
            )
            dismiss()
        }
    }
}
