//
//  PetMedicationView.swift
//  Ohana
//
//  Pet medication cockpit using V4 interaction rules.
//

import SwiftData
import SwiftUI

struct PetMedicationContentView: View {
    let pet: Pet
    let medications: [PetMedication]
    let doseEvents: [Event]
    var onDataChanged: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var showingAddSheet = false
    @State private var selectedMedication: PetMedication?
    @State private var doseRefreshToken = UUID()
    @State private var toastMessage: String?

    private var l: L10n { L10n(appLanguage) }
    private var chromeAccent: Color { colorScheme == .dark ? Color.goPrimary : Color.goBlue }
    private var medicationEvents: [Event] {
        let ids = Set(medications.map(\.id))
        return doseEvents.filter {
            guard let medicationId = PetMedicationDoseLogging.doseMedicationId(for: $0) else { return false }
            return ids.contains(medicationId)
        }
    }

    private var activeMeds: [PetMedication] {
        medications
            .filter(\.isActiveToday)
            .sorted { medicationSortKey($0) < medicationSortKey($1) }
    }

    private var inactiveMeds: [PetMedication] {
        medications
            .filter { !$0.isActiveToday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var todayRequired: Int {
        _ = doseRefreshToken
        return activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.requiredDoses(on: Date(), for: $1) }
    }

    private var todayDone: Int {
        _ = doseRefreshToken
        return activeMeds.reduce(0) {
            $0 + min(
                PetMedicationDoseLogging.todayDoseCount(events: medicationEvents, medicationId: $1.id),
                max(0, PetMedicationDoseLogging.requiredDoses(on: Date(), for: $1))
            )
        }
    }

    private var pendingMedication: PetMedication? {
        activeMeds.first { remainingDoses(for: $0) > 0 }
    }

    private var bodyTitle: String {
        if pet.hasPassedAway {
            return l.tr(zh: "纪念模式", en: "Memorial", de: "Gedenken")
        }
        if todayRequired == 0 {
            return l.tr(zh: "没有固定剂量", en: "No scheduled dose", de: "Keine feste Dosis")
        }
        if todayDone >= todayRequired {
            return l.tr(zh: "今天已完成", en: "Done today", de: "Heute erledigt")
        }
        return l.tr(
            zh: "还需 \(todayRequired - todayDone) 次",
            en: "\(todayRequired - todayDone) dose(s) left",
            de: "\(todayRequired - todayDone) Dosis offen"
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                OhanaAppBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if pet.hasPassedAway {
                            PetMemorialBanner(pet: pet)
                        }

                        summaryStrip

                        if !medications.isEmpty {
                            medicationRhythmStrip
                        }

                        if medications.isEmpty {
                            emptyState
                        } else {
                            todayPanel

                            if !activeMeds.isEmpty {
                                medicationSection(
                                    title: l.tr(zh: "当前用药", en: "Current medication", de: "Aktuelle Medikamente"),
                                    subtitle: l.tr(zh: "今天需要处理的剂量", en: "Doses to handle today", de: "Heutige Dosen"),
                                    meds: activeMeds
                                )
                            }

                            if !inactiveMeds.isEmpty {
                                medicationSection(
                                    title: l.tr(zh: "历史用药", en: "History", de: "Verlauf"),
                                    subtitle: l.tr(zh: "已结束或未开始的疗程", en: "Stopped or not started", de: "Beendet oder noch nicht begonnen"),
                                    meds: inactiveMeds
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 38)
                    .petMemorialTone(isActive: pet.hasPassedAway)
                }

                if let toastMessage {
                    Text(toastMessage)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.goPrimary, in: Capsule())
                        .padding(.bottom, 18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if showingAddSheet {
                    addMedicationOverlay
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !pet.hasPassedAway, !showingAddSheet {
                    addMedicationFab
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                        .transition(
                            .scale(scale: 0.86, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                        )
                }
            }
            .sheet(item: $selectedMedication) { med in
                PetMedicationDetailSheet(pet: pet, medication: med, onDataChanged: onDataChanged)
            }
            .animation(GoMotion.stateChange, value: doseRefreshToken)
            .animation(GoMotion.feedback, value: toastMessage)
            .animation(GoMotion.sheet, value: showingAddSheet)
        }
    }

    private var addMedicationOverlay: some View {
        GeometryReader { proxy in
            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: showingAddSheet) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.16 : 0.08), // ui-v4: allow modal scrim
                        Color.black.opacity(colorScheme == .dark ? 0.42 : 0.22) // ui-v4: allow modal scrim
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    closeAddMedicationPopup()
                }

                AddPetMedicationSheet(
                    pet: pet,
                    isInlinePopup: true,
                    onClose: closeAddMedicationPopup,
                    onSaved: {
                        appServices.medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
                        doseRefreshToken = UUID()
                        onDataChanged?()
                        closeAddMedicationPopup()
                    }
                )
                .frame(maxHeight: min(proxy.size.height * 0.88, 690))
                .padding(.horizontal, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 6)
            }
            .animation(GoMotion.sheet, value: showingAddSheet)
        }
        .ignoresSafeArea()
        .zIndex(40)
    }

