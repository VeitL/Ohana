//
//  ZenHomeView.swift
//  Ohana
//
//  Fast presence check-ins for every active person, pet, and plant.
//

import SwiftUI

@MainActor
struct ZenHomeView: View {
    @Binding var snapshot: ZenPresenceSnapshot
    @Binding var requestedAutoCheckInToastSubjectID: String?
    let actions: ZenShellActions
    let profileTransitionNamespace: Namespace.ID

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cardExpansionNamespace
    @State private var pendingSubjectIDs: Set<String> = []
    @State private var isCheckingInAll = false
    @State private var transientNotice: ZenHomeTransientNotice?
    @State private var transientNoticeTask: Task<Void, Never>?
    @State private var expandedSubjectID: String?
    @State private var scoreSelectingSubjectID: String?
    @State private var frontSubjectID: String?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        VStack(spacing: 14) {
                            if snapshot.isReady, ownerSubject == nil {
                                ownerBindingPrompt
                            }
                            checkInAllControl
                        }
                        .padding(.horizontal, 16)

                        if !snapshot.isReady {
                            loadingCards(
                                containerWidth: viewport.size.width,
                                minimumViewportHeight: cardDeckViewportHeight(in: viewport.size.height)
                            )
                        } else if snapshot.subjects.isEmpty {
                            emptyState
                                .padding(.horizontal, 16)
                        } else {
                            subjectCards(
                                containerWidth: viewport.size.width,
                                minimumViewportHeight: cardDeckViewportHeight(in: viewport.size.height)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollDisabled(expandedSubjectID != nil || scoreSelectingSubjectID != nil)
            }

            if let expandedSubject {
                expandedCardOverlay(expandedSubject)
                    .transition(.opacity)
                    .zIndex(7)
            }

            if let noticeSubject, let transientNotice {
                ZenHomeCheckInNotice(
                    subject: noticeSubject,
                    notice: transientNotice,
                    localization: l
                )
                    .id(transientNotice)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96, anchor: .top))
                    )
                    .zIndex(8)
            }
        }
        .navigationTitle(l.tr(
            zh: "佛系打卡",
            en: "Zen check-in",
            de: "Zen-Check-in",
            es: "Check-in zen",
            pt: "Check-in zen",
            fr: "Check-in zen",
            ja: "佛系チェックイン",
            ko: "마음 편한 체크인",
            it: "Check-in zen"
        ))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            consumeRequestedAutoCheckInToast()
        }
        .onChange(of: requestedAutoCheckInToastSubjectID) { _, _ in
            consumeRequestedAutoCheckInToast()
        }
        .onChange(of: snapshot.subjects.map(\.id)) { _, subjectIDs in
            let validIDs = Set(subjectIDs)
            if let expandedSubjectID, !validIDs.contains(expandedSubjectID) {
                self.expandedSubjectID = nil
            }
            if let scoreSelectingSubjectID, !validIDs.contains(scoreSelectingSubjectID) {
                self.scoreSelectingSubjectID = nil
            }
            if let frontSubjectID, !validIDs.contains(frontSubjectID) {
                self.frontSubjectID = nil
            }
            if let transientNotice, !validIDs.contains(transientNotice.subjectID) {
                self.transientNotice = nil
            }
        }
        .onDisappear {
            transientNoticeTask?.cancel()
            transientNoticeTask = nil
            transientNotice = nil
            expandedSubjectID = nil
            scoreSelectingSubjectID = nil
            frontSubjectID = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-home-screen")
    }

    private var ownerSubject: ZenPresenceSubjectDTO? {
        snapshot.subjects.first(where: { $0.id == snapshot.ownerID && $0.isOwner })
    }

    private var noticeSubject: ZenPresenceSubjectDTO? {
        guard let subjectID = transientNotice?.subjectID else { return nil }
        return snapshot.subjects.first(where: { $0.id == subjectID })
    }

    private var expandedSubject: ZenPresenceSubjectDTO? {
        guard let expandedSubjectID else { return nil }
        return snapshot.subjects.first(where: { $0.id == expandedSubjectID })
    }

    private var ownerBindingPrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 18, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(
                    zh: "还没有指定本人",
                    en: "Choose who you are",
                    de: "Wähle deine Person",
                    es: "Elige quién eres",
                    pt: "Escolha quem é você",
                    fr: "Choisissez votre profil",
                    ja: "自分のプロフィールを選んでください",
                    ko: "본인을 선택하세요",
                    it: "Scegli il tuo profilo"
                ))
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "指定后，打开 App 就会自动打卡",
                    en: "Opening Ohana will check you in",
                    de: "Ohana checkt dich beim Öffnen ein",
                    es: "Ohana registrará tu check-in al abrirse",
                    pt: "O Ohana fará seu check-in ao abrir",
                    fr: "Ohana vous enregistrera à l’ouverture",
                    ja: "Ohanaを開くと自動でチェックインします",
                    ko: "Ohana를 열면 자동으로 체크인해요",
                    it: "Ohana effettuerà il check-in all’apertura"
                ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 8)

            Button(l.tr(
                zh: "选择本人",
                en: "Choose me",
                de: "Mich wählen",
                es: "Elegirme",
                pt: "Escolher meu perfil",
                fr: "Me choisir",
                ja: "自分を選ぶ",
                ko: "나를 선택",
                it: "Scegli me"
            )) {
                actions.onOpenSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("zen-home-choose-owner-action")
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("zen-home-owner-status")
    }

    @ViewBuilder
    private var checkInAllControl: some View {
        let isComplete = ZenPresencePresentation.allChecked(snapshot.subjects)
        if snapshot.isReady, !snapshot.subjects.isEmpty {
            if isComplete {
                Label(
                    l.tr(
                        zh: "今日全部完成",
                        en: "All done today",
                        de: "Heute alles erledigt",
                        es: "Todo listo por hoy",
                        pt: "Tudo pronto por hoje",
                        fr: "Tout est fait aujourd’hui",
                        ja: "今日はすべて完了",
                        ko: "오늘 모두 완료",
                        it: "Tutto fatto per oggi"
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(OhanaFont.footnote(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("zen-home-all-complete-status")
            } else {
                Button {
                    checkInAll()
                } label: {
                    HStack(spacing: 9) {
                        if isCheckingInAll {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.ohanaPrimaryActionText)
                        } else {
                            Image(systemName: "checkmark.circle.badge.plus").accessibilityHidden(true)
                        }
                        Text(l.tr(
                            zh: "一键全部打卡",
                            en: "Check in everyone",
                            de: "Alle einchecken",
                            es: "Hacer check-in de todos",
                            pt: "Fazer check-in de todos",
                            fr: "Tout enregistrer",
                            ja: "まとめてチェックイン",
                            ko: "모두 한번에 체크인",
                            it: "Check-in per tutti"
                        ))
                        .font(OhanaFont.callout(.bold))
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Color.goPrimary)
                .disabled(isCheckingInAll)
                .accessibilityIdentifier("zen-home-check-in-all-action")
                .accessibilityHint(l.tr(
                    zh: "为首页所有未打卡的人、宠物和植物完成今日打卡",
                    en: "Checks in every person, pet, and plant that is not yet checked in",
                    de: "Checkt alle Personen, Tiere und Pflanzen ein",
                    es: "Registra el check-in de cada persona, mascota y planta pendiente",
                    pt: "Faz o check-in de todas as pessoas, pets e plantas pendentes",
                    fr: "Enregistre chaque personne, animal et plante encore en attente",
                    ja: "未チェックインの家族、ペット、植物をまとめて記録します",
                    ko: "아직 체크인하지 않은 가족, 반려동물과 식물을 모두 체크인해요",
                    it: "Registra ogni persona, animale e pianta ancora in attesa"
                ))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func loadingCards(
        containerWidth: CGFloat,
        minimumViewportHeight: CGFloat
    ) -> some View {
        ZenPresenceCardPlaceholderDeck(
            containerWidth: containerWidth,
            minimumViewportHeight: minimumViewportHeight
        )
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                l.tr(
                    zh: "还没有成员",
                    en: "No one here yet",
                    de: "Noch niemand hier",
                    es: "Aún no hay nadie",
                    pt: "Ainda não há ninguém",
                    fr: "Il n’y a encore personne",
                    ja: "まだメンバーがいません",
                    ko: "아직 구성원이 없어요",
                    it: "Non c’è ancora nessuno"
                ),
                systemImage: "person.2.slash"
            )
        } description: {
            Text(l.tr(
                zh: "添加家人、宠物或植物后，就能在这里快速打卡。",
                en: "Add a person, pet, or plant to start checking in.",
                de: "Füge eine Person, ein Tier oder eine Pflanze hinzu.",
                es: "Añade una persona, mascota o planta para empezar.",
                pt: "Adicione uma pessoa, um pet ou uma planta para começar.",
                fr: "Ajoutez une personne, un animal ou une plante pour commencer.",
                ja: "家族、ペット、または植物を追加すると、すぐにチェックインできます。",
                ko: "가족, 반려동물 또는 식물을 추가해 체크인을 시작하세요.",
                it: "Aggiungi una persona, un animale o una pianta per iniziare."
            ))
        } actions: {
            Button(l.tr(
                zh: "打开成员页",
                en: "Open members",
                de: "Mitglieder öffnen",
                es: "Abrir miembros",
                pt: "Abrir membros",
                fr: "Ouvrir les membres",
                ja: "メンバーを開く",
                ko: "구성원 열기",
                it: "Apri membri"
            ), action: actions.onOpenMembers)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("zen-home-empty-members-action")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }

    private func subjectCards(
        containerWidth: CGFloat,
        minimumViewportHeight: CGFloat
    ) -> some View {
        ZenPresenceCardDeck(
            subjects: ZenPresencePresentation.orderedSubjects(snapshot.subjects),
            coconutBalance: snapshot.coconutBalance,
            avatarCacheRevision: snapshot.avatarCacheRevision,
            pendingSubjectIDs: pendingSubjectIDs,
            containerWidth: containerWidth,
            minimumViewportHeight: minimumViewportHeight,
            localization: l,
            onTap: handleCardTap,
            onSelectScore: selectStatusScore,
            scoreSelectingSubjectID: scoreSelectingSubjectID,
            frontSubjectID: frontSubjectID,
            onScoreSelectionActivityChanged: setScoreSelectionActivity,
            expandedSubjectID: expandedSubjectID,
            expansionNamespace: cardExpansionNamespace,
            onExpand: expandCard,
            profileTransitionNamespace: profileTransitionNamespace
        )
    }

    private func expandedCardOverlay(_ subject: ZenPresenceSubjectDTO) -> some View {
        GeometryReader { geometry in
            let expandedFrame = FocusHomeVerticalSolidExpandedLayoutPolicy.frame(
                in: geometry.size,
                visibleCenterX: geometry.size.width / 2,
                safeTop: 12,
                safeBottom: 12,
                embedsQuickActionsInCard: true,
                placement: .sceneCenter
            )

            ZStack {
                Color.arkInk.opacity(0.46)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: collapseExpandedCard)

                ZenPresenceWalletCard(
                    subject: subject,
                    coconutBalance: snapshot.coconutBalance,
                    avatarCacheRevision: snapshot.avatarCacheRevision,
                    isPending: pendingSubjectIDs.contains(subject.id),
                    presentation: .expanded,
                    localization: l,
                    onTap: collapseExpandedCard,
                    onSelectScore: { score in selectStatusScore(score, for: subject) },
                    onScoreSelectionActivityChanged: { isActive in
                        setScoreSelectionActivity(isActive, for: subject)
                    },
                    onUndoCheckIn: { undoCheckIn(subject) },
                    onAccessoryAction: { actions.onOpenProfile(subject) },
                    profileTransitionNamespace: profileTransitionNamespace
                )
                .matchedGeometryEffect(id: "zen-card:\(subject.id)", in: cardExpansionNamespace)
                .frame(width: expandedFrame.width, height: expandedFrame.height)
                .position(x: expandedFrame.midX, y: expandedFrame.midY)
                .shadow(color: Color.arkInk.opacity(0.30), radius: 28, y: 18) // ui-v4: allow expanded Hero card elevation
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func expandCard(_ subject: ZenPresenceSubjectDTO) {
        guard expandedSubjectID == nil else { return }
        OhanaFeedback.light()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            frontSubjectID = nil
            expandedSubjectID = subject.id
        }
    }

    private func collapseExpandedCard() {
        guard expandedSubjectID != nil else { return }
        OhanaFeedback.light()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            expandedSubjectID = nil
        }
    }

    private func cardDeckViewportHeight(in viewportHeight: CGFloat) -> CGFloat {
        max(320, viewportHeight - 150)
    }

    private func consumeRequestedAutoCheckInToast() {
        guard let subjectID = requestedAutoCheckInToastSubjectID else { return }
        requestedAutoCheckInToastSubjectID = nil
        presentNotice(.automatic(subjectID: subjectID), durationMilliseconds: 5000)
    }

    private func presentNotice(
        _ notice: ZenHomeTransientNotice,
        durationMilliseconds: UInt64
    ) {
        transientNoticeTask?.cancel()
        if reduceMotion {
            transientNotice = notice
        } else {
            withAnimation(GoMotion.zStackPopup) {
                transientNotice = notice
            }
        }
        transientNoticeTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: durationMilliseconds) {
            guard transientNotice == notice else { return }
            if reduceMotion {
                transientNotice = nil
            } else {
                withAnimation(GoMotion.quick) {
                    transientNotice = nil
                }
            }
            transientNoticeTask = nil
        }
    }

    private func finishManualCheckIn(subjectID: String) {
        pendingSubjectIDs.remove(subjectID)
        OhanaFeedback.success()
    }

    private func finishCheckInAll() {
        pendingSubjectIDs.removeAll()
        isCheckingInAll = false
        OhanaFeedback.success()
    }

    private func beginPendingCheckIn(for subjectID: String, at now: Date) {
        mutateSubject(id: subjectID) {
            $0.checkedToday = true
            $0.checkedAt = now
        }
        pendingSubjectIDs.insert(subjectID)
    }

    private func handleCardTap(_ subject: ZenPresenceSubjectDTO) {
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            frontSubjectID = subject.id
        }
        guard !pendingSubjectIDs.contains(subject.id) else { return }
        switch ZenPresenceCardTapIntent.resolve(checkedToday: subject.checkedToday) {
        case .bringToFront:
            return
        case .checkIn:
            checkIn(subject)
        }
    }

    private func checkIn(_ subject: ZenPresenceSubjectDTO) {
        beginPendingCheckIn(for: subject.id, at: Date())

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onCheckIn(subject.id, subject.kind, nil)
            finishManualCheckIn(subjectID: subject.id)
        }
    }

    private func undoCheckIn(_ subject: ZenPresenceSubjectDTO) {
        guard subject.checkedToday,
              !pendingSubjectIDs.contains(subject.id) else { return }
        mutateSubject(id: subject.id) {
            $0.checkedToday = false
            $0.checkedAt = nil
            $0.status = nil
        }
        pendingSubjectIDs.insert(subject.id)
        OhanaFeedback.selection()

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onUndoCheckIn(subject.id, subject.kind)
            pendingSubjectIDs.remove(subject.id)
        }
    }

    private func checkInAll() {
        guard !isCheckingInAll,
              !ZenPresencePresentation.allChecked(snapshot.subjects)
        else { return }

        let uncheckedSubjectIDs = snapshot.subjects
            .filter { !$0.checkedToday }
            .map(\.id)
        isCheckingInAll = true
        let now = Date()
        for subjectID in uncheckedSubjectIDs {
            beginPendingCheckIn(for: subjectID, at: now)
        }

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onCheckInAll()
            finishCheckInAll()
        }
    }

    private func selectStatusScore(_ subject: ZenPresenceSubjectDTO, _ score: Int) {
        selectStatusScore(score, for: subject)
    }

    private func selectStatusScore(_ score: Int, for subject: ZenPresenceSubjectDTO) {
        frontSubjectID = subject.id
        guard !pendingSubjectIDs.contains(subject.id),
              let current = currentSubject(withID: subject.id)
        else { return }

        let wasCheckedToday = current.checkedToday
        let status = ZenPresenceStatus(score: score)
        mutateSubject(id: subject.id) {
            $0.checkedToday = true
            $0.checkedAt = $0.checkedAt ?? Date()
            $0.status = status
        }
        pendingSubjectIDs.insert(subject.id)
        OhanaFeedback.selection()

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            if wasCheckedToday {
                await actions.onUpdateStatus(subject.id, subject.kind, status)
            } else {
                await actions.onCheckIn(subject.id, subject.kind, status)
            }
            pendingSubjectIDs.remove(subject.id)
        }
    }

    private func setScoreSelectionActivity(
        _ isActive: Bool,
        for subject: ZenPresenceSubjectDTO
    ) {
        if isActive {
            frontSubjectID = subject.id
            scoreSelectingSubjectID = subject.id
        } else if scoreSelectingSubjectID == subject.id {
            scoreSelectingSubjectID = nil
        }
    }

    private func currentSubject(withID id: String) -> ZenPresenceSubjectDTO? {
        snapshot.subjects.first(where: { $0.id == id })
    }

    private func mutateSubject(
        id: String,
        mutation: (inout ZenPresenceSubjectDTO) -> Void
    ) {
        guard let index = snapshot.subjects.firstIndex(where: { $0.id == id }) else { return }
        mutation(&snapshot.subjects[index])
    }
}

