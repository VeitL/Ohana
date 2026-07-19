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
    var experienceMode: AppExperienceMode = .standard
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

    private var trimmedHumanName: String {
        humanName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localized(
        zh: String,
        en: String,
        de: String,
        es: String,
        pt: String,
        fr: String,
        ja: String,
        ko: String,
        it: String
    ) -> String {
        L10n(appLanguage).tr(
            zh: zh,
            en: en,
            de: de,
            es: es,
            pt: pt,
            fr: fr,
            ja: ja,
            ko: ko,
            it: it
        )
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
            // Both shells share the same household starter journey key. Zen
            // defers eligibility until the first Pet or Plant, while Standard
            // continues to wait for the first Pet.
            appServices.onboardingJourney.beginFreshJourney(context: modelContext)
            recoverInterruptedFlow()
        }
        .alert(
            localized(
                zh: "无法建立家庭成员",
                en: "Couldn't create the family member",
                de: "Familienmitglied konnte nicht erstellt werden",
                es: "No se pudo crear el miembro de la familia",
                pt: "Não foi possível criar o membro da família",
                fr: "Impossible de créer le membre de la famille",
                ja: "家族メンバーを作成できませんでした",
                ko: "가족 구성원을 만들 수 없어요",
                it: "Impossibile creare il membro della famiglia"
            ),
            isPresented: $showsError
        ) {
            Button(localized(
                zh: "好",
                en: "OK",
                de: "OK",
                es: "Aceptar",
                pt: "OK",
                fr: "OK",
                ja: "OK",
                ko: "확인",
                it: "OK"
            ), role: .cancel) {}
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
                            de: "Dein Tier ist gespeichert, aber Home ist noch nicht bereit.",
                            es: "Tu mascota se ha guardado, pero Inicio aún no está listo.",
                            pt: "Seu pet foi salvo, mas a tela Início ainda não está pronta.",
                            fr: "Votre animal a été enregistré, mais l’accueil n’est pas encore prêt.",
                            ja: "ペットは保存されましたが、ホームの準備がまだできていません。",
                            ko: "반려동물은 저장했지만 홈이 아직 준비되지 않았어요.",
                            it: "Il tuo animale è stato salvato, ma la Home non è ancora pronta."
                        ))
                        .font(.headline)
                        .foregroundStyle(OnboardingPalette.primaryText)
                        .multilineTextAlignment(.center)

                        Button {
                            onRetryHomePreparation?()
                        } label: {
                            Text(localized(
                                zh: "重新准备首页",
                                en: "Try Home again",
                                de: "Home erneut laden",
                                es: "Reintentar Inicio",
                                pt: "Tentar o Início novamente",
                                fr: "Réessayer l’accueil",
                                ja: "ホームを再準備",
                                ko: "홈 다시 준비",
                                it: "Riprova la Home"
                            ))
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
                    de: "Startseite wird vorbereitet",
                    es: "Preparando Inicio",
                    pt: "Preparando o Início",
                    fr: "Préparation de l’accueil",
                    ja: "ホームを準備中",
                    ko: "홈 준비 중",
                    it: "Preparazione della Home"
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
                        de: "Wie dürfen wir dich nennen?",
                        es: "¿Cómo quieres que te llamemos?",
                        pt: "Como você gostaria que chamássemos você?",
                        fr: "Comment souhaitez-vous que nous vous appelions ?",
                        ja: "何とお呼びすればよいですか？",
                        ko: "어떻게 불러 드릴까요?",
                        it: "Come vuoi che ti chiamiamo?"
                    ))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .multilineTextAlignment(.center)

                    Text(localized(
                        zh: "先建立这台设备上的第一位家庭成员。",
                        en: "Start with the first family member on this device.",
                        de: "Beginne mit dem ersten Familienmitglied auf diesem Gerät.",
                        es: "Empieza con el primer miembro de la familia en este dispositivo.",
                        pt: "Comece com o primeiro membro da família neste dispositivo.",
                        fr: "Commencez par le premier membre de la famille sur cet appareil.",
                        ja: "まず、この端末に最初の家族メンバーを作成します。",
                        ko: "먼저 이 기기에 첫 가족 구성원을 만들어 주세요.",
                        it: "Inizia con il primo membro della famiglia su questo dispositivo."
                    ))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                TextField(
                    localized(
                        zh: "你的名字",
                        en: "Your name",
                        de: "Dein Name",
                        es: "Tu nombre",
                        pt: "Seu nome",
                        fr: "Votre nom",
                        ja: "あなたの名前",
                        ko: "이름",
                        it: "Il tuo nome"
                    ),
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
                    title: localized(
                        zh: "继续",
                        en: "Continue",
                        de: "Weiter",
                        es: "Continuar",
                        pt: "Continuar",
                        fr: "Continuer",
                        ja: "続ける",
                        ko: "계속",
                        it: "Continua"
                    ),
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
                        de: "Jetzt ein Tier hinzufügen?",
                        es: "¿Añadir una mascota ahora?",
                        pt: "Adicionar um pet agora?",
                        fr: "Ajouter un animal maintenant ?",
                        ja: "今ペットを追加しますか？",
                        ko: "지금 반려동물을 추가할까요?",
                        it: "Aggiungere un animale ora?"
                    ))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(OnboardingPalette.primaryText)
                    .multilineTextAlignment(.center)

                    Text(localized(
                        zh: "只需名字和物种，其他资料可以以后再补充。",
                        en: "You only need a name and species. Everything else can wait.",
                        de: "Name und Art genügen. Alles Weitere kann warten.",
                        es: "Solo necesitas un nombre y la especie. El resto puede esperar.",
                        pt: "Você só precisa do nome e da espécie. O restante pode esperar.",
                        fr: "Il suffit d’un nom et de l’espèce. Le reste peut attendre.",
                        ja: "必要なのは名前と種類だけです。ほかの情報は後から追加できます。",
                        ko: "이름과 종만 입력하면 돼요. 나머지는 나중에 추가할 수 있어요.",
                        it: "Bastano nome e specie. Il resto può aspettare."
                    ))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    primaryButton(
                        title: localized(
                            zh: "现在建立",
                            en: "Add pet now",
                            de: "Tier jetzt hinzufügen",
                            es: "Añadir ahora",
                            pt: "Adicionar agora",
                            fr: "Ajouter maintenant",
                            ja: "今すぐ追加",
                            ko: "지금 추가",
                            it: "Aggiungi ora"
                        ),
                        systemImage: "pawprint.fill",
                        isLoading: false,
                        isEnabled: true,
                        identifier: "onboarding-create-pet-now",
                        action: startPetCreation
                    )

                    Button(action: deferPetCreation) {
                        Text(localized(
                            zh: "稍后再说",
                            en: "Maybe later",
                            de: "Vielleicht später",
                            es: "Más tarde",
                            pt: "Mais tarde",
                            fr: "Plus tard",
                            ja: "後で",
                            ko: "나중에",
                            it: "Più tardi"
                        ))
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
                        de: "Wir legen es in Aufgaben ab, damit du jederzeit fortfahren kannst.",
                        es: "Si omites este paso, lo añadiremos a Tareas para que puedas continuar cuando quieras.",
                        pt: "Se você pular, vamos adicionar a Tarefas para continuar quando quiser.",
                        fr: "Si vous passez cette étape, nous l’ajouterons aux tâches afin de reprendre à tout moment.",
                        ja: "スキップすると「やること」に追加され、いつでも続けられます。",
                        ko: "건너뛰면 ‘할 일’에 추가되어 언제든 이어서 할 수 있어요.",
                        it: "Se salti, lo aggiungeremo alle attività così potrai continuare quando vuoi."
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
                    de: "Die Einrichtung ist abgeschlossen",
                    es: "La configuración ya está completa",
                    pt: "A configuração já foi concluída",
                    fr: "La configuration est déjà terminée",
                    ja: "初期設定は完了しています",
                    ko: "초기 설정이 완료되었어요",
                    it: "La configurazione è già completata"
                ))
                .font(OhanaFont.title(.black))
                .foregroundStyle(OnboardingPalette.primaryText)
                .multilineTextAlignment(.center)

                primaryButton(
                    title: localized(
                        zh: "关闭",
                        en: "Close",
                        de: "Schließen",
                        es: "Cerrar",
                        pt: "Fechar",
                        fr: "Fermer",
                        ja: "閉じる",
                        ko: "닫기",
                        it: "Chiudi"
                    ),
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
            if experienceMode == .zen {
                finishOnboarding(playsFeedback: false)
                return
            }
            withAnimation(GoMotion.page) {
                step = .petChoice
            }
        } catch MemberCreationError.duplicateName {
            handleHumanSaveFailure(localized(
                zh: "这个名字已经被使用。",
                en: "This name is already in use.",
                de: "Dieser Name wird bereits verwendet.",
                es: "Este nombre ya está en uso.",
                pt: "Este nome já está em uso.",
                fr: "Ce nom est déjà utilisé.",
                ja: "この名前はすでに使われています。",
                ko: "이미 사용 중인 이름이에요.",
                it: "Questo nome è già in uso."
            ))
        } catch MemberCreationError.emptyName {
            handleHumanSaveFailure(localized(
                zh: "请先输入名字。",
                en: "Enter a name first.",
                de: "Gib zuerst einen Namen ein.",
                es: "Introduce primero un nombre.",
                pt: "Digite um nome primeiro.",
                fr: "Saisissez d’abord un nom.",
                ja: "先に名前を入力してください。",
                ko: "먼저 이름을 입력해 주세요.",
                it: "Inserisci prima un nome."
            ))
        } catch {
            handleHumanSaveFailure(localized(
                zh: "保存失败，请再试一次。",
                en: "Saving failed. Please try again.",
                de: "Speichern fehlgeschlagen. Bitte versuche es erneut.",
                es: "No se pudo guardar. Inténtalo de nuevo.",
                pt: "Não foi possível salvar. Tente novamente.",
                fr: "Échec de l’enregistrement. Réessayez.",
                ja: "保存できませんでした。もう一度お試しください。",
                ko: "저장하지 못했어요. 다시 시도해 주세요.",
                it: "Salvataggio non riuscito. Riprova."
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
        if experienceMode == .zen,
           let humanID = appServices.humanRequirements.firstLivingHumanID(context: modelContext) {
            currentActiveHumanId = humanID.uuidString
            onFirstHumanSaved?(humanID)
            finishOnboarding(playsFeedback: false)
            return
        }
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
