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
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
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
        case .vaccine: l.tr(zh: "疫苗接种", en: "Vaccine", de: "Impfung")
        case .dewormingInternal: l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .checkup: l.tr(zh: "体检记录", en: "Checkup", de: "Check-up")
        case .surgery: l.tr(zh: "就诊记录", en: "Visit", de: "Besuch")
        default: selectedType.rawValue
        }
    }

    private func healthIcon(for type: HealthLogType) -> String {
        switch type {
        case .general: "clipboard.fill"
        case .vaccine: "syringe.fill"
        case .medication: "pill.fill"
        case .dewormingInternal: "pills.fill"
        case .dewormingExternal: "shield.lefthalf.filled"
        case .surgery: "cross.case.fill"
        case .dental: "mouth.fill"
        case .checkup: "stethoscope"
        case .emergency: "cross.circle.fill"
        case .other: "doc.text.fill"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let entryMode {
                    Section {
                        Picker(l.tr(zh: "记录类型", en: "Record type", de: "Eintragstyp"), selection: $selectedType) {
                            ForEach(healthSubtypeOptions(mode: entryMode), id: \.self) { type in
                                Label(healthTypeTitle(type), systemImage: healthIcon(for: type))
                                    .tag(type)
                            }
                        }
                    }
                }

                Section {
                    if showsNameField {
                        TextField(l.tr(zh: "名称（可选）", en: "Name (optional)", de: "Name (optional)"), text: $name)
                    }
                    DatePicker(l.tr(zh: "记录日期", en: "Date", de: "Datum"), selection: $date, displayedComponents: .date)
                }

                if showsExpiration {
                    Section {
                        Toggle(l.tr(zh: "有效期提醒", en: "Expiry reminder", de: "Ablauf-Erinnerung"), isOn: $hasExpiration)
                            .tint(Color.goPrimary)
                        if hasExpiration {
                            DatePicker(
                                l.tr(zh: "有效期至", en: "Valid until", de: "Gültig bis"),
                                selection: $expirationDate,
                                in: date...,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                if showsNextCheckup {
                    Section {
                        Toggle(l.tr(zh: "下次体检提醒", en: "Next checkup reminder", de: "Nächster Check-up"), isOn: $hasNextCheckup)
                            .tint(Color.goPrimary)
                        if hasNextCheckup {
                            DatePicker(
                                l.tr(zh: "提醒日期", en: "Reminder date", de: "Erinnerungsdatum"),
                                selection: $nextCheckupDate,
                                in: date...,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                Section {
                    TextField(l.tr(zh: "医生 / 诊所（可选）", en: "Vet / clinic (optional)", de: "Tierarzt / Klinik (optional)"), text: $vetName)
                    TextField(l.tr(zh: "费用（可选）", en: "Cost (optional)", de: "Kosten (optional)"), text: $cost)
                        .keyboardType(.decimalPad)
                    TextField(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"), text: $note, axis: .vertical)
                        .lineLimit(2 ... 4)
                } header: {
                    Text(l.tr(zh: "详情", en: "Details", de: "Details"))
                }
            }
            .navigationTitle(typeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) {
                        guard !isSaving else { return }
                        onClose()
                    }
                    .accessibilityIdentifier("pet-health-record-close-action")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Sichern")) {
                        save()
                    }
                    .disabled(isSaving || !pet.canWriteHealthFacts)
                    .accessibilityIdentifier("pet-health-record-save-action")
                }
            }
        }
        .accessibilityIdentifier("pet-health-record-sheet")
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

    private func healthSubtypeOptions(mode: HealthRecordEntryMode) -> [HealthLogType] {
        switch mode {
        case .preventive:
            [.vaccine, .dewormingInternal, .dewormingExternal, .checkup]
        case .visit:
            [.surgery, .general]
        }
    }

    private func healthTypeTitle(_ type: HealthLogType) -> String {
        switch type {
        case .vaccine: l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .dewormingInternal: l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal: l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .checkup: l.tr(zh: "体检", en: "Checkup", de: "Check-up")
        case .surgery: l.tr(zh: "就诊", en: "Visit", de: "Besuch")
        case .general: l.tr(zh: "常规", en: "General", de: "Allgemein")
        default: type.rawValue
        }
    }

    private func healthSubtypeSelector(mode: HealthRecordEntryMode) -> some View {
        let options: [(HealthLogType, String)] = switch mode {
        case .preventive:
            [(.vaccine, "疫苗"), (.dewormingInternal, "体内"), (.dewormingExternal, "体外"), (.checkup, "体检")]
        case .visit:
            [(.surgery, "就诊"), (.general, "常规")]
        }

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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func inlineField(
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> some View
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
        guard !isSaving, pet.canWriteHealthFacts else { return }
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
            guard PetHealthCommandExecutor(context: modelContext, services: appServices).recordHealth(
                pet: pet,
                input: input,
                note: "pet.health.inline.record"
            ) != nil else {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            onSaved()
        }
    }
}