private struct ZenPresenceCardDeck: View {
    let subjects: [ZenPresenceSubjectDTO]
    let coconutBalance: Int
    let avatarCacheRevision: Int
    let pendingSubjectIDs: Set<String>
    let containerWidth: CGFloat
    let minimumViewportHeight: CGFloat
    let localization: L10n
    let onTap: (ZenPresenceSubjectDTO) -> Void
    let onSelectScore: (ZenPresenceSubjectDTO, Int) -> Void
    let scoreSelectingSubjectID: String?
    let frontSubjectID: String?
    let onScoreSelectionActivityChanged: (Bool, ZenPresenceSubjectDTO) -> Void
    let expandedSubjectID: String?
    let expansionNamespace: Namespace.ID
    let onExpand: (ZenPresenceSubjectDTO) -> Void
    let profileTransitionNamespace: Namespace.ID

    var body: some View {
        let sceneSize = CGSize(
            width: containerWidth,
            height: ZenPresenceCardDeckLayout.sceneHeight(
                cardCount: subjects.count,
                containerWidth: containerWidth,
                minimumViewportHeight: minimumViewportHeight
            )
        )

        ZStack {
            ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                let frame = ZenPresenceCardDeckLayout.frame(
                    index: index,
                    count: subjects.count,
                    in: sceneSize
                )
                Group {
                    if expandedSubjectID == subject.id {
                        Color.clear
                            .accessibilityHidden(true)
                    } else {
                        ZenPresenceWalletCard(
                            subject: subject,
                            coconutBalance: coconutBalance,
                            avatarCacheRevision: avatarCacheRevision,
                            isPending: pendingSubjectIDs.contains(subject.id),
                            presentation: .collapsed,
                            localization: localization,
                            onTap: { onTap(subject) },
                            onSelectScore: { score in onSelectScore(subject, score) },
                            onScoreSelectionActivityChanged: { isActive in
                                onScoreSelectionActivityChanged(isActive, subject)
                            },
                            onAccessoryAction: { onExpand(subject) },
                            profileTransitionNamespace: profileTransitionNamespace
                        )
                        .matchedGeometryEffect(id: "zen-card:\(subject.id)", in: expansionNamespace)
                        .opacity(expandedSubjectID == nil ? 1 : 0)
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .scaleEffect(scoreSelectingSubjectID == subject.id ? 1.025 : 1)
                .rotationEffect(.degrees(ZenPresenceCardDeckLayout.rotation(index: index)))
                .position(x: frame.midX, y: frame.midY)
                .opacity(
                    scoreSelectingSubjectID == nil || scoreSelectingSubjectID == subject.id
                        ? 1
                        : 0.68
                )
                .zIndex(
                    ZenPresenceCardDeckLayout.interactiveZIndex(
                        subjectID: subject.id,
                        index: index,
                        count: subjects.count,
                        frontSubjectID: frontSubjectID,
                        scoreSelectingSubjectID: scoreSelectingSubjectID
                    )
                )
            }
        }
        .frame(width: sceneSize.width, height: sceneSize.height)
        .allowsHitTesting(expandedSubjectID == nil)
        .animation(GoMotion.quick, value: expandedSubjectID)
        .animation(GoMotion.quick, value: scoreSelectingSubjectID)
        .animation(GoMotion.quick, value: frontSubjectID)
    }
}

private enum ZenPresenceWalletCardPresentation {
    case collapsed
    case expanded
}

nonisolated enum ZenPresenceCardAccessoryMetrics {
    static let minimumHitSize: CGFloat = 44
    static let collapsedVisualDiameter: CGFloat = 30
    static let expandedVisualDiameter: CGFloat = 42
    static let collapsedSymbolSize: CGFloat = 11
    static let expandedSymbolSize: CGFloat = 18
}

nonisolated enum ZenCardScoreSelectionPolicy {
    static let minimumLongPressDuration: TimeInterval = 0.45
    static let maximumPreselectionMovement: CGFloat = 22
    static let pointsPerStep: CGFloat = 18
    static let defaultScore = 5
    static let quickTapSuppressionDuration: TimeInterval = 0.18

    static func initialScore(currentScore: Int?) -> Int {
        min(max(currentScore ?? defaultScore, 1), 10)
    }

    static func score(startingAt initialScore: Int, translationY: CGFloat) -> Int {
        let scoreDelta = Int(-translationY / pointsPerStep)
        return min(max(initialScore + scoreDelta, 1), 10)
    }

    static func quickTapSuppressionDeadline(after now: Date) -> Date {
        now.addingTimeInterval(quickTapSuppressionDuration)
    }

    static func suppressesQuickTap(now: Date, deadline: Date) -> Bool {
        now < deadline
    }
}

private struct ZenPresenceWalletCard: View {
    let subject: ZenPresenceSubjectDTO
    let displayedCoconutBalance: Int
    let avatarCacheRevision: Int
    let isPending: Bool
    let presentation: ZenPresenceWalletCardPresentation
    let localization: L10n
    let onTap: () -> Void
    let onSelectScore: (Int) -> Void
    let onScoreSelectionActivityChanged: (Bool) -> Void
    let onUndoCheckIn: () -> Void
    let onAccessoryAction: () -> Void
    let profileTransitionNamespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var fallbackCardID: UUID
    @GestureState private var isScoreGestureActive = false
    @State private var gestureStartScore = ZenCardScoreSelectionPolicy.defaultScore
    @State private var gesturePreviewScore: Int?
    @State private var quickTapSuppressionDeadline = Date.distantPast
    @State private var displayedBackgroundState: ZenPresencePresentation.CardBackgroundState
    @State private var outgoingBackgroundState: ZenPresencePresentation.CardBackgroundState?
    @State private var backgroundTransitionProgress: CGFloat = 1
    @State private var backgroundTransitionTask: Task<Void, Never>?
    @State private var completionTrigger = 0
    @State private var showsCompletionMark = false
    @State private var completionCleanupTask: Task<Void, Never>?

