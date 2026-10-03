//
//  ZenMembersView.swift
//  Ohana
//
//  Lightweight Human, Pet, and Plant management for the Zen shell. The list
//  consumes value snapshots; existing creation and editable profile routes own
//  all persistent commands.
//

import SwiftUI
import UIKit

@MainActor
struct ZenMembersRouteContainer: View {
    let subjects: [ZenPresenceSubjectDTO]
    let avatarCacheRevision: Int
    let onRefresh: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var childRoute: ZenMembersChildRoute?

    var body: some View {
        NavigationStack {
            ZenMembersView(
                subjects: subjects,
                avatarCacheRevision: avatarCacheRevision,
                onAdd: { childRoute = .add($0) },
                onOpenProfile: { childRoute = .profile($0) }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").accessibilityHidden(true)
                    }
                    .accessibilityLabel(L10n.current.tr(
                        zh: "关闭",
                        en: "Close",
                        de: "Schließen",
                        es: "Cerrar",
                        pt: "Fechar",
                        fr: "Fermer",
                        ja: "閉じる",
                        ko: "닫기",
                        it: "Chiudi"
                    ))
                    .accessibilityIdentifier("zen-members-close-action")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ZenMemberAddMenu { childRoute = .add($0) }
                }
            }
        }
        .fullScreenCover(item: $childRoute, onDismiss: onRefresh) { route in
            childDestination(route)
                .environment(\.memberProfileExperienceStyle, .zen)
        }
    }

    @ViewBuilder
    private func childDestination(_ route: ZenMembersChildRoute) -> some View {
        switch route {
        case let .add(kind):
            NavigationStack {
                AddEntityDestinationView(
                    type: entityType(kind),
                    onComplete: closeChild,
                    onPetSaved: { _ in closeChildAndRefresh() },
                    onHumanSaved: { _ in closeChildAndRefresh() },
                    onPlantSaved: { _ in closeChildAndRefresh() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OhanaAppBackground())
            }

        case let .profile(subject):
            profileDestination(subject)
        }
    }

    @ViewBuilder
    private func profileDestination(_ subject: ZenPresenceSubjectDTO) -> some View {
        if let id = UUID(uuidString: subject.id) {
            switch subject.kind {
            case .human:
                AppHumanDetailSheetRouteContainer(
                    id: id,
                    destination: .basicInfo,
                    onMissing: closeChild,
                    onDismiss: closeChild
                )
            case .pet:
                AppPetDetailSheetRouteContainer(
                    id: id,
                    destination: .basicInfo,
                    onMissing: closeChild,
                    onDismiss: closeChild
                )
            case .plant:
                AppPlantRouteContainer(
                    id: id,
                    destination: .basicInfo,
                    onDismiss: closeChild,
                    onChanged: closeChildAndRefresh
                )
            }
        } else {
            Color.clear.onAppear(perform: closeChild)
        }
    }

    private func closeChild() {
        childRoute = nil
    }

    private func closeChildAndRefresh() {
        childRoute = nil
        onRefresh()
    }

    private func entityType(_ kind: ZenPresenceSubjectKind) -> EntityType {
        switch kind {
        case .human: .human
        case .pet: .pet
        case .plant: .plant
        }
    }
}

private enum ZenMembersChildRoute: Identifiable {
    case add(ZenPresenceSubjectKind)
    case profile(ZenPresenceSubjectDTO)

    var id: String {
        switch self {
        case let .add(kind): "add:\(kind.rawValue)"
        case let .profile(subject): "profile:\(subject.kind.rawValue):\(subject.id)"
        }
    }
}

