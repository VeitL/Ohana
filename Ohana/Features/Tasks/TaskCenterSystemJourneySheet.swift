//
//  TaskCenterSystemJourneySheet.swift
//  Ohana
//
//  Card-based question flow for household starter tasks.
//

import SwiftUI

enum TaskCenterSystemJourneyMutationOutcome {
    case success
    case failure(String)
}

struct TaskCenterSystemJourneySheet: View {
    let item: TaskCenterItemSnapshot
    let taskState: HouseholdStarterJourneyTaskState?
    let onOpenDestination: (HouseholdStarterJourneyCheckpoint?) -> Void
    let onClaim: () -> TaskCenterSystemJourneyMutationOutcome
    let onRecordResolution: (
        HouseholdStarterJourneyCheckpoint,
        HouseholdStarterJourneyResolution
    ) -> TaskCenterSystemJourneyMutationOutcome
    let onClose: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AccessibilityFocusState private var focusedQuestionIndex: Int?
    @State private var recordedResolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution] = [:]
    @State private var questionIndex = 0
    @State private var errorMessage: String?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                            .id("task-center-starter-journey-top")

                        if let guide {
                            progress(guide)
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(OhanaFont.footnote(.semibold))
                                .foregroundStyle(Color.goRed)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("task-center-starter-journey-error")
                        }

                        if sheetMode == .rewardClaim {
                            rewardReadyContent
                        } else if sheetMode == .completedThisSession {
                            localCompletionCard
                        } else if let guide, let question = currentQuestion(in: guide) {
                            questionCard(question, guide: guide)
                            questionNavigation(guide)
                        } else {
                            Text(explanation)
                                .font(OhanaFont.callout())
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            openButton(checkpoint: nil, title: openActionTitle)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 34)
                }
                .onChange(of: questionIndex) { _, newIndex in
                    withAnimation(GoMotion.selection) {
                        scrollProxy.scrollTo("task-center-starter-journey-top", anchor: .top)
                    }
                    focusQuestion(newIndex)
                }
            }
            .background(OhanaAppBackground().ignoresSafeArea())
            .navigationTitle(l.tr(zh: "引导完成", en: "Guided setup", de: "Geführte Einrichtung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark") // a11y: allow decorative close glyph is hidden and the parent Button is labeled
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                    .accessibilityIdentifier("task-center-starter-journey-close")
                }
            }
        }
        .onAppear {
            questionIndex = guide?.initialQuestionIndex ?? 0
        }
        .onChange(of: guide?.completedCheckpointCount) { oldCount, newCount in
            guard let oldCount,
                  let newCount,
                  newCount > oldCount,
                  let guide,
                  !guide.isComplete,
                  let nextIndex = guide.nextIncompleteQuestionIndex(after: questionIndex) else {
                return
            }
            withAnimation(GoMotion.selection) {
                questionIndex = nextIndex
            }
        }
        .accessibilityIdentifier("task-center-starter-journey-sheet-\(item.systemDestination?.rawValue ?? "unknown")")
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.symbol)
                .font(OhanaFont.adaptive(size: 22, weight: .bold))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 52, height: 52)
                .background(Color.goPrimary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    if let subjectName = item.subjectName, !subjectName.isEmpty {
                        Text(subjectName)
                        Text("·")
                            .accessibilityHidden(true)
                    }
                    Text("+\(item.rewardCoconuts) 🥥")
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goPrimary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func progress(_ guide: TaskCenterSystemJourneyGuide) -> some View {
        let usesCompletionPercent = guide.completionPercent != nil
            && guide.requiredCompletionPercent != nil
        let progressValue = usesCompletionPercent
            ? Double(guide.completionPercent ?? 0)
            : Double(guide.completedCheckpointCount)
        let progressTotal = usesCompletionPercent
            ? 100
            : Double(max(1, guide.requiredCheckpointCount))
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(progressTitle(for: guide))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(usesCompletionPercent
                    ? "\(guide.completionPercent ?? 0)%"
                    : "\(guide.completedCheckpointCount)/\(guide.requiredCheckpointCount)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .monospacedDigit()
            }
            ProgressView(
                value: progressValue,
                total: progressTotal
            )
            .tint(Color.goPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("task-center-starter-journey-progress")
    }

    private func progressTitle(for guide: TaskCenterSystemJourneyGuide) -> String {
        if guide.completionPercent != nil,
           let requiredPercent = guide.requiredCompletionPercent {
            return l.tr(
                zh: "资料完成度 · 达到 \(requiredPercent)% 可领取",
                en: "Profile completion · Claim at \(requiredPercent)%",
                de: "Profilfortschritt · Ab \(requiredPercent)% abholbar",
                es: "Perfil · Reclama al \(requiredPercent)%",
                pt: "Perfil · Resgate com \(requiredPercent)%",
                fr: "Profil · Récompense à \(requiredPercent)%",
                ja: "プロフィール完成度 · \(requiredPercent)%で受取可能",
                ko: "프로필 완성도 · \(requiredPercent)%에서 수령",
                it: "Profilo · Premio al \(requiredPercent)%"
            )
        }
        return l.tr(zh: "完成进度", en: "Progress", de: "Fortschritt")
    }

    private func questionCard(
        _ question: TaskCenterSystemJourneyGuide.Question,
        guide: TaskCenterSystemJourneyGuide
    ) -> some View {
        let completed = guide.isCompleted(question)
        let resolutions = guide.allowedResolutions(for: question)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text(l.tr(
                    zh: "第 \(questionIndex + 1) / \(guide.questions.count) 题",
                    en: "Question \(questionIndex + 1) of \(guide.questions.count)",
                    de: "Frage \(questionIndex + 1) von \(guide.questions.count)"
                ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goPrimary)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(Color.goPrimary.opacity(0.12), in: Capsule())

                Spacer(minLength: 0)

                if completed {
                    Label(
                        l.tr(zh: "已完成", en: "Complete", de: "Erledigt"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goTeal)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: questionSymbol(question))
                    .font(OhanaFont.adaptive(size: 24, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)

                Text(questionPrompt(question))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("task-center-starter-question-\(question.id)")
                    .accessibilityFocused($focusedQuestionIndex, equals: questionIndex)

                Text(questionDetail(question))
                    .font(OhanaFont.callout())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if completed {
                completedAnswer(question)
            }

            openButton(
                checkpoint: question.checkpoint,
                title: completed ? reviewAgainTitle(question) : openQuestionActionTitle(question)
            )

            if !completed, !resolutions.isEmpty {
                Divider().overlay(Color.ohanaCardStroke)

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(
                        zh: "也可以按真实情况回答",
                        en: "Or answer for your current situation",
                        de: "Oder passend zur aktuellen Situation antworten"
                    ))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)

                    ForEach(resolutions, id: \.rawValue) { resolution in
                        resolutionButton(resolution, question: question)
                    }

                    Label(
                        l.tr(
                            zh: "留空、未知或不愿透露同样有效，不需要为了奖励补写敏感资料。",
                            en: "Leaving details unknown or private is valid. Never add sensitive information just for a reward.",
                            de: "Unbekannte oder private Angaben sind gültig. Trage sensible Daten nie nur für eine Belohnung ein."
                        ),
                        systemImage: "hand.raised.fill"
                    )
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(completed ? Color.goTeal.opacity(0.48) : Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func openButton(
        checkpoint: HouseholdStarterJourneyCheckpoint?,
        title: String
    ) -> some View {
        Button {
            OhanaFeedback.light()
            onOpenDestination(checkpoint)
        } label: {
            Label(title, systemImage: openActionSymbol)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .accessibilityHint(l.tr(
            zh: "打开对应页面填写或记录，保存后任务会自动重新判断。",
            en: "Open the matching page. After saving, the task checks your progress again.",
            de: "Öffnet die passende Seite. Nach dem Speichern wird der Fortschritt erneut geprüft."
        ))
        .accessibilityIdentifier("task-center-starter-journey-open-\(checkpoint?.rawValue ?? item.systemDestination?.rawValue ?? "unknown")")
    }

    private func resolutionButton(
        _ resolution: HouseholdStarterJourneyResolution,
        question: TaskCenterSystemJourneyGuide.Question
    ) -> some View {
        Button {
            guard let checkpoint = question.checkpoint else { return }
            record(resolution, for: checkpoint)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: resolutionSymbol(resolution))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(resolutionTitle(resolution, checkpoint: question.checkpoint))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward") // a11y: allow decorative direction glyph is hidden by the chained modifier below
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
            }
            .font(OhanaFont.callout(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
        .tint(Color.goPrimary)
        .accessibilityIdentifier(
            "task-center-starter-resolution-\(question.checkpoint?.rawValue ?? "none")-\(resolution.rawValue)"
        )
    }

    private func completedAnswer(_ question: TaskCenterSystemJourneyGuide.Question) -> some View {
        let resolution = question.checkpoint.flatMap {
            completedAnswerResolution(for: $0)
        }
        let text = resolution.map { resolutionTitle($0, checkpoint: question.checkpoint) }
            ?? l.tr(
                zh: "现有资料已经满足这一题。",
                en: "Your existing information already answers this question.",
                de: "Die vorhandenen Angaben beantworten diese Frage bereits."
            )
        return Label(text, systemImage: "checkmark.seal.fill")
            .font(OhanaFont.footnote(.semibold))
            .foregroundStyle(Color.goTeal)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("task-center-starter-answer-complete-\(question.id)")
    }

    private func completedAnswerResolution(
        for checkpoint: HouseholdStarterJourneyCheckpoint
    ) -> HouseholdStarterJourneyResolution? {
        if let taskState, taskState.completedCheckpoints.contains(checkpoint) {
            return taskState.checkpointResolutions[checkpoint]
        }
        return recordedResolutions[checkpoint] ?? taskState?.checkpointResolutions[checkpoint]
    }

    private func questionNavigation(_ guide: TaskCenterSystemJourneyGuide) -> some View {
        HStack(spacing: 12) {
            if questionIndex > 0 {
                Button {
                    moveQuestion(by: -1, guide: guide)
                } label: {
                    Label(
                        l.tr(zh: "上一题", en: "Previous", de: "Zurück"),
                        systemImage: "chevron.backward"
                    )
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("task-center-starter-question-previous")
            }

            Spacer(minLength: 0)

            if questionIndex < guide.questions.count - 1 {
                Button {
                    moveQuestion(by: 1, guide: guide)
                } label: {
                    Label(
                        l.tr(zh: "下一题", en: "Next", de: "Weiter"),
                        systemImage: "chevron.forward"
                    )
                    .labelStyle(.titleAndIcon)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("task-center-starter-question-next")
            }
        }
    }

    private var rewardReadyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(
                isProfileCompletionTask
                    ? l.tr(
                        zh: "资料完成度已达到 75%",
                        en: "Profile completion reached 75%",
                        de: "Profil ist zu 75% vollständig",
                        es: "El perfil alcanzó el 75%",
                        pt: "O perfil chegou a 75%",
                        fr: "Le profil a atteint 75%",
                        ja: "プロフィール完成度が75%に到達",
                        ko: "프로필 완성도 75% 달성",
                        it: "Il profilo ha raggiunto il 75%"
                    )
                    : l.tr(zh: "所有问题都已完成", en: "All questions complete", de: "Alle Fragen abgeschlossen"),
                systemImage: "checkmark.seal.fill"
            )
            .font(OhanaFont.headline(.black))
            .foregroundStyle(Color.goTeal)

            Text(l.tr(
                zh: "资料或真实照护已经通过检查。奖励不会自动发放，请由你确认领取。",
                en: "Your information or real care activity passed the check. Confirm the reward when you are ready.",
                de: "Angaben oder echte Pflege wurden geprüft. Bestätige die Belohnung, wenn du bereit bist."
            ))
            .font(OhanaFont.callout())
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)

            claimButton
        }
        .padding(18)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.goTeal.opacity(0.42), lineWidth: 1)
        }
    }

    private var localCompletionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative completion glyph is hidden by the chained modifier below
                .font(OhanaFont.adaptive(size: 34, weight: .bold))
                .foregroundStyle(Color.goTeal)
                .accessibilityHidden(true)

            Text(l.tr(zh: "这项引导已完成", en: "Guided setup complete", de: "Einrichtung abgeschlossen"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .accessibilityIdentifier("task-center-starter-journey-complete")

            Text(l.tr(
                zh: "返回待办后，这项任务会切换为“领取”。资料保存和奖励领取始终是两步。",
                en: "Return to Tasks and this item will change to Claim. Saving information and claiming the reward stay separate.",
                de: "Zurück in Aufgaben wechselt der Eintrag zu „Abholen“. Speichern und Belohnung bleiben getrennt."
            ))
            .font(OhanaFont.callout())
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                OhanaFeedback.success()
                onClose()
            } label: {
                Text(l.tr(zh: "返回待办", en: "Back to Tasks", de: "Zurück zu Aufgaben"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goTeal)
            .accessibilityIdentifier("task-center-starter-journey-finish")
        }
        .padding(18)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.goTeal.opacity(0.42), lineWidth: 1)
        }
    }

    private var claimButton: some View {
        Button {
            switch onClaim() {
            case .success:
                errorMessage = nil
                OhanaFeedback.success()
            case let .failure(message):
                errorMessage = message
                OhanaFeedback.error()
            }
        } label: {
            Text(l.tr(
                zh: "领取 \(item.rewardCoconuts) 椰子",
                en: "Claim \(item.rewardCoconuts) coconuts",
                de: "\(item.rewardCoconuts) Kokosnüsse abholen"
            ))
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .accessibilityIdentifier("task-center-starter-journey-claim-\(item.systemDestination?.rawValue ?? "unknown")")
    }

    private func record(
        _ resolution: HouseholdStarterJourneyResolution,
        for checkpoint: HouseholdStarterJourneyCheckpoint
    ) {
        switch onRecordResolution(checkpoint, resolution) {
        case .success:
            recordedResolutions[checkpoint] = resolution
            errorMessage = nil
            OhanaFeedback.selection()
        case let .failure(message):
            errorMessage = message
            OhanaFeedback.error()
        }
    }

    private func moveQuestion(by offset: Int, guide: TaskCenterSystemJourneyGuide) {
        let destination = min(max(questionIndex + offset, 0), guide.questions.count - 1)
        guard destination != questionIndex else { return }
        OhanaFeedback.selection()
        withAnimation(GoMotion.selection) {
            questionIndex = destination
        }
    }

    private func focusQuestion(_ index: Int) {
        focusedQuestionIndex = nil
        Task { @MainActor in
            await Task.yield()
            guard questionIndex == index else { return }
            focusedQuestionIndex = index
        }
    }

    private func currentQuestion(
        in guide: TaskCenterSystemJourneyGuide
    ) -> TaskCenterSystemJourneyGuide.Question? {
        guard guide.questions.indices.contains(questionIndex) else {
            return guide.questions.first
        }
        return guide.questions[questionIndex]
    }

    private var guide: TaskCenterSystemJourneyGuide? {
        if let taskState {
            return TaskCenterSystemJourneyGuide(
                state: taskState,
                locallyCompletedCheckpoints: Set(recordedResolutions.keys)
            )
        }
        guard let task = fallbackTask else { return nil }
        return TaskCenterSystemJourneyGuide(task: task)
    }

    private var fallbackTask: HouseholdStarterJourneyTask? {
        switch item.systemDestination {
        case .completeHumanProfile: .humanProfile
        case .completeFirstPetProfile: .petProfile
        case .confirmPetIdentityProtection: .identityProtection
        case .confirmPetPreventiveCare: .healthProtection
        case .configureFirstCarePlan: .carePlan
        case .recordFirstCare: .firstCare
        case .createFirstPet, .claimStarterGift, nil: nil
        }
    }

    private var isProfileCompletionTask: Bool {
        guide?.task == .humanProfile || guide?.task == .petProfile
    }

    private var sheetMode: TaskCenterSystemJourneySheetMode {
        TaskCenterSystemJourneySheetMode.resolve(
            openedAs: item.systemJourneyPresentationState,
            guideIsComplete: guide?.isComplete == true
        )
    }

    private func resolutionTitle(
        _ resolution: HouseholdStarterJourneyResolution,
        checkpoint: HouseholdStarterJourneyCheckpoint?
    ) -> String {
        switch resolution {
        case .reviewed:
            if checkpoint == .acceptedRecommendedCarePlan {
                l.tr(zh: "采用推荐计划", en: "Use recommended plan", de: "Empfohlenen Plan verwenden")
            } else if checkpoint == .petDailyCare {
                l.tr(zh: "沿用当前设置", en: "Use current setup", de: "Aktuelle Einstellung verwenden")
            } else if checkpoint == .humanAppearance {
                l.tr(zh: "当前形象就很好", en: "Keep my current look", de: "Aktuelles Aussehen beibehalten")
            } else {
                l.tr(zh: "当前状态已确认", en: "Current status reviewed", de: "Aktuellen Stand bestätigt")
            }
        case .unknown:
            l.tr(zh: "暂不清楚", en: "Not sure yet", de: "Noch unklar")
        case .notApplicable:
            l.tr(zh: "不适用", en: "Not applicable", de: "Nicht zutreffend")
        case .preferNotToSay:
            l.tr(zh: "暂不透露", en: "Prefer not to say", de: "Keine Angabe")
        }
    }

    private func resolutionSymbol(_ resolution: HouseholdStarterJourneyResolution) -> String {
        switch resolution {
        case .reviewed: "checkmark.circle"
        case .unknown: "questionmark.circle"
        case .notApplicable: "minus.circle"
        case .preferNotToSay: "hand.raised"
        }
    }

    private func questionSymbol(_ question: TaskCenterSystemJourneyGuide.Question) -> String {
        switch question.checkpoint {
        case .humanAppearance: "person.crop.circle"
        case .humanLifeStage: "calendar.badge.clock"
        case .humanBodyProfile: "person.text.rectangle"
        case .humanPersonalityContext: "text.quote"
        case .humanOptionalDetails: "person.text.rectangle"
        case .petLifeStage: "calendar.badge.clock"
        case .petBodyProfile: "pawprint.circle"
        case .petPersonalityAppearance: "sparkles"
        case .petDailyCare: "fork.knife.circle"
        case .petIdentityDocuments: "doc.text.magnifyingglass"
        case .petEmergencyContact: "cross.case.fill"
        case .petHealthProtection: "syringe.fill"
        case .acceptedRecommendedCarePlan: "calendar.badge.checkmark"
        case nil: "heart.circle.fill"
        }
    }

    private func questionPrompt(_ question: TaskCenterSystemJourneyGuide.Question) -> String {
        switch question.checkpoint {
        case .humanAppearance:
            l.tr(
                zh: "你想用怎样的形象代表自己？", en: "How would you like your member card to represent you?", de: "Wie soll deine Mitgliedskarte dich darstellen?",
                es: "¿Cómo quieres que te represente tu tarjeta?", pt: "Como você quer ser representado no cartão?", fr: "Comment souhaitez-vous être représenté sur votre carte ?",
                ja: "メンバーカードで自分をどう表現しますか？", ko: "멤버 카드에서 나를 어떻게 표현할까요?", it: "Come vuoi essere rappresentato sulla tua scheda?"
            )
        case .humanLifeStage:
            l.tr(
                zh: "请填写本人的生日", en: "Add your birthday", de: "Geburtstag eintragen",
                es: "Añade tu cumpleaños", pt: "Adicione seu aniversário", fr: "Ajoutez votre anniversaire",
                ja: "本人の誕生日を入力", ko: "본인의 생일을 입력해 주세요", it: "Aggiungi il tuo compleanno"
            )
        case .humanBodyProfile:
            l.tr(
                zh: "请选择本人的性别或身份", en: "Choose your gender or identity", de: "Geschlecht oder Identität auswählen",
                es: "Elige tu género o identidad", pt: "Escolha seu gênero ou identidade", fr: "Choisissez votre genre ou identité",
                ja: "本人の性別またはアイデンティティを選択", ko: "본인의 성별 또는 정체성을 선택해 주세요", it: "Scegli il tuo genere o la tua identità"
            )
        case .humanPersonalityContext:
            l.tr(
                zh: "还想补充哪些其他资料？", en: "Which other details would you like to add?", de: "Welche weiteren Angaben möchtest du ergänzen?",
                es: "¿Qué otros datos quieres añadir?", pt: "Quais outros detalhes você quer adicionar?", fr: "Quelles autres informations souhaitez-vous ajouter ?",
                ja: "ほかに追加したい情報は？", ko: "어떤 기타 정보를 추가하고 싶나요?", it: "Quali altri dettagli vuoi aggiungere?"
            )
        case .humanOptionalDetails:
            l.tr(zh: "哪些可选资料会让成员卡更有用？", en: "Which optional details would make your member card useful?", de: "Welche optionalen Angaben machen deine Karte nützlicher?")
        case .petLifeStage:
            l.tr(zh: "你知道它的生日、年龄或到家日期吗？", en: "Do you know their birthday, age, or homecoming date?", de: "Kennst du Geburtstag, Alter oder Einzugsdatum?")
        case .petBodyProfile:
            l.tr(zh: "需要补充它的身体资料吗？", en: "Would you like to add their body profile?", de: "Möchtest du das Körperprofil ergänzen?")
        case .petPersonalityAppearance:
            l.tr(zh: "什么头像或性格最能代表它？", en: "Which look or personality best represents them?", de: "Welches Aussehen oder welcher Charakter passt am besten?")
        case .petDailyCare:
            l.tr(zh: "当前的日常照护设置合适吗？", en: "Does the current daily-care setup work for you?", de: "Passt die aktuelle tägliche Pflege?")
        case .petIdentityDocuments:
            l.tr(zh: "有哪些证件或保障可以记录？", en: "Which identity or protection records are available?", de: "Welche Dokumente oder Schutzangaben sind vorhanden?")
        case .petEmergencyContact:
            l.tr(zh: "紧急时应该联系谁？", en: "Who should be contacted in an emergency?", de: "Wer soll im Notfall kontaktiert werden?")
        case .petHealthProtection:
            l.tr(zh: "疫苗、驱虫或体检当前是什么状态？", en: "What is the current vaccine, deworming, or checkup status?", de: "Wie ist der Stand bei Impfungen, Entwurmung oder Kontrollen?")
        case .acceptedRecommendedCarePlan:
            l.tr(zh: "想按什么节奏安排日常照护？", en: "What daily-care rhythm works for you?", de: "Welcher Pflegerhythmus passt zu euch?")
        case nil:
            l.tr(zh: "刚刚完成了哪一次真实照护？", en: "Which real care action did you complete?", de: "Welche echte Pflege hast du erledigt?")
        }
    }

    private func questionDetail(_ question: TaskCenterSystemJourneyGuide.Question) -> String {
        switch question.checkpoint {
        case .humanAppearance:
            l.tr(
                zh: "设置头像或个人风格；也可以确认沿用当前形象。", en: "Set an avatar or personal style, or keep your current look.", de: "Lege Avatar oder Stil fest oder behalte das aktuelle Aussehen.",
                es: "Elige un avatar o estilo personal, o conserva tu aspecto actual.", pt: "Escolha um avatar ou estilo pessoal, ou mantenha o visual atual.", fr: "Choisissez un avatar ou un style personnel, ou gardez l’apparence actuelle.",
                ja: "アバターや自分らしいスタイルを設定するか、現在の外観をそのまま使えます。", ko: "아바타나 개인 스타일을 설정하거나 현재 모습을 그대로 사용할 수 있어요.", it: "Scegli un avatar o uno stile personale, oppure mantieni l’aspetto attuale."
            )
        case .humanLifeStage:
            l.tr(
                zh: "生日是本人资料任务的必填项，也用于年龄、星座与纪念日展示。", en: "Birthday is required for this profile task and enables age, zodiac, and anniversary details.", de: "Der Geburtstag ist für diese Profilaufgabe erforderlich und ermöglicht Alters-, Sternzeichen- und Jahrestagsangaben.",
                es: "El cumpleaños es obligatorio para esta tarea y permite mostrar edad, signo y aniversarios.", pt: "O aniversário é obrigatório nesta tarefa e permite mostrar idade, signo e datas especiais.", fr: "L’anniversaire est requis pour cette tâche et permet d’afficher l’âge, le signe et les dates marquantes.",
                ja: "誕生日はこのプロフィールタスクの必須項目で、年齢・星座・記念日の表示に使われます。", ko: "생일은 이 프로필 과제의 필수 항목이며 나이, 별자리, 기념일 표시에 사용돼요.", it: "Il compleanno è obbligatorio per questa attività e abilita età, segno e ricorrenze."
            )
        case .humanBodyProfile:
            l.tr(
                zh: "性别或身份必须作出选择；“不愿透露”也是有效选择。血型和身高仍为可选。", en: "A gender or identity choice is required; “Prefer not to say” is valid. Blood type and height remain optional.", de: "Eine Auswahl zu Geschlecht oder Identität ist erforderlich; „Keine Angabe“ ist gültig. Blutgruppe und Größe bleiben optional.",
                es: "Debes elegir género o identidad; «Prefiero no decirlo» es válido. El grupo sanguíneo y la altura siguen siendo opcionales.", pt: "É necessário escolher gênero ou identidade; “Prefiro não informar” é válido. Tipo sanguíneo e altura continuam opcionais.", fr: "Un choix de genre ou d’identité est requis ; « Je préfère ne pas répondre » est valide. Le groupe sanguin et la taille restent facultatifs.",
                ja: "性別またはアイデンティティの選択は必須です。「回答しない」も有効です。血液型と身長は任意です。", ko: "성별 또는 정체성을 선택해야 하며 ‘공개하지 않음’도 유효해요. 혈액형과 키는 선택 사항이에요.", it: "È richiesta una scelta di genere o identità; “Preferisco non dirlo” è valida. Gruppo sanguigno e altezza restano facoltativi."
            )
        case .humanPersonalityContext:
            l.tr(
                zh: "血型、身高、MBTI、地区与个人故事都可选，也可以明确暂不填写。", en: "Blood type, height, MBTI, location, and your story are optional and can be explicitly left blank.", de: "Blutgruppe, Größe, MBTI, Ort und Geschichte sind optional und können bewusst leer bleiben.",
                es: "El grupo sanguíneo, la altura, el MBTI, el lugar y la historia son opcionales y pueden dejarse explícitamente en blanco.", pt: "Tipo sanguíneo, altura, MBTI, local e história são opcionais e podem ficar explicitamente em branco.", fr: "Le groupe sanguin, la taille, le MBTI, le lieu et l’histoire sont facultatifs et peuvent être explicitement laissés vides.",
                ja: "血液型・身長・MBTI・地域・ストーリーは任意で、明示的に未入力を選べます。", ko: "혈액형, 키, MBTI, 지역, 이야기는 선택 사항이며 명시적으로 비워둘 수 있어요.", it: "Gruppo sanguigno, altezza, MBTI, luogo e storia sono facoltativi e possono essere lasciati esplicitamente vuoti."
            )
        case .humanOptionalDetails:
            l.tr(
                zh: "这是旧版资料确认，只计入其他资料；生日与性别/身份仍需真实填写。",
                en: "This legacy answer counts only toward other details; birthday and gender/identity still require real entries.",
                de: "Diese alte Antwort zählt nur für weitere Angaben; Geburtstag und Geschlecht/Identität müssen weiterhin wirklich eingetragen werden."
            )
        case .petLifeStage:
            l.tr(zh: "生日和到家日有助于年龄与纪念日提醒，不清楚也可以直接说明。", en: "Dates help with age and anniversary reminders. It is fine if you do not know them.", de: "Daten helfen bei Alters- und Jahrestagserinnerungen. Unbekannt ist in Ordnung.")
        case .petBodyProfile:
            l.tr(zh: "性别、毛色或出生地可帮助形成更准确的档案。", en: "Sex, coat, or birthplace can make the profile more useful.", de: "Geschlecht, Fell oder Geburtsort können das Profil nützlicher machen.")
        case .petPersonalityAppearance:
            l.tr(zh: "用头像或性格标签，让家人更快认出这位伙伴。", en: "Use an avatar or personality tag to make them easy to recognize.", de: "Avatar oder Charaktermerkmal machen dein Tier leichter erkennbar.")
        case .petDailyCare:
            l.tr(zh: "检查饮食、份量、补货与提醒；没有固定设置也可以如实确认。", en: "Review food, portions, restocking, and reminders. No fixed setup is also a valid answer.", de: "Prüfe Futter, Portionen, Vorrat und Erinnerungen. Keine feste Einstellung ist ebenfalls gültig.")
        case .petIdentityDocuments:
            l.tr(zh: "可以记录芯片、护照、保险或其他已有证件。", en: "Record a microchip, passport, insurance, or other available document.", de: "Erfasse Chip, Pass, Versicherung oder andere vorhandene Dokumente.")
        case .petEmergencyContact:
            l.tr(zh: "补充诊所、兽医、电话、地址或过敏信息；没有固定联系人也可说明。", en: "Add a clinic, vet, phone, address, or allergy note. No regular contact is a valid answer too.", de: "Ergänze Klinik, Tierarzt, Telefon, Adresse oder Allergien. Kein fester Kontakt ist ebenfalls gültig.")
        case .petHealthProtection:
            l.tr(zh: "只记录真实发生的保健事实；不要为了完成任务编造记录。", en: "Record only real preventive-care facts. Never invent a health record to finish a task.", de: "Erfasse nur echte Vorsorge. Erfinde keine Gesundheitsdaten für eine Aufgabe.")
        case .acceptedRecommendedCarePlan:
            l.tr(zh: "建立自己的重复照护计划，或在可用时明确采用系统推荐。", en: "Create your own repeating care plan, or explicitly use the recommendation when available.", de: "Erstelle einen wiederkehrenden Plan oder übernimm ausdrücklich die Empfehlung.")
        case nil:
            l.tr(zh: "喂食、饮水、如厕、遛狗、陪玩或卫生等真实照护才会计入；这里没有跳过捷径。", en: "A real feeding, watering, potty, walk, play, or hygiene action counts. This step has no skip shortcut.", de: "Nur echte Fütterung, Wasser-, Toiletten-, Spazier-, Spiel- oder Hygienepflege zählt."
            )
        }
    }

    private func openQuestionActionTitle(_ question: TaskCenterSystemJourneyGuide.Question) -> String {
        switch question.checkpoint {
        case .humanAppearance:
            l.tr(
                zh: "去设置头像与形象", en: "Set avatar and look", de: "Avatar und Aussehen festlegen",
                es: "Configurar avatar y aspecto", pt: "Definir avatar e visual", fr: "Définir l’avatar et l’apparence",
                ja: "アバターと外観を設定", ko: "아바타와 모습 설정", it: "Imposta avatar e aspetto"
            )
        case .humanLifeStage: l.tr(zh: "去填写生日资料", en: "Add birthday details", de: "Geburtstag ergänzen", es: "Añadir cumpleaños", pt: "Adicionar aniversário", fr: "Ajouter l’anniversaire", ja: "誕生日を追加", ko: "생일 정보 추가", it: "Aggiungi compleanno")
        case .humanBodyProfile: l.tr(zh: "去选择性别或身份", en: "Choose gender or identity", de: "Geschlecht oder Identität wählen", es: "Elegir género o identidad", pt: "Escolher gênero ou identidade", fr: "Choisir le genre ou l’identité", ja: "性別または本人情報を選択", ko: "성별 또는 정체성 선택", it: "Scegli genere o identità")
        case .humanPersonalityContext: l.tr(zh: "去完善其他资料", en: "Add more details", de: "Weitere Angaben ergänzen", es: "Añadir más datos", pt: "Adicionar mais detalhes", fr: "Ajouter d’autres informations", ja: "その他の情報を追加", ko: "기타 정보 추가", it: "Aggiungi altri dettagli")
        case .humanOptionalDetails: l.tr(zh: "去填写可选资料", en: "Add optional details", de: "Optionale Angaben ergänzen")
        case .petLifeStage: l.tr(zh: "去填写日期资料", en: "Add dates", de: "Daten ergänzen")
        case .petBodyProfile: l.tr(zh: "去填写身体资料", en: "Add body profile", de: "Körperprofil ergänzen")
        case .petPersonalityAppearance: l.tr(zh: "去设置头像与性格", en: "Set look and personality", de: "Aussehen und Charakter festlegen")
        case .petDailyCare: l.tr(zh: "去检查日常照护", en: "Review daily care", de: "Tägliche Pflege prüfen")
        case .petIdentityDocuments: l.tr(zh: "去添加证件与保障", en: "Add documents and protection", de: "Dokumente und Schutz ergänzen")
        case .petEmergencyContact: l.tr(zh: "去填写紧急联系", en: "Add emergency contact", de: "Notfallkontakt ergänzen")
        case .petHealthProtection: l.tr(zh: "去记录保健状态", en: "Record preventive care", de: "Vorsorge erfassen")
        case .acceptedRecommendedCarePlan: l.tr(zh: "去设置照护计划", en: "Set up care plan", de: "Pflegeplan einrichten")
        case nil: l.tr(zh: "去记录一次真实照护", en: "Record a real care action", de: "Echte Pflege erfassen")
        }
    }

    private func reviewAgainTitle(_ question: TaskCenterSystemJourneyGuide.Question) -> String {
        switch question.checkpoint {
        case nil:
            openQuestionActionTitle(question)
        default:
            l.tr(zh: "重新查看或修改", en: "Review or edit", de: "Prüfen oder bearbeiten")
        }
    }

    private var openActionSymbol: String {
        switch guide?.task {
        case .carePlan: "calendar.badge.plus"
        case .firstCare: "plus.circle.fill"
        case .healthProtection: "cross.case.fill"
        case .identityProtection: "doc.badge.plus"
        case .humanProfile, .petProfile, nil: "arrow.up.right"
        }
    }

    private var openActionTitle: String {
        switch guide?.task {
        case .humanProfile: l.tr(zh: "查看人类资料", en: "Review human profile", de: "Menschenprofil prüfen")
        case .petProfile: l.tr(zh: "查看宠物资料", en: "Review pet profile", de: "Haustierprofil prüfen")
        case .identityProtection: l.tr(zh: "查看证件与保障", en: "Review identity and protection", de: "Dokumente und Schutz prüfen")
        case .healthProtection: l.tr(zh: "查看疫苗与保健", en: "Review preventive care", de: "Vorsorge prüfen")
        case .carePlan: l.tr(zh: "设置照护计划", en: "Set up care plan", de: "Pflegeplan einrichten")
        case .firstCare: l.tr(zh: "记录一次照护", en: "Record a care action", de: "Pflege erfassen")
        case nil: l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
    }

    private var explanation: String {
        l.tr(
            zh: "跟着问题逐项完成；填写、保持现状或明确暂不提供都可以。",
            en: "Answer one question at a time. You can add details, keep the current state, or explicitly leave them private.",
            de: "Beantworte eine Frage nach der anderen. Ergänzen, beibehalten oder privat lassen ist möglich."
        )
    }
}