    init(
        subject: ZenPresenceSubjectDTO,
        coconutBalance: Int,
        avatarCacheRevision: Int = 0,
        isPending: Bool,
        presentation: ZenPresenceWalletCardPresentation,
        localization: L10n,
        onTap: @escaping () -> Void,
        onSelectScore: @escaping (Int) -> Void,
        onScoreSelectionActivityChanged: @escaping (Bool) -> Void,
        onUndoCheckIn: @escaping () -> Void = {},
        onAccessoryAction: @escaping () -> Void,
        profileTransitionNamespace: Namespace.ID
    ) {
        self.subject = subject
        self.displayedCoconutBalance = coconutBalance
        self.avatarCacheRevision = avatarCacheRevision
        self.isPending = isPending
        self.presentation = presentation
        self.localization = localization
        self.onTap = onTap
        self.onSelectScore = onSelectScore
        self.onScoreSelectionActivityChanged = onScoreSelectionActivityChanged
        self.onUndoCheckIn = onUndoCheckIn
        self.onAccessoryAction = onAccessoryAction
        self.profileTransitionNamespace = profileTransitionNamespace
        _fallbackCardID = State(initialValue: UUID())
        _displayedBackgroundState = State(
            initialValue: ZenPresencePresentation.cardBackgroundState(for: subject)
        )
        _outgoingBackgroundState = State(initialValue: nil)
    }

