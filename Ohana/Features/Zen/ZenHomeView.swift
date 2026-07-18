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
    let actions: ZenShellActions
    var onOpenOasis: () -> Void = {}

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedStatusSubject: ZenPresenceSubjectDTO?
    @State private var pendingSubjectIDs: Set<String> = []
    @State private var isCheckingInAll = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ownerStatusBanner
                    checkInAllButton

                    if !snapshot.isReady {
                        loadingCards
                    } else if snapshot.subjects.isEmpty {
                        emptyState
                    } else {
                        subjectCards
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
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
        .toolbar { homeToolbar }
        .sheet(item: $selectedStatusSubject) { subject in
            ZenStatusPickerSheet(subject: subject) { status in
                updateStatus(status, for: subject)
            }
            .presentationDetents(OhanaSheetDetents.compactMedium)
            .presentationDragIndicator(.visible)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-home-screen")
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            CoconutBalanceCapsule(
                balance: snapshot.coconutBalance,
                showsDeltaAnimation: true,
                deltaAnimationContext: "zen-home",
                onTap: onOpenOasis
            )
            .accessibilityLabel(l.tr(
                zh: "椰子余额 \(snapshot.coconutBalance)，打开 Oasis",
                en: "Coconut balance \(snapshot.coconutBalance), open Oasis",
                de: "Kokosnuss-Guthaben \(snapshot.coconutBalance), Oasis öffnen",
                es: "Saldo de cocos \(snapshot.coconutBalance), abrir Oasis",
                pt: "Saldo de cocos \(snapshot.coconutBalance), abrir o Oásis",
                fr: "Solde de noix de coco : \(snapshot.coconutBalance), ouvrir Oasis",
                ja: "ココナッツ残高 \(snapshot.coconutBalance)、Oasisを開く",
                ko: "코코넛 잔액 \(snapshot.coconutBalance), Oasis 열기",
                it: "Saldo noci di cocco \(snapshot.coconutBalance), apri Oasi"
            ))
            .accessibilityIdentifier("zen-home-coconut-balance")

            Menu {
                ForEach(ZenPresenceSubjectKind.allCases, id: \.self) { kind in
                    Button {
                        actions.onAdd(kind)
                    } label: {
                        Label(kind.title(l), systemImage: kind.icon)
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(l.tr(
                zh: "添加",
                en: "Add",
                de: "Hinzufügen",
                es: "Añadir",
                pt: "Adicionar",
                fr: "Ajouter",
                ja: "追加",
                ko: "추가",
                it: "Aggiungi"
            ))
            .accessibilityIdentifier("zen-home-add-menu")

            Button(action: actions.onOpenSettings) {
                Image(systemName: "gearshape.fill")
            }
            .accessibilityLabel(l.tr(
                zh: "设置",
                en: "Settings",
                de: "Einstellungen",
                es: "Ajustes",
                pt: "Ajustes",
                fr: "Réglages",
                ja: "設定",
                ko: "설정",
                it: "Impostazioni"
            ))
            .accessibilityIdentifier("zen-home-settings-action")
        }
    }

    private var ownerStatusBanner: some View {
        let owner = snapshot.subjects.first(where: { $0.id == snapshot.ownerID && $0.isOwner })
        return HStack(spacing: 10) {
            Image(systemName: owner?.checkedToday == true ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                .font(OhanaFont.adaptive(size: 18, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(owner?.checkedToday == true ? Color.goTeal : Color.goOrange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(ownerBannerTitle(owner))
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(ownerBannerSubtitle(owner))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 8)

            if owner == nil, snapshot.isReady {
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

    private func ownerBannerTitle(_ owner: ZenPresenceSubjectDTO?) -> String {
        guard let owner else {
            return l.tr(
                zh: "还没有指定本人",
                en: "Choose who you are",
                de: "Wähle deine Person",
                es: "Elige quién eres",
                pt: "Escolha quem é você",
                fr: "Choisissez votre profil",
                ja: "自分のプロフィールを選んでください",
                ko: "본인을 선택하세요",
                it: "Scegli il tuo profilo"
            )
        }
        if owner.checkedToday {
            return l.tr(
                zh: "\(owner.name) 今天已自动打卡",
                en: "\(owner.name) checked in automatically",
                de: "\(owner.name) wurde automatisch eingecheckt",
                es: "Check-in automático de \(owner.name) completado",
                pt: "Check-in automático de \(owner.name) concluído",
                fr: "Check-in automatique de \(owner.name) effectué",
                ja: "\(owner.name)さんを自動でチェックインしました",
                ko: "\(owner.name) 님이 자동으로 체크인했어요",
                it: "Check-in automatico di \(owner.name) completato"
            )
        }
        return l.tr(
            zh: "正在为 \(owner.name) 打卡",
            en: "Checking in \(owner.name)",
            de: "Check-in für \(owner.name)",
            es: "Registrando el check-in de \(owner.name)",
            pt: "Fazendo check-in de \(owner.name)",
            fr: "Check-in de \(owner.name) en cours",
            ja: "\(owner.name)さんをチェックイン中",
            ko: "\(owner.name) 님 체크인 중",
            it: "Check-in di \(owner.name) in corso"
        )
    }

    private func ownerBannerSubtitle(_ owner: ZenPresenceSubjectDTO?) -> String {
        guard let owner else {
            return l.tr(
                zh: "指定后，打开 App 就会自动打卡",
                en: "Opening Ohana will check you in",
                de: "Ohana checkt dich beim Öffnen ein",
                es: "Ohana registrará tu check-in al abrirse",
                pt: "O Ohana fará seu check-in ao abrir",
                fr: "Ohana vous enregistrera à l’ouverture",
                ja: "Ohanaを開くと自動でチェックインします",
                ko: "Ohana를 열면 자동으로 체크인해요",
                it: "Ohana effettuerà il check-in all’apertura"
            )
        }
        if let checkedAt = owner.checkedAt, owner.checkedToday {
            return l.tr(
                zh: "打卡时间 \(checkedAt.formatted(date: .omitted, time: .shortened))",
                en: "Checked in at \(checkedAt.formatted(date: .omitted, time: .shortened))",
                de: "Eingecheckt um \(checkedAt.formatted(date: .omitted, time: .shortened))",
                es: "Check-in a las \(checkedAt.formatted(date: .omitted, time: .shortened))",
                pt: "Check-in às \(checkedAt.formatted(date: .omitted, time: .shortened))",
                fr: "Check-in à \(checkedAt.formatted(date: .omitted, time: .shortened))",
                ja: "\(checkedAt.formatted(date: .omitted, time: .shortened)) にチェックイン",
                ko: "\(checkedAt.formatted(date: .omitted, time: .shortened))에 체크인",
                it: "Check-in alle \(checkedAt.formatted(date: .omitted, time: .shortened))"
            )
        }
        return l.tr(
            zh: "无需额外操作",
            en: "No extra step needed",
            de: "Kein weiterer Schritt nötig",
            es: "No tienes que hacer nada más",
            pt: "Nenhuma etapa extra é necessária",
            fr: "Aucune autre action n’est nécessaire",
            ja: "そのままで大丈夫です",
            ko: "추가로 할 일이 없어요",
            it: "Non serve altro"
        )
    }

    private var checkInAllButton: some View {
        let isComplete = ZenPresencePresentation.allChecked(snapshot.subjects)
        return Button {
            checkInAll()
        } label: {
            HStack(spacing: 9) {
                if isCheckingInAll {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.ohanaPrimaryActionText)
                } else {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "checkmark.circle.badge.plus")
                }
                Text(isComplete
                    ? l.tr(
                        zh: "今日全部完成",
                        en: "All done today",
                        de: "Heute alles erledigt",
                        es: "Todo listo por hoy",
                        pt: "Tudo pronto por hoje",
                        fr: "Tout est fait aujourd’hui",
                        ja: "今日はすべて完了",
                        ko: "오늘 모두 완료",
                        it: "Tutto fatto per oggi"
                    )
                    : l.tr(
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
                    .font(OhanaFont.headline(.bold))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .disabled(!snapshot.isReady || snapshot.subjects.isEmpty || isComplete || isCheckingInAll)
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
    }

    private var loadingCards: some View {
        VStack(spacing: 10) {
            ForEach(0 ..< 3, id: \.self) { _ in
                ZenPresenceCardPlaceholder()
            }
        }
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
            Menu(l.tr(
                zh: "添加",
                en: "Add",
                de: "Hinzufügen",
                es: "Añadir",
                pt: "Adicionar",
                fr: "Ajouter",
                ja: "追加",
                ko: "추가",
                it: "Aggiungi"
            )) {
                ForEach(ZenPresenceSubjectKind.allCases, id: \.self) { kind in
                    Button(kind.title(l)) { actions.onAdd(kind) }
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("zen-home-empty-add-menu")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }

    private var subjectCards: some View {
        ForEach(ZenPresencePresentation.orderedSubjects(snapshot.subjects)) { subject in
            ZenPresenceCard(
                subject: subject,
                isPending: pendingSubjectIDs.contains(subject.id),
                localization: l,
                onTap: { handleCardTap(subject) },
                onManage: { actions.onManage(subject) }
            )
        }
    }

    private func handleCardTap(_ subject: ZenPresenceSubjectDTO) {
        guard !pendingSubjectIDs.contains(subject.id) else { return }
        if subject.checkedToday {
            selectedStatusSubject = currentSubject(withID: subject.id) ?? subject
        } else {
            checkIn(subject)
        }
    }

    private func checkIn(_ subject: ZenPresenceSubjectDTO) {
        mutateSubject(id: subject.id) {
            $0.checkedToday = true
            $0.checkedAt = Date()
        }
        pendingSubjectIDs.insert(subject.id)

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onCheckIn(subject.id, subject.kind)
            pendingSubjectIDs.remove(subject.id)
        }
    }

    private func checkInAll() {
        guard !isCheckingInAll,
              !ZenPresencePresentation.allChecked(snapshot.subjects)
        else { return }

        isCheckingInAll = true
        let now = Date()
        for index in snapshot.subjects.indices where !snapshot.subjects[index].checkedToday {
            snapshot.subjects[index].checkedToday = true
            snapshot.subjects[index].checkedAt = now
            pendingSubjectIDs.insert(snapshot.subjects[index].id)
        }

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onCheckInAll()
            pendingSubjectIDs.removeAll()
            isCheckingInAll = false
        }
    }

    private func updateStatus(_ status: ZenPresenceStatus?, for subject: ZenPresenceSubjectDTO) {
        mutateSubject(id: subject.id) {
            $0.checkedToday = true
            $0.checkedAt = $0.checkedAt ?? Date()
            $0.status = status
        }
        pendingSubjectIDs.insert(subject.id)

        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onUpdateStatus(subject.id, subject.kind, status)
            pendingSubjectIDs.remove(subject.id)
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

private struct ZenPresenceCard: View {
    let subject: ZenPresenceSubjectDTO
    let isPending: Bool
    let localization: L10n
    let onTap: () -> Void
    let onManage: () -> Void

    private var stateColor: Color {
        subject.status?.zenColor ?? (subject.checkedToday ? Color.goPrimary : Color.ohanaSecondaryText)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                HStack(spacing: 13) {
                    ZenSubjectAvatar(subject: subject)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(subject.name)
                                .font(OhanaFont.headline(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(2)
                            if subject.isOwner {
                                Text(localization.tr(
                                    zh: "本人",
                                    en: "Me",
                                    de: "Ich",
                                    es: "Yo",
                                    pt: "Eu",
                                    fr: "Moi",
                                    ja: "本人",
                                    ko: "본인",
                                    it: "Io"
                                ))
                                    .font(OhanaFont.caption2(.black))
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.goPrimary, in: Capsule())
                            }
                        }

                        Text(statusText)
                            .font(OhanaFont.footnote(.semibold))
                            .foregroundStyle(stateColor)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 42)

                    if isPending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(stateColor)
                    } else {
                        Image(systemName: subject.checkedToday ? "checkmark.circle.fill" : "circle")
                            .font(OhanaFont.adaptive(size: 25, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(stateColor)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                        .strokeBorder(subject.checkedToday ? stateColor.opacity(0.42) : Color.ohanaCardStroke, lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(subject.checkedToday
                ? localization.tr(
                    zh: "选择今天的状态",
                    en: "Choose today's status",
                    de: "Heutigen Status wählen",
                    es: "Elegir el estado de hoy",
                    pt: "Escolher o status de hoje",
                    fr: "Choisir l’état du jour",
                    ja: "今日の状態を選ぶ",
                    ko: "오늘의 상태 선택",
                    it: "Scegli lo stato di oggi"
                )
                : localization.tr(
                    zh: "完成今天的打卡",
                    en: "Complete today's check-in",
                    de: "Heutigen Check-in abschließen",
                    es: "Completar el check-in de hoy",
                    pt: "Concluir o check-in de hoje",
                    fr: "Effectuer le check-in du jour",
                    ja: "今日のチェックインを完了",
                    ko: "오늘의 체크인 완료",
                    it: "Completa il check-in di oggi"
                ))
            .accessibilityIdentifier("zen-home-subject-\(subject.kind.rawValue)-\(subject.id)")

            Menu {
                Button(action: onManage) {
                    Label(localization.tr(
                        zh: "管理",
                        en: "Manage",
                        de: "Verwalten",
                        es: "Gestionar",
                        pt: "Gerenciar",
                        fr: "Gérer",
                        ja: "管理",
                        ko: "관리",
                        it: "Gestisci"
                    ), systemImage: "slider.horizontal.3")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(OhanaFont.callout(.bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Color.ohanaSecondaryText)
            .accessibilityLabel(localization.tr(
                zh: "管理 \(subject.name)",
                en: "Manage \(subject.name)",
                de: "\(subject.name) verwalten",
                es: "Gestionar a \(subject.name)",
                pt: "Gerenciar \(subject.name)",
                fr: "Gérer \(subject.name)",
                ja: "\(subject.name)を管理",
                ko: "\(subject.name) 관리",
                it: "Gestisci \(subject.name)"
            ))
            .accessibilityIdentifier("zen-home-manage-\(subject.kind.rawValue)-\(subject.id)")
        }
    }

    private var statusText: String {
        if let status = subject.status {
            return localization.tr(
                zh: "今日状态：\(status.title(localization))",
                en: "Today: \(status.title(localization))",
                de: "Heute: \(status.title(localization))",
                es: "Hoy: \(status.title(localization))",
                pt: "Hoje: \(status.title(localization))",
                fr: "Aujourd’hui : \(status.title(localization))",
                ja: "今日：\(status.title(localization))",
                ko: "오늘: \(status.title(localization))",
                it: "Oggi: \(status.title(localization))"
            )
        }
        if subject.checkedToday {
            return localization.tr(
                zh: "今天已打卡 · 可添加状态",
                en: "Checked in · Add a status",
                de: "Eingecheckt · Status hinzufügen",
                es: "Check-in hecho · Añadir estado",
                pt: "Check-in feito · Adicionar status",
                fr: "Check-in effectué · Ajouter un état",
                ja: "チェックイン済み · 状態を追加",
                ko: "체크인 완료 · 상태 추가",
                it: "Check-in fatto · Aggiungi uno stato"
            )
        }
        return localization.tr(
            zh: "点击卡片打卡",
            en: "Tap to check in",
            de: "Zum Einchecken tippen",
            es: "Toca para hacer check-in",
            pt: "Toque para fazer check-in",
            fr: "Touchez pour enregistrer",
            ja: "タップしてチェックイン",
            ko: "탭하여 체크인",
            it: "Tocca per il check-in"
        )
    }

    private var accessibilityLabel: String {
        let kind = subject.kind.title(localization)
        return "\(subject.name), \(kind), \(statusText)"
    }
}

private struct ZenSubjectAvatar: View {
    let subject: ZenPresenceSubjectDTO

    var body: some View {
        ZStack {
            Circle()
                .fill(themeColor.opacity(0.16))
            if let assetName = subject.avatarAssetName, !assetName.isEmpty {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: subject.kind.icon)
                    .font(OhanaFont.adaptive(size: 22, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(themeColor)
            }
        }
        .frame(width: 52, height: 52)
        .overlay(Circle().strokeBorder(themeColor.opacity(0.28), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var themeColor: Color {
        if let themeHex = subject.themeHex, !themeHex.isEmpty {
            return Color(hex: themeHex)
        }
        return switch subject.kind {
        case .human: Color.goBlue
        case .pet: Color.goOrange
        case .plant: Color.goTeal
        }
    }
}

private struct ZenPresenceCardPlaceholder: View {
    var body: some View {
        HStack(spacing: 13) {
            Circle()
                .fill(Color.ohanaControlFill)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: OhanaRadius.micro)
                    .fill(Color.ohanaControlFill)
                    .frame(width: 120, height: 16)
                RoundedRectangle(cornerRadius: OhanaRadius.micro)
                    .fill(Color.ohanaControlFill)
                    .frame(width: 176, height: 12)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }
}

private struct ZenStatusPickerSheet: View {
    let subject: ZenPresenceSubjectDTO
    let onSelect: (ZenPresenceStatus?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ZenPresenceStatus.allCases) { status in
                        statusButton(status)
                    }
                    statusButton(nil)
                } header: {
                    Text(l.tr(
                        zh: "今天感觉如何？",
                        en: "How is today going?",
                        de: "Wie läuft der Tag?",
                        es: "¿Cómo va el día?",
                        pt: "Como está o dia?",
                        fr: "Comment se passe la journée ?",
                        ja: "今日の調子はどうですか？",
                        ko: "오늘은 어떤가요?",
                        it: "Come va oggi?"
                    ))
                } footer: {
                    Text(l.tr(
                        zh: "状态是可选的，之后仍可修改。",
                        en: "Status is optional and can be changed later.",
                        de: "Der Status ist optional und kann später geändert werden.",
                        es: "El estado es opcional y puedes cambiarlo después.",
                        pt: "O status é opcional e pode ser alterado depois.",
                        fr: "L’état est facultatif et peut être modifié plus tard.",
                        ja: "状態の記録は任意で、後から変更できます。",
                        ko: "상태는 선택 사항이며 나중에 변경할 수 있어요.",
                        it: "Lo stato è facoltativo e può essere modificato in seguito."
                    ))
                }
            }
            .navigationTitle(subject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(
                        zh: "取消",
                        en: "Cancel",
                        de: "Abbrechen",
                        es: "Cancelar",
                        pt: "Cancelar",
                        fr: "Annuler",
                        ja: "キャンセル",
                        ko: "취소",
                        it: "Annulla"
                    )) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("zen-status-picker")
    }

    private func statusButton(_ status: ZenPresenceStatus?) -> some View {
        Button {
            onSelect(status)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: status?.icon ?? "checkmark.circle")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(status?.zenColor ?? Color.ohanaSecondaryText)
                    .frame(width: 24)
                Text(status?.title(l) ?? l.tr(
                    zh: "只打卡，不记录状态",
                    en: "Check in without a status",
                    de: "Ohne Status einchecken",
                    es: "Hacer check-in sin estado",
                    pt: "Fazer check-in sem status",
                    fr: "Enregistrer sans état",
                    ja: "状態を記録せずチェックイン",
                    ko: "상태 기록 없이 체크인",
                    it: "Check-in senza stato"
                ))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                if subject.status == status {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.goPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("zen-status-option-\(status?.rawValue ?? "none")")
    }
}

extension ZenPresenceStatus {
    @MainActor
    var zenColor: Color {
        switch self {
        case .great: Color.goTeal
        case .okay: Color.goBlue
        case .needsAttention: Color.goOrange
        case .poor: Color.goRed
        }
    }
}
