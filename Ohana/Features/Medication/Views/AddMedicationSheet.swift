//
//  AddMedicationSheet.swift
//  Ohana
//
//  Add/edit sheet for human medication plans.
//

import Foundation
import SwiftData
import SwiftUI

struct AddMedicationSheet: View {
    let human: Human
    var editing: HumanMedication?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var name = ""
    @State private var doseForm: HumanMedicationDoseForm = .tablet
    @State private var doseAmount = ""
    @State private var doseUnit = "片"
    @State private var frequency: MedicationFrequency = .daily
    @State private var customNote = ""
    @State private var doseMinutes = HumanMedicationSchedulePlan.defaultDoseMinutes(for: .daily)
    @State private var weeklyWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var colorHex = "FF4757"
    @State private var notes = ""
    @State private var isActive = true
    @State private var showMore = false
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case name, dosage, customNote, notes
    }

    private enum HumanMedicationDoseForm: String, CaseIterable, Identifiable {
        case tablet
        case liquid
        case powder
        case injection
        case other

        var id: String { rawValue }

        func title(l: L10n) -> String {
            switch self {
            case .tablet:
                l.tr(zh: "片剂", en: "Tablet", de: "Tablette")
            case .liquid:
                l.tr(zh: "液体", en: "Liquid", de: "Flüssig")
            case .powder:
                l.tr(zh: "粉剂", en: "Powder", de: "Pulver")
            case .injection:
                l.tr(zh: "注射", en: "Injection", de: "Injektion")
            case .other:
                l.tr(zh: "其他", en: "Other", de: "Andere")
            }
        }

        var unitOptions: [String] {
            switch self {
            case .tablet:
                ["片", "粒", "mg"]
            case .liquid:
                ["ml", "滴"]
            case .powder:
                ["mg", "g", "勺"]
            case .injection:
                ["ml", "IU"]
            case .other:
                ["单位", "mg", "ml"]
            }
        }
    }

    private let colorOptions = ["FF4757", "FF8C42", "FFF44F", "00D4AA", "14B8A6", "9B5DE5", "64748B"]

    private var l: L10n { L10n(appLanguage) }
    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var controlFill: Color { Color.ohanaControlFill }
    private var controlStroke: Color { Color.ohanaCardStroke }
    private var canSave: Bool { !isSaving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isEditing: Bool { editing != nil }
    private var composedDosage: String {
        let amount = doseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !amount.isEmpty else { return "" }
        return "\(amount) \(doseUnit)"
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    basicInfoCard
                    frequencyCard
                    dateCard

                    if frequency.isManualEntry {
                        manualModeCard
                    } else {
                        scheduleCard
                        previewCard
                    }

                    if isEditing {
                        editingStateCard
                    }

                    moreDisclosure

                    Spacer(minLength: 110)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { footerBar }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                    focusedField = nil
                    GoKeyboard.dismiss()
                }
                if canSave {
                    Button(l.tr(zh: "保存", en: "Save", de: "Sichern")) {
                        GoKeyboard.dismiss()
                        DispatchQueue.main.async {
                            save()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .alert(l.tr(zh: "删除药物计划？", en: "Delete medication plan?", de: "Medikamentenplan löschen?"), isPresented: $showDeleteConfirmation) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                deleteMedication()
            }
        } message: {
            Text(l.tr(zh: "只会删除这个药物计划，历史服药记录会保留。", en: "Only this medication plan will be deleted. Past dose logs stay saved.", de: "Nur dieser Plan wird gelöscht. Frühere Einnahmen bleiben gespeichert."))
        }
        .onAppear {
            loadEditing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusedField = .name
            }
        }
        .onChange(of: frequency) { _, newValue in
            applyDefaults(for: newValue)
        }
        .onChange(of: startDate) { _, newValue in
            if frequency == .weekly {
                weeklyWeekday = Calendar.current.component(.weekday, from: newValue)
            }
            if endDate < newValue {
                endDate = newValue
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? l.tr(zh: "编辑药物", en: "Edit medication", de: "Medikament bearbeiten") : l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen"))
                    .font(OhanaFont.title2(.bold))
                    .foregroundStyle(primaryText)
                    .accessibilityIdentifier("add-human-medication-sheet")
                Text(l.tr(zh: "先设好药名、频率和时间。", en: "Set the name, frequency, and time first.", de: "Lege zuerst Name, Häufigkeit und Zeit fest."))
                    .font(OhanaFont.caption())
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Button {
                guard !isSaving else { return }
                dismiss()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isSaving)
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var basicInfoCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "pills.fill", color: Color(hex: colorHex), title: l.tr(zh: "药物信息", en: "Medication", de: "Medikament"))
                fieldRow(icon: "textformat", label: l.tr(zh: "药品名称", en: "Name", de: "Name")) {
                    GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                        l.tr(zh: "如：维生素 D", en: "e.g. Vitamin D", de: "z. B. Vitamin D"),
                        text: $name,
                        capitalization: .words,
                        autoFocusDelay: 0.25
                    )
                    .font(OhanaFont.body())
                    .foregroundStyle(primaryText)
                    .accessibilityIdentifier("add-human-medication-name-input")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label(l.tr(zh: "剂型", en: "Form", de: "Form"), systemImage: "pills")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(HumanMedicationDoseForm.allCases) { form in
                                let selected = doseForm == form
                                Button {
                                    endEditing()
                                    withAnimation(GoMotion.feedback) {
                                        doseForm = form
                                        if !form.unitOptions.contains(doseUnit) {
                                            doseUnit = form.unitOptions[0]
                                        }
                                    }
                                } label: {
                                    Text(form.title(l: l))
                                        .font(OhanaFont.caption(.bold))
                                        .foregroundStyle(selected ? Color.arkInk : primaryText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .goSelectableSurface(isSelected: selected, tint: Color.goPrimary, in: Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }
                fieldRow(icon: "scalemass", label: l.tr(zh: "每次剂量", en: "Dose per time", de: "Dosis pro Einnahme")) {
                    GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                        l.tr(zh: "数值", en: "Amount", de: "Menge"),
                        text: $doseAmount,
                        keyboardType: .decimalPad
                    )
                    .font(OhanaFont.body())
                    .foregroundStyle(primaryText)

                    Spacer(minLength: 8)

                    Menu {
                        ForEach(doseForm.unitOptions, id: \.self) { unit in
                            Button(unit) {
                                endEditing()
                                doseUnit = unit
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(doseUnit)
                                .font(OhanaFont.callout(.bold))
                            Image(systemName: "chevron.up.chevron.down") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.caption(.bold))
                        }
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
    }

    private var frequencyCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(icon: "repeat", color: Color.goTeal, title: l.tr(zh: "频率", en: "Frequency", de: "Häufigkeit"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MedicationFrequency.allCases) { freq in
                            frequencyChip(freq)
                        }
                    }
                }
                if frequency == .custom {
                    fieldRow(icon: "text.bubble", label: l.tr(zh: "自定义说明", en: "Custom note", de: "Eigene Notiz")) {
                        GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                            l.tr(zh: "说明服药规则", en: "Describe the rule", de: "Regel beschreiben"),
                            text: $customNote
                        )
                        .font(OhanaFont.body())
                        .foregroundStyle(primaryText)
                    }
                }
            }
        }
    }

    private var dateCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "calendar", color: Color.goBlue, title: l.tr(zh: "日期", en: "Dates", de: "Daten"))
                HStack {
                    Label(l.tr(zh: "开始日期", en: "Start date", de: "Startdatum"), systemImage: "calendar")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .simultaneousGesture(TapGesture().onEnded { endEditing() })
                }
                .padding(12)
                .background(controlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                Toggle(isOn: $hasEndDate) {
                    Label(l.tr(zh: "设置结束日期", en: "Set end date", de: "Enddatum setzen"), systemImage: "calendar.badge.checkmark")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(primaryText)
                }
                .tint(Color.goTeal)
                .onChange(of: hasEndDate) { _, _ in endEditing() }

                if hasEndDate {
                    HStack {
                        Label(l.tr(zh: "结束日期", en: "End date", de: "Enddatum"), systemImage: "calendar.badge.minus")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(secondaryText)
                        Spacer()
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .labelsHidden()
                            .simultaneousGesture(TapGesture().onEnded { endEditing() })
                    }
                    .padding(12)
                    .background(controlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                }
            }
        }
    }

    private var scheduleCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "clock.fill", color: Color.goPrimary, title: l.tr(zh: "服药时间", en: "Dose times", de: "Einnahmezeiten"))

                ForEach(Array(doseMinutes.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        Label(doseTimeLabel(index), systemImage: "clock")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(secondaryText)
                        Spacer()
                        DatePicker("", selection: doseTimeBinding(index), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .simultaneousGesture(TapGesture().onEnded { endEditing() })
                    }
                    .padding(12)
                    .background(controlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                }

                if frequency == .weekly {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.tr(zh: "每周哪一天", en: "Day of week", de: "Wochentag"))
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(secondaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(weekdayOptions, id: \.0) { weekday, label in
                                    Button {
                                        endEditing()
                                        withAnimation(GoMotion.feedback) { weeklyWeekday = weekday }
                                    } label: {
                                        Text(label)
                                            .font(OhanaFont.caption(.bold))
                                            .foregroundStyle(weeklyWeekday == weekday ? Color.arkInk : primaryText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(weeklyWeekday == weekday ? Color.goPrimary : controlFill, in: Capsule())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.badge.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.goYellow)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "接下来提醒", en: "Next reminders", de: "Nächste Erinnerungen"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(primaryText)
                Text(previewText)
                    .font(OhanaFont.caption())
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.goYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous).strokeBorder(Color.goYellow.opacity(0.28), lineWidth: 1))
    }

    private var manualModeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.goPrimary)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "手动记录", en: "Manual logging", de: "Manuell eintragen"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "按需和自定义药物不会自动生成固定提醒，可在管理页记录一次。", en: "As-needed and custom medications do not create fixed reminders. Log them from the management page.", de: "Bedarfs- und eigene Medikamente erzeugen keine festen Erinnerungen. Trage sie auf der Verwaltungsseite ein."))
                    .font(OhanaFont.caption())
                    .foregroundStyle(secondaryText)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.goPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous).strokeBorder(Color.goPrimary.opacity(0.24), lineWidth: 1))
    }

    private var editingStateCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(icon: isActive ? "pause.circle.fill" : "play.circle.fill", color: isActive ? Color.goOrange : Color.goTeal, title: l.tr(zh: "药物状态", en: "Medication status", de: "Status"))
                Button {
                    withAnimation(GoMotion.feedback) { isActive.toggle() }
                } label: {
                    Label(
                        isActive ? l.tr(zh: "标记为停药", en: "Mark as stopped", de: "Als pausiert markieren") : l.tr(zh: "恢复用药", en: "Resume medication", de: "Fortsetzen"),
                        systemImage: isActive ? "pause.circle" : "play.circle"
                    )
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(isActive ? Color.goOrange : Color.goTeal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((isActive ? Color.goOrange : Color.goTeal).opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label(l.tr(zh: "删除药物计划", en: "Delete plan", de: "Plan löschen"), systemImage: "trash")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.goRed.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSaving)
            }
        }
    }

    private var moreDisclosure: some View {
        DisclosureGroup(isExpanded: $showMore) {
            moreCard
        } label: {
            Label(l.tr(zh: "更多", en: "More", de: "Mehr"), systemImage: "ellipsis.circle")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(primaryText)
        }
    }

    private var moreCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "slider.horizontal.3", color: Color.goBlue, title: l.tr(zh: "更多", en: "More", de: "Mehr"))

                VStack(alignment: .leading, spacing: 8) {
                    Text(l.tr(zh: "标签颜色", en: "Color", de: "Farbe"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    HStack(spacing: 10) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                withAnimation(GoMotion.feedback) { colorHex = hex }
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                    .overlay(Circle().strokeBorder(primaryText, lineWidth: colorHex == hex ? 2.5 : 0))
                                    .scaleEffect(colorHex == hex ? 1.12 : 1.0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(l.tr(zh: "备注", en: "Notes", de: "Notizen"), systemImage: "note.text")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    GoDraftTextEditor(
                        l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                        text: $notes,
                        minHeight: 74
                    )
                    .font(OhanaFont.body())
                    .foregroundStyle(primaryText)
                    .frame(height: 74)
                    .padding(10)
                    .background(controlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous).strokeBorder(controlStroke, lineWidth: 1))
                }
            }
        }
    }

    private var footerBar: some View {
        VStack(spacing: 0) {
            Button {
                GoKeyboard.dismiss()
                DispatchQueue.main.async {
                    save()
                }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        Image(systemName: "hourglass") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.callout(.bold))
                    }
                    Text(isSaving ? l.tr(zh: "保存中", en: "Saving", de: "Speichert") : (isEditing ? l.tr(zh: "保存修改", en: "Save changes", de: "Änderungen sichern") : l.tr(zh: "保存药物", en: "Save medication", de: "Medikament sichern")))
                        .font(OhanaFont.headline(.bold))
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.goPrimary : Color.goPrimary.opacity(0.35), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSave)
            .accessibilityIdentifier("add-human-medication-save-action")
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color.ohanaCardSurface)
    }

    private func sheetCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }

    private func cardHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Image(systemName: icon).font(OhanaFont.callout(.bold)).foregroundStyle(color)
            }
            Text(title).font(OhanaFont.headline(.bold)).foregroundStyle(primaryText)
            Spacer()
        }
    }

    private func fieldRow(icon: String, label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(secondaryText)
            HStack { content() }
                .padding(12)
                .background(controlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous).strokeBorder(controlStroke, lineWidth: 1))
        }
    }

    private func frequencyChip(_ freq: MedicationFrequency) -> some View {
        let selected = frequency == freq
        return Button {
            endEditing()
            withAnimation(GoMotion.feedback) { frequency = freq }
        } label: {
            Text(freq.displayTitle(l: l))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(selected ? Color.arkInk : primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .goSelectableSurface(isSelected: selected, tint: Color.goTeal, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func doseTimeLabel(_ index: Int) -> String {
        if doseMinutes.count == 1 {
            return l.tr(zh: "服药时间", en: "Dose time", de: "Einnahmezeit")
        }
        return l.tr(zh: "第 \(index + 1) 次", en: "Dose \(index + 1)", de: "Dosis \(index + 1)")
    }

    private func doseTimeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minute = doseMinutes.indices.contains(index) ? doseMinutes[index] : 8 * 60
                return dateFromMinute(minute)
            },
            set: { newDate in
                guard doseMinutes.indices.contains(index) else { return }
                doseMinutes[index] = HumanMedicationSchedulePlan.minuteOfDay(from: newDate)
                doseMinutes = HumanMedicationScheduleMetadata.normalizedDoseMinutes(doseMinutes)
            }
        )
    }

    private var weekdayOptions: [(Int, String)] {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (1 ... 7).map { ($0, symbols[$0 - 1]) }
    }

    private var previewText: String {
        let dates = previewDates().prefix(3)
        guard !dates.isEmpty else {
            return l.tr(zh: "当前设置不会生成未来提醒。", en: "This setup will not create future reminders.", de: "Diese Einstellung erzeugt keine zukünftigen Erinnerungen.")
        }
        return dates
            .map { $0.formatted(date: .abbreviated, time: .shortened) }
            .joined(separator: " · ")
    }

    private func previewDates() -> [Date] {
        guard !frequency.isManualEntry else { return [] }
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return (0 ..< 14).flatMap { offset -> [Date] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return [] }
            guard calendar.startOfDay(for: day) >= calendar.startOfDay(for: startDate) else { return [] }
            if hasEndDate, calendar.startOfDay(for: day) > calendar.startOfDay(for: endDate) { return [] }
            if frequency == .weekly, calendar.component(.weekday, from: day) != weeklyWeekday { return [] }
            return doseMinutes.compactMap { HumanMedicationSchedulePlan.date(on: day, minuteOfDay: $0) }
        }
        .filter { $0 > now }
        .sorted()
    }

    private func dateFromMinute(_ minute: Int) -> Date {
        HumanMedicationSchedulePlan.date(on: Date(), minuteOfDay: minute) ?? Date()
    }

    private func applyDefaults(for frequency: MedicationFrequency) {
        if frequency.isManualEntry {
            doseMinutes = []
        } else {
            doseMinutes = HumanMedicationSchedulePlan.defaultDoseMinutes(for: frequency)
        }
        if frequency == .weekly {
            weeklyWeekday = Calendar.current.component(.weekday, from: startDate)
        }
    }

    private func endEditing() {
        focusedField = nil
        GoKeyboard.dismiss()
    }

    private func loadEditing() {
        guard let med = editing else { return }
        name = med.name
        loadDosage(med.dosage)
        frequency = med.frequency
        customNote = med.customFrequencyNote
        let loadedMinutes = HumanMedicationSchedulePlan.doseMinutes(for: med)
        doseMinutes = loadedMinutes.isEmpty ? HumanMedicationSchedulePlan.defaultDoseMinutes(for: med.frequency) : loadedMinutes
        weeklyWeekday = HumanMedicationScheduleMetadata.parse(from: med.notes)?.weeklyWeekday
            ?? Calendar.current.component(.weekday, from: med.startDate)
        startDate = med.startDate
        hasEndDate = med.endDate != nil
        endDate = med.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        colorHex = med.colorHex
        notes = HumanMedicationScheduleMetadata.visibleNotes(from: med.notes)
        isActive = med.isActive
    }

    private func loadDosage(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            doseForm = .tablet
            doseAmount = ""
            doseUnit = "片"
            return
        }

        let allUnits = Array(Set(HumanMedicationDoseForm.allCases.flatMap(\.unitOptions)))
            .sorted { $0.count > $1.count }
        if let unit = allUnits.first(where: { trimmed.hasSuffix($0) }) {
            doseUnit = unit
            doseForm = inferredDoseForm(for: unit)
            doseAmount = trimmed
                .dropLast(unit.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2, allUnits.contains(parts[1]) {
            doseAmount = parts[0]
            doseUnit = parts[1]
            doseForm = inferredDoseForm(for: parts[1])
        } else {
            doseForm = .other
            doseAmount = trimmed
            doseUnit = "单位"
        }
    }

    private func inferredDoseForm(for unit: String) -> HumanMedicationDoseForm {
        switch unit {
        case "片", "粒":
            .tablet
        case "ml", "滴":
            .liquid
        case "mg", "g", "勺":
            .powder
        case "IU":
            .injection
        default:
            .other
        }
    }

    private var commandInput: HumanMedicationPlanCommandInput {
        HumanMedicationPlanCommandInput(
            name: name,
            dosage: composedDosage,
            frequency: frequency,
            customFrequencyNote: customNote,
            doseMinutes: doseMinutes,
            weeklyWeekday: weeklyWeekday,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            colorHex: colorHex,
            visibleNotes: notes,
            isActive: isActive,
            appLanguage: appLanguage
        )
    }

    private func save() {
        let input = commandInput
        guard !input.cleanName.isEmpty, !isSaving else { return }
        isSaving = true

        let command = DomainCommand.humanMedicationPlan(humanID: human.id, medicationID: editing?.id)
        commandQueue.enqueue(command) {
            guard HumanCareCommandExecutor(context: modelContext, services: appServices).saveMedicationPlan(
                human: human,
                editing: editing,
                input: input
            ) != nil else {
                isSaving = false
                return
            }

            isSaving = false
            dismiss()
        }
    }

    private func deleteMedication() {
        guard let med = editing, !isSaving else { return }
        isSaving = true

        let command = DomainCommand.humanMedicationPlanDelete(humanID: human.id, medicationID: med.id)
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext, services: appServices).deleteMedicationPlan(
                human: human,
                medication: med,
                note: "human.medication.plan.deleted"
            )
            isSaving = false
            dismiss()
        }
    }
}