    var body: some View {
        GeometryReader { cardGeometry in
            ZStack(alignment: .topTrailing) {
                Button(action: handleQuickTap) {
                    ZStack {
                        cardBackgroundLayers

                        if let gesturePreviewScore {
                            ZenCardScoreSelectionOverlay(
                                score: gesturePreviewScore,
                                localization: localization
                            )
                            .transition(.opacity)
                        }

                        if isPending {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(Color.ohanaPrimaryActionText)
                                .padding(13)
                                .background(Color.arkInk.opacity(0.68), in: Circle())
                                .accessibilityHidden(true)
                        }

                        completionMark
                    }
                    .frame(width: cardGeometry.size.width, height: cardGeometry.size.height)
                    .contentShape(RoundedRectangle(
                        cornerRadius: cardCornerRadius,
                        style: .continuous
                    ))
                }
                .buttonStyle(.plain)
                .ohanaPhasePop(trigger: completionTrigger, enabled: true)
                .scaleEffect(gesturePreviewScore == nil ? 1 : 1.012)
                .zenCardScoreSelectionGesture(
                    cardInteractionGesture,
                    isEnabled: presentation == .collapsed
                )
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(backgroundAccessibilityValue)
                .accessibilityHint(cardActionAccessibilityHint)
                .zenCardScoreAccessibilityAction(
                    isEnabled: presentation == .collapsed,
                    action: adjustAccessibilityScore
                )
                .accessibilityIdentifier(cardAccessibilityIdentifier)

                if presentation == .expanded {
                    ZenExpandedCardDetails(
                        subject: subject,
                        localization: localization
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, subject.checkedToday ? 76 : 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)

                    if subject.checkedToday {
                        ZenUndoCheckInButton(
                            localization: localization,
                            action: onUndoCheckIn
                        )
                        .padding(.trailing, 18)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }

                accessoryButton
                    .padding(presentation == .expanded ? 14 : 7)
                    .opacity(gesturePreviewScore == nil ? 1 : 0)
                    .allowsHitTesting(gesturePreviewScore == nil)
            }
            .frame(width: cardGeometry.size.width, height: cardGeometry.size.height)
        }
        .onAppear {
            synchronizeBackgroundState()
        }
        .onChange(of: subject.checkedToday) { wasChecked, isChecked in
            guard !wasChecked, isChecked else { return }
            playCompletionFeedback()
        }
        .onChange(of: backgroundState) { _, newState in
            transitionBackground(to: newState)
        }
        .onChange(of: gesturePreviewScore) { oldScore, newScore in
            if oldScore != nil, newScore == nil {
                synchronizeBackgroundState()
            }
        }
        .onChange(of: isScoreGestureActive) { wasActive, isActive in
            guard wasActive, !isActive, gesturePreviewScore != nil else { return }
            commitScoreSelection()
        }
        .onDisappear {
            backgroundTransitionTask?.cancel()
            completionCleanupTask?.cancel()
            cancelScoreSelection()
            quickTapSuppressionDeadline = .distantPast
        }
    }

    @ViewBuilder
    private var accessoryButton: some View {
        Button(action: onAccessoryAction) {
            accessoryGlyph
                .frame(width: accessoryVisualDiameter, height: accessoryVisualDiameter)
                .modifier(ZenCardAccessorySurfaceModifier())
                .frame(
                    width: ZenPresenceCardAccessoryMetrics.minimumHitSize,
                    height: ZenPresenceCardAccessoryMetrics.minimumHitSize
                )
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .matchedTransitionSource(id: profileTransitionSourceID, in: profileTransitionNamespace)
        .accessibilityLabel(accessoryAccessibilityLabel)
        .accessibilityHint(accessoryAccessibilityHint)
        .accessibilityIdentifier(accessoryAccessibilityIdentifier)
    }

    @ViewBuilder
    private var accessoryGlyph: some View {
        if presentation == .collapsed {
            ZenExpandGlyph(size: accessorySymbolSize)
        } else {
            Image(systemName: accessoryIcon)
                .font(OhanaFont.adaptive(size: accessorySymbolSize, weight: .black))
                .symbolRenderingMode(.monochrome)
        }
    }

    private var accessoryVisualDiameter: CGFloat {
        presentation == .collapsed
            ? ZenPresenceCardAccessoryMetrics.collapsedVisualDiameter
            : ZenPresenceCardAccessoryMetrics.expandedVisualDiameter
    }

    private var accessorySymbolSize: CGFloat {
        presentation == .collapsed
            ? ZenPresenceCardAccessoryMetrics.collapsedSymbolSize
            : ZenPresenceCardAccessoryMetrics.expandedSymbolSize
    }

    private var accessoryIcon: String {
        guard presentation == .expanded else {
            return "arrow.up.left.and.arrow.down.right"
        }
        switch subject.kind {
        case .human: return "person.crop.circle.fill"
        case .pet: return "pawprint.circle.fill"
        case .plant: return "leaf.circle.fill"
        }
    }

    private var accessoryAccessibilityLabel: String {
        if presentation == .collapsed {
            return localization.tr(
                zh: "放大 \(subject.name) 的卡片",
                en: "Expand \(subject.name)'s card",
                de: "Karte von \(subject.name) vergrößern",
                es: "Ampliar la tarjeta de \(subject.name)",
                pt: "Ampliar o cartão de \(subject.name)",
                fr: "Agrandir la carte de \(subject.name)",
                ja: "\(subject.name)のカードを拡大",
                ko: "\(subject.name) 카드 확대",
                it: "Ingrandisci la scheda di \(subject.name)"
            )
        }
        return localization.tr(
            zh: "查看 \(subject.name) 的基础资料",
            en: "View \(subject.name)'s profile",
            de: "Profil von \(subject.name) anzeigen",
            es: "Ver el perfil de \(subject.name)",
            pt: "Ver o perfil de \(subject.name)",
            fr: "Voir le profil de \(subject.name)",
            ja: "\(subject.name)のプロフィールを表示",
            ko: "\(subject.name)의 프로필 보기",
            it: "Vedi il profilo di \(subject.name)"
        )
    }

    private var accessoryAccessibilityHint: String {
        presentation == .collapsed
            ? localization.tr(
                zh: "展开卡片，不会打卡",
                en: "Expands the card without checking in",
                de: "Vergrößert die Karte ohne Check-in",
                es: "Amplía la tarjeta sin hacer check-in",
                pt: "Amplia o cartão sem fazer check-in",
                fr: "Agrandit la carte sans effectuer de check-in",
                ja: "チェックインせずカードを拡大します",
                ko: "체크인하지 않고 카드를 확대해요",
                it: "Ingrandisce la scheda senza fare check-in"
            )
            : localization.tr(
                zh: "打开可编辑的基础资料",
                en: "Opens the editable profile",
                de: "Öffnet das bearbeitbare Profil",
                es: "Abre el perfil editable",
                pt: "Abre o perfil editável",
                fr: "Ouvre le profil modifiable",
                ja: "編集可能なプロフィールを開きます",
                ko: "편집 가능한 프로필을 열어요",
                it: "Apre il profilo modificabile"
            )
    }

    private var accessoryAccessibilityIdentifier: String {
        switch presentation {
        case .collapsed:
            "zen-home-expand-\(subject.kind.rawValue)-\(subject.id)"
        case .expanded:
            "zen-home-profile-\(subject.kind.rawValue)-\(subject.id)"
        }
    }

    private var cardAccessibilityIdentifier: String {
        switch presentation {
        case .collapsed:
            "zen-home-subject-\(subject.kind.rawValue)-\(subject.id)"
        case .expanded:
            "zen-home-collapse-\(subject.kind.rawValue)-\(subject.id)"
        }
    }

    private var cardActionAccessibilityHint: String {
        if presentation == .expanded {
            return localization.tr(
                zh: "轻点缩小卡片",
                en: "Tap to collapse the card",
                de: "Tippen, um die Karte zu verkleinern",
                es: "Toca para reducir la tarjeta",
                pt: "Toque para reduzir o cartão",
                fr: "Touchez pour réduire la carte",
                ja: "タップしてカードを縮小",
                ko: "탭하여 카드를 축소하세요",
                it: "Tocca per ridurre la scheda"
            )
        }
        return subject.checkedToday
            ? localization.tr(
                    zh: "按住卡片并上下滑动，松手保存状态分数",
                    en: "Press and hold, then slide up or down; release to save the status score",
                    de: "Gedrückt halten, nach oben oder unten ziehen und zum Speichern loslassen",
                    es: "Mantén pulsado, desliza arriba o abajo y suelta para guardar",
                    pt: "Mantenha pressionado, deslize para cima ou para baixo e solte para salvar",
                    fr: "Maintenez, glissez vers le haut ou le bas, puis relâchez pour enregistrer",
                    ja: "長押ししたまま上下に動かし、離して状態スコアを保存",
                    ko: "길게 누른 채 위아래로 움직이고 놓아서 상태 점수를 저장하세요",
                    it: "Tieni premuto, scorri in alto o in basso e rilascia per salvare"
                )
            : localization.tr(
                    zh: "轻点快速打卡；按住并上下滑动可同时选择状态分数",
                    en: "Tap for a quick check-in; press and slide up or down to include a status score",
                    de: "Tippen für schnellen Check-in; gedrückt halten und ziehen, um einen Statuswert hinzuzufügen",
                    es: "Toca para un check-in rápido; mantén y desliza para incluir una puntuación",
                    pt: "Toque para check-in rápido; mantenha e deslize para incluir uma pontuação",
                    fr: "Touchez pour un check-in rapide ; maintenez et glissez pour ajouter un score",
                    ja: "タップでクイックチェックイン。長押しして上下に動かすと状態スコアも記録",
                    ko: "탭하여 빠르게 체크인하고 길게 눌러 위아래로 움직이면 상태 점수도 기록해요",
                    it: "Tocca per il check-in rapido; tieni premuto e scorri per includere un punteggio"
                )
    }

    private var profileTransitionSourceID: String {
        "profile:\(subject.kind.rawValue):\(subject.id)"
    }

    @ViewBuilder
    private var cardBackgroundLayers: some View {
        ZStack {
            persistedCardBackgroundLayers
                .opacity(gesturePreviewScore == nil ? 1 : 0)

            if let gesturePreviewScore {
                cardSurface(
                    for: .score(gesturePreviewScore),
                    contentStyle: .nameOnly
                )
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? GoMotion.reduced : GoMotion.quick, value: gesturePreviewScore)
    }

    @ViewBuilder
    private var persistedCardBackgroundLayers: some View {
        ZStack {
            if let outgoingBackgroundState {
                cardSurface(for: outgoingBackgroundState)
                    .opacity(Double(1 - backgroundTransitionProgress))
                cardSurface(for: displayedBackgroundState)
                    .opacity(Double(backgroundTransitionProgress))
            } else {
                cardSurface(for: displayedBackgroundState)
            }

            if pendingGlassOpacity > 0.001 {
                ZenPresencePendingGlassOverlay(
                    opacity: pendingGlassOpacity,
                    cornerRadius: cardCornerRadius,
                    usesMaterial: usesPendingGlassMaterial
                )
            }
        }
    }

    private func cardSurface(
        for state: ZenPresencePresentation.CardBackgroundState,
        contentStyle: FocusHomeVerticalSolidCardContentStyle = .standard
    ) -> some View {
        let card = focusCard(for: state)
        return FocusHomeVerticalSolidCardSurface(
            card: card,
            progress: presentation == .expanded ? 1 : 0,
            reduceMotion: reduceMotion,
            localization: localization,
            frozenAvatarSource: FocusHomeFrozenAvatarSource.cached(for: card),
            showsBorder: false,
            usesPlantSpecificBackground: false,
            showsStatusBadge: false,
            compactMetricValueOverride: "\(subject.currentDisplayStreak)",
            compactMetricUnitOverride: streakUnit,
            expandedContentStyle: presentation == .expanded ? .zenProfile : .standard,
            contentStyle: contentStyle
        )
        .accessibilityHidden(true)
    }

    private var backgroundState: ZenPresencePresentation.CardBackgroundState {
        ZenPresencePresentation.cardBackgroundState(for: subject)
    }

    private var cardCornerRadius: CGFloat {
        presentation == .expanded
            ? 44
            : FocusHomeVerticalSolidCollapsedLayoutPolicy.cardCornerRadius
    }

    private var canAnimateBackgroundTransition: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var usesPendingGlassMaterial: Bool {
        !reduceTransparency &&
            workloadPolicy.visualEffectsBudget(isVisible: true).usesFullEffects
    }

    private var pendingGlassOpacity: CGFloat {
        let displayedOpacity: CGFloat = displayedBackgroundState == .pending ? 1 : 0
        guard let outgoingBackgroundState else { return displayedOpacity }
        let outgoingOpacity: CGFloat = outgoingBackgroundState == .pending ? 1 : 0
        return outgoingOpacity + (displayedOpacity - outgoingOpacity) * backgroundTransitionProgress
    }

    @ViewBuilder
    private var completionMark: some View {
        ZStack {
            Circle()
                .fill(Color.arkInk.opacity(0.70))
                .frame(width: 70, height: 70)
            Image(systemName: "checkmark").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryActionText)
        }
        .scaleEffect(showsCompletionMark && !reduceMotion ? 1 : 0.86)
        .opacity(showsCompletionMark ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var cardID: UUID {
        UUID(uuidString: subject.id) ?? fallbackCardID
    }

    private func focusCard(
        for state: ZenPresencePresentation.CardBackgroundState
    ) -> FocusCard {
        let profile = subject.expandedProfile
        var card = FocusCard(
            id: cardID,
            name: subject.name,
            kind: subject.subtitle?.isEmpty == false ? subject.subtitle ?? subject.kind.title(localization) : subject.kind.title(localization),
            emoji: fallbackEmoji,
            color: state.accentColor,
            streak: subject.currentDisplayStreak,
            coconutBalance: max(displayedCoconutBalance, 0),
            createdAt: subject.createdAt,
            avatarImageSignature: subject.avatarThumbnailSignature,
            avatarImageAssetName: subject.avatarAssetName,
            petSpecies: subject.kind == .pet ? subject.subtitle ?? "Pet" : nil,
            themeColorHex: state.themeColorHex,
            statusBadgeText: compactStatusText,
            statusBadgeToneRaw: statusBadgeTone.rawValue,
            isHuman: subject.kind == .human,
            isPlant: subject.kind == .plant,
            actions: []
        )
        card.ageText = profile?.metricValue(for: .age)
        card.daysTogetherText = profile?.metricValue(for: .together)
        card.togetherHeadlineText = profile?.metricHeadline(for: .together)
        card.zodiacText = profile?.metricValue(for: .zodiac)
        card.mbtiText = profile?.metricValue(for: .mbti)
        card.humanEquivalentAgeText = profile?.metricValue(for: .humanEquivalentAge)
        card.personalityHint = profile?.personalityStory
        return card
    }

    private var fallbackEmoji: String {
        subject.zenFallbackEmoji
    }

    private var statusBadgeTone: FocusCardStatusBadgeTone {
        subject.zenStatusBadgeTone
    }

    private var compactStatusText: String {
        subject.zenCompactStatusText(localization)
    }

    private var streakUnit: String {
        let isSingular = subject.currentDisplayStreak == 1
        return isSingular
            ? localization.tr(
                zh: "天",
                en: "Day",
                de: "Tag",
                es: "día",
                pt: "dia",
                fr: "jour",
                ja: "日",
                ko: "일",
                it: "giorno"
            )
            : localization.tr(
                zh: "天",
                en: "Days",
                de: "Tage",
                es: "días",
                pt: "dias",
                fr: "jours",
                ja: "日",
                ko: "일",
                it: "giorni"
            )
    }

    private var accessibilityLabel: String {
        subject.zenAccessibilityLabel(localization)
    }

    private var backgroundAccessibilityValue: String {
        if let gesturePreviewScore {
            return localization.tr(
                zh: "正在选择状态：\(gesturePreviewScore)/10",
                en: "Selecting status: \(gesturePreviewScore)/10",
                de: "Statusauswahl: \(gesturePreviewScore)/10",
                es: "Seleccionando estado: \(gesturePreviewScore)/10",
                pt: "Selecionando status: \(gesturePreviewScore)/10",
                fr: "Sélection de l’état : \(gesturePreviewScore)/10",
                ja: "状態を選択中：\(gesturePreviewScore)/10",
                ko: "상태 선택 중: \(gesturePreviewScore)/10",
                it: "Selezione dello stato: \(gesturePreviewScore)/10"
            )
        }
        return subject.zenBackgroundAccessibilityValue(localization)
    }

    private var cardInteractionGesture: some Gesture {
        LongPressGesture(
            minimumDuration: ZenCardScoreSelectionPolicy.minimumLongPressDuration,
            maximumDistance: ZenCardScoreSelectionPolicy.maximumPreselectionMovement
        )
        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
        .updating($isScoreGestureActive) { value, state, _ in
            switch value {
            case .first(true), .second(true, _):
                state = true
            default:
                break
            }
        }
        .onChanged { value in
            switch value {
            case .first(true):
                beginScoreSelection()
            case let .second(true, dragValue):
                beginScoreSelection()
                if let dragValue {
                    updateScoreSelection(translationY: dragValue.translation.height)
                }
            default:
                break
            }
        }
        .onEnded { value in
            switch value {
            case .first(true):
                commitScoreSelection()
            case let .second(true, dragValue):
                if let dragValue {
                    updateScoreSelection(translationY: dragValue.translation.height)
                }
                commitScoreSelection()
            default:
                cancelScoreSelection()
            }
        }
    }

    private func handleQuickTap() {
        guard !ZenCardScoreSelectionPolicy.suppressesQuickTap(
            now: Date(),
            deadline: quickTapSuppressionDeadline
        ) else { return }
        onTap()
    }

    private func beginScoreSelection() {
        guard !isPending, gesturePreviewScore == nil else { return }
        let initialScore = ZenCardScoreSelectionPolicy.initialScore(
            currentScore: subject.status?.score
        )
        gestureStartScore = initialScore
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            gesturePreviewScore = initialScore
        }
        onScoreSelectionActivityChanged(true)
        OhanaFeedback.medium()
    }

    private func updateScoreSelection(translationY: CGFloat) {
        guard !isPending else { return }
        if gesturePreviewScore == nil {
            beginScoreSelection()
        }
        let score = ZenCardScoreSelectionPolicy.score(
            startingAt: gestureStartScore,
            translationY: translationY
        )
        guard score != gesturePreviewScore else { return }
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            gesturePreviewScore = score
        }
        OhanaFeedback.selection()
    }

    private func commitScoreSelection() {
        guard let score = gesturePreviewScore else { return }
        armQuickTapSuppression()
        onSelectScore(score)
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            gesturePreviewScore = nil
        }
        onScoreSelectionActivityChanged(false)
    }

    private func cancelScoreSelection() {
        guard gesturePreviewScore != nil else { return }
        armQuickTapSuppression()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            gesturePreviewScore = nil
        }
        onScoreSelectionActivityChanged(false)
    }

