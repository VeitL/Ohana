//
//  PetHealthRecordInlinePopup.swift
//  Ohana
//
//  Inline health record editor used by PetHealthDetailContentView.
//

import Foundation
import SwiftData
import SwiftUI

struct PetHealthRecordInlinePopup: View {
    let pet: Pet
    let entryMode: HealthRecordEntryMode?
    let onClose: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var selectedType: HealthLogType
    @State private var date = Date()
    @State private var name = ""
    @State private var note = ""
    @State private var vetName = ""
    @State private var cost = ""
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasNextCheckup = false
    @State private var nextCheckupDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        pet: Pet,
        initialType: HealthLogType,
        entryMode: HealthRecordEntryMode?,
        onClose: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.pet = pet
        self.entryMode = entryMode
        self.onClose = onClose
        self.onSaved = onSaved
        _selectedType = State(initialValue: initialType)
    }

    private var l: L10n { L10n(appLanguage) }
    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { isDark ? Color.goPrimary : Color.goBlue }
    private var activeExecutorID: String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }

    private var showsNameField: Bool {
        selectedType == .vaccine || selectedType == .dewormingInternal || selectedType == .dewormingExternal || selectedType == .medication
    }
    private var showsExpiration: Bool { selectedType.needsExpiration }
    private var showsNextCheckup: Bool { selectedType == .checkup }

    private var typeLabel: String {
        switch selectedType {
        case .vaccine: return l.tr(zh: "疫苗接种", en: "Vaccine", de: "Impfung")
        case .dewormingInternal: return l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: return l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .checkup: return l.tr(zh: "体检记录", en: "Checkup", de: "Check-up")
        case .surgery: return l.tr(zh: "就诊记录", en: "Visit", de: "Besuch")
        default: return selectedType.rawValue
        }
    }

    private func healthIcon(for type: HealthLogType) -> String {
        switch type {
        case .general: return "clipboard.fill"
        case .vaccine: return "syringe.fill"
        case .medication: return "pill.fill"
        case .dewormingInternal: return "pills.fill"
        case .dewormingExternal: return "shield.lefthalf.filled"
        case .surgery: return "cross.case.fill"
        case .dental: return "mouth.fill"
        case .checkup: return "stethoscope"
        case .emergency: return "cross.circle.fill"
        case .other: return "doc.text.fill"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.ohanaPrimaryText.opacity(0.26))
                .frame(width: 48, height: 5)
                .padding(.top, 8)

            HStack(spacing: 12) {
                Image(systemName: healthIcon(for: selectedType))
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(typeLabel)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pet.name)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                    guard !isSaving else { return }
                    onClose()
                }
            }
            .padding(.horizontal, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if let entryMode {
                        healthSubtypeSelector(mode: entryMode)
                    }

                    if showsNameField {
                        inlineField(icon: "pencil.line", tint: accent) {
                            TextField(l.tr(zh: "名称（可选）", en: "Name (optional)", de: "Name (optional)"), text: $name)
                                .font(OhanaFont.subheadline(.semibold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                    }

                    inlineField(icon: "calendar", tint: accent) {
                        DatePicker(l.tr(zh: "记录日期", en: "Date", de: "Datum"), selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(accent)
                    }

                    if showsExpiration {
                        inlineToggleDateBlock(
                            title: l.tr(zh: "有效期提醒", en: "Expiry reminder", de: "Ablauf-Erinnerung"),
                            isOn: $hasExpiration,
                            date: $expirationDate,
                            range: date...,
                            tint: Color.goTeal
                        )
                    }

                    if showsNextCheckup {
                        inlineToggleDateBlock(
                            title: l.tr(zh: "下次体检提醒", en: "Next checkup reminder", de: "Nächster Check-up"),
                            isOn: $hasNextCheckup,
                            date: $nextCheckupDate,
                            range: date...,
                            tint: Color.goTeal
                        )
                    }

                    inlineField(icon: "stethoscope", tint: Color.goTeal) {
                        TextField(l.tr(zh: "医生 / 诊所（可选）", en: "Vet / clinic (optional)", de: "Tierarzt / Klinik (optional)"), text: $vetName)
                            .font(OhanaFont.subheadline(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }

                    inlineField(icon: AppCurrency.systemIconName, tint: Color.goYellow) {
                        InlineNumericInput(
                            text: $cost,
                            placeholder: l.tr(zh: "费用（可选）", en: "Cost (optional)", de: "Kosten (optional)"),
                            maxFractionDigits: 2,
                            accent: Color.goYellow,
                            step: 10,
                            valueFont: OhanaFont.subheadline(.semibold),
                            valueAlignment: .leading,
                            fill: Color.clear,
                            cornerRadius: 12,
                            horizontalPadding: 4,
                            verticalPadding: 0
                        )
                    }

                    inlineField(icon: "note.text", tint: Color.ohanaSecondaryText) {
                        TextField(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"), text: $note, axis: .vertical)
                            .font(OhanaFont.subheadline(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
            }

            Button(action: save) {
                HStack(spacing: 8) {
                    Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    Text(isSaving
                        ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                        : l.tr(zh: "保存记录", en: "Save record", de: "Eintrag speichern")
                    )
                }
                .font(OhanaFont.body(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isSaving ? Color.ohanaControlFill : accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isSaving)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            FeedInlineSheetGlassSurface(cornerRadius: 52, glassMode: .regular)
        }
        .onAppear(perform: applyDefaultsForSelectedType)
        .onChange(of: selectedType) { _, _ in applyDefaultsForSelectedType() }
        .onChange(of: date) { _, newDate in
            if hasExpiration {
                expirationDate = defaultExpirationDate(from: newDate)
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private func healthSubtypeSelector(mode: HealthRecordEntryMode) -> some View {
        let options: [(HealthLogType, String)] = {
            switch mode {
            case .preventive:
                return [(.vaccine, "疫苗"), (.dewormingInternal, "体内"), (.dewormingExternal, "体外"), (.checkup, "体检")]
            case .visit:
                return [(.surgery, "就诊"), (.general, "常规")]
            }
        }()

        return HStack(spacing: 8) {
            ForEach(options, id: \.0) { type, title in
                Button {
                    withAnimation(GoMotion.selection) { selectedType = type }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: healthIcon(for: type))
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                        Text(title)
                            .font(OhanaFont.caption(.black))
                    }
                    .foregroundStyle(selectedType == type ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedType == type ? accent : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func inlineField<Content: View>(
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 22)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func inlineToggleDateBlock(
        title: String,
        isOn: Binding<Bool>,
        date: Binding<Date>,
        range: PartialRangeFrom<Date>,
        tint: Color
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(tint)
            }
            if isOn.wrappedValue {
                DatePicker("", selection: date, in: range, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(tint)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func defaultExpirationDate(from base: Date) -> Date {
        let cal = Calendar.current
        switch selectedType {
        case .vaccine:
            return cal.date(byAdding: .year, value: 1, to: base) ?? base
        case .dewormingInternal:
            return cal.date(byAdding: .month, value: 3, to: base) ?? base
        case .dewormingExternal, .medication:
            return cal.date(byAdding: .month, value: 1, to: base) ?? base
        default:
            return cal.date(byAdding: .year, value: 1, to: base) ?? base
        }
    }

    private func applyDefaultsForSelectedType() {
        switch selectedType {
        case .vaccine:
            if name.isEmpty { name = "\(pet.name)疫苗" }
            hasExpiration = true
            expirationDate = defaultExpirationDate(from: date)
        case .dewormingInternal, .dewormingExternal, .medication:
            if name.isEmpty { name = "\(pet.name)\(typeLabel)" }
            hasExpiration = true
            expirationDate = defaultExpirationDate(from: date)
        case .checkup:
            hasNextCheckup = true
            nextCheckupDate = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
        default:
            break
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let input = PetHealthRecordCommandInput(
            type: selectedType,
            date: date,
            name: name,
            note: note,
            vetName: vetName,
            cost: CountryDecimalInput.parse(cost, countryCode: AppCountry.code) ?? 0,
            expirationDate: (showsExpiration && hasExpiration) ? expirationDate : nil,
            nextCheckupDate: (showsNextCheckup && hasNextCheckup) ? nextCheckupDate : nil,
            executorId: activeExecutorID,
            source: .detail,
            includesNameInNote: showsNameField
        )
        let command = DomainCommand.petHealthRecord(petID: pet.id, type: selectedType.rawValue)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(command) {
            PetHealthCommandExecutor(context: modelContext, services: appServices).recordHealth(
                pet: pet,
                input: input,
                note: "pet.health.inline.record"
            )
            onSaved()
        }
    }
}
