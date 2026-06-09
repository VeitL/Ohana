//
//  QuickHumanWorkoutSheet.swift
//  Ohana
//
//  Lightweight inline popup for human workout quick records.
//

import SwiftUI
import SwiftData

private struct QuickHumanWorkoutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct QuickHumanWorkoutSheet: View {
    let human: Human
    var onSaved: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
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
        GeometryReader { proxy in
            let minPanelHeight: CGFloat = 430
            let maxPanelHeight = max(minPanelHeight, proxy.size.height * 0.86)
            let scrollMaxHeight = max(250, maxPanelHeight - 142)
            let measuredHeight = contentHeight > 1 ? contentHeight : 320
            let scrollHeight = min(measuredHeight, scrollMaxHeight)
            let panelHeightEstimate = min(maxPanelHeight, max(adaptiveSheetHeight, minPanelHeight))
            let hiddenOffset = panelHeightEstimate + 72

            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: popupVisible) {
                popupBackdrop
                    .opacity(popupVisible ? 1 : 0)

                VStack(spacing: 0) {
                    popupDragHandle
                        .padding(.top, 4)
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
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
                        .padding(.bottom, 10)
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(key: QuickHumanWorkoutHeightKey.self, value: contentProxy.size.height)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(height: scrollHeight)

                    saveBar
                }
                .background { OhanaPopupGlassSurface(cornerRadius: 52) }
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .shadow(color: Color.black.opacity(0.56), radius: 48, x: 0, y: -18) // ui-v4: allow short popup liftedAlert shadow token
                .shadow(color: Color(hex: "0B102C").opacity(0.46), radius: 28, x: 0, y: 12) // ui-v4: allow short popup liftedAlert shadow token
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .offset(y: popupVisible ? popupDragOffset : hiddenOffset)
                .frame(maxHeight: maxPanelHeight, alignment: .bottom)
                .ohanaAdaptiveSheetContentHeight(
                    $adaptiveSheetHeight,
                    minHeight: minPanelHeight,
                    maxHeight: maxPanelHeight,
                    chromePadding: 18
                )
            }
        }
        .allowsHitTesting(popupVisible && !isClosing)
        .animation(popupAnimation, value: popupVisible)
        .presentationBackground(.clear)
        .presentationDetents([.height(adaptiveSheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationContentInteraction(.scrolls)
        .onAppear {
            popupVisible = false
            isClosing = false
            DispatchQueue.main.async {
                withAnimation(popupAnimation) {
                    popupVisible = true
                }
            }
        }
        .onChange(of: durationText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(newValue, countryCode: appCountry, maxFractionDigits: 0)
            if sanitized != newValue {
                durationText = sanitized
            }
        }
        .onPreferenceChange(QuickHumanWorkoutHeightKey.self) { height in
            guard height.isFinite, height > 0 else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                contentHeight = height
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(0.18))
                Image(systemName: selectedType.icon)
                    .font(.system(size: 19, weight: .black))
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
                            .font(.system(size: 15, weight: .black))
                        Text(type.rawValue)
                            .font(OhanaFont.caption2(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(isSelected ? Color(hex: type.colorHex) : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    .font(.system(size: 16, weight: .black))
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
        withAnimation(popupAnimation) {
            popupVisible = false
            popupDragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss?()
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
            HumanCareCommandExecutor(context: modelContext).recordWorkout(
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