    private func armQuickTapSuppression() {
        quickTapSuppressionDeadline = ZenCardScoreSelectionPolicy
            .quickTapSuppressionDeadline(after: Date())
    }

    private func adjustAccessibilityScore(_ direction: AccessibilityAdjustmentDirection) {
        guard !isPending else { return }
        let currentScore = ZenCardScoreSelectionPolicy.initialScore(
            currentScore: subject.status?.score
        )
        let delta: Int
        switch direction {
        case .increment:
            delta = 1
        case .decrement:
            delta = -1
        @unknown default:
            return
        }
        let score = min(max(currentScore + delta, 1), 10)
        guard score != currentScore || subject.status == nil else { return }
        onSelectScore(score)
    }

    private func synchronizeBackgroundState() {
        backgroundTransitionTask?.cancel()
        displayedBackgroundState = backgroundState
        outgoingBackgroundState = nil
        backgroundTransitionProgress = 1
        backgroundTransitionTask = nil
    }

    private func transitionBackground(
        to newState: ZenPresencePresentation.CardBackgroundState
    ) {
        guard newState != displayedBackgroundState else { return }
        backgroundTransitionTask?.cancel()

        if gesturePreviewScore != nil {
            displayedBackgroundState = newState
            outgoingBackgroundState = nil
            backgroundTransitionProgress = 1
            backgroundTransitionTask = nil
            return
        }

        guard canAnimateBackgroundTransition else {
            displayedBackgroundState = newState
            outgoingBackgroundState = nil
            backgroundTransitionProgress = 1
            backgroundTransitionTask = nil
            return
        }

        outgoingBackgroundState = displayedBackgroundState
        displayedBackgroundState = newState
        backgroundTransitionProgress = 0

        backgroundTransitionTask = OhanaFrameScheduler.runAfterNextFrame {
            guard displayedBackgroundState == newState else { return }
            withAnimation(GoMotion.zenCardGlassDissolve) {
                backgroundTransitionProgress = 1
            }
            backgroundTransitionTask = OhanaFrameScheduler.runAfterNextFrame(
                milliseconds: ZenPresenceCardTransition.cleanupDelayMilliseconds
            ) {
                guard displayedBackgroundState == newState else { return }
                outgoingBackgroundState = nil
                backgroundTransitionProgress = 1
                backgroundTransitionTask = nil
            }
        }
    }

