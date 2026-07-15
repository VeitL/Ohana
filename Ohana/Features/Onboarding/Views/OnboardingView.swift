//
//  OnboardingView.swift
//  Ohana
//
//  First-run setup: create the local Human, then optionally create a Pet.
//

import SwiftData
import SwiftUI
import UIKit

private enum OnboardingPalette {
    static let primaryText = Color.goCardWhite.opacity(0.94)
    static let secondaryText = Color.goCardWhite.opacity(0.66)
    static let tertiaryText = Color.goCardWhite.opacity(0.46)
    static let panelFill = Color.goCardWhite.opacity(0.08)
    static let panelStroke = Color.goCardWhite.opacity(0.14)
    static let controlFill = Color.goCardWhite.opacity(0.10)
    static let controlStroke = Color.goCardWhite.opacity(0.18)
    static let selectedText = Color.arkInk
}

struct OnboardingView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.detectedCode
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    var isReplay = false
    var onReplayFinished: (() -> Void)?
    var onFirstHumanSaved: ((UUID) -> Void)?
    var onPetDeferred: (() -> Void)?
    var onPetCreationStarted: (() -> Void)?
    var onCompletionRequested: ((UUID) -> Void)?
    var onFirstPetRecovered: ((UUID) -> Void)?
    var onFirstPetSaved: ((Pet) -> Void)?
    var onHomeJoinHandoffPreflight: (() -> Void)?
    var homePreparationRecoveryNeeded = false
    var onRetryHomePreparation: (() -> Void)?

    private enum FlowStep: Equatable {
        case humanName
        case petChoice
        case petCreation
    }

    @State private var step: FlowStep = .humanName
    @State private var humanName = ""
    @State private var isSavingHuman = false
    @State private var errorMessage = ""
    @State private var showsError = false
    @State private var petWizardSessionID = UUID()
    @State private var pendingCompletionPetID: UUID?
    @State private var externallyRequestedCompletionPetID: UUID?
    @State private var isHomeJoinHandoffPreflightActive = false
    @State private var isHomeJoinHandoffPresentationActive = false
    @FocusState private var isHumanNameFocused: Bool

    private var languageCode: String { AppLanguage.normalize(appLanguage) }

    private var trimmedHumanName: String {
        humanName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localized(zh: String, en: String, de: String) -> String {
        AppLocalizedText(zh: zh, en: en, de: de).resolve(languageCode)
    }

    var body: some View {
        ZStack {
            if !isHomeJoinHandoffPresentationActive {
                OhanaAppBackground()
                    .ignoresSafeArea()
            }

            if isReplay {
                replayUnavailableView
            } else {
                flowContent
                    .opacity(externallyRequestedCompletionPetID == nil ? 1 : 0)
                    .allowsHitTesting(externallyRequestedCompletionPetID == nil)
                    .accessibilityHidden(externallyRequestedCompletionPetID != nil)
                if externallyRequestedCompletionPetID != nil {
                    homePreparationStatusView
                }
            }
        }
        .preferredColorScheme(isHomeJoinHandoffPreflightActive ? nil : .dark)
        .environment(\.colorScheme, .dark)
        .onAppear {
            guard !isReplay else { return }
            appServices.onboardingJourney.beginFreshJourney(context: modelContext)
            recoverInterruptedFlow()
        }
        .alert(
            localized(
                zh: "无法建立家庭成员",
                en: "Couldn't create the family member",
                de: "Familienmitglied konnte nicht erstellt werden"
            ),
            isPresented: $showsError
        ) {
            Button(localized(zh: "好", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var flowContent: some View {
        switch step {
        case .humanName:
            humanNameView
                .transition(.opacity)
        case .petChoice:
            petChoiceView
                .transition(.opacity)
        case .petCreation:
            petCreationView
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var homePreparationStatusView: some View {
        if homePreparationRecoveryNeeded {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.clockwise.circle").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 32, weight: .semibold))
                            .foregroundStyle(Color.goPrimary)

                        Text(localized(
                            zh: "宠物已经保存，但首页暂时没有准备好。",
                            en: "Your pet is saved, but Home isn’t ready yet.",
                            de: "Dein Tier ist gespeichert, aber Home ist noch nicht bereit."
                        ))
                        .font(.headline)
                        .foregroundStyle(OnboardingPalette.primaryText)
                        .multilineTextAlignment(.center)

                        Button {
                            onRetryHomePreparation?()
                        } label: {
                            Text(localized(zh: "重新准备首页", en: "Try Home again", de: "Home erneut laden"))
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.goPrimary)
                        .accessibilityIdentifier("onboarding-home-preparation-retry")
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .background(
                        OnboardingPalette.panelFill,
                        in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                            .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        } else {
            ProgressView()
                .tint(Color.goPrimary)
                .accessibilityLabel(localized(
                    zh: "正在准备首页",
                    en: "Preparing Home",
                    de: "Startseite wird vorbereitet"
                ))
        }
    }

    private var humanNameView: some View {
        onboardingShell {
            VStack(spacing: 26) {
                onboardingGlyph(systemName: "person.fill", tint: Color.goBlue)

                VStack(spacing: 9) {
                    Text(localized(
                        zh: "你希望我们怎么称呼你？",
                        en: "What should we call you?",
                        de: "Wie dürfen wir dich nennen?"
                    ))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .multilineTextAlignment(.center)

                    Text(localized(
                        zh: "先建立这台设备上的第一位家庭成员。",
                        en: "Start with the first family member on this device.",
                        de: "Beginne mit dem ersten Familienmitglied auf diesem Gerät."
                    ))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                TextField(
                    localized(zh: "你的名字", en: "Your name", de: "Dein Name"),
                    text: $humanName
                )
                .textFieldStyle(.plain)
                .textContentType(.name)
                .submitLabel(.continue)
                .font(OhanaFont.body(.bold))
                .foregroundStyle(OnboardingPalette.primaryText)
                .tint(Color.goPrimary)
                .focused($isHumanNameFocused)
                .onSubmit(saveHuman)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .background(OnboardingPalette.controlFill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isHumanNameFocused ? Color.goPrimary.opacity(0.62) : OnboardingPalette.controlStroke,
                            lineWidth: isHumanNameFocused ? 1.5 : 1
                        )
                }
                .accessibilityIdentifier("onboarding-human-name-input")

                primaryButton(
                    title: localized(zh: "继续", en: "Continue", de: "Weiter"),
                    systemImage: "arrow.right",
                    isLoading: isSavingHuman,
                    isEnabled: !trimmedHumanName.isEmpty && !isSavingHuman,
                    identifier: "onboarding-human-continue",
                    action: saveHuman
                )
            }
        }
        .onAppear {
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
                isHumanNameFocused = true
            }
        }
    }

    private var petChoiceView: some View {
        onboardingShell {
            VStack(spacing: 26) {
                onboardingGlyph(systemName: "pawprint.fill", tint: Color.goOrange)

                VStack(spacing: 9) {
                    Text(localized(
                        zh: "现在建立宠物吗？",
                        en: "Add a pet now?",
                        de: "Jetzt ein Tier hinzufügen?"
                    ))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .multilineTextAlignment(.center)

                    Text(localized(
                        zh: "只需名字和物种，其他资料可以以后再补充。",
                        en: "You only need a name and species. Everything else can wait.",
                        de: "Name und Art genügen. Alles Weitere kann warten."
                    ))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    primaryButton(
                        title: localized(zh: "现在建立", en: "Add pet now", de: "Tier jetzt hinzufügen"),
                        systemImage: "pawprint.fill",
                        isLoading: false,
                        isEnabled: true,
                        identifier: "onboarding-create-pet-now",
                        action: startPetCreation
                    )

                    Button(action: deferPetCreation) {
                        Text(localized(zh: "稍后再说", en: "Maybe later", de: "Vielleicht später"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(OnboardingPalette.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(OnboardingPalette.controlFill, in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(OnboardingPalette.controlStroke, lineWidth: 1)
                            }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("onboarding-defer-pet")

                    Text(localized(
                        zh: "跳过后会放入「待办」，随时可以继续。",
                        en: "We'll place it in To-dos so you can continue anytime.",
                        de: "Wir legen es in Aufgaben ab, damit du jederzeit fortfahren kannst."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(OnboardingPalette.tertiaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var petCreationView: some View {
        AddPetWizardView(
            onComplete: {
                requestPetOnboardingCompletion()
            },
            onCancel: deferPetCreation,
            onPetSaved: recordOnboardingPetSaved,
            presentationStyle: .onboarding,
            onHomeJoinHandoffPreflight: beginHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: beginHomeJoinHandoffPresentation,
            onHomeJoinHandoffEnded: endHomeJoinHandoffPresentation
        )
        .id(petWizardSessionID)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(isHomeJoinHandoffPreflightActive ? nil : .dark)
    }

    private var replayUnavailableView: some View {
        onboardingShell {
            VStack(spacing: 24) {
                onboardingGlyph(systemName: "checkmark.circle.fill", tint: Color.goPrimary)
                Text(localized(
                    zh: "初始设置已完成",
                    en: "Setup is already complete",
                    de: "Die Einrichtung ist abgeschlossen"
                ))
                .font(OhanaFont.title(.black))
                .foregroundStyle(OnboardingPalette.primaryText)
                .multilineTextAlignment(.center)

                primaryButton(
                    title: localized(zh: "关闭", en: "Close", de: "Schließen"),
                    systemImage: "xmark",
                    isLoading: false,
                    isEnabled: true,
                    identifier: "onboarding-replay-close",
                    action: { onReplayFinished?() }
                )
            }
        }
    }

    private func onboardingShell(
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        GeometryReader { proxy in
            let width = MemberCreationCardLayout.cardWidth(in: proxy.size.width)
            ScrollView(showsIndicators: false) {
                VStack {
                    Spacer(minLength: 24)
                    content()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 30)
                        .frame(width: width)
                        .background(
                            OnboardingPalette.panelFill,
                            in: RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                                .strokeBorder(OnboardingPalette.panelStroke, lineWidth: 1)
                        }
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, MemberCreationCardLayout.horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func onboardingGlyph(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(OhanaFont.adaptive(size: 34, weight: .black))
            .foregroundStyle(OnboardingPalette.selectedText)
            .frame(width: 86, height: 86)
            .background(tint, in: Circle())
            .overlay {
                Circle().strokeBorder(Color.goCardWhite.opacity(0.20), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func primaryButton(
        title: String,
        systemImage: String,
        isLoading: Bool,
        isEnabled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(OnboardingPalette.selectedText)
                } else {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(OhanaFont.callout(.black))
            .foregroundStyle(isEnabled ? OnboardingPalette.selectedText : OnboardingPalette.tertiaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(isEnabled ? Color.goPrimary : OnboardingPalette.controlFill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isEnabled ? Color.goPrimary.opacity(0.42) : OnboardingPalette.controlStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    private func saveHuman() {
        guard !trimmedHumanName.isEmpty, !isSavingHuman else { return }
        GoKeyboard.dismiss()
        isSavingHuman = true

        var draft = MemberCreationDraft(kind: .human)
        draft.name = trimmedHumanName
        do {
            let result = try appServices.memberCreation.save(
                draft: draft,
                existingPets: [],
                existingHumans: [],
                context: modelContext,
                countryCode: appCountry
            )
            guard let human = result.human else {
                throw MemberCreationError.saveFailed("Human creation returned no member.")
            }

            currentActiveHumanId = human.id.uuidString
            onFirstHumanSaved?(human.id)
            isSavingHuman = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(GoMotion.page) {
                step = .petChoice
            }
        } catch MemberCreationError.duplicateName {
            handleHumanSaveFailure(localized(
                zh: "这个名字已经被使用。",
                en: "This name is already in use.",
                de: "Dieser Name wird bereits verwendet."
            ))
        } catch MemberCreationError.emptyName {
            handleHumanSaveFailure(localized(
                zh: "请先输入名字。",
                en: "Enter a name first.",
                de: "Gib zuerst einen Namen ein."
            ))
        } catch {
            handleHumanSaveFailure(localized(
                zh: "保存失败，请再试一次。",
                en: "Saving failed. Please try again.",
                de: "Speichern fehlgeschlagen. Bitte versuche es erneut."
            ))
        }
    }

    private func handleHumanSaveFailure(_ message: String) {
        isSavingHuman = false
        errorMessage = message
        showsError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func startPetCreation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onPetCreationStarted?()
        petWizardSessionID = UUID()
        withAnimation(GoMotion.page) {
            step = .petCreation
        }
    }

    private func deferPetCreation() {
        guard !hasOnboarded else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onPetDeferred?()
        finishOnboarding(playsFeedback: false)
    }

    private func recordOnboardingPetSaved(_ pet: Pet) {
        guard !isReplay else { return }
        pendingCompletionPetID = pet.id
        OnboardingHomeJoinHandoffGate.markCompleted()
        onFirstPetSaved?(pet)
    }

    private func recoverInterruptedFlow() {
        guard !hasOnboarded else { return }
        if let firstPetID = appServices.onboardingJourney.interruptedOnboardingFirstPetID(
            context: modelContext
        ), let petID = UUID(uuidString: firstPetID) {
            pendingCompletionPetID = petID
            OnboardingHomeJoinHandoffGate.markCompleted()
            onFirstPetRecovered?(petID)
            requestPetOnboardingCompletion()
            return
        }

        if let humanID = appServices.onboardingJourney.interruptedOnboardingPrimaryHumanID(
            context: modelContext
        ) {
            currentActiveHumanId = humanID
            let evaluation = appServices.onboardingJourney.evaluate(
                hasOnboarded: false,
                activeHumanID: humanID,
                context: modelContext,
                projectionManager: appServices.questManager
            )
            switch evaluation.phase {
            case .petCreation:
                step = .petCreation
            case .awaitingPet, .starterGiftReady, .complete, .existingUser:
                finishOnboarding(playsFeedback: false)
            case .preOnboarding, .needsHumanName, .petChoice:
                step = .petChoice
            }
        } else {
            currentActiveHumanId = ""
            step = .humanName
        }
    }

    private func beginHomeJoinHandoffPreflight() {
        guard !isHomeJoinHandoffPreflightActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeJoinHandoffPreflightActive = true
        }
        onHomeJoinHandoffPreflight?()
    }

    private func beginHomeJoinHandoffPresentation() {
        beginHomeJoinHandoffPreflight()
        guard !isHomeJoinHandoffPresentationActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeJoinHandoffPresentationActive = true
        }
    }

    private func endHomeJoinHandoffPresentation() {
        guard externallyRequestedCompletionPetID == nil else { return }
        guard isHomeJoinHandoffPresentationActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeJoinHandoffPresentationActive = false
        }
    }

    private func finishOnboarding(playsFeedback: Bool = true) {
        if isReplay {
            onReplayFinished?()
            return
        }
        guard !hasOnboarded else { return }
        if playsFeedback {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hasOnboarded = true
        }
    }

    private func requestPetOnboardingCompletion() {
        guard let petID = pendingCompletionPetID else {
            OhanaLog.warning(
                "Onboarding completion requested before a Pet ID was available.",
                category: "Onboarding"
            )
            if onCompletionRequested == nil {
                finishOnboarding(playsFeedback: false)
            }
            return
        }
        guard let onCompletionRequested else {
            finishOnboarding(playsFeedback: false)
            return
        }
        guard externallyRequestedCompletionPetID != petID else { return }
        externallyRequestedCompletionPetID = petID
        beginHomeJoinHandoffPresentation()
        onCompletionRequested(petID)
    }
}

#Preview {
    if let modelContainer = try? SharedModelContainer.makePreview() {
        OnboardingView()
            .modelContainer(modelContainer)
    }
}