@MainActor
private struct ZenMembersView: View {
    let subjects: [ZenPresenceSubjectDTO]
    let avatarCacheRevision: Int
    let onAdd: (ZenPresenceSubjectKind) -> Void
    let onOpenProfile: (ZenPresenceSubjectDTO) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    private var orderedSubjects: [ZenPresenceSubjectDTO] {
        ZenPresencePresentation.orderedSubjects(subjects.filter(\.isActive))
    }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            if orderedSubjects.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "person.2.slash")
                } description: {
                    EmptyView()
                } actions: {
                    ZenMemberAddMenu(onAdd: onAdd)
                        .ohanaPrimaryProminentButton()
                }
            } else {
                List {
                    ForEach(orderedSubjects) { subject in
                        Button {
                            onOpenProfile(subject)
                        } label: {
                            ZenMemberRow(
                                subject: subject,
                                avatarCacheRevision: avatarCacheRevision,
                                localization: l
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "zen-members-row-\(subject.kind.rawValue)-\(subject.id)"
                        )
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(l.tr(
            zh: "成员",
            en: "Members",
            de: "Mitglieder",
            es: "Miembros",
            pt: "Membros",
            fr: "Membres",
            ja: "メンバー",
            ko: "구성원",
            it: "Membri"
        ))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-members-screen")
    }

    private var emptyTitle: String {
        l.tr(
            zh: "还没有成员",
            en: "No members yet",
            de: "Noch keine Mitglieder",
            es: "Aún no hay miembros",
            pt: "Ainda não há membros",
            fr: "Aucun membre pour le moment",
            ja: "まだメンバーがいません",
            ko: "아직 구성원이 없어요",
            it: "Nessun membro"
        )
    }
}

@MainActor
private struct ZenMemberRow: View {
    let subject: ZenPresenceSubjectDTO
    let avatarCacheRevision: Int
    let localization: L10n

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color.ohanaControlFill)
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .clipShape(Circle())
                        .transition(.opacity)
                } else {
                    Text(subject.zenFallbackEmoji)
                        .font(OhanaFont.adaptive(size: 22, weight: .semibold))
                }
            }
            .frame(width: 46, height: 46)
            .animation(GoMotion.quick, value: avatarCacheRevision)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subject.name)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    if subject.isOwner {
                        Image(systemName: "person.crop.circle.badge.checkmark").accessibilityHidden(true)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.goPrimary)
                    }
                }

                Text("\(subject.kind.title(localization)) · \(primaryDayMetricText)")
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Label(statusText, systemImage: statusIcon)
                .labelStyle(.titleAndIcon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(statusColor)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)

            Image(systemName: "chevron.right").accessibilityHidden(true)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaTertiaryText)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(localization.tr(
            zh: "打开可编辑的基础资料",
            en: "Open the editable profile",
            de: "Bearbeitbares Profil öffnen",
            es: "Abrir el perfil editable",
            pt: "Abrir o perfil editável",
            fr: "Ouvrir le profil modifiable",
            ja: "編集可能なプロフィールを開きます",
            ko: "편집 가능한 프로필 열기",
            it: "Apri il profilo modificabile"
        ))
    }

    private var avatarImage: UIImage? {
        guard let id = UUID(uuidString: subject.id) else { return nil }
        _ = avatarCacheRevision
        return FocusWalletAvatarCache.cachedEntry(
            for: id,
            signature: subject.avatarThumbnailSignature
        )?.image
    }

    private var primaryDayMetricText: String {
        if let companionText = subject.plantCompanionText(localization) {
            return companionText
        }
        let days = subject.currentDisplayStreak
        return localization.tr(
            zh: "连续 \(days) 天",
            en: "\(days)-day streak",
            de: days == 1 ? "Serie: 1 Tag" : "Serie: \(days) Tage",
            es: days == 1 ? "Racha de 1 día" : "Racha de \(days) días",
            pt: days == 1 ? "Sequência de 1 dia" : "Sequência de \(days) dias",
            fr: days == 1 ? "Série de 1 jour" : "Série de \(days) jours",
            ja: "\(days)日連続",
            ko: "\(days)일 연속",
            it: days == 1 ? "Serie di 1 giorno" : "Serie di \(days) giorni"
        )
    }

    private var statusText: String {
        if let status = subject.status {
            return "\(status.score)/10"
        }
        return subject.zenCompactStatusText(localization)
    }

    private var statusIcon: String {
        if let status = subject.status { return status.icon }
        return subject.checkedToday ? "checkmark.circle.fill" : "circle.dashed"
    }

    private var statusColor: Color {
        if let status = subject.status { return status.zenColor }
        return subject.checkedToday ? Color.goTeal : Color.ohanaSecondaryText
    }
}

@MainActor
private struct ZenMemberAddMenu: View {
    let onAdd: (ZenPresenceSubjectKind) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Menu {
            ForEach(ZenPresenceSubjectKind.allCases, id: \.self) { kind in
                Button {
                    onAdd(kind)
                } label: {
                    Label(kind.title(l), systemImage: kind.icon)
                }
                .accessibilityIdentifier("zen-members-add-\(kind.rawValue)-action")
            }
        } label: {
            Image(systemName: "plus").accessibilityHidden(true)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(l.tr(
            zh: "添加成员",
            en: "Add member",
            de: "Mitglied hinzufügen",
            es: "Añadir miembro",
            pt: "Adicionar membro",
            fr: "Ajouter un membre",
            ja: "メンバーを追加",
            ko: "구성원 추가",
            it: "Aggiungi membro"
        ))
        .accessibilityIdentifier("zen-members-add-menu")
    }
}