    private func playCompletionFeedback() {
        completionCleanupTask?.cancel()
        completionTrigger += 1
        if reduceMotion {
            showsCompletionMark = true
        } else {
            withAnimation(GoMotion.rewardPop) {
                showsCompletionMark = true
            }
        }
        completionCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 680) {
            if reduceMotion {
                showsCompletionMark = false
            } else {
                withAnimation(GoMotion.quick) {
                    showsCompletionMark = false
                }
            }
            completionCleanupTask = nil
        }
    }
}

private extension View {
    @ViewBuilder
    func zenCardScoreSelectionGesture(
        _ gesture: some Gesture,
        isEnabled: Bool
    ) -> some View {
        if isEnabled {
            simultaneousGesture(gesture)
        } else {
            self
        }
    }

    @ViewBuilder
    func zenCardScoreAccessibilityAction(
        isEnabled: Bool,
        action: @escaping (AccessibilityAdjustmentDirection) -> Void
    ) -> some View {
        if isEnabled {
            accessibilityAdjustableAction(action)
        } else {
            self
        }
    }
}

nonisolated enum ZenPresenceCardDeckLayout {
    static func mode(cardCount: Int) -> FocusHomeVerticalSolidCollapsedLayoutMode {
        VerticalSolidHomeMemberWalletScrollPolicy.usesExtendedLayout(cardCount: cardCount)
            ? .scrollExtended
            : .balanced
    }

    static func sceneHeight(
        cardCount: Int,
        containerWidth: CGFloat,
        minimumViewportHeight: CGFloat
    ) -> CGFloat {
        let layoutMode = mode(cardCount: cardCount)
        let standardMinimum = FocusHomeVerticalSolidCollapsedLayoutPolicy.minimumSceneHeight(
            cardCount: cardCount,
            containerWidth: containerWidth,
            mode: layoutMode
        )
        let standardBottomInset: CGFloat = switch layoutMode {
        case .balanced: 0
        case .scrollExtended: VerticalSolidHomeMemberWalletScrollPolicy.bottomContentInset
        }
        return max(minimumViewportHeight, standardMinimum + standardBottomInset)
    }

    static func frame(index: Int, count: Int, in sceneSize: CGSize) -> CGRect {
        FocusHomeVerticalSolidCollapsedLayoutPolicy.frame(
            index: index,
            count: count,
            in: sceneSize,
            mode: mode(cardCount: count)
        )
    }

    static func rotation(index: Int) -> Double {
        FocusHomeVerticalSolidCollapsedLayoutPolicy.rotation(index: index)
    }

    static func zIndex(index: Int, count: Int) -> Double {
        FocusHomeVerticalSolidCollapsedLayoutPolicy.zIndex(
            index: index,
            count: count,
            mode: mode(cardCount: count)
        )
    }

    static func interactiveZIndex(
        subjectID: String,
        index: Int,
        count: Int,
        frontSubjectID: String?,
        scoreSelectingSubjectID: String?
    ) -> Double {
        if scoreSelectingSubjectID == subjectID { return 2000 }
        if frontSubjectID == subjectID { return 1000 }
        return zIndex(index: index, count: count)
    }
}

