//
//  AddSymptomSheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct AddSymptomSheet: View {
    let pet: Pet
    var onSaved: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedDate = Date()
    @State private var category: SymptomCategory = .digestive
    @State private var symptomName: String = ""
    @State private var severity: SymptomSeverity = .mild
    @State private var note: String = ""
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var l: L10n { L10n(appLanguage) }
    private var canSave: Bool {
        pet.canWriteHealthFacts && !symptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        categorySection
                        symptomField
                        severitySection
                        dateSection
                        noteSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 94)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
        .interactiveDismissDisabled(isSaving)
        .onDisappear {
            commandQueue.cancelAll()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                pet: pet,
                fallbackText: pet.avatarEmoji,
                themeColor: themeColor,
                size: 46,
                backgroundOpacity: 0.16
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "记录异常", en: "Log symptom", de: "Symptom erfassen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var categorySection: some View {
        formBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(l.tr(zh: "类别", en: "Category", de: "Kategorie"), icon: "waveform.path.ecg", tint: Color.ohanaFunctionalIcon)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(SymptomCategory.allCases, id: \.self) { item in
                        Button {
                            withAnimation(GoMotion.selection) { category = item }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: categoryIcon(item))
                                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                                Text(categoryTitle(item))
                                    .font(OhanaFont.caption(.black))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .foregroundStyle(category == item ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(category == item ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var symptomField: some View {
        formBlock {
            HStack(spacing: 10) {
                sectionLabel(l.tr(zh: "症状", en: "Symptom", de: "Symptom"), icon: "pencil.line", tint: Color.goOrange)
                TextField(l.tr(zh: "例如：呕吐、咳嗽、跛行", en: "e.g. vomiting, cough, limping", de: "z. B. Erbrechen, Husten, Hinken"), text: $symptomName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
    }

    private var severitySection: some View {
        formBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(l.tr(zh: "程度", en: "Severity", de: "Schwere"), icon: severity.icon, tint: severityColor(severity))
                HStack(spacing: 8) {
                    ForEach(SymptomSeverity.allCases, id: \.self) { level in
                        Button {
                            withAnimation(GoMotion.selection) { severity = level }
                        } label: {
                            Text(severityTitle(level))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(severity == level ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(severity == level ? severityColor(level) : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        formBlock {
            HStack(spacing: 10) {
                sectionLabel(l.tr(zh: "时间", en: "Time", de: "Zeit"), icon: "calendar", tint: Color.goTeal)
                Spacer()
                DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
            }
        }
    }

    private var noteSection: some View {
        formBlock {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(l.tr(zh: "备注", en: "Note", de: "Notiz"), icon: "note.text", tint: Color.ohanaSecondaryText)
                TextField(l.tr(zh: "精神状态、用药、持续时间（可选）", en: "Mood, meds, duration (optional)", de: "Zustand, Medikamente, Dauer (optional)"), text: $note, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(3 ... 5)
            }
        }
    }

    private var saveBar: some View {
        Button(action: save) {
            Text(l.tr(zh: "保存记录", en: "Save record", de: "Eintrag speichern"))
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func sectionLabel(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
            Text(title)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private func formBlock(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func categoryTitle(_ category: SymptomCategory) -> String {
        switch category {
        case .digestive: l.tr(zh: "消化", en: "Digestive", de: "Verdauung")
        case .respiratory: l.tr(zh: "呼吸", en: "Breathing", de: "Atmung")
        case .mobility: l.tr(zh: "运动", en: "Mobility", de: "Bewegung")
        case .appetite: l.tr(zh: "饮食", en: "Appetite", de: "Appetit")
        case .skin: l.tr(zh: "皮毛", en: "Skin", de: "Haut")
        case .behavior: l.tr(zh: "精神", en: "Behavior", de: "Verhalten")
        case .other: l.tr(zh: "其他", en: "Other", de: "Andere")
        }
    }

    private func categoryIcon(_ category: SymptomCategory) -> String {
        switch category {
        case .digestive: "stomach.fill"
        case .respiratory: "lungs.fill"
        case .mobility: "figure.walk"
        case .appetite: "fork.knife"
        case .skin: "bandage.fill"
        case .behavior: "moon.zzz.fill"
        case .other: "magnifyingglass"
        }
    }

    private func severityTitle(_ severity: SymptomSeverity) -> String {
        switch severity {
        case .mild: l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case .moderate: l.tr(zh: "中度", en: "Moderate", de: "Mittel")
        case .severe: l.tr(zh: "严重", en: "Severe", de: "Schwer")
        case .critical: l.tr(zh: "紧急", en: "Critical", de: "Kritisch")
        }
    }

    private func severityColor(_ severity: SymptomSeverity) -> Color {
        switch severity {
        case .mild: Color.goTeal
        case .moderate: Color.goYellow
        case .severe: Color.goOrange
        case .critical: Color.goRed
        }
    }

    private var symptomCommandInput: PetSymptomCommandInput {
        PetSymptomCommandInput(
            date: selectedDate,
            category: category,
            symptomName: symptomName,
            severity: severity,
            note: note,
            photoData: nil
        )
    }

    private func save() {
        guard canSave else { return }
        let input = symptomCommandInput
        let command = DomainCommand.petHealthRecord(petID: pet.id, type: "symptom")
        isSaving = true

        commandQueue.enqueue(command) {
            guard PetHealthCommandExecutor(context: modelContext, services: appServices).recordSymptom(
                pet: pet,
                input: input,
                note: "pet.symptom.recorded"
            ) != nil else {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved?()
            dismiss()
        }
    }
}
