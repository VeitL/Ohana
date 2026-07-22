//
//  QuickHumanWorkoutSheet.swift
//  Ohana
//
//  Lightweight inline popup for human workout quick records.
//

import SwiftData
import SwiftUI

private struct QuickHumanWorkoutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct QuickHumanWorkoutSheet: View {
    let human: Human
    var onSaved: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var selectedType: WorkoutType = .walking
    @State private var durationText = "30"
    @State private var adaptiveSheetHeight: CGFloat = 500
    @State private var contentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var isSaving = false
    @State private var popupDragOffset: CGFloat = 0
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var duration: Int { Int(durationText) ?? 0 }
    private var canSave: Bool { duration > 0 }
    private var accent: Color { Color(hex: selectedType.colorHex) }
    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(human.name)
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    typeGrid
                    durationBlock
                    EmbeddedDecimalKeypad(
                        text: $durationText,
                        countryCode: appCountry,
                        maxFractionDigits: 0,
                        accent: accent,
                        isMini: true,
                        showsSubmitButton: false,
                        onSubmit: {
                            if canSave { save() }
                        }
                    )
                    .padding(.horizontal, 22)
                    quickDurationStrip
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("quick-human-workout-sheet")
            .navigationTitle(l.tr(zh: "快速运动", en: "Quick Workout", de: "Schnelles Training"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { close() }
                        .accessibilityIdentifier("ohana-sheet-close-action")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .onChange(of: durationText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(newValue, countryCode: appCountry, maxFractionDigits: 0)
            if sanitized != newValue {
                durationText = sanitized
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var popupBackdrop: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.06), // ui-v4: allow short popup scrimGradient token
                Color.black.opacity(0.30) // ui-v4: allow short popup scrimGradient token
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { close() }
    }

    private var popupDragHandle: some View {
        OhanaPopupDragHandle()
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        popupDragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 70 || value.predictedEndTranslation.height > 130 {
                            close()
                        } else {
                            withAnimation(popupAnimation) { popupDragOffset = 0 }
                        }
                    }
            )
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(accent.opacity(0.18))
                Image(systemName: selectedType.icon)
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(accent)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "快速运动", en: "Quick Workout", de: "Schnelles Training"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(human.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            OhanaPopupCloseButton { close() }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var typeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(WorkoutType.allCases, id: \.self) { type in
                let isSelected = selectedType == type
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedType = type
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: type.icon)
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                        Text(type.rawValue)
                            .font(OhanaFont.caption2(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(isSelected ? Color(hex: type.colorHex) : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 22)
    }

    private var durationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "时长", en: "Duration", de: "Dauer"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(durationText.isEmpty ? "0" : durationText)
                    .font(OhanaFont.metric(size: 44))
                    .foregroundStyle(durationText.isEmpty ? Color.ohanaTertiaryText : Color.ohanaPrimaryText)
                Text(l.tr(zh: "分钟", en: "min", de: "Min."))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        }
        .padding(.horizontal, 22)
    }

    private var quickDurationStrip: some View {
        HStack(spacing: 8) {
            ForEach([15, 30, 45, 60], id: \.self) { value in
                Button {
                    withAnimation(GoMotion.feedback) {
                        durationText = "\(value)"
                    }
                } label: {
                    Text("\(value)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(duration == value ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(duration == value ? accent : Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 22)
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                Text(isSaving
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : l.tr(zh: "保存运动", en: "Save Workout", de: "Training speichern")
                )
                .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canSave && !isSaving ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave || isSaving)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func save() {
        guard !isSaving, canSave else { return }
        isSaving = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let savedType = selectedType
        let savedDuration = duration
        let command = DomainCommand.quickHumanWorkout(humanID: human.id)
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext, services: appServices).recordWorkout(
                human: human,
                type: savedType,
                durationMinutes: savedDuration,
                date: Date(),
                command: command,
                note: "quick.human.workout"
            )
            onSaved?()
            close()
        }
    }
}