private struct ZenPresenceCardPlaceholderDeck: View {
    let containerWidth: CGFloat
    let minimumViewportHeight: CGFloat

    var body: some View {
        let cardCount = 4
        let sceneSize = CGSize(
            width: containerWidth,
            height: ZenPresenceCardDeckLayout.sceneHeight(
                cardCount: cardCount,
                containerWidth: containerWidth,
                minimumViewportHeight: minimumViewportHeight
            )
        )

        ZStack {
            ForEach(0 ..< cardCount, id: \.self) { index in
                let frame = ZenPresenceCardDeckLayout.frame(
                    index: index,
                    count: cardCount,
                    in: sceneSize
                )
                RoundedRectangle(
                    cornerRadius: FocusHomeVerticalSolidCollapsedLayoutPolicy.cardCornerRadius,
                    style: .continuous
                )
                .fill(Color.ohanaControlFill)
                .frame(width: frame.width, height: frame.height)
                .rotationEffect(.degrees(ZenPresenceCardDeckLayout.rotation(index: index)))
                .position(x: frame.midX, y: frame.midY)
                .zIndex(ZenPresenceCardDeckLayout.zIndex(index: index, count: cardCount))
            }
        }
        .frame(width: sceneSize.width, height: sceneSize.height)
    }
}

private enum ZenHomeTransientNotice: Hashable {
    case automatic(subjectID: String)

    var subjectID: String {
        switch self {
        case let .automatic(subjectID): subjectID
        }
    }
}

private struct ZenHomeCheckInNotice: View {
    let subject: ZenPresenceSubjectDTO
    let notice: ZenHomeTransientNotice
    let localization: L10n

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 19, weight: .bold))
                .foregroundStyle(Color(hex: "43A079"))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)

                if let detail {
                    Text(detail)
                        .font(OhanaFont.caption())
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 58)
        .modifier(ZenNativeGlassSurfaceModifier(cornerRadius: OhanaRadius.controlLarge))
        .shadow(color: Color.arkInk.opacity(0.12), radius: 14, y: 6) // ui-v4: allow transient success toast above moving cards
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var title: String {
        switch notice {
        case .automatic:
            localization.tr(
                zh: "\(subject.name) 今天已自动打卡",
                en: "\(subject.name) checked in automatically",
                de: "\(subject.name) wurde automatisch eingecheckt",
                es: "Check-in automático de \(subject.name) completado",
                pt: "Check-in automático de \(subject.name) concluído",
                fr: "Check-in automatique de \(subject.name) effectué",
                ja: "\(subject.name)さんを自動でチェックインしました",
                ko: "\(subject.name) 님이 자동으로 체크인했어요",
                it: "Check-in automatico di \(subject.name) completato"
            )
        }
    }

    private var detail: String? {
        let parts = [
            subject.checkedAt?.formatted(date: .omitted, time: .shortened),
            subject.status.map { "\($0.score)/10" }
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var accessibilityIdentifier: String {
        switch notice {
        case .automatic: "zen-home-auto-check-in-toast"
        }
    }
}

private struct ZenNativeGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content.background(Color.ohanaCardSurfaceElevated, in: shape)
        } else {
            content.glassEffect(.regular.interactive(false), in: shape)
        }
    }
}

private struct ZenCardAccessorySurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color.arkInk.opacity(0.58), in: Circle())
        } else {
            content.glassEffect(
                .clear.tint(Color.arkInk.opacity(0.28)).interactive(true),
                in: Circle()
            )
            .clipShape(Circle())
        }
    }
}

private struct ZenExpandGlyph: View {
    let size: CGFloat

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, canvasSize in
            let width = canvasSize.width
            let height = canvasSize.height
            var path = Path()

            path.move(to: CGPoint(x: width * 0.46, y: height * 0.46))
            path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.18))
            path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.39))
            path.move(to: CGPoint(x: width * 0.18, y: height * 0.18))
            path.addLine(to: CGPoint(x: width * 0.39, y: height * 0.18))

            path.move(to: CGPoint(x: width * 0.54, y: height * 0.54))
            path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.82))
            path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.61))
            path.move(to: CGPoint(x: width * 0.82, y: height * 0.82))
            path.addLine(to: CGPoint(x: width * 0.61, y: height * 0.82))

            context.stroke(
                path,
                with: .color(Color.goCardWhite),
                style: StrokeStyle(
                    lineWidth: max(1.35, width * 0.15),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }
}

