//
//  ZenStarterJourneySheet.swift
//  Ohana
//
//  Lightweight two-milestone starter journey for the Zen shell.
//

import SwiftUI

private struct ZenStarterHumanEditorRoute: Identifiable, Equatable {
    let humanID: UUID
    let checkpoint: HouseholdStarterJourneyCheckpoint?

    var id: String {
        "\(humanID.uuidString)-\(checkpoint?.rawValue ?? "profile")"
    }
}

@MainActor
struct ZenStarterJourneySheet: View {
    let projection: StarterJourneyExperienceProjection
    let onClaimGift: () -> TaskCenterSystemJourneyMutationOutcome
    let onClaimHumanProfile: () -> TaskCenterSystemJourneyMutationOutcome
    let onRecordHumanResolution: (
        HouseholdStarterJourneyCheckpoint,
        HouseholdStarterJourneyResolution
    ) -> TaskCenterSystemJourneyMutationOutcome
    let onRefresh: () -> Void
    let onClose: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var isClaimingGift = false
    @State private var isClaimingProfile = false
    @State private var humanGuideItem: TaskCenterItemSnapshot?
    @State private var humanEditorRoute: ZenStarterHumanEditorRoute?
    @State private var errorMessage: String?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    journeyProgress

                    if projection.isComplete {
                        completionCard
                    } else {
                        giftTaskCard
                        humanProfileTaskCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background(OhanaAppBackground().ignoresSafeArea())
            .navigationTitle(l.tr(
                zh: "新手成长",
                en: "Starter growth",
                de: "Starter-Fortschritt",
                es: "Progreso inicial",
                pt: "Progresso inicial",
                fr: "Progression de départ",
                ja: "はじめの成長",
                ko: "시작 성장",
                it: "Crescita iniziale"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark") // a11y: allow decorative glyph; the close Button has a localized label
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(l.tr(
                        zh: "关闭", en: "Close", de: "Schließen", es: "Cerrar",
                        pt: "Fechar", fr: "Fermer", ja: "閉じる", ko: "닫기", it: "Chiudi"
                    ))
                }
            }
        }
        .sheet(item: $humanGuideItem) { item in
            TaskCenterSystemJourneySheet(
                item: item,
                taskState: projection.humanProfileState,
                onOpenDestination: { checkpoint in
                    guard let humanID = projection.humanProfileState?.targetID else { return }
                    humanEditorRoute = ZenStarterHumanEditorRoute(
                        humanID: humanID,
                        checkpoint: checkpoint
                    )
                },
                onClaim: {
                    let outcome = onClaimHumanProfile()
                    if case .success = outcome {
                        onRefresh()
                    }
                    return outcome
                },
                onRecordResolution: { checkpoint, resolution in
                    let outcome = onRecordHumanResolution(checkpoint, resolution)
                    if case .success = outcome {
                        onRefresh()
                    }
                    return outcome
                },
                onClose: {
                    humanGuideItem = nil
                    onRefresh()
                }
            )
            .sheet(item: $humanEditorRoute, onDismiss: onRefresh) { route in
                ZenStarterHumanProfileEditor(
                    humanID: route.humanID,
                    onSaved: {
                        humanEditorRoute = nil
                        onRefresh()
                    }
                )
                .presentationDetents([.large])
                .presentationContentInteraction(.scrolls)
            }
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
        }
        .alert(
            l.tr(
                zh: "暂时无法完成",
                en: "Unable to complete",
                de: "Aktion nicht möglich",
                es: "No se puede completar",
                pt: "Não foi possível concluir",
                fr: "Impossible de terminer",
                ja: "完了できません",
                ko: "완료할 수 없어요",
                it: "Impossibile completare"
            ),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .accessibilityIdentifier("zen-starter-journey-sheet")
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles") // a11y: allow decorative hero icon; the adjacent heading carries the meaning
                .font(OhanaFont.adaptive(size: 22, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 52, height: 52)
                .background(Color.goPrimary.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(l.tr(
                    zh: "两步，让 Ohana 真正属于你",
                    en: "Two steps to make Ohana yours",
                    de: "Zwei Schritte, damit Ohana deins wird",
                    es: "Dos pasos para hacer Ohana tuyo",
                    pt: "Dois passos para tornar o Ohana seu",
                    fr: "Deux étapes pour faire d’Ohana le vôtre",
                    ja: "2つのステップでOhanaを自分らしく",
                    ko: "두 단계로 Ohana를 나답게",
                    it: "Due passi per rendere Ohana tuo"
                ))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "只需要本人。宠物和植物以后想加再加。",
                    en: "Only your Human profile is required. Pets and plants can wait.",
                    de: "Nur dein Personenprofil ist nötig. Tiere und Pflanzen können warten.",
                    es: "Solo necesitas tu perfil. Las mascotas y plantas pueden esperar.",
                    pt: "Só seu perfil é necessário. Pets e plantas podem esperar.",
                    fr: "Seul votre profil est requis. Animaux et plantes peuvent attendre.",
                    ja: "必要なのは自分のプロフィールだけ。ペットや植物は後から追加できます。",
                    ko: "본인 프로필만 필요해요. 반려동물과 식물은 나중에 추가해도 돼요.",
                    it: "Serve solo il tuo profilo. Animali e piante possono aspettare."
                ))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var journeyProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l.tr(
                    zh: "完成进度",
                    en: "Progress",
                    de: "Fortschritt",
                    es: "Progreso",
                    pt: "Progresso",
                    fr: "Progression",
                    ja: "進捗",
                    ko: "진행률",
                    it: "Progresso"
                ))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text("\(projection.completedTaskCount)/\(projection.totalTaskCount)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .monospacedDigit()
            }
            ProgressView(
                value: Double(projection.completedTaskCount),
                total: Double(projection.totalTaskCount)
            )
            .tint(Color.goPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var giftTaskCard: some View {
        starterTaskCard(
            symbol: "gift.fill",
            title: l.tr(
                zh: "领取新人礼包",
                en: "Claim your welcome gift",
                de: "Willkommensgeschenk abholen",
                es: "Reclama tu regalo de bienvenida",
                pt: "Resgate seu presente de boas-vindas",
                fr: "Récupérez votre cadeau de bienvenue",
                ja: "ウェルカムギフトを受け取る",
                ko: "환영 선물 받기",
                it: "Riscatta il regalo di benvenuto"
            ),
            subtitle: l.tr(
                zh: "立即解锁 Lv.0 椰子树 · 不增加能量",
                en: "Unlocks the Lv.0 coconut tree · Adds no energy",
                de: "Schaltet den Kokosbaum auf Lv. 0 frei · Keine Energie",
                es: "Desbloquea el cocotero de Nv. 0 · Sin energía",
                pt: "Desbloqueia o coqueiro Nv. 0 · Sem energia",
                fr: "Déverrouille le cocotier niv. 0 · Sans énergie",
                ja: "Lv.0のココナッツツリーを解放・エネルギー追加なし",
                ko: "Lv.0 코코넛 나무 잠금 해제 · 에너지 추가 없음",
                it: "Sblocca l’albero al Lv. 0 · Nessuna energia"
            ),
            reward: StarterGiftPolicy.giftAmount,
            isClaimed: projection.giftState == .claimed,
            isClaimable: projection.giftState == .claimable,
            isWorking: isClaimingGift,
            actionIdentifier: "zen-starter-gift-claim-action",
            action: claimGift
        )
        .accessibilityIdentifier("zen-starter-gift-task")
    }

    private var humanProfileTaskCard: some View {
        let state = projection.humanProfileState
        let completionPercent = state?.completionPercent ?? 0
        return starterTaskCard(
            symbol: "person.crop.circle.badge.checkmark",
            title: l.tr(
                zh: "完善本人资料至 75%",
                en: "Complete your profile to 75%",
                de: "Profil auf 75 % vervollständigen",
                es: "Completa tu perfil al 75 %",
                pt: "Complete seu perfil até 75%",
                fr: "Complétez votre profil à 75 %",
                ja: "プロフィールを75%まで完成",
                ko: "본인 프로필 75% 완성",
                it: "Completa il profilo al 75%"
            ),
            subtitle: l.tr(
                zh: "当前 \(completionPercent)% · 生日与性别/身份必填",
                en: "Currently \(completionPercent)% · Birthday and gender/identity required",
                de: "Aktuell \(completionPercent) % · Geburtstag und Geschlecht/Identität erforderlich",
                es: "Ahora \(completionPercent)% · Cumpleaños y género/identidad obligatorios",
                pt: "Agora \(completionPercent)% · Aniversário e gênero/identidade obrigatórios",
                fr: "Actuellement \(completionPercent) % · Anniversaire et genre/identité requis",
                ja: "現在\(completionPercent)%・誕生日と性別／本人情報は必須",
                ko: "현재 \(completionPercent)% · 생일 및 성별/정체성 필수",
                it: "Attualmente \(completionPercent)% · Compleanno e genere/identità obbligatori"
            ),
            reward: HouseholdStarterJourneyTask.humanProfile.rewardCoconuts,
            isClaimed: state?.isClaimed == true,
            isClaimable: state?.isClaimable == true,
            isWorking: isClaimingProfile,
            actionIdentifier: "zen-starter-human-profile-action",
            action: {
                if state?.isClaimable == true {
                    claimHumanProfile()
                } else {
                    openHumanGuide()
                }
            }
        )
        .accessibilityIdentifier("zen-starter-human-profile-task")
    }

    private var completionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative completion icon; the adjacent completion text is authoritative
                .font(OhanaFont.adaptive(size: 34, weight: .black))
                .foregroundStyle(Color.goTeal)
                .accessibilityHidden(true)
            Text(l.tr(
                zh: "新手成长完成",
                en: "Starter growth complete",
                de: "Starter-Fortschritt abgeschlossen",
                es: "Progreso inicial completado",
                pt: "Progresso inicial concluído",
                fr: "Progression de départ terminée",
                ja: "はじめの成長が完了",
                ko: "시작 성장 완료",
                it: "Crescita iniziale completata"
            ))
            .font(OhanaFont.title3(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "椰子树已经启程，接下来按自己的节奏使用就好。",
                en: "Your coconut tree is awake. Continue at your own pace.",
                de: "Dein Kokosbaum ist erwacht. Mach in deinem Tempo weiter.",
                es: "Tu cocotero está despierto. Continúa a tu ritmo.",
                pt: "Seu coqueiro despertou. Continue no seu ritmo.",
                fr: "Votre cocotier est éveillé. Continuez à votre rythme.",
                ja: "ココナッツツリーが目覚めました。自分のペースで続けましょう。",
                ko: "코코넛 나무가 깨어났어요. 이제 내 속도로 이어가세요.",
                it: "Il tuo albero si è risvegliato. Continua al tuo ritmo."
            ))
            .font(OhanaFont.callout())
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("zen-starter-journey-complete")
    }

