//
//  AddEventView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @State private var title = ""
    @State private var eventType: EventType = .daily
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var isAllDay = false
    @State private var hasEndDate = false
    @State private var relatedEntityType = ""
    @State private var relatedEntityId = ""
    @State private var recurrenceOption: RecurrenceOption = .none
    @State private var recurrenceDays = 2
    @State private var recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var hasRecurrenceEnd = false
    @State private var reminderAdvanceDays = 0
    @State private var hasReminder = true
    @State private var assigneeId: String? = nil
    @State private var showsAdvanced = false
    @State private var isSaving = false
    @State private var didSave = false
    @FocusState private var titleFocused: Bool

    private var l: L10n { L10n(appLanguage) }

    private enum RecurrenceOption: String, CaseIterable, Identifiable {
        case none
        case daily
        case weekly
        case monthly
        case custom

        var id: String { rawValue }

        func title(_ l: L10n) -> String {
            switch self {
            case .none: return l.tr(zh: "不重复", en: "Never", de: "Nie")
            case .daily: return l.tr(zh: "每天", en: "Daily", de: "Täglich")
            case .weekly: return l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
            case .monthly: return l.tr(zh: "每月", en: "Monthly", de: "Monatlich")
            case .custom: return l.tr(zh: "自定义", en: "Custom", de: "Eigen")
            }
        }

        var presetDays: Int? {
            switch self {
            case .none: return nil
            case .daily: return 1
            case .weekly: return 7
            case .monthly: return 30
            case .custom: return nil
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isSaving
    }

    private var manualEventTypes: [EventType] {
        EventType.allCases.filter { type in
            ![.petMedicationDose, .insurancePremium].contains(type)
        }
    }

    private var selectedRecurrenceDays: Int {
        recurrenceOption.presetDays ?? max(2, recurrenceDays)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()
                .onTapGesture {
                    titleFocused = false
                    GoKeyboard.dismiss()
                }

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        titleSection
                        eventTypeSection
                        timeSection
                        relatedSection
                        reminderSection
                        advancedSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 104)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            saveBar
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .presentationBackground(.clear)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.large]) // ui-v4: allow long calendar editor uses system sheet
        .interactiveDismissDisabled(isSaving)
        .onChange(of: startDate) { _, newValue in
            keepDependentDatesAfter(newValue)
        }
        .onChange(of: isAllDay) { _, allDay in
            let cal = Calendar.current
            if allDay {
                startDate = cal.startOfDay(for: startDate)
                endDate = cal.startOfDay(for: endDate)
            } else if endDate <= startDate {
                endDate = cal.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.addEvent)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(dateSummary)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(l.tr(zh: "标题", en: "Title", de: "Titel"))

            HStack(spacing: 10) {
                Image(systemName: eventType.silhouetteSymbol)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 32, height: 32)

                TextField(l.tr(zh: "给这件事起个名字", en: "Name this event", de: "Termin benennen"), text: $title)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .onSubmit {
                        titleFocused = false
                        GoKeyboard.dismiss()
                    }

                if !title.isEmpty {
                    Button {
                        withAnimation(GoMotion.feedback) { title = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(14)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var eventTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "类型", en: "Type", de: "Typ"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(manualEventTypes) { type in
                    let selected = eventType == type
                    Button {
                        withAnimation(GoMotion.selection) {
                            eventType = type
                            if trimmedTitle.isEmpty {
                                title = eventTypeTitle(type)
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Text(type.emoji)
                            Text(eventTypeTitle(type))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(selected ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel(l.tr(zh: "时间", en: "Time", de: "Zeit"))
                Spacer()
                Toggle(isOn: $isAllDay) {
                    Text(l.tr(zh: "全天", en: "All day", de: "Ganztägig"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .toggleStyle(.switch)
                .tint(Color.goPrimary)
                .fixedSize()
            }

            VStack(spacing: 10) {
                datePickerRow(
                    icon: "calendar",
                    title: l.tr(zh: "日期", en: "Date", de: "Datum"),
                    selection: $startDate,
                    components: .date
                )

                if !isAllDay {
                    datePickerRow(
                        icon: "clock.fill",
                        title: l.tr(zh: "时间", en: "Hour", de: "Uhrzeit"),
                        selection: $startDate,
                        components: .hourAndMinute
                    )
                }
            }
            .padding(12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "关联对象", en: "Link to", de: "Verknüpfen"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    relatedChip(
                        title: l.tr(zh: "无", en: "None", de: "Keine"),
                        icon: "circle.slash",
                        isSelected: relatedEntityType.isEmpty,
                        tint: Color.goPrimary
                    ) {
                        relatedEntityType = ""
                        relatedEntityId = ""
                    }

                    ForEach(pets) { pet in
                        relatedPersonChip(
                            title: pet.name,
                            imageData: pet.avatarImageData,
                            fallback: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                            tint: Color(hex: pet.safeThemeColorHex),
                            isSelected: relatedEntityId == pet.id.uuidString
                        ) {
                            relatedEntityType = EntityKind.pet.rawValue
                            relatedEntityId = pet.id.uuidString
                        }
                    }

                    ForEach(humans) { human in
                        relatedPersonChip(
                            title: human.name,
                            imageData: human.avatarImageData,
                            fallback: human.avatarEmoji.isEmpty ? "🙂" : human.avatarEmoji,
                            tint: Color(hex: human.safeThemeColorHex),
                            isSelected: relatedEntityId == human.id.uuidString
                        ) {
                            relatedEntityType = EntityKind.human.rawValue
                            relatedEntityId = human.id.uuidString
                        }
                    }

                    ForEach(plants) { plant in
                        relatedPersonChip(
                            title: plant.name,
                            imageData: plant.avatarImageData,
                            fallback: plant.avatarEmoji,
                            tint: Color(hex: plant.themeColorHex),
                            isSelected: relatedEntityId == plant.id.uuidString
                        ) {
                            relatedEntityType = EntityKind.plant.rawValue
                            relatedEntityId = plant.id.uuidString
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var reminderSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: hasReminder ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(hasReminder ? Color.goPrimary : Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(reminderSummary)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                Toggle("", isOn: $hasReminder)
                    .labelsHidden()
                    .tint(Color.goPrimary)
            }
            .padding(14)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(GoMotion.page) { showsAdvanced.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .black))
                    Text(l.tr(zh: "更多", en: "More", de: "Mehr"))
                        .font(OhanaFont.callout(.black))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .rotationEffect(.degrees(showsAdvanced ? 180 : 0))
                }
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if showsAdvanced {
                VStack(spacing: 14) {
                    endDateSection
                    recurrenceSection
                    if hasReminder { reminderAdvanceSection }
                    assigneeSection
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var endDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $hasEndDate) {
                sectionLabel(isAllDay ? l.tr(zh: "结束日期", en: "End date", de: "Enddatum") : l.tr(zh: "结束时间", en: "End time", de: "Endzeit"))
            }
            .tint(Color.goPrimary)
            .onChange(of: hasEndDate) { _, on in
                if on { keepDependentDatesAfter(startDate) }
            }

            if hasEndDate {
                VStack(spacing: 10) {
                    datePickerRow(
                        icon: "calendar.badge.clock",
                        title: l.tr(zh: "日期", en: "Date", de: "Datum"),
                        selection: $endDate,
                        components: .date
                    )
                    if !isAllDay {
                        datePickerRow(
                            icon: "clock",
                            title: l.tr(zh: "时间", en: "Hour", de: "Uhrzeit"),
                            selection: $endDate,
                            components: .hourAndMinute
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "循环", en: "Repeat", de: "Wiederholen"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(RecurrenceOption.allCases) { option in
                    recurrenceChip(option)
                }
            }

            if recurrenceOption == .custom {
                Stepper(value: $recurrenceDays, in: 2...365) {
                    Text(l.tr(zh: "每 \(recurrenceDays) 天", en: "Every \(recurrenceDays) days", de: "Alle \(recurrenceDays) Tage"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .tint(Color.goPrimary)
                .padding(12)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if recurrenceOption != .none {
                Toggle(isOn: $hasRecurrenceEnd) {
                    Text(l.tr(zh: "循环结束日期", en: "Repeat end date", de: "Enddatum"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .tint(Color.goPrimary)

                if hasRecurrenceEnd {
                    datePickerRow(
                        icon: "calendar.badge.exclamationmark",
                        title: l.tr(zh: "结束", en: "End", de: "Ende"),
                        selection: $recurrenceEndDate,
                        components: .date
                    )
                    .padding(12)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var reminderAdvanceSection: some View {
        Stepper(value: $reminderAdvanceDays, in: 0...30) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "提前提醒", en: "Remind before", de: "Vorher erinnern"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(reminderSummary)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .tint(Color.goPrimary)
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var assigneeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "执行人", en: "Assignee", de: "Zuständig"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    relatedChip(
                        title: l.tr(zh: "任何人", en: "Anyone", de: "Alle"),
                        icon: "person.2.fill",
                        isSelected: assigneeId == nil,
                        tint: Color.goPrimary
                    ) {
                        assigneeId = nil
                    }

                    ForEach(humans) { human in
                        relatedPersonChip(
                            title: human.name,
                            imageData: human.avatarImageData,
                            fallback: human.avatarEmoji.isEmpty ? "🙂" : human.avatarEmoji,
                            tint: Color(hex: human.safeThemeColorHex),
                            isSelected: assigneeId == human.id.uuidString
                        ) {
                            assigneeId = human.id.uuidString
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, Color.ohanaCardSurfaceElevated.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 22)

            Button {
                saveEvent()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: didSave ? "checkmark.circle.fill" : "calendar.badge.plus")
                    Text(didSave ? l.tr(zh: "已添加", en: "Added", de: "Hinzugefügt") : l.addEvent)
                }
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(canSave ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(Color.ohanaCardSurfaceElevated.opacity(0.92))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var dateSummary: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateFormat = isAllDay
            ? AppLanguage.compactMonthDayFormat
            : "\(AppLanguage.compactMonthDayFormat) HH:mm"
        return formatter.string(from: startDate)
    }

    private var reminderSummary: String {
        guard hasReminder else {
            return l.tr(zh: "不创建提醒", en: "No reminder", de: "Keine Erinnerung")
        }
        if reminderAdvanceDays == 0 {
            return l.tr(zh: "准时提醒", en: "At event time", de: "Zur Terminzeit")
        }
        return l.tr(zh: "提前 \(reminderAdvanceDays) 天", en: "\(reminderAdvanceDays)d before", de: "\(reminderAdvanceDays) Tage vorher")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func datePickerRow(
        icon: String,
        title: String,
        selection: Binding<Date>,
        components: DatePickerComponents
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 28, height: 28)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            Spacer()

            DatePicker("", selection: selection, displayedComponents: components)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.goPrimary)
        }
    }

    private func recurrenceChip(_ option: RecurrenceOption) -> some View {
        let selected = recurrenceOption == option
        return Button {
            withAnimation(GoMotion.selection) {
                recurrenceOption = option
                if option == .custom {
                    recurrenceDays = max(recurrenceDays, 2)
                } else if option == .none {
                    hasRecurrenceEnd = false
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(option.title(l))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(selected ? Color.arkInk : Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func relatedChip(
        title: String,
        icon: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(GoMotion.selection) { action() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .lineLimit(1)
            }
            .font(OhanaFont.caption(.black))
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 9)
            .background(isSelected ? tint : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func relatedPersonChip(
        title: String,
        imageData: Data?,
        fallback: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(GoMotion.selection) { action() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 7) {
                PetAvatarPortraitView(
                    imageData: imageData,
                    fallbackText: fallback,
                    themeColor: tint,
                    size: 26,
                    backgroundOpacity: isSelected ? 0.24 : 0.16,
                    transparentScale: 0.72,
                    transparentYOffset: 0.03
                )
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .font(OhanaFont.caption(.black))
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .padding(.vertical, 7)
            .background(isSelected ? tint : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func eventTypeTitle(_ type: EventType) -> String {
        switch type {
        case .birthday: return l.tr(zh: "生日", en: "Birthday", de: "Geburtstag")
        case .anniversary: return l.tr(zh: "纪念日", en: "Anniversary", de: "Jahrestag")
        case .daily: return l.tr(zh: "日常", en: "Daily", de: "Alltag")
        case .health: return l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .task: return l.tr(zh: "任务", en: "Task", de: "Aufgabe")
        case .shoppingList: return l.tr(zh: "购物", en: "Shopping", de: "Einkauf")
        case .chore: return l.tr(zh: "家务", en: "Chore", de: "Haushalt")
        case .vaccine: return l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .externalDeworming: return l.tr(zh: "体外驱虫", en: "External", de: "Äußerlich")
        case .internalDeworming: return l.tr(zh: "体内驱虫", en: "Internal", de: "Innerlich")
        case .grooming: return l.tr(zh: "护理", en: "Grooming", de: "Pflege")
        case .vetVisit: return l.tr(zh: "就医", en: "Vet", de: "Tierarzt")
        case .foodChange: return l.tr(zh: "饮食", en: "Food", de: "Futter")
        case .litterBox: return l.tr(zh: "猫砂", en: "Litter", de: "Streu")
        case .watering: return l.tr(zh: "浇水", en: "Water", de: "Gießen")
        case .fertilizing: return l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        case .medication: return l.tr(zh: "吃药", en: "Medication", de: "Medizin")
        case .petMedicationDose: return l.tr(zh: "喂药", en: "Dose", de: "Dosis")
        case .insurancePremium: return l.tr(zh: "保险", en: "Insurance", de: "Versicherung")
        }
    }

    private func keepDependentDatesAfter(_ base: Date) {
        let cal = Calendar.current
        if hasEndDate, endDate < base {
            endDate = isAllDay ? cal.startOfDay(for: base) : (cal.date(byAdding: .hour, value: 1, to: base) ?? base)
        }
        if recurrenceEndDate < base {
            recurrenceEndDate = cal.date(byAdding: .month, value: 1, to: base) ?? base
        }
    }

    private func saveEvent() {
        guard canSave else { return }
        isSaving = true
        titleFocused = false
        GoKeyboard.dismiss()

        let repeats = recurrenceOption != .none
        let event = Event(
            title: trimmedTitle,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            isAllDay: isAllDay,
            eventType: eventType.rawValue,
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityId
        )
        event.recurrenceDays = repeats ? selectedRecurrenceDays : 0
        event.recurrenceEndDate = repeats && hasRecurrenceEnd ? recurrenceEndDate : nil
        event.assigneeId = assigneeId
        modelContext.insert(event)
        var createdReminders: [Reminder] = []

        if hasReminder {
            let cal = Calendar.current
            if repeats && selectedRecurrenceDays >= 1 {
                let hardCap: Date = hasRecurrenceEnd
                    ? recurrenceEndDate
                    : (cal.date(byAdding: .day, value: 365, to: startDate) ?? startDate)
                var cursor = startDate
                var safetyCount = 0
                let maxOccurrences = 500
                while cursor <= hardCap && safetyCount < maxOccurrences {
                    let scheduled = cal.date(byAdding: .day, value: -reminderAdvanceDays, to: cursor) ?? cursor
                    let reminder = Reminder(event: event, scheduledAt: scheduled)
                    modelContext.insert(reminder)
                    createdReminders.append(reminder)
                    guard let next = cal.date(byAdding: .day, value: selectedRecurrenceDays, to: cursor),
                          next > cursor else { break }
                    cursor = next
                    safetyCount += 1
                }
            } else {
                let scheduled = cal.date(byAdding: .day, value: -reminderAdvanceDays, to: startDate) ?? startDate
                let reminder = Reminder(event: event, scheduledAt: scheduled)
                modelContext.insert(reminder)
                createdReminders.append(reminder)
            }
        }

        modelContext.safeSave()
        if !createdReminders.isEmpty {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleManyIfNeeded(reminders: createdReminders, context: modelContext, source: .calendar)
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(GoMotion.feedback) { didSave = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dismiss()
        }
    }
}