private struct ZenExpandedCardDetails: View {
    let subject: ZenPresenceSubjectDTO
    let localization: L10n

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var profile: ZenExpandedProfileDTO {
        subject.expandedProfile ?? ZenExpandedProfileDTO()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let story = profile.personalityStory {
                Text(story)
                    .font(OhanaFont.callout(.black))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
            }

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                if let score = profile.recentStatus.todayScore ?? subject.status?.score {
                    Text("\(score)/10")
                        .font(OhanaFont.metric(size: 21, .black))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                } else {
                    Image(systemName: "sparkles").accessibilityHidden(true)
                        .font(OhanaFont.caption(.black))
                }

                Text(statusQuip)
                    .font(OhanaFont.footnote(.bold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
            }
        }
        .foregroundStyle(Color.goCardWhite)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Color.arkInk.opacity(0.64), radius: 6, y: 2) // ui-v4: allow text contrast over user-selected card art
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("zen-expanded-card-details-\(subject.id)")
    }

    private var statusQuip: String {
        let summary = profile.recentStatus
        if let todayScore = summary.todayScore {
            return scoreQuip(todayScore)
        }
        if summary.scoredCount >= 3 {
            switch summary.trend {
            case .rising:
                return localization.tr(zh: "最近七天在悄悄回升。", en: "The last seven days are quietly looking up.", de: "Die letzten sieben Tage zeigen sanft nach oben.", es: "Los últimos siete días van mejorando poco a poco.", pt: "Os últimos sete dias estão melhorando aos poucos.", fr: "Les sept derniers jours remontent doucement.", ja: "この7日間、少しずつ上向いています。", ko: "최근 7일은 조용히 좋아지고 있어요.", it: "Gli ultimi sette giorni stanno migliorando piano piano.")
            case .softening:
                return localization.tr(zh: "最近七天有点往下，值得多留意一下。", en: "The last seven days dipped a little—worth an extra look.", de: "Die letzten sieben Tage gingen etwas nach unten – ein Blick lohnt sich.", es: "Los últimos siete días bajaron un poco; conviene prestar atención.", pt: "Os últimos sete dias caíram um pouco; vale observar.", fr: "Les sept derniers jours baissent un peu ; à surveiller.", ja: "この7日間は少し下向き。もう少し見守ってみよう。", ko: "최근 7일은 조금 내려갔어요. 한 번 더 살펴봐요.", it: "Gli ultimi sette giorni sono scesi un po’: vale la pena osservare.")
            case .steady, .insufficient:
                return localization.tr(zh: "最近七天的节奏很稳。", en: "The last seven days found a steady rhythm.", de: "Die letzten sieben Tage hatten einen stabilen Rhythmus.", es: "Los últimos siete días mantuvieron un ritmo estable.", pt: "Os últimos sete dias mantiveram um ritmo estável.", fr: "Les sept derniers jours ont gardé un rythme stable.", ja: "この7日間は安定したペースです。", ko: "최근 7일은 안정적인 리듬이에요.", it: "Gli ultimi sette giorni hanno mantenuto un ritmo stabile.")
            }
        }
        if let latestScore = summary.latestScore {
            return scoreQuip(latestScore)
        }
        return localization.tr(zh: "还没有状态分数，长按卡片告诉我吧。", en: "No status score yet—press and hold the card to add one.", de: "Noch kein Statuswert – halte die Karte gedrückt.", es: "Aún no hay puntuación; mantén pulsada la tarjeta para añadirla.", pt: "Ainda não há pontuação; mantenha o cartão pressionado para adicionar.", fr: "Pas encore de score ; maintenez la carte pour en ajouter un.", ja: "まだ状態スコアがありません。カードを長押しして教えてください。", ko: "아직 상태 점수가 없어요. 카드를 길게 눌러 알려주세요.", it: "Nessun punteggio ancora: tieni premuta la scheda per aggiungerlo.")
    }

    private func scoreQuip(_ score: Int) -> String {
        switch ZenPresenceScoreBand(score: score) {
        case .low:
            localization.tr(zh: "今天先慢一点，也算认真生活。", en: "Taking it slowly today still counts.", de: "Heute langsam zu machen zählt genauso.", es: "Ir despacio hoy también cuenta.", pt: "Ir com calma hoje também conta.", fr: "Ralentir aujourd’hui compte aussi.", ja: "今日はゆっくりでも、ちゃんと過ごしている。", ko: "오늘은 천천히 가도 충분해요.", it: "Andare piano oggi conta comunque.")
        case .attention:
            localization.tr(zh: "状态在轻轻敲门，记得多看一眼。", en: "The status is gently knocking—take another look.", de: "Der Status klopft leise an – schau noch einmal hin.", es: "El estado llama suavemente; échale otro vistazo.", pt: "O estado está chamando de leve; observe mais uma vez.", fr: "L’état frappe doucement ; jetez-y un autre regard.", ja: "状態がそっと合図中。もう少し見てみよう。", ko: "상태가 살짝 신호를 보내요. 한 번 더 살펴봐요.", it: "Lo stato bussa piano: dagli un altro sguardo.")
        case .steady:
            localization.tr(zh: "平稳在线，按自己的节奏就好。", en: "Steady and present—your own pace is enough.", de: "Stabil und präsent – dein eigenes Tempo reicht.", es: "Estable y presente; tu propio ritmo está bien.", pt: "Estável e presente; seu ritmo está ótimo.", fr: "Stable et présent ; votre rythme suffit.", ja: "安定運転。自分のペースで大丈夫。", ko: "안정적으로 잘 지내고 있어요. 내 속도면 충분해요.", it: "Stabile e presente: il tuo ritmo va bene.")
        case .good:
            localization.tr(zh: "今天的状态很顺，继续保持这份松弛。", en: "Today feels smooth—keep that easy rhythm.", de: "Heute läuft es rund – behalte diesen leichten Rhythmus.", es: "Hoy todo fluye; mantén ese ritmo relajado.", pt: "Hoje está fluindo; mantenha esse ritmo leve.", fr: "Aujourd’hui tout est fluide ; gardez ce rythme léger.", ja: "今日はいい流れ。このゆるやかな調子をそのまま。", ko: "오늘 흐름이 좋아요. 이 여유로운 리듬을 이어가요.", it: "Oggi fila tutto liscio: continua con questo ritmo leggero.")
        case .great:
            localization.tr(zh: "能量满格，今天像自带阳光。", en: "Full of energy—today comes with its own sunshine.", de: "Volle Energie – heute scheint die Sonne von innen.", es: "Energía al máximo; hoy trae su propio sol.", pt: "Energia total; hoje vem com sol próprio.", fr: "Énergie au maximum ; aujourd’hui rayonne tout seul.", ja: "エネルギー満タン。今日は自分で光っているみたい。", ko: "에너지 가득, 오늘은 스스로 햇살을 품은 날이에요.", it: "Energia al massimo: oggi porta il sole con sé.")
        }
    }

    private var accessibilitySummary: String {
        let metricText = profile.metrics.map { "\($0.label): \($0.value)" }.joined(separator: ", ")
        return [metricText, profile.personalityStory, statusQuip]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: ". ")
    }
}

private struct ZenUndoCheckInButton: View {
    let localization: L10n
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            Label(
                localization.tr(
                    zh: "撤回今日打卡",
                    en: "Undo today's check-in",
                    de: "Heutigen Check-in zurücknehmen",
                    es: "Deshacer el check-in de hoy",
                    pt: "Desfazer o check-in de hoje",
                    fr: "Annuler le check-in du jour",
                    ja: "今日のチェックインを取り消す",
                    ko: "오늘 체크인 취소",
                    it: "Annulla il check-in di oggi"
                ),
                systemImage: "arrow.uturn.backward"
            )
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.goCardWhite)
            .padding(.horizontal, 13)
            .frame(minHeight: 42)
            .background {
                if reduceTransparency {
                    Capsule().fill(Color.arkInk.opacity(0.74))
                } else {
                    Capsule().fill(Color.arkInk.opacity(0.28))
                }
            }
            .overlay {
                Capsule().strokeBorder(Color.goCardWhite.opacity(0.20), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("zen-expanded-undo-check-in")
    }
}

private extension ZenExpandedProfileDTO {
    func metricValue(for kind: ZenExpandedMetricKind) -> String? {
        metrics.first(where: { $0.kind == kind })?.value
    }

    func metricHeadline(for kind: ZenExpandedMetricKind) -> String? {
        guard let metric = metrics.first(where: { $0.kind == kind }) else { return nil }
        return "\(metric.label) · \(metric.value)"
    }
}

private struct ZenCardScoreSelectionOverlay: View {
    let score: Int
    let localization: L10n

    private var scoreBand: ZenPresenceScoreBand {
        ZenPresenceScoreBand(score: score)
    }

    var body: some View {
        GeometryReader { cardGeometry in
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(score)")
                        .font(OhanaFont.metric(size: 52, .black))
                        .contentTransition(.numericText())
                    Text("/10")
                        .font(OhanaFont.callout(.bold))
                        .opacity(0.78)
                }

                Label(scoreBand.title(localization), systemImage: scoreBand.icon)
                    .font(OhanaFont.callout(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(Color.arkInk)
            .frame(
                width: cardGeometry.size.width,
                height: cardGeometry.size.height,
                alignment: .center
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(GoMotion.quick, value: score)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
extension ZenPresenceStatus {
    @MainActor
    var zenColor: Color {
        Color(hex: ZenPresenceScorePalette.hex(for: score))
    }
}
