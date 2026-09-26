import SwiftUI

struct ZenRetrospectiveStatusDraft: Identifiable, Equatable {
    let subjectID: String
    let subjectKind: ZenPresenceSubjectKind
    let recordSemantic: ZenPresenceRecordSemantic
    let subjectName: String
    let dayKey: String
    let date: Date
    let initialScore: Int
    var id: String { "\(subjectKind.rawValue):\(subjectID):\(dayKey)" }
}
struct ZenRetrospectiveStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let draft: ZenRetrospectiveStatusDraft
    let localization: L10n
    let languageCode: String
    let onSave: (_ score: Int) async -> Void

    @State private var score: Double
    @State private var isSaving = false

    init(
        draft: ZenRetrospectiveStatusDraft,
        localization: L10n,
        languageCode: String,
        onSave: @escaping (_ score: Int) async -> Void
    ) {
        self.draft = draft
        self.localization = localization
        self.languageCode = languageCode
        self.onSave = onSave
        _score = State(initialValue: Double(min(max(draft.initialScore, 1), 10)))
    }

    private var selectedScore: Int { Int(score.rounded()) }
    private var selectedStatus: ZenPresenceStatus { ZenPresenceStatus(score: selectedScore) }
    private var usesObservationCopy: Bool {
        draft.recordSemantic == .petObservation || draft.recordSemantic == .plantObservation
    }

    private var scoreAccessibilityLabel: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "观察分数",
                en: "Observation score",
                de: "Beobachtungswert",
                es: "Puntuación de observación",
                pt: "Pontuação da observação",
                fr: "Score d’observation",
                ja: "観察スコア",
                ko: "관찰 점수",
                it: "Punteggio di osservazione"
            )
        }
        return localization.tr(
            zh: "状态分数",
            en: "Status score",
            de: "Statuswert",
            es: "Puntuación de estado",
            pt: "Pontuação de estado",
            fr: "Score d’état",
            ja: "状態スコア",
            ko: "상태 점수",
            it: "Punteggio di stato"
        )
    }

    private var retrospectiveExplanation: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "这是补记观察，不会变成当天记录，也不会产生椰子奖励。",
                en: "This is a remembered observation. It will not become a same-day record or earn coconut rewards.",
                de: "Dies ist eine nachgetragene Beobachtung. Sie wird kein Tageseintrag und bringt keine Kokosnuss-Belohnung.",
                es: "Es una observación recordada. No será un registro del mismo día ni dará recompensas de cocos.",
                pt: "Esta é uma observação lembrada. Ela não vira um registro do mesmo dia nem gera recompensas de cocos.",
                fr: "C’est une observation ajoutée. Elle ne deviendra pas une note du jour et ne donnera pas de noix de coco.",
                ja: "これはあとから追加する観察です。当日の記録やココナッツ報酬にはなりません。",
                ko: "나중에 추가하는 관찰 기록입니다. 당일 기록이나 코코넛 보상이 되지는 않아요.",
                it: "È un’osservazione annotata in seguito. Non diventa una registrazione del giorno e non dà ricompense in cocco."
            )
        }
        if draft.recordSemantic == .humanContact {
            return localization.tr(
                zh: "这是补记状态，不会变成当天联系记录，也不会产生椰子奖励。",
                en: "This remembers a status. It will not become same-day contact or earn coconut rewards.",
                de: "Dies ist ein nachgetragener Status. Er wird kein Kontakt und bringt keine Belohnung.",
                es: "Es un estado recordado. No será contacto del mismo día ni dará cocos.",
                pt: "Este é um status lembrado. Ele não vira contato do dia nem gera cocos.",
                fr: "C’est un état ajouté. Il ne deviendra pas un contact du jour et ne donnera pas de récompense.",
                ja: "状態の補記です。当日の連絡やココナッツ報酬にはなりません。",
                ko: "상태 보충 기록입니다. 당일 연락이나 코코넛 보상이 되지는 않아요.",
                it: "È uno stato annotato. Non diventa un contatto del giorno e non dà ricompense."
            )
        }
        return localization.tr(
            zh: "这是补记状态，不会恢复当天平安确认、连续天数或椰子奖励。",
            en: "This remembers a status. It will not restore that day’s safety confirmation, streak, or coconut rewards.",
            de: "Dies ist ein nachgetragener Status. Bestätigung, Serie und Belohnung werden nicht wiederhergestellt.",
            es: "Es un estado recordado. No restaurará la confirmación, la racha ni las recompensas.",
            pt: "Este é um status lembrado. Ele não restaura a confirmação, a sequência nem recompensas.",
            fr: "C’est un état ajouté. Il ne restaure ni la confirmation, ni la série, ni les récompenses.",
            ja: "状態の補記です。その日の無事確認、連続記録、報酬は戻りません。",
            ko: "상태 보충 기록입니다. 당일 무사 확인, 연속 기록, 보상은 복원되지 않아요.",
            it: "È uno stato annotato. Non ripristina conferma, serie o ricompense."
        )
    }

    private var saveLabel: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "保存观察",
                en: "Save observation",
                de: "Beobachtung speichern",
                es: "Guardar observación",
                pt: "Salvar observação",
                fr: "Enregistrer l’observation",
                ja: "観察を保存",
                ko: "관찰 저장",
                it: "Salva osservazione"
            )
        }
        return localization.tr(
            zh: "保存补记",
            en: "Save remembered status",
            de: "Nachtrag speichern",
            es: "Guardar estado recordado",
            pt: "Salvar estado lembrado",
            fr: "Enregistrer l’état ajouté",
            ja: "補記を保存",
            ko: "보충 기록 저장",
            it: "Salva stato annotato"
        )
    }

    private var navigationTitle: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "补记观察",
                en: "Remember an observation",
                de: "Beobachtung nachtragen",
                es: "Recordar una observación",
                pt: "Lembrar uma observação",
                fr: "Ajouter une observation",
                ja: "観察を補記",
                ko: "관찰 보충 기록",
                it: "Annota un’osservazione"
            )
        }
        return localization.tr(
            zh: "补记状态",
            en: "Remember a status",
            de: "Status nachtragen",
            es: "Recordar un estado",
            pt: "Lembrar um estado",
            fr: "Ajouter un état",
            ja: "状態を補記",
            ko: "상태 보충 기록",
            it: "Annota uno stato"
        )
    }

    private var selectedStatusActionForeground: Color {
        OhanaResolvedPrimaryAccent(
            customHex: ZenPresenceScorePalette.hex(for: selectedScore)
        )?.actionTextColor ?? Color.goCardWhite
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Text(draft.subjectName)
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(draft.date.formatted(
                        .dateTime
                            .year()
                            .month(.wide)
                            .day()
                            .locale(Locale(identifier: languageCode))
                    ))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }

                VStack(spacing: 8) {
                    Text("\(selectedScore)/10")
                        .font(OhanaFont.metric(size: 42, .black))
                        .foregroundStyle(selectedStatus.zenColor)
                        .contentTransition(.numericText())
                    Text(selectedStatus.scoreBand.title(localization))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)

                    Slider(value: $score, in: 1 ... 10, step: 1)
                        .tint(selectedStatus.zenColor)
                        .accessibilityLabel(scoreAccessibilityLabel)
                        .accessibilityValue("\(selectedScore)/10")
                }
                .animation(reduceMotion ? GoMotion.reduced : GoMotion.quick, value: selectedScore)

                Label {
                    Text(retrospectiveExplanation)
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true)
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.ohanaControlFill,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                )

                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(selectedStatusActionForeground)
                        }
                        Text(saveLabel)
                            .font(OhanaFont.callout(.bold))
                    }
                    .foregroundStyle(selectedStatusActionForeground)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: OhanaRadius.controlLarge))
                .tint(selectedStatus.zenColor)
                .disabled(isSaving)
                .accessibilityIdentifier("zen-retrospective-status-save")
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.tr(
                        zh: "取消",
                        en: "Cancel",
                        de: "Abbrechen",
                        es: "Cancelar",
                        pt: "Cancelar",
                        fr: "Annuler",
                        ja: "キャンセル",
                        ko: "취소",
                        it: "Annulla"
                    )) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .presentationDetents(OhanaSheetDetents.overview)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .accessibilityIdentifier("zen-retrospective-status-sheet")
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let value = selectedScore
        Task {
            await onSave(value)
            isSaving = false
            dismiss()
        }
    }
}
