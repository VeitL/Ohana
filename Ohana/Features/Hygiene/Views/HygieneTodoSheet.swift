//
//  HygieneTodoSheet.swift
//  Ohana
//
//  Lightweight hygiene plan sheet backed by PetHygieneCommandExecutor.
//

import SwiftData
import SwiftUI

struct HygieneTodoSheet: View {
    let pet: Pet
    let type: HygieneType
    let accent: Color
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var startDate: Date
    @State private var startTime: Date
    @State private var isAllDay: Bool
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var repeatDays: Int
    @State private var customNote: String

    init(
        pet: Pet,
        type: HygieneType,
        accent: Color,
        onSaved: @escaping () -> Void
    ) {
        let now = Date()
        let defaultRepeatDays = type.effectiveCycleDays(for: pet.id)
        self.pet = pet
        self.type = type
        self.accent = accent
        self.onSaved = onSaved
        _startDate = State(initialValue: now)
        _startTime = State(initialValue: now)
        _isAllDay = State(initialValue: true)
        _hasEndDate = State(initialValue: false)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        _repeatDays = State(initialValue: max(defaultRepeatDays, 1))
        _customNote = State(initialValue: "")
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scheduleSection
                    recurrenceSection
                    noteSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(OhanaAppBackground().ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Sichern")) { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(accent)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: type.systemIconName)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                .background(accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(type.localizedLabel(l))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "为 \(pet.name) 添加护理计划",
                    en: "Add a care plan for \(pet.name)",
                    de: "Pflegeplan fuer \(pet.name) hinzufuegen"
                ))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "时间", en: "Time", de: "Zeit"))

            Toggle(l.tr(zh: "全天", en: "All day", de: "Ganztagig"), isOn: $isAllDay)
                .tint(accent)

            DatePicker(l.tr(zh: "开始日期", en: "Start date", de: "Startdatum"), selection: $startDate, displayedComponents: .date)

            if !isAllDay {
                DatePicker(l.tr(zh: "提醒时间", en: "Reminder time", de: "Erinnerungszeit"), selection: $startTime, displayedComponents: .hourAndMinute)
            }

            Toggle(l.tr(zh: "结束日期", en: "End date", de: "Enddatum"), isOn: $hasEndDate)
                .tint(accent)

            if hasEndDate {
                DatePicker(l.tr(zh: "结束", en: "Ends", de: "Endet"), selection: $endDate, displayedComponents: .date)
            }
        }
        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "重复", en: "Repeat", de: "Wiederholen"))

            Stepper(value: $repeatDays, in: 0 ... 365) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recurrenceLabel)
                        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "0 表示只提醒一次", en: "0 means remind only once", de: "0 bedeutet nur einmal erinnern"))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "备注", en: "Notes", de: "Notizen"))

            TextField(l.tr(zh: "可选", en: "Optional", de: "Optional"), text: $customNote, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .lineLimit(2 ... 4)
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                .padding(12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private var recurrenceLabel: String {
        switch repeatDays {
        case 0: l.tr(zh: "不重复", en: "Does not repeat", de: "Wiederholt sich nicht")
        case 1: l.tr(zh: "每天", en: "Every day", de: "Jeden Tag")
        case 7: l.tr(zh: "每周", en: "Every week", de: "Jede Woche")
        case 14: l.tr(zh: "每两周", en: "Every two weeks", de: "Alle zwei Wochen")
        case 30: l.tr(zh: "每月", en: "Every month", de: "Jeden Monat")
        default: l.tr(zh: "每 \(repeatDays) 天", en: "Every \(repeatDays) days", de: "Alle \(repeatDays) Tage")
        }
    }

    private func save() {
        let input = PetHygienePlanCommandInput(
            startDate: startDate,
            isAllDay: isAllDay,
            startTime: startTime,
            hasEndDate: hasEndDate,
            endDate: endDate,
            repeatDays: repeatDays,
            customNote: customNote
        )
        PetHygieneCommandExecutor(context: modelContext, services: appServices).createPlan(
            pet: pet,
            type: type,
            input: input,
            note: "PetHygieneDetailView.HygieneTodoSheet"
        )
        onSaved()
        dismiss()
    }
}