    private var addMedicationFab: some View {
        Button {
            openAddMedicationPopup()
        } label: {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 22, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 60, height: 60)
                .background(chromeAccent, in: Circle())
                .shadow(color: chromeAccent.opacity(0.26), radius: 18, x: 0, y: 10) // ui-v4: allow floating FAB lift
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen"))
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageCacheID: "pet-medication-\(pet.id.uuidString)",
                imageSignature: pet.avatarThumbnailSignature,
                petModelID: pet.persistentModelID,
                emoji: pet.avatarEmoji,
                fallback: "🐾",
                tint: Color(hex: pet.safeThemeColorHex)
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "用药管理", en: "Medication", de: "Medikation"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(pet.name)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(bodyTitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var summaryStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                medicationMetricCell(
                    title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                    value: todayRequired == 0 ? "—" : "\(todayDone)/\(todayRequired)"
                )
                medicationMetricCell(
                    title: l.tr(zh: "当前", en: "Active", de: "Aktiv"),
                    value: "\(activeMeds.count)"
                )
                medicationMetricCell(
                    title: l.tr(zh: "待处理", en: "Pending", de: "Offen"),
                    value: "\(max(0, todayRequired - todayDone))"
                )
            }

            VStack(spacing: 10) {
                medicationMetricCell(
                    title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                    value: todayRequired == 0 ? "—" : "\(todayDone)/\(todayRequired)"
                )
                medicationMetricCell(
                    title: l.tr(zh: "当前", en: "Active", de: "Aktiv"),
                    value: "\(activeMeds.count)"
                )
                medicationMetricCell(
                    title: l.tr(zh: "待处理", en: "Pending", de: "Offen"),
                    value: "\(max(0, todayRequired - todayDone))"
                )
            }
        }
    }

    private var rhythmDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (-13 ... 0).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    private var medicationRhythmStrip: some View {
        let days = rhythmDays
        let completedDays = days.count(where: { day in
            let stats = medicationDayStats(for: day)
            return stats.required > 0 && stats.done >= stats.required
        })
        let plannedDays = days.count(where: { medicationDayStats(for: $0).required > 0 })

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Label {
                    Text(l.tr(zh: "用药节奏", en: "Medication rhythm", de: "Medikamentenrhythmus"))
                } icon: {
                    Image(systemName: "calendar.badge.checkmark").accessibilityHidden(true)
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(plannedDays == 0 ? "—" : "\(completedDays)/\(plannedDays)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(chromeAccent)
                    .contentTransition(.numericText())
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days, id: \.self) { day in
                    medicationRhythmDay(day)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func medicationRhythmDay(_ day: Date) -> some View {
        let stats = medicationDayStats(for: day)
        let progress = stats.required == 0 ? 0 : min(1, Double(stats.done) / Double(stats.required))
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let tint: Color = {
            if stats.required == 0 { return Color.ohanaTertiaryText.opacity(0.42) }
            if stats.done >= stats.required { return Color.goTeal }
            if stats.done > 0 { return Color.goOrange }
            return isToday ? chromeAccent : Color.goRed.opacity(0.82)
        }()

        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: OhanaRadius.tiny, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .frame(width: 14, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                RoundedRectangle(cornerRadius: OhanaRadius.tiny, style: .continuous)
                    .fill(tint)
                    .frame(width: 14, height: max(stats.required == 0 ? 4 : 6, 34 * progress))
                    .animation(GoMotion.stateChange, value: progress)
            }
            Text(isToday ? l.tr(zh: "今", en: "T", de: "H") : "\(cal.component(.day, from: day))")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(isToday ? chromeAccent : Color.ohanaTertiaryText)
                .frame(width: 20)
        }
        .accessibilityLabel(medicationRhythmAccessibility(for: day, stats: stats))
    }

    private func medicationDayStats(for day: Date) -> (required: Int, done: Int) {
        let required = medications.reduce(0) { total, medication in
            total + PetMedicationDoseLogging.requiredDoses(on: day, for: medication)
        }
        let done = medications.reduce(0) { total, medication in
            let count = medicationEvents.count(where: { event in
                PetMedicationDoseLogging.isDoseEvent(event, medicationId: medication.id) &&
                    Calendar.current.isDate(event.startDate, inSameDayAs: day)
            })
            return total + min(count, max(0, PetMedicationDoseLogging.requiredDoses(on: day, for: medication)))
        }
        return (required, done)
    }

    private func medicationRhythmAccessibility(for day: Date, stats: (required: Int, done: Int)) -> String {
        let dateText = day.formatted(.dateTime.month().day())
        if stats.required == 0 {
            return "\(dateText) \(l.tr(zh: "无固定用药", en: "No scheduled medication", de: "Keine geplante Medikation"))"
        }
        return "\(dateText) \(stats.done)/\(stats.required)"
    }

    private func medicationMetricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .ohanaNumericMotion(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: todayDone >= todayRequired && todayRequired > 0 ? "checkmark.circle.fill" : "pills.fill")
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(todayDone >= todayRequired && todayRequired > 0 ? Color.goTeal : chromeAccent)
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background((todayDone >= todayRequired && todayRequired > 0 ? Color.goTeal : chromeAccent).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(bodyTitle)
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(todayPanelSubtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Spacer()
            }

            ProgressView(value: todayRequired == 0 ? 0 : Double(min(todayDone, todayRequired)) / Double(todayRequired))
                .tint(todayDone >= todayRequired && todayRequired > 0 ? Color.goTeal : chromeAccent)
                .scaleEffect(x: 1, y: 1.35, anchor: .center)

            if let pendingMedication, !pet.hasPassedAway {
                Button {
                    recordDose(for: pendingMedication)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                        Text(l.tr(zh: "直接打卡", en: "Check in", de: "Abhaken"))
                        Spacer()
                        Text(pendingMedication.dosage.isEmpty ? l.tr(zh: "按医嘱", en: "As directed", de: "Nach Anweisung") : pendingMedication.dosage)
                            .font(OhanaFont.caption(.black))
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(chromeAccent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var todayPanelSubtitle: String {
        guard let pendingMedication else {
            if todayRequired == 0 {
                return l.tr(zh: "按需药物可在药物卡片里手动记录。", en: "As-needed medication can be logged from each card.", de: "Bedarfsmedikamente kannst du über die Karte eintragen.")
            }
            return l.tr(zh: "今日所有固定用药都已经记录。", en: "All scheduled doses are recorded today.", de: "Alle geplanten Dosen sind heute erledigt.")
        }
        let name = pendingMedication.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : pendingMedication.name
        return l.tr(
            zh: "下一次：\(name) · \(pendingMedication.dosage.isEmpty ? "按医嘱" : pendingMedication.dosage)",
            en: "Next: \(name) · \(pendingMedication.dosage.isEmpty ? "as directed" : pendingMedication.dosage)",
            de: "Als Nächstes: \(name) · \(pendingMedication.dosage.isEmpty ? "nach Anweisung" : pendingMedication.dosage)"
        )
    }

    private func medicationSection(title: String, subtitle: String, meds: [PetMedication]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            ForEach(meds) { med in
                medicationCard(med)
                    .ohanaSmoothAppear(index: meds.firstIndex(where: { $0.id == med.id }) ?? 0)
            }
        }
    }

    private func medicationCard(_ med: PetMedication) -> some View {
        let required = PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
        let done = PetMedicationDoseLogging.todayDoseCount(events: medicationEvents, medicationId: med.id)
        let remaining = max(0, required - done)
        let tint = Color(hex: med.colorHex)

        return VStack(alignment: .leading, spacing: 12) {
            medicationCardHeader(for: med, tint: tint, remaining: remaining, required: required)

            if med.isActiveToday, required > 0 {
                ProgressView(value: Double(min(done, required)) / Double(required))
                    .tint(remaining == 0 ? Color.goTeal : tint)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)
            }

            medicationCardActions(for: med, remaining: remaining, tint: tint)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .onTapGesture {
            selectedMedication = med
        }
    }

    private func medicationCardHeader(for med: PetMedication, tint: Color, remaining: Int, required: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                medicationCardIcon(tint: tint)
                medicationCardText(for: med)
                Spacer(minLength: 8)
                statusPill(for: med, remaining: remaining, required: required)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    medicationCardIcon(tint: tint)
                    medicationCardText(for: med)
                }
                statusPill(for: med, remaining: remaining, required: required)
            }
        }
    }

    private func medicationCardIcon(tint: Color) -> some View {
        Image(systemName: "pills.fill").accessibilityHidden(true)
            .font(OhanaFont.adaptive(size: 18, weight: .black))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            .background(tint.opacity(0.14), in: Circle())
    }

    private func medicationCardText(for med: PetMedication) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(med.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : med.name)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(medicationSubtitle(for: med))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func medicationCardActions(for med: PetMedication, remaining: Int, tint: Color) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                medicationDetailsButton(for: med)
                if !pet.hasPassedAway, med.isActiveToday {
                    medicationCheckInButton(for: med, remaining: remaining, tint: tint)
                }
            }

            VStack(spacing: 8) {
                medicationDetailsButton(for: med)
                if !pet.hasPassedAway, med.isActiveToday {
                    medicationCheckInButton(for: med, remaining: remaining, tint: tint)
                }
            }
        }
    }

    private func medicationDetailsButton(for med: PetMedication) -> some View {
        Button {
            selectedMedication = med
        } label: {
            Text(l.tr(zh: "详情", en: "Details", de: "Details"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func medicationCheckInButton(for med: PetMedication, remaining: Int, tint: Color) -> some View {
        Button {
            recordDose(for: med)
        } label: {
            Text(remaining > 0 ? l.tr(zh: "打卡", en: "Check in", de: "Abhaken") : l.tr(zh: "加记一次", en: "Extra dose", de: "Extra"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(remaining > 0 ? chromeAccent : tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func statusPill(for med: PetMedication, remaining: Int, required: Int) -> some View {
        let done = required > 0 && remaining == 0
        let text: String = {
            if !med.isActive { return l.tr(zh: "停用", en: "Stopped", de: "Pausiert") }
            if !med.isActiveToday { return l.tr(zh: "未开始", en: "Not started", de: "Noch nicht") }
            if required == 0 { return l.tr(zh: "按需", en: "As needed", de: "Bedarf") }
            return done ? l.tr(zh: "完成", en: "Done", de: "Fertig") : "\(required - remaining)/\(required)"
        }()
        let color = done ? Color.goTeal : (med.isActiveToday ? Color(hex: med.colorHex) : Color.ohanaSecondaryText)
        return Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(done ? Color.arkInk : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(done ? Color.goTeal : color.opacity(0.14), in: Capsule())
            .ohanaNumericMotion(text)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "pills.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 30, weight: .black))
                .foregroundStyle(chromeAccent)
                .frame(width: 58, height: 58)
                .background(chromeAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            Text(l.tr(zh: "还没有用药计划", en: "No medication yet", de: "Noch keine Medikamente"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "添加药物后，Today Focus 可以直接打卡，不需要再跳进用药页。", en: "After adding medication, Today Focus can check in directly.", de: "Nach dem Hinzufügen kannst du direkt in Today Focus abhaken."))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private func medicationSubtitle(for med: PetMedication) -> String {
        let dose = med.dosage.isEmpty ? l.tr(zh: "按医嘱", en: "As directed", de: "Nach Anweisung") : med.dosage
        let times = medicationTimeSummary(for: med)
        return times.isEmpty ? "\(localizedFrequency(med.frequency)) · \(dose)" : "\(localizedFrequency(med.frequency)) · \(times) · \(dose)"
    }

    private func localizedFrequency(_ frequency: PetMedicationFrequency) -> String {
        switch frequency {
        case .daily:
            l.tr(zh: "每天", en: "Daily", de: "Täglich")
        case .twiceDaily:
            l.tr(zh: "每天两次", en: "Twice daily", de: "Zweimal täglich")
        case .threeTimesDaily:
            l.tr(zh: "每天三次", en: "Three times daily", de: "Dreimal täglich")
        case .everyOtherDay:
            l.tr(zh: "隔天", en: "Every other day", de: "Alle zwei Tage")
        case .weekly:
            l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
        case .asNeeded:
            l.tr(zh: "按需", en: "As needed", de: "Nach Bedarf")
        case .custom:
            l.tr(zh: "自定义", en: "Custom", de: "Benutzerdefiniert")
        }
    }

    private func medicationSortKey(_ med: PetMedication) -> Int {
        remainingDoses(for: med) > 0 ? 0 : 1
    }

    private func remainingDoses(for med: PetMedication) -> Int {
        let required = PetMedicationDoseLogging.requiredDoses(on: Date(), for: med)
        guard required > 0 else { return 0 }
        let done = PetMedicationDoseLogging.todayDoseCount(events: medicationEvents, medicationId: med.id)
        return max(0, required - done)
    }

    private func openAddMedicationPopup() {
        withAnimation(GoMotion.sheet) {
            showingAddSheet = true
        }
    }

    private func closeAddMedicationPopup() {
        withAnimation(GoMotion.sheet) {
            showingAddSheet = false
        }
    }

    private func medicationTimeSummary(for med: PetMedication) -> String {
        let required = PetMedicationSchedulePlan.dosesPerDay(for: med.frequency)
        guard required > 0 else { return "" }
        let minutes = PetMedicationSchedulePlan.doseMinutes(for: med, required: required)
        return minutes
            .map { minute in
                let hour = minute / 60
                let min = minute % 60
                return String(format: "%02d:%02d", hour, min)
            }
            .joined(separator: "/")
    }

    @MainActor
    private func recordDose(for med: PetMedication) {
        guard !pet.hasPassedAway else { return }
        let result = PetMedicationCommandExecutor(context: modelContext, services: appServices).recordDose(
            medication: med,
            pet: pet,
            awardCoconut: true,
            note: "pet.medication.list.dose"
        )
        guard result.didRecord, result.allowsDerivedEffects else { return }
        appServices.medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        doseRefreshToken = UUID()
        onDataChanged?()
        showToast(l.tr(zh: "已记录喂药", en: "Dose logged", de: "Dosis erfasst"))
    }

    private func showToast(_ message: String) {
        withAnimation(GoMotion.feedback) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(GoMotion.quick) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}
