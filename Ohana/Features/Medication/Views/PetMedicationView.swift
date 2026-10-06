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
    var showsCloseButton = true
    let medications: [PetMedication]
    let doseEvents: [Event]
    var onDataChanged: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var showingAddSheet = false
    @State private var selectedMedication: PetMedication?
    @State private var pendingDoseActorDraft: PetMedicationDoseActorDraft?
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
            return l.tr(
                zh: "今天无计划服药", en: "No scheduled doses today", de: "Heute keine geplanten Dosen",
                es: "Sin dosis programadas hoy", pt: "Sem doses programadas hoje", fr: "Aucune prise prévue aujourd’hui",
                ja: "今日の服薬予定はありません", ko: "오늘 예정된 투약이 없어요", it: "Nessuna dose programmata oggi"
            )
        }
        if todayDone >= todayRequired {
            return l.tr(
                zh: "今天已记录", en: "Today’s doses logged", de: "Heutige Dosen erfasst",
                es: "Dosis de hoy registradas", pt: "Doses de hoje registradas", fr: "Prises du jour enregistrées",
                ja: "今日の服薬を記録済み", ko: "오늘 투약 기록 완료", it: "Dosi di oggi registrate"
            )
        }
        return l.tr(
            zh: "待记录 \(todayRequired - todayDone) 次", en: "\(todayRequired - todayDone) to log", de: "Noch \(todayRequired - todayDone) zu erfassen",
            es: "\(todayRequired - todayDone) por registrar", pt: "\(todayRequired - todayDone) para registrar", fr: "\(todayRequired - todayDone) à enregistrer",
            ja: "あと\(todayRequired - todayDone)回を記録", ko: "\(todayRequired - todayDone)회 기록 필요", it: "\(todayRequired - todayDone) da registrare"
        )
    }

    var body: some View {
        OhanaNavigationContainer(ownsNavigationStack: showsCloseButton) {
            ZStack(alignment: .bottom) {
                OhanaAppBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if pet.hasPassedAway {
                            PetMemorialBanner(pet: pet)
                        }

                        if medications.isEmpty {
                            emptyState
                        } else {
                            todayPanel
                            summaryStrip

                            if !activeMeds.isEmpty {
                                medicationSection(
                                    title: l.tr(zh: "当前用药", en: "Current medication", de: "Aktuelle Medikamente"),
                                    meds: activeMeds
                                )
                            }

                            medicationRhythmStrip

                            if !inactiveMeds.isEmpty {
                                medicationSection(
                                    title: l.tr(zh: "历史用药", en: "History", de: "Verlauf"),
                                    meds: inactiveMeds
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 96)
                    .petMemorialTone(isActive: pet.hasPassedAway)
                }

                if let toastMessage {
                    Text(toastMessage)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.goPrimary, in: Capsule())
                        .padding(.bottom, 18)
                }
            }
            .navigationTitle(l.tr(zh: "用药", en: "Medication", de: "Medikamente", es: "Medicación", pt: "Medicação", fr: "Médicaments", ja: "服薬", ko: "복약", it: "Farmaci"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton { OhanaModalToolbar(onClose: { dismiss() }, closeIdentifier: "pet-medication-close-action") }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddPetMedicationSheet(
                    pet: pet,
                    isInlinePopup: false,
                    onClose: closeAddMedicationPopup,
                    onSaved: {
                        appServices.medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
                        doseRefreshToken = UUID()
                        onDataChanged?()
                        closeAddMedicationPopup()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
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
            .navigationDestination(item: $selectedMedication) { med in
                PetMedicationDetailSheet(pet: pet, medication: med, onDataChanged: onDataChanged)
            }
            .petMedicationDoseActorConfirmation(draft: $pendingDoseActorDraft) { draft, executorID in
                guard let medication = medications.first(where: { $0.id == draft.medicationID }) else { return }
                recordDose(for: medication, executorID: executorID)
            }
            .animation(GoMotion.stateChange, value: doseRefreshToken)
            .animation(GoMotion.feedback, value: toastMessage)
            .animation(GoMotion.sheet, value: showingAddSheet)
        }
    }

    private var addMedicationFab: some View {
        Button {
            openAddMedicationPopup()
        } label: {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 22, weight: .semibold))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 60, height: 60)
                .background(chromeAccent, in: Circle())
                .shadow(color: chromeAccent.opacity(0.26), radius: 18, x: 0, y: 10) // ui-v4: allow floating FAB lift
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen"))
    }

    private var header: some View {
        FeatureHubHeader(
            title: pet.name,
            subtitle: bodyTitle,
            eyebrow: "",
            onClose: { dismiss() },
            closeAccessibilityIdentifier: "pet-medication-close-action",
            showsCloseButton: false,
            avatar: {
                FeatureHubAvatar(
                    imageCacheID: "pet-medication-\(pet.id.uuidString)",
                    imageSignature: pet.avatarThumbnailSignature,
                    petModelID: pet.persistentModelID,
                    emoji: pet.avatarEmoji,
                    fallback: "🐾",
                    tint: Color(hex: pet.safeThemeColorHex)
                )
            }
        )
    }

    private var summaryStrip: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3),
            alignment: .leading,
            spacing: 10
        ) {
            medicationMetricCell(
                title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                value: todayRequired == 0 ? "—" : "\(todayDone)/\(todayRequired)"
            )
            medicationMetricCell(
                title: l.tr(zh: "当前", en: "Active", de: "Aktiv"),
                value: "\(activeMeds.count)"
            )
            medicationMetricCell(
                title: l.tr(
                    zh: "待记录", en: "To log", de: "Zu erfassen",
                    es: "Por registrar", pt: "Para registrar", fr: "À enregistrer",
                    ja: "未記録", ko: "기록 필요", it: "Da registrare"
                ),
                value: "\(max(0, todayRequired - todayDone))"
            )
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
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(plannedDays == 0 ? "—" : "\(completedDays)/\(plannedDays)")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(chromeAccent)
                    .contentTransition(.numericText())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        medicationRhythmDay(day)
                    }
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
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(isToday ? chromeAccent : Color.ohanaTertiaryText)
                .frame(minWidth: 20)
        }
        .accessibilityElement(children: .ignore)
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
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(OhanaFont.title3(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .ohanaNumericMotion(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: todayDone >= todayRequired && todayRequired > 0 ? "checkmark.circle.fill" : "pills.fill")
                    .font(OhanaFont.adaptive(size: 22, weight: .semibold))
                    .foregroundStyle(todayDone >= todayRequired && todayRequired > 0 ? Color.goTeal : chromeAccent)
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background((todayDone >= todayRequired && todayRequired > 0 ? Color.goTeal : chromeAccent).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(bodyTitle)
                        .font(OhanaFont.headline(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(todayPanelSubtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
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
                        Text(logDoseTitle)
                        Spacer()
                        Text(doseDescription(for: pendingMedication))
                            .font(OhanaFont.caption(.semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(chromeAccent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("\(logDoseTitle): \(medicationName(for: pendingMedication))")
                .accessibilityIdentifier("pet-medication-next-dose-action")
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var todayPanelSubtitle: String {
        guard let pendingMedication else {
            if todayRequired == 0 {
                return l.tr(zh: "按需药物可在卡片中记录", en: "Log as-needed medication from its card", de: "Bedarfsmedikamente über die Karte eintragen")
            }
            return l.tr(zh: "固定用药已记录", en: "Scheduled doses logged", de: "Geplante Dosen erfasst")
        }
        let name = medicationName(for: pendingMedication)
        let dose = doseDescription(for: pendingMedication)
        return l.tr(
            zh: "下一项：\(name) · \(dose)", en: "Next: \(name) · \(dose)", de: "Als Nächstes: \(name) · \(dose)",
            es: "Siguiente: \(name) · \(dose)", pt: "Próximo: \(name) · \(dose)", fr: "Ensuite : \(name) · \(dose)",
            ja: "次の記録：\(name) · \(dose)", ko: "다음 기록: \(name) · \(dose)", it: "Prossimo: \(name) · \(dose)"
        )
    }

    private func medicationSection(title: String, meds: [PetMedication]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.headline(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)

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
            .font(OhanaFont.adaptive(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            .background(tint.opacity(0.14), in: Circle())
    }

    private func medicationCardText(for med: PetMedication) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(medicationName(for: med))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Text(medicationSubtitle(for: med))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func medicationCardActions(for med: PetMedication, remaining: Int, tint: Color) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            medicationDetailsButton(for: med)
            if !pet.hasPassedAway, med.isActiveToday {
                medicationCheckInButton(for: med, remaining: remaining, tint: tint)
            }
        }
    }

    private func medicationDetailsButton(for med: PetMedication) -> some View {
        Button {
            selectedMedication = med
        } label: {
            Text(l.tr(zh: "详情", en: "Details", de: "Details"))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func medicationCheckInButton(for med: PetMedication, remaining: Int, tint: Color) -> some View {
        let actionForeground = remaining > 0
            ? Color.ohanaPrimaryActionText
            : (OhanaResolvedPrimaryAccent(customHex: med.colorHex)?.actionTextColor ?? Color.ohanaPrimaryText)
        let actionTitle = remaining > 0 || med.frequency == .asNeeded ? logDoseTitle : l.tr(
            zh: "补充服药记录", en: "Log another dose", de: "Weitere Einnahme erfassen",
            es: "Registrar otra toma", pt: "Registrar outra dose", fr: "Enregistrer une autre prise",
            ja: "服薬記録を追加", ko: "투약 기록 추가", it: "Registra un’altra dose"
        )

        return Button {
            recordDose(for: med)
        } label: {
            Text(actionTitle)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(actionForeground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(remaining > 0 ? chromeAccent : tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(actionTitle): \(medicationName(for: med))")
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
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(done ? Color.arkInk : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(done ? Color.goTeal : color.opacity(0.14), in: Capsule())
            .ohanaNumericMotion(text)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "pills.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 30, weight: .semibold))
                .foregroundStyle(chromeAccent)
                .frame(width: 58, height: 58)
                .background(chromeAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            Text(l.tr(zh: "还没有用药计划", en: "No medication yet", de: "Noch keine Medikamente"))
                .font(OhanaFont.title3(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            if !pet.hasPassedAway {
                Text(l.tr(
                    zh: "点按 + 添加药物",
                    en: "Tap + to add medication",
                    de: "Tippe auf +, um ein Medikament hinzuzufügen",
                    es: "Toca + para añadir un medicamento",
                    pt: "Toque em + para adicionar um medicamento",
                    fr: "Touchez + pour ajouter un médicament",
                    ja: "＋をタップして薬を追加",
                    ko: "+를 탭해 약을 추가하세요",
                    it: "Tocca + per aggiungere un farmaco"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private func medicationSubtitle(for med: PetMedication) -> String {
        let dose = doseDescription(for: med)
        let times = medicationTimeSummary(for: med)
        return times.isEmpty ? "\(localizedFrequency(med.frequency)) · \(dose)" : "\(localizedFrequency(med.frequency)) · \(times) · \(dose)"
    }

    private var logDoseTitle: String {
        l.tr(
            zh: "记录服药", en: "Log dose", de: "Einnahme erfassen",
            es: "Registrar toma", pt: "Registrar dose", fr: "Enregistrer la prise",
            ja: "服薬を記録", ko: "투약 기록", it: "Registra la dose"
        )
    }

    private func medicationName(for med: PetMedication) -> String {
        med.name.isEmpty ? l.tr(
            zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament",
            es: "Medicamento sin nombre", pt: "Medicamento sem nome", fr: "Médicament sans nom",
            ja: "名前のない薬", ko: "이름 없는 약", it: "Farmaco senza nome"
        ) : med.name
    }

    private func doseDescription(for med: PetMedication) -> String {
        med.dosage.isEmpty ? l.tr(
            zh: "按医嘱", en: "As directed", de: "Nach Anweisung",
            es: "Según indicación", pt: "Conforme orientação", fr: "Selon la prescription",
            ja: "医師の指示どおり", ko: "처방에 따라", it: "Come prescritto"
        ) : med.dosage
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
        let actorContext = PetMedicationDoseActorSelectionResolver.resolve(
            context: modelContext,
            currentLocalHumanIDRaw: appServices.activeHumanSelection.currentHumanId
        )
        guard actorContext.needsConfirmation else {
            recordDose(for: med, executorID: actorContext.defaultExecutorID)
            return
        }
        pendingDoseActorDraft = PetMedicationDoseActorDraft(
            petID: pet.id,
            medicationID: med.id,
            actionTitle: l.tr(
                zh: "给 \(pet.name) 喂 \(med.name.isEmpty ? "药" : med.name)",
                en: "Give \(pet.name) \(med.name.isEmpty ? "medicine" : med.name)",
                de: "\(pet.name) \(med.name.isEmpty ? "Medikament" : med.name) geben"
            ),
            initialExecutorID: actorContext.defaultExecutorID
        )
    }

    @MainActor
    private func recordDose(for med: PetMedication, executorID: UUID?) {
        guard !pet.hasPassedAway else { return }
        let result = PetMedicationCommandExecutor(context: modelContext, services: appServices).recordDose(
            medication: med,
            pet: pet,
            awardCoconut: true,
            executorId: executorID?.uuidString,
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