    private func starterTaskCard(
        symbol: String,
        title: String,
        subtitle: String,
        reward: Int,
        isClaimed: Bool,
        isClaimable: Bool,
        isWorking: Bool,
        actionIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: isClaimed ? "checkmark.circle.fill" : symbol)
                .font(OhanaFont.adaptive(size: 20, weight: .black))
                .foregroundStyle(isClaimed ? Color.goTeal : Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(
                    (isClaimed ? Color.goTeal : Color.goPrimary).opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isClaimed {
                Text(l.tr(
                    zh: "已领取", en: "Claimed", de: "Erhalten", es: "Reclamado",
                    pt: "Resgatado", fr: "Récupéré", ja: "受取済み", ko: "받음", it: "Riscattato"
                ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goTeal)
            } else {
                Button(action: action) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(isClaimable
                            ? l.tr(
                                zh: "领取 +\(reward)",
                                en: "Claim +\(reward)",
                                de: "+\(reward) abholen",
                                es: "Reclamar +\(reward)",
                                pt: "Resgatar +\(reward)",
                                fr: "Récupérer +\(reward)",
                                ja: "+\(reward)を受取",
                                ko: "+\(reward) 받기",
                                it: "Riscatta +\(reward)"
                            )
                            : l.tr(
                                zh: "去完成", en: "Continue", de: "Weiter", es: "Continuar",
                                pt: "Continuar", fr: "Continuer", ja: "続ける", ko: "계속", it: "Continua"
                            )
                        )
                        .font(OhanaFont.caption2(.black))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isClaimable ? Color.goTeal : Color.goPrimary)
                .disabled(isWorking)
                .accessibilityIdentifier(actionIdentifier)
            }
        }
        .padding(14)
        .frame(minHeight: 86)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private func claimGift() {
        guard !isClaimingGift else { return }
        isClaimingGift = true
        OhanaFeedback.light()
        let outcome = onClaimGift()
        isClaimingGift = false
        handle(outcome)
    }

    private func claimHumanProfile() {
        guard !isClaimingProfile else { return }
        isClaimingProfile = true
        OhanaFeedback.light()
        let outcome = onClaimHumanProfile()
        isClaimingProfile = false
        handle(outcome)
    }

    private func handle(_ outcome: TaskCenterSystemJourneyMutationOutcome) {
        switch outcome {
        case .success:
            OhanaFeedback.success()
            onRefresh()
        case let .failure(message):
            errorMessage = message
            OhanaFeedback.error()
        }
    }

    private func openHumanGuide() {
        guard let state = projection.humanProfileState,
              state.status != .locked,
              !state.isClaimed else { return }
        humanGuideItem = TaskCenterItemSnapshot(
            id: state.task.id,
            eventID: nil,
            reminderID: nil,
            familyTaskID: nil,
            source: .systemJourney,
            systemDestination: .completeHumanProfile,
            systemJourneyPresentationState: state.isClaimable ? .rewardReady : .actionRequired,
            title: l.tr(
                zh: "完善本人资料",
                en: "Complete your profile",
                de: "Profil vervollständigen",
                es: "Completa tu perfil",
                pt: "Complete seu perfil",
                fr: "Complétez votre profil",
                ja: "プロフィールを完成",
                ko: "본인 프로필 완성",
                it: "Completa il profilo"
            ),
            subject: TaskSubjectSnapshot(
                kind: .human,
                id: state.targetID,
                name: nil,
                themeColorHex: nil
            ),
            eventType: nil,
            symbol: "person.crop.circle.badge.checkmark",
            occurrenceDate: Date(),
            scheduledAt: Date(),
            dueAt: nil,
            isAllDay: true,
            isRecurring: false,
            urgency: .standard,
            workflowStatus: .active,
            availableActions: [],
            participantHumanIDs: [],
            rewardCoconuts: state.rewardCoconuts
        )
    }
}

@MainActor
private struct ZenStarterHumanProfileEditor: View {
    let humanID: UUID
    let onSaved: () -> Void

    var body: some View {
        ZenStarterHumanProfileEditorDataContainer(
            humanID: humanID,
            onSaved: onSaved
        )
    }
}
