//
//  AddEventView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI
import UIKit

struct AddEventContentView: View {
    var onClose: (() -> Void)?
    let pets: [Pet]
    let humans: [Human]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaInlinePageSafeAreaInsets) private var inlinePageSafeAreaInsets
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""

    @State private var title = ""
    @State private var eventType: EventType = .daily
    @State private var startDate = Date()
    @State private var isAllDay = false
    @State private var relatedEntityType = ""
    @State private var relatedEntityId = ""
    @State private var recurrenceOption: RecurrenceOption = .none
    @State private var recurrenceDays = 2
    @State private var recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var reminderLeadOption: ReminderLeadOption = .thirtyMinutes
    @State private var hasReminder = true
    @State private var assigneeId: String? = nil
    @State private var showsTypePicker = false
    @State private var isSaving = false
    @State private var didSave = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @FocusState private var titleFocused: Bool

    private var l: L10n { L10n(appLanguage) }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var activeHumans: [Human] { humans.filter { !$0.hasPassedAway } }

    private enum RecurrenceOption: String, CaseIterable, Identifiable {
        case none
        case daily
        case weekly
        case monthly
        case custom

        var id: String { rawValue }

        func title(_ l: L10n) -> String {
            switch self {
            case .none: l.tr(zh: "不重复", en: "Never", de: "Nie")
            case .daily: l.tr(zh: "每天", en: "Daily", de: "Täglich")
            case .weekly: l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
            case .monthly: l.tr(zh: "每月", en: "Monthly", de: "Monatlich")
            case .custom: l.tr(zh: "自定义", en: "Custom", de: "Eigen")
            }
        }

        var presetDays: Int? {
            switch self {
            case .none: nil
            case .daily: 1
            case .weekly: 7
            case .monthly: 30
            case .custom: nil
            }
        }
    }

    private enum ReminderLeadOption: Int, CaseIterable, Identifiable {
        case thirtyMinutes = 30
        case oneHour = 60
        case threeHours = 180
        case oneDay = 1440

        var id: Int { rawValue }

        func title(_ l: L10n) -> String {
            switch self {
            case .thirtyMinutes: l.tr(zh: "前30分钟", en: "30m before", de: "30 Min. vorher")
            case .oneHour: l.tr(zh: "前1小时", en: "1h before", de: "1 Std. vorher")
            case .threeHours: l.tr(zh: "前3小时", en: "3h before", de: "3 Std. vorher")
            case .oneDay: l.tr(zh: "前一天", en: "1 day before", de: "1 Tag vorher")
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
        [.daily, .task, .health, .birthday, .anniversary, .chore, .shoppingList, .medication, .petMedication]
    }

    private var visibleRecurrenceOptions: [RecurrenceOption] {
        [.none, .daily, .weekly, .monthly]
    }

    private var allowedReminderLeadOptions: [ReminderLeadOption] {
        recurrenceOption == .none
            ? [.thirtyMinutes, .oneHour, .threeHours, .oneDay]
            : [.thirtyMinutes, .oneHour, .threeHours]
    }

    private var selectedRecurrenceDays: Int {
        recurrenceOption.presetDays ?? max(2, recurrenceDays)
    }

    var body: some View {
        GeometryReader { proxy in
            let effectiveSafeTop = max(proxy.safeAreaInsets.top, inlinePageSafeAreaInsets.top)
            let effectiveSafeBottom = max(proxy.safeAreaInsets.bottom, inlinePageSafeAreaInsets.bottom)
            let headerTopInset = max(14, effectiveSafeTop + 12)
            let bottomControlInset = max(18, effectiveSafeBottom + 14)

            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()
                    .onTapGesture {
                        titleFocused = false
                        showsTypePicker = false
                        GoKeyboard.dismiss()
                    }

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, headerTopInset)
                        .padding(.bottom, 10)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            titleSection
                                .zIndex(showsTypePicker ? 10 : 0)
                            timeSection
                            recurrenceSection
                            if recurrenceOption != .none {
                                recurrenceEndSection
                            }
                            reminderLeadSection
                            relatedSection
                            assigneeSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, bottomControlInset + 86)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }

                saveBar(safeBottom: bottomControlInset)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ohanaSheetPagePresentation() // ui-v4: allow long calendar editor uses system sheet
        .interactiveDismissDisabled(isSaving)
        .onChange(of: startDate) { _, newValue in
            keepDependentDatesAfter(newValue)
        }
        .onChange(of: recurrenceOption) { _, option in
            normalizeRecurrenceState(for: option)
        }
        .onChange(of: isAllDay) { _, allDay in
            let cal = Calendar.current
            if allDay {
                startDate = cal.startOfDay(for: startDate)
            }
        }
        .onAppear {
            if assigneeId == nil, activeHumans.contains(where: { $0.id.uuidString == currentActiveHumanId }) {
                assigneeId = currentActiveHumanId
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.addEvent)
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(dateSummary)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                closeEditor()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
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

            ZStack(alignment: .topLeading) {
                HStack(spacing: 10) {
                    Button {
                        titleFocused = false
                        GoKeyboard.dismiss()
                        withAnimation(GoMotion.selection) { showsTypePicker.toggle() }
                        OhanaFeedback.light()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: eventType.silhouetteSymbol)
                                .font(OhanaFont.adaptive(size: 18, weight: .black))
                            Image(systemName: "chevron.down").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 8, weight: .black))
                                .rotationEffect(.degrees(showsTypePicker ? 180 : 0))
                                .offset(y: 1)
                        }
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 46, height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "更换类型", en: "Change type", de: "Typ ändern"))

                    TextField(l.tr(zh: "给这件事起个名字", en: "Name this event", de: "Termin benennen"), text: $title) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .onSubmit {
                            titleFocused = false
                            GoKeyboard.dismiss()
                        }
                        .accessibilityIdentifier("add-event-title-input")

                    if !title.isEmpty {
                        Button {
                            withAnimation(GoMotion.feedback) { title = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 17, weight: .bold))
                                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

                if showsTypePicker {
                    eventTypeAnchorMenu
                        .offset(x: 14, y: 54)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity),
                            removal: .scale(scale: 0.98, anchor: .topLeading).combined(with: .opacity)
                        ))
                        .zIndex(4)
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
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
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

                    ForEach(activePets) { pet in
                        relatedPersonChip(
                            title: pet.name,
                            imageData: pet.avatarImageData,
                            fallback: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                            tint: Color(hex: pet.safeThemeColorHex),
                            identifier: "add-event-related-pet-\(pet.name)",
                            isSelected: relatedEntityId == pet.id.uuidString
                        ) {
                            relatedEntityType = EntityKind.pet.rawValue
                            relatedEntityId = pet.id.uuidString
                        }
                    }

                    ForEach(activeHumans) { human in
                        relatedPersonChip(
                            title: human.name,
                            imageData: human.avatarImageData,
                            fallback: human.avatarEmoji.isEmpty ? "🙂" : human.avatarEmoji,
                            tint: Color(hex: human.safeThemeColorHex),
                            identifier: "add-event-related-human-\(human.name)",
                            isSelected: relatedEntityId == human.id.uuidString
                        ) {
                            relatedEntityType = EntityKind.human.rawValue
                            relatedEntityId = human.id.uuidString
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "循环", en: "Repeat", de: "Wiederholen"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(visibleRecurrenceOptions) { option in
                    recurrenceChip(option)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var recurrenceEndSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "结束日期", en: "End date", de: "Enddatum"))
            datePickerRow(
                icon: "calendar.badge.exclamationmark",
                title: l.tr(zh: "结束", en: "End", de: "Ende"),
                selection: $recurrenceEndDate,
                components: .date
            )
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var reminderLeadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l.tr(zh: "提前提醒", en: "Remind before", de: "Vorher erinnern"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(allowedReminderLeadOptions) { option in
                    let selected = reminderLeadOption == option
                    Button {
                        withAnimation(GoMotion.selection) { reminderLeadOption = option }
                        OhanaFeedback.light()
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
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
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

                    ForEach(activeHumans) { human in
                        relatedPersonChip(
                            title: human.name,
                            imageData: human.avatarImageData,
                            fallback: human.avatarEmoji.isEmpty ? "🙂" : human.avatarEmoji,
                            tint: Color(hex: human.safeThemeColorHex),
                            identifier: "add-event-assignee-human-\(human.name)",
                            isSelected: assigneeId == human.id.uuidString
                        ) {
                            assigneeId = human.id.uuidString
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func saveBar(safeBottom: CGFloat) -> some View {
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
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(canSave ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSave)
            .accessibilityIdentifier("add-event-save-action")
            .padding(.horizontal, 20)
            .padding(.bottom, safeBottom)
            .background {
                Color.ohanaCardSurfaceElevated
                    .opacity(0.92)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
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
        reminderLeadOption.title(l)
    }

    private var recurrenceEndOfDay: Date {
        let day = Calendar.current.startOfDay(for: recurrenceEndDate)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: day) ?? recurrenceEndDate
    }

    private var eventCommandInput: CalendarEventPlanCommandInput {
        let repeats = recurrenceOption != .none
        return CalendarEventPlanCommandInput(
            title: title,
            startDate: startDate,
            isAllDay: isAllDay,
            eventType: eventType,
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityId,
            recurrenceDays: repeats ? selectedRecurrenceDays : 0,
            recurrenceEndDate: repeats ? recurrenceEndOfDay : nil,
            reminderLeadMinutes: hasReminder ? reminderLeadOption.rawValue : nil,
            assigneeId: assigneeId
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private var eventTypeAnchorMenu: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(manualEventTypes) { type in
                eventTypeAnchorMenuCell(type)
            }
        }
        .padding(10)
        .frame(width: 268)
        .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.cardLarge) }
        .shadow(color: Color.black.opacity(0.34), radius: 24, x: 0, y: 14) // ui-v4: allow anchored menu shadow
    }

    private func eventTypeAnchorMenuCell(_ type: EventType) -> some View {
        let selected = eventType == type
        return Button {
            withAnimation(GoMotion.selection) {
                eventType = type
                if trimmedTitle.isEmpty {
                    title = eventTypeTitle(type)
                }
                showsTypePicker = false
            }
            OhanaFeedback.light()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type.silhouetteSymbol)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 20, height: 20) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

                Text(eventTypeTitle(type))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer()

                if selected {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(selected ? Color.goPrimary.opacity(0.16) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func datePickerRow(
        icon: String,
        title: String,
        selection: Binding<Date>,
        components: DatePickerComponents
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

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
            }
            OhanaFeedback.light()
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

    private func normalizeRecurrenceState(for option: RecurrenceOption) {
        if option == .none {
            return
        } else {
            if !allowedReminderLeadOptions.contains(reminderLeadOption) {
                withAnimation(GoMotion.selection) { reminderLeadOption = .threeHours }
            }
            keepDependentDatesAfter(startDate)
        }
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
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
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
        identifier: String,
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
        .accessibilityIdentifier(identifier)
    }

    private func eventTypeTitle(_ type: EventType) -> String {
        switch type {
        case .birthday: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag")
        case .anniversary: l.tr(zh: "纪念日", en: "Anniversary", de: "Jahrestag")
        case .daily: l.tr(zh: "日常", en: "Daily", de: "Alltag")
        case .health: l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .task: l.tr(zh: "任务", en: "Task", de: "Aufgabe")
        case .shoppingList: l.tr(zh: "购物", en: "Shopping", de: "Einkauf")
        case .chore: l.tr(zh: "家务", en: "Chore", de: "Haushalt")
        case .vaccine: l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .externalDeworming: l.tr(zh: "体外驱虫", en: "External", de: "Äußerlich")
        case .internalDeworming: l.tr(zh: "体内驱虫", en: "Internal", de: "Innerlich")
        case .grooming: l.tr(zh: "护理", en: "Grooming", de: "Pflege")
        case .vetVisit: l.tr(zh: "就医", en: "Vet", de: "Tierarzt")
        case .foodChange: l.tr(zh: "饮食", en: "Food", de: "Futter")
        case .litterBox: l.tr(zh: "猫砂", en: "Litter", de: "Streu")
        case .watering: l.tr(zh: "浇水", en: "Water", de: "Gießen")
        case .fertilizing: l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        case .plantRepotting: l.tr(zh: "换盆", en: "Repot", de: "Umtopfen")
        case .plantPruning: l.tr(zh: "修剪", en: "Prune", de: "Schneiden")
        case .plantMisting: l.tr(zh: "喷雾", en: "Mist", de: "Besprühen")
        case .plantRotation: l.tr(zh: "转盆", en: "Rotate", de: "Drehen")
        case .plantLeafCleaning: l.tr(zh: "清洁叶片", en: "Clean leaves", de: "Blätter reinigen")
        case .plantPestCheck: l.tr(zh: "病虫害检查", en: "Pest check", de: "Schädlingscheck")
        case .plantHealthCheck: l.tr(zh: "植物状态", en: "Plant status", de: "Pflanzenstatus")
        case .medication: l.tr(zh: "吃药", en: "Medication", de: "Medizin")
        case .petMedication: l.tr(zh: "宠物用药", en: "Pet meds", de: "Tiermedizin")
        case .petMedicationDose: l.tr(zh: "喂药", en: "Dose", de: "Dosis")
        case .insurancePremium: l.tr(zh: "保险", en: "Insurance", de: "Versicherung")
        }
    }

    private func keepDependentDatesAfter(_ base: Date) {
        let cal = Calendar.current
        if recurrenceEndDate < base {
            recurrenceEndDate = cal.date(byAdding: .month, value: 1, to: base) ?? base
        }
    }

    private func saveEvent() {
        guard canSave else { return }
        let input = eventCommandInput
        let command = DomainCommand.calendarEventPlan(eventID: nil)
        isSaving = true
        titleFocused = false
        GoKeyboard.dismiss()

        commandQueue.enqueue(command) {
            let executor = CalendarCommandExecutor(context: modelContext, services: appServices)
            guard executor.createEvent(input: input) != nil else {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(GoMotion.feedback) { didSave = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                closeEditor()
            }
        }
    }

    private func closeEditor() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
