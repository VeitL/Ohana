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

nonisolated enum TaskCenterSystemJourneyCopy {
    static func profile(_ l: L10n) -> String {
        l.tr(
            zh: "资料", en: "Profile", de: "Profil",
            es: "Perfil", pt: "Perfil", fr: "Profil",
            ja: "プロフィール", ko: "프로필", it: "Profilo"
        )
    }

    static func progress(_ l: L10n) -> String {
        l.tr(
            zh: "进度", en: "Progress", de: "Fortschritt",
            es: "Progreso", pt: "Progresso", fr: "Progression",
            ja: "進捗", ko: "진행", it: "Avanzamento"
        )
    }

    static func documents(_ l: L10n) -> String {
        l.tr(
            zh: "证件与保障", en: "Documents & protection", de: "Dokumente & Schutz",
            es: "Documentos y protección", pt: "Documentos e proteção", fr: "Documents et protection",
            ja: "書類と保障", ko: "서류 및 보호", it: "Documenti e protezione"
        )
    }

    static func emergencyContact(_ l: L10n) -> String {
        l.tr(
            zh: "紧急联系", en: "Emergency contact", de: "Notfallkontakt",
            es: "Contacto de emergencia", pt: "Contato de emergência", fr: "Contact d’urgence",
            ja: "緊急連絡先", ko: "긴급 연락처", it: "Contatto di emergenza"
        )
    }

    static func preventiveCare(_ l: L10n) -> String {
        l.tr(
            zh: "疫苗与保健", en: "Preventive care", de: "Vorsorge",
            es: "Cuidados preventivos", pt: "Cuidados preventivos", fr: "Soins préventifs",
            ja: "予防ケア", ko: "예방 관리", it: "Cure preventive"
        )
    }

    static func carePlan(_ l: L10n) -> String {
        l.tr(
            zh: "照护计划", en: "Care plan", de: "Pflegeplan",
            es: "Plan de cuidados", pt: "Plano de cuidados", fr: "Plan de soins",
            ja: "ケアプラン", ko: "돌봄 계획", it: "Piano di cura"
        )
    }

    static func recordCare(_ l: L10n) -> String {
        l.tr(
            zh: "记录一次照护", en: "Record care", de: "Pflege erfassen",
            es: "Registrar cuidado", pt: "Registrar cuidado", fr: "Enregistrer un soin",
            ja: "ケアを記録", ko: "돌봄 기록", it: "Registra una cura"
        )
    }

    static func completedCareOnly(_ l: L10n) -> String {
        l.tr(
            zh: "只记录真实完成的照护。", en: "Only completed care counts.", de: "Nur erledigte Pflege zählt.",
            es: "Solo cuenta el cuidado realizado.", pt: "Só contam cuidados concluídos.", fr: "Seuls les soins effectués comptent.",
            ja: "実際に完了したケアのみ記録します。", ko: "실제로 완료한 돌봄만 기록하세요.", it: "Conta solo la cura effettivamente completata."
        )
    }

    static func preventiveCareTruth(_ l: L10n) -> String {
        l.tr(
            zh: "只记录真实发生的保健事实；不要为了完成任务编造记录。",
            en: "Record only real preventive-care facts. Never invent a health record to finish a task.",
            de: "Erfasse nur echte Vorsorge. Erfinde keine Gesundheitsdaten für eine Aufgabe.",
            es: "Registra solo cuidados preventivos reales; no inventes datos para completar una tarea.",
            pt: "Registre apenas cuidados preventivos reais; não invente dados para concluir uma tarefa.",
            fr: "N’enregistrez que des soins préventifs réels ; n’inventez rien pour terminer une tâche.",
            ja: "実際に行った予防ケアだけを記録し、タスクのために記録を作らないでください。",
            ko: "실제로 한 예방 관리만 기록하고, 과제를 위해 기록을 만들지 마세요.",
            it: "Registra solo cure preventive reali; non inventare dati per completare un’attività."
        )
    }

    static func exactValues(_ l: L10n) -> [String] {
        [
            profile(l), progress(l), documents(l), emergencyContact(l),
            preventiveCare(l), carePlan(l), recordCare(l), completedCareOnly(l),
            preventiveCareTruth(l)
        ]
    }
}

struct TaskCenterSystemJourneySheet: View {
    let item: TaskCenterItemSnapshot
    let taskState: HouseholdStarterJourneyTaskState?
    let humanProfileTarget: Human?
    let petProfileTarget: Pet?
    let onOpenDestination: (HouseholdStarterJourneyCheckpoint?) -> Void
    let onUpdateHumanProfile: (
        TaskCenterHumanProfileInlineUpdate
    ) -> TaskCenterSystemJourneyMutationOutcome
    let onUpdatePetProfile: (
        TaskCenterPetProfileInlineUpdate
    ) -> TaskCenterSystemJourneyMutationOutcome
    let onClaim: () -> TaskCenterSystemJourneyMutationOutcome
    let onRecordResolution: (
        HouseholdStarterJourneyCheckpoint,
        HouseholdStarterJourneyResolution
    ) -> TaskCenterSystemJourneyMutationOutcome
    let onClose: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AccessibilityFocusState private var focusedQuestionIndex: Int?
    @State private var recordedResolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution] = [:]
    @State private var locallySavedHumanCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = []
    @State private var locallySavedPetCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = []
    @State private var expandedHumanCheckpoint: HouseholdStarterJourneyCheckpoint?
    @State private var expandedPetCheckpoint: HouseholdStarterJourneyCheckpoint?
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
                            openButton(checkpoint: nil, title: openActionTitle)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 34)
                }
                .onChange(of: questionIndex) { _, newIndex in
                    expandedHumanCheckpoint = nil
                    expandedPetCheckpoint = nil
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
                  guide.task != .humanProfile,
                  expandedPetCheckpoint == nil,
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
        if guide.completionPercent != nil {
            return TaskCenterSystemJourneyCopy.profile(l)
        }
        return TaskCenterSystemJourneyCopy.progress(l)
    }

    private func questionCard(
        _ question: TaskCenterSystemJourneyGuide.Question,
        guide: TaskCenterSystemJourneyGuide
    ) -> some View {
        let completed = guide.isCompleted(question)
        let resolutions = guide.allowedResolutions(for: question)
        let hasCompletedResolution = question.checkpoint.flatMap {
            completedAnswerResolution(for: $0)
        } != nil

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("\(questionIndex + 1)/\(guide.questions.count)")
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

                if let safetyNote = safetyNote(question) {
                    Text(safetyNote)
                        .font(OhanaFont.callout())
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if completed, !isProfileCompletionTask || hasCompletedResolution {
                completedAnswer(question)
            }

            if !completed, !resolutions.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(resolutions, id: \.rawValue) { resolution in
                        resolutionButton(resolution, question: question)
                    }
                }
            }

            if guide.task == .humanProfile, let checkpoint = question.checkpoint {
                humanInlineAction(
                    checkpoint: checkpoint,
                    title: l.edit
                )
            } else if guide.task == .petProfile, let checkpoint = question.checkpoint {
                petInlineAction(
                    checkpoint: checkpoint,
                    title: l.edit
                )
                if expandedPetCheckpoint == checkpoint,
                   checkpoint == .petDailyCare {
                    secondaryOpenButton(
                        checkpoint: checkpoint,
                        title: l.tr(
                            zh: "完整照护设置", en: "Full care settings", de: "Vollständige Pflegeeinstellungen",
                            es: "Ajustes completos de cuidados", pt: "Configurações completas de cuidado", fr: "Réglages complets des soins",
                            ja: "ケア設定の詳細", ko: "전체 돌봄 설정", it: "Impostazioni complete della cura"
                        ),
                        identifierPrefix: "task-center-starter-journey-details"
                    )
                }
            } else if !resolutions.isEmpty {
                secondaryOpenButton(
                    checkpoint: question.checkpoint,
                    title: completed ? reviewAgainTitle(question) : openQuestionActionTitle(question)
                )
            } else {
                openButton(
                    checkpoint: question.checkpoint,
                    title: completed ? reviewAgainTitle(question) : openQuestionActionTitle(question)
                )
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

    private func secondaryOpenButton(
        checkpoint: HouseholdStarterJourneyCheckpoint?,
        title: String,
        identifierPrefix: String = "task-center-starter-journey-open"
    ) -> some View {
        Button {
            OhanaFeedback.light()
            onOpenDestination(checkpoint)
        } label: {
            Label(title, systemImage: "arrow.up.right")
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.goPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(Color.goPrimary)
        .accessibilityIdentifier("\(identifierPrefix)-\(checkpoint?.rawValue ?? item.systemDestination?.rawValue ?? "unknown")")
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
            }
            .font(OhanaFont.callout(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
        .tint(Color.goPrimary)
        .accessibilityHint(resolutionAccessibilityHint)
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
            .tint(Color.goPrimary)
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
        let locallyCompleted = Set(recordedResolutions.keys)
            .union(locallySavedHumanCheckpoints)
            .union(locallySavedPetCheckpoints)
        if let taskState {
            return TaskCenterSystemJourneyGuide(
                state: taskState,
                locallyCompletedCheckpoints: locallyCompleted
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
        if guide?.task == .humanProfile, expandedHumanCheckpoint != nil {
            return .questions
        }
        if guide?.task == .petProfile, expandedPetCheckpoint != nil {
            return .questions
        }
        return TaskCenterSystemJourneySheetMode.resolve(
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
                l.tr(
                    zh: "当前计划已确认", en: "Current plan confirmed", de: "Aktueller Plan bestätigt",
                    es: "Plan actual confirmado", pt: "Plano atual confirmado", fr: "Plan actuel confirmé",
                    ja: "現在のプランを確認済み", ko: "현재 계획 확인됨", it: "Piano attuale confermato"
                )
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
            MemberProfileCompletionCategory.humanAppearance.localizedTitle(l)
        case .humanLifeStage:
            MemberProfileCompletionCategory.humanLifeStage.localizedTitle(l)
        case .humanBodyProfile:
            MemberProfileCompletionCategory.humanBodyProfile.localizedTitle(l)
        case .humanPersonalityContext:
            MemberProfileCompletionCategory.humanPersonalityContext.localizedTitle(l)
        case .humanOptionalDetails:
            MemberProfileCompletionCategory.humanPersonalityContext.localizedTitle(l)
        case .petLifeStage:
            MemberProfileCompletionCategory.petLifeStage.localizedTitle(l)
        case .petBodyProfile:
            MemberProfileCompletionCategory.petBodyProfile.localizedTitle(l)
        case .petPersonalityAppearance:
            MemberProfileCompletionCategory.petPersonalityAppearance.localizedTitle(l)
        case .petDailyCare:
            MemberProfileCompletionCategory.petDailyCare.localizedTitle(l)
        case .petIdentityDocuments:
            TaskCenterSystemJourneyCopy.documents(l)
        case .petEmergencyContact:
            TaskCenterSystemJourneyCopy.emergencyContact(l)
        case .petHealthProtection:
            TaskCenterSystemJourneyCopy.preventiveCare(l)
        case .acceptedRecommendedCarePlan:
            TaskCenterSystemJourneyCopy.carePlan(l)
        case nil:
            TaskCenterSystemJourneyCopy.recordCare(l)
        }
    }

    private func safetyNote(_ question: TaskCenterSystemJourneyGuide.Question) -> String? {
        switch question.checkpoint {
        case .petHealthProtection:
            TaskCenterSystemJourneyCopy.preventiveCareTruth(l)
        case nil:
            TaskCenterSystemJourneyCopy.completedCareOnly(l)
        default:
            nil
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
}

private extension TaskCenterSystemJourneySheet {
    var resolutionAccessibilityHint: String {
        l.tr(
            zh: "按真实情况确认，无需补写敏感资料。",
            en: "Answer honestly; sensitive details are optional.",
            de: "Antworte ehrlich; sensible Angaben sind optional.",
            es: "Responde con sinceridad; los datos sensibles son opcionales.",
            pt: "Responda com sinceridade; dados sensíveis são opcionais.",
            fr: "Répondez simplement; les données sensibles sont facultatives.",
            ja: "実際の状況で回答してください。機密情報は任意です。",
            ko: "현재 상황대로 답하세요. 민감한 정보는 선택 사항이에요.",
            it: "Rispondi sinceramente; i dati sensibili sono facoltativi."
        )
    }

    @ViewBuilder
    func humanInlineAction(
        checkpoint: HouseholdStarterJourneyCheckpoint,
        title: String
    ) -> some View {
        let isExpanded = expandedHumanCheckpoint == checkpoint
        Button {
            OhanaFeedback.selection()
            withAnimation(GoMotion.selection) {
                expandedHumanCheckpoint = isExpanded ? nil : checkpoint
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil") // a11y: allow decorative edit glyph; the Button has a text label
                    .accessibilityHidden(true)
                Text(isExpanded ? localizedCollapseTitle : title)
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(OhanaFont.caption(.bold))
                    .accessibilityHidden(true)
            }
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .accessibilityHint(l.tr(
            zh: "在当前卡片中编辑",
            en: "Edit in this card",
            de: "Direkt in dieser Karte bearbeiten",
            es: "Editar en esta tarjeta",
            pt: "Editar neste cartão",
            fr: "Modifier dans cette carte",
            ja: "このカード内で編集",
            ko: "이 카드에서 편집",
            it: "Modifica in questa scheda"
        ))
        .accessibilityIdentifier("task-center-starter-journey-open-\(checkpoint.rawValue)")

        if isExpanded {
            if let humanProfileTarget {
                TaskCenterHumanProfileInlineEditor(
                    checkpoint: checkpoint,
                    human: humanProfileTarget,
                    onSave: { update in
                        saveHumanProfileInline(update, checkpoint: checkpoint)
                    },
                    onCancel: {
                        withAnimation(GoMotion.selection) {
                            expandedHumanCheckpoint = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(l.tr(
                    zh: "未找到这位成员",
                    en: "Member unavailable",
                    de: "Mitglied nicht verfügbar",
                    es: "Miembro no disponible",
                    pt: "Membro indisponível",
                    fr: "Membre indisponible",
                    ja: "メンバーが見つかりません",
                    ko: "구성원을 찾을 수 없음",
                    it: "Membro non disponibile"
                ))
                .font(OhanaFont.footnote(.semibold))
                .foregroundStyle(Color.goRed)
                .accessibilityIdentifier("task-center-human-profile-inline-missing")
            }
        }
    }

    var localizedCollapseTitle: String {
        l.tr(
            zh: "收起", en: "Collapse", de: "Einklappen",
            es: "Contraer", pt: "Recolher", fr: "Réduire",
            ja: "閉じる", ko: "접기", it: "Riduci"
        )
    }

    @ViewBuilder
    func petInlineAction(
        checkpoint: HouseholdStarterJourneyCheckpoint,
        title: String
    ) -> some View {
        let isExpanded = expandedPetCheckpoint == checkpoint
        Button {
            OhanaFeedback.selection()
            withAnimation(GoMotion.selection) {
                expandedPetCheckpoint = isExpanded ? nil : checkpoint
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil") // a11y: allow decorative edit glyph; the Button has a text label
                    .accessibilityHidden(true)
                Text(isExpanded ? localizedCollapseTitle : title)
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(OhanaFont.caption(.bold))
                    .accessibilityHidden(true)
            }
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .accessibilityHint(l.tr(
            zh: "在当前卡片中编辑",
            en: "Edit in this card",
            de: "Direkt in dieser Karte bearbeiten",
            es: "Editar en esta tarjeta",
            pt: "Editar neste cartão",
            fr: "Modifier dans cette carte",
            ja: "このカード内で編集",
            ko: "이 카드에서 편집",
            it: "Modifica in questa scheda"
        ))
        .accessibilityIdentifier("task-center-starter-journey-open-\(checkpoint.rawValue)")

        if isExpanded {
            if let petProfileTarget {
                TaskCenterPetProfileInlineEditor(
                    checkpoint: checkpoint,
                    pet: petProfileTarget,
                    onSave: { update in
                        savePetProfileInline(update, checkpoint: checkpoint)
                    },
                    onCancel: {
                        withAnimation(GoMotion.selection) {
                            expandedPetCheckpoint = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(l.tr(
                    zh: "未找到这只宠物",
                    en: "Pet unavailable",
                    de: "Tier nicht verfügbar",
                    es: "Mascota no disponible",
                    pt: "Pet indisponível",
                    fr: "Animal indisponible",
                    ja: "ペットが見つかりません",
                    ko: "반려동물을 찾을 수 없음",
                    it: "Animale non disponibile"
                ))
                .font(OhanaFont.footnote(.semibold))
                .foregroundStyle(Color.goRed)
                .accessibilityIdentifier("task-center-pet-profile-inline-missing")
            }
        }
    }

    func saveHumanProfileInline(
        _ update: TaskCenterHumanProfileInlineUpdate,
        checkpoint: HouseholdStarterJourneyCheckpoint
    ) -> TaskCenterSystemJourneyMutationOutcome {
        let outcome = onUpdateHumanProfile(update)
        switch outcome {
        case .success:
            if let humanProfileTarget,
               TaskCenterHumanProfileInlineInputBuilder.isSatisfied(
                   checkpoint,
                   by: humanProfileTarget
               ) {
                locallySavedHumanCheckpoints.insert(checkpoint)
            }
            errorMessage = nil
        case let .failure(message):
            errorMessage = message
        }
        return outcome
    }

    func savePetProfileInline(
        _ update: TaskCenterPetProfileInlineUpdate,
        checkpoint: HouseholdStarterJourneyCheckpoint
    ) -> TaskCenterSystemJourneyMutationOutcome {
        let outcome = onUpdatePetProfile(update)
        switch outcome {
        case .success:
            if let petProfileTarget,
               TaskCenterPetProfileInlineInputBuilder.isSatisfied(
                   checkpoint,
                   by: petProfileTarget
               ) {
                locallySavedPetCheckpoints.insert(checkpoint)
            }
            errorMessage = nil
        case let .failure(message):
            errorMessage = message
        }
        return outcome
    }
}
