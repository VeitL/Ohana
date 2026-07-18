//
//  ZenExperienceContainer.swift
//  Ohana
//
//  Production adapter between the value-only Zen shell and existing domain
//  services. The shell never receives live SwiftData models.
//

import SwiftData
import SwiftUI

@MainActor
struct ZenExperienceContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(AppExperienceController.self) private var experienceController
    @Environment(\.appPersistentBootstrapReady) private var persistentBootstrapReady

    @State private var snapshot = ZenPresenceSnapshot.empty
    @State private var oasisSnapshot = ZenOasisSnapshot.empty
    @State private var presentedRoute: ZenExperienceRoute?
    @State private var refreshTask: Task<Void, Never>?
    @State private var didLoadStreak = false
    @State private var didLoadOasis = false
    @State private var errorMessage: String?

    let onRequestModeSwitch: () -> Void

    init(onRequestModeSwitch: @escaping () -> Void) {
        self.onRequestModeSwitch = onRequestModeSwitch
    }

    var body: some View {
        ZenShell(
            snapshot: $snapshot,
            oasisSnapshot: $oasisSnapshot,
            actions: actions
        )
        .task(id: "\(experienceController.zenOwnerHumanID):\(persistentBootstrapReady)") {
            await prepareExperience()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRefresh()
        }
        .onChange(of: appServices.commerce.personalAccessLevel) { _, _ in
            scheduleRefresh(delayMilliseconds: 0)
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .sheet(item: $presentedRoute) { route in
            routeDestination(route)
                .ohanaSheetPagePresentation()
        }
        .alert(
            L10n.current.tr(
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
            Button(L10n.current.tr(
                zh: "知道了",
                en: "OK",
                de: "OK",
                es: "Aceptar",
                pt: "OK",
                fr: "OK",
                ja: "OK",
                ko: "확인",
                it: "OK"
            ), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var commandService: PresenceCheckInCommandService {
        PresenceCheckInCommandService(
            context: modelContext,
            wallet: appServices.coconutWallet,
            projectionManager: appServices.questManager
        )
    }

    private var actions: ZenShellActions {
        ZenShellActions(
            onAutoCheckInOwner: {
                await runPresenceCommand { try commandService.autoCheckInOwner() }
            },
            onCheckIn: { subjectID, kind in
                guard let subject = presenceSubject(id: subjectID, kind: kind) else { return }
                await runPresenceCommand { try commandService.checkIn(subject: subject) }
            },
            onUpdateStatus: { subjectID, kind, status in
                guard let subject = presenceSubject(id: subjectID, kind: kind) else { return }
                await runPresenceCommand {
                    try commandService.updateTodayStatus(
                        subject: subject,
                        status: status.map(presenceStatus)
                    )
                }
            },
            onCheckInAll: {
                await runPresenceCommand { try commandService.checkInAll() }
            },
            onLoadStreak: {
                didLoadStreak = true
                refresh(streak: true)
            },
            onLoadOasis: {
                didLoadOasis = true
                guard persistentBootstrapReady else { return }
                refreshOasis(balance: appServices.coconutWallet.totalBalance(context: modelContext))
            },
            onAdd: { kind in
                presentedRoute = .add(entityType(kind))
            },
            onManage: { subject in
                guard let id = UUID(uuidString: subject.id) else { return }
                presentedRoute = switch subject.kind {
                case .human: .human(id)
                case .pet: .pet(id)
                case .plant: .plant(id)
                }
            },
            onOpenSettings: onRequestModeSwitch,
            onOpenPersonalAnalytics: {
                presentedRoute = appServices.commerce.allows(.presenceLongRangeAnalytics)
                    ? .analytics
                    : .personalPlan
            },
            onOpenShop: {
                guard lockedLevel(for: .coconutShop(.appIcon)) == nil else { return }
                presentedRoute = .shop
            },
            onOpenGacha: {
                guard lockedLevel(for: .gacha) == nil else { return }
                presentedRoute = .gacha
            },
            onOpenCritters: {
                guard lockedLevel(for: .critterCodex) == nil else { return }
                presentedRoute = .critters
            },
            onInjectEnergy: {
                _ = appServices.oasisTree.injectEnergy(
                    cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
                    modelContext: modelContext
                )
                refresh(streak: didLoadStreak)
            },
            onClaimStarterGift: {
                let result = StarterGiftService.claimZenStarterGift(
                    context: modelContext,
                    careLedger: appServices.careLedger,
                    wallet: appServices.coconutWallet,
                    projectionManager: appServices.questManager
                )
                if case .claimed = result {
                    StarterGiftService.markCeremonySeen()
                } else if case .persistenceFailed = result {
                    errorMessage = L10n.current.tr(
                        zh: "起航礼没有保存，请稍后重试。",
                        en: "The welcome gift was not saved. Try again.",
                        de: "Das Willkommensgeschenk wurde nicht gespeichert.",
                        es: "El regalo de bienvenida no se guardó. Inténtalo de nuevo.",
                        pt: "O presente de boas-vindas não foi salvo. Tente novamente.",
                        fr: "Le cadeau de bienvenue n’a pas été enregistré. Réessayez.",
                        ja: "スタートギフトを保存できませんでした。もう一度お試しください。",
                        ko: "시작 선물이 저장되지 않았어요. 다시 시도하세요.",
                        it: "Il regalo di benvenuto non è stato salvato. Riprova."
                    )
                }
                refresh(streak: didLoadStreak)
            }
        )
    }

    private func prepareExperience() async {
        guard persistentBootstrapReady,
              UUID(uuidString: experienceController.zenOwnerHumanID) != nil else {
            snapshot = .empty
            oasisSnapshot = .empty
            return
        }
        refresh(streak: didLoadStreak)
    }

    private func runPresenceCommand(
        _ operation: () throws -> PresenceCheckInCommandResult
    ) async {
        do {
            let result = try operation()
            if let ownerCheckIn = result.checkIns.first(where: \.isOwner) {
                await SystemPresenceReminderScheduler().cancelToday(now: ownerCheckIn.checkedInAt)
            }
        } catch {
            present(error)
        }
        refresh(streak: didLoadStreak)
    }

    private func scheduleRefresh(delayMilliseconds: UInt64 = 100) {
        refreshTask?.cancel()
        refreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            refresh(streak: didLoadStreak)
            refreshTask = nil
        }
    }

    private func refresh(streak shouldLoadStreak: Bool) {
        guard persistentBootstrapReady,
              let ownerID = UUID(uuidString: experienceController.zenOwnerHumanID) else {
            snapshot = .empty
            oasisSnapshot = .empty
            return
        }
        do {
            let home = try PresenceCheckInReadService.homeSnapshot(
                context: modelContext,
                ownerHumanId: ownerID
            )
            let todayCheckIns = try todayCheckIns(dayKey: home.dayKey)
            let todayBySubject = Dictionary(
                todayCheckIns.compactMap { item in item.subject.map { ($0, item) } },
                uniquingKeysWith: { first, _ in first }
            )
            var currentStreak = shouldLoadStreak ? 0 : snapshot.currentStreak
            var longestStreak = shouldLoadStreak ? 0 : snapshot.longestStreak
            var days = shouldLoadStreak ? [] : snapshot.days
            var streakSubjects = shouldLoadStreak ? [] : snapshot.streakSubjects
            if shouldLoadStreak {
                let historicalSubjects = try PresenceCheckInReadService.streakSubjects(
                    context: modelContext,
                    ownerHumanId: ownerID
                )
                streakSubjects = historicalSubjects.enumerated().map { index, subject in
                    ZenPresenceSubjectDTO(
                        id: subject.subject.id.uuidString,
                        kind: zenKind(subject.subject.kind),
                        name: subject.isAnonymousHistory
                            ? anonymousHistoryName(for: subject.subject.kind)
                            : subject.name,
                        avatarAssetName: nil,
                        themeHex: subject.themeColorHex,
                        isOwner: subject.isOwner,
                        sortIndex: index,
                        isActive: subject.isActive,
                        isAnonymousHistory: subject.isAnonymousHistory
                    )
                }
                for subject in historicalSubjects {
                    let value = try PresenceCheckInReadService.streakSnapshot(
                        context: modelContext,
                        ownerHumanId: ownerID,
                        subject: subject.subject
                    )
                    if subject.isOwner {
                        currentStreak = value.currentStreak
                        longestStreak = value.longestStreak
                    }
                    days += value.days.map { day in
                        ZenPresenceDayDTO(
                            subjectID: subject.subject.id.uuidString,
                            dayKey: day.dayKey,
                            checkedIn: day.isCheckedIn,
                            status: day.status.map(zenStatus),
                            participation: day.isParticipating ? .participating : .notParticipating
                        )
                    }
                }
            }

            let balance = appServices.coconutWallet.totalBalance(context: modelContext)
            snapshot = ZenPresenceSnapshot(
                isReady: true,
                subjects: home.subjects.enumerated().map { index, subject in
                    let today = todayBySubject[subject.subject]
                    return ZenPresenceSubjectDTO(
                        id: subject.subject.id.uuidString,
                        kind: zenKind(subject.subject.kind),
                        name: subject.name,
                        avatarAssetName: nil,
                        themeHex: subject.themeColorHex,
                        isOwner: subject.isOwner,
                        sortIndex: index,
                        isActive: true,
                        isAnonymousHistory: false,
                        checkedToday: subject.isCheckedInToday,
                        status: subject.status.map(zenStatus),
                        checkedAt: today?.checkedInAt
                    )
                },
                streakSubjects: streakSubjects,
                ownerID: ownerID.uuidString,
                dayKey: home.dayKey,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                days: days,
                coconutBalance: balance,
                personalAccessLevel: appServices.commerce.personalAccessLevel
            )
            if didLoadOasis {
                refreshOasis(balance: balance)
            }
        } catch {
            present(error)
        }
    }

    private func refreshOasis(balance: Int) {
        _ = appServices.oasisTree.refreshLedgerEnergy(modelContext: modelContext)
        let level = appServices.oasisTree.treeLevel.rawValue
        let gift = StarterGiftService.evaluateZenEligibility(
            context: modelContext,
            wallet: appServices.coconutWallet,
            projectionManager: appServices.questManager
        )
        let giftState: ZenStarterGiftState = switch gift {
        case .readyToClaim:
            .claimable
        case .claimed, .alreadyHandled:
            .claimed
        case .markedExistingUser, .pendingFirstPet, .persistenceFailed:
            .hidden
        }
        oasisSnapshot = ZenOasisSnapshot(
            isReady: true,
            level: level,
            progressToNextLevel: appServices.oasisTree.progressToNextLevel,
            totalEnergy: appServices.oasisTree.totalEnergy,
            nextLevelThreshold: appServices.oasisTree.nextLevelThreshold,
            coconutBalance: balance,
            canInjectEnergy: balance >= OasisTreeEnergyInjectionPolicy.starterPackageCost &&
                appServices.oasisTree.canUseInjectionPackage(cost: OasisTreeEnergyInjectionPolicy.starterPackageCost),
            shopLockedLevel: lockedLevel(for: .coconutShop(.appIcon), currentLevel: level),
            gachaLockedLevel: lockedLevel(for: .gacha, currentLevel: level),
            crittersLockedLevel: lockedLevel(for: .critterCodex, currentLevel: level),
            starterGiftState: giftState
        )
    }

    private func todayCheckIns(dayKey: String) throws -> [PresenceCheckIn] {
        try modelContext.fetch(FetchDescriptor<PresenceCheckIn>(
            predicate: #Predicate {
                $0.dayKey == dayKey
            },
            sortBy: [SortDescriptor(\.checkedInAt)]
        ))
    }

    private func lockedLevel(
        for route: OasisSheetRoute,
        currentLevel: Int? = nil
    ) -> Int? {
        let level = currentLevel ?? appServices.oasisTree.treeLevel.rawValue
        guard let required = AppFeatureRouteGuard.requiredLevel(for: route), level < required else {
            return nil
        }
        return required
    }

    @ViewBuilder
    private func routeDestination(_ route: ZenExperienceRoute) -> some View {
        switch route {
        case let .add(type):
            NavigationStack {
                AddEntityDestinationView(
                    type: type,
                    onComplete: closeRoute,
                    onPetSaved: { _ in closeAndRefreshRoute() },
                    onHumanSaved: { _ in closeAndRefreshRoute() },
                    onPlantSaved: { _ in closeAndRefreshRoute() }
                )
            }
        case let .human(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .basicInfo,
                onMissing: closeRoute,
                onDismiss: closeRoute
            )
        case let .pet(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .basicInfo,
                onMissing: closeRoute,
                onDismiss: closeRoute
            )
        case let .plant(id):
            ZenPlantManagementRoute(id: id, onClose: closeAndRefreshRoute)
        case .shop:
            NavigationStack { CoconutShopRouteContainer() }
        case .gacha:
            GachaRouteContainer(
                drawsBackground: true,
                onClose: closeRoute,
                onPresentCoconutLog: nil
            )
        case .critters:
            NavigationStack {
                OasisCritterCodexRouteContainer(mode: .codex, onClose: closeRoute)
            }
        case .analytics:
            NavigationStack { ZenPersonalAnalyticsView(snapshot: snapshot) }
        case .personalPlan:
            PersonalPlanView(prompt: PersonalUpgradePrompt(feature: .presenceLongRangeAnalytics))
        }
    }

    private func closeRoute() {
        presentedRoute = nil
    }

    private func closeAndRefreshRoute() {
        presentedRoute = nil
        scheduleRefresh(delayMilliseconds: 80)
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        OhanaLog.warning("Zen experience command failed: \(error.localizedDescription)", category: "Presence")
    }

    private func presenceSubject(
        id rawID: String,
        kind: ZenPresenceSubjectKind
    ) -> PresenceSubjectRef? {
        guard let id = UUID(uuidString: rawID) else { return nil }
        return PresenceSubjectRef(kind: presenceKind(kind), id: id)
    }

    private func entityType(_ kind: ZenPresenceSubjectKind) -> EntityType {
        switch kind {
        case .human: .human
        case .pet: .pet
        case .plant: .plant
        }
    }

    private func zenKind(_ kind: PresenceSubjectKind) -> ZenPresenceSubjectKind {
        ZenPresenceSubjectKind(rawValue: kind.rawValue) ?? .human
    }

    private func presenceKind(_ kind: ZenPresenceSubjectKind) -> PresenceSubjectKind {
        PresenceSubjectKind(rawValue: kind.rawValue) ?? .human
    }

    private func zenStatus(_ status: PresenceStatus) -> ZenPresenceStatus {
        ZenPresenceStatus(rawValue: status.rawValue) ?? .okay
    }

    private func presenceStatus(_ status: ZenPresenceStatus) -> PresenceStatus {
        PresenceStatus(rawValue: status.rawValue) ?? .okay
    }

    private func anonymousHistoryName(for kind: PresenceSubjectKind) -> String {
        switch kind {
        case .human:
            L10n.current.tr(
                zh: "已删除的成员",
                en: "Deleted person",
                de: "Gelöschte Person",
                es: "Persona eliminada",
                pt: "Pessoa excluída",
                fr: "Personne supprimée",
                ja: "削除されたメンバー",
                ko: "삭제된 구성원",
                it: "Persona eliminata"
            )
        case .pet:
            L10n.current.tr(
                zh: "已删除的宠物",
                en: "Deleted pet",
                de: "Gelöschtes Tier",
                es: "Mascota eliminada",
                pt: "Pet excluído",
                fr: "Animal supprimé",
                ja: "削除されたペット",
                ko: "삭제된 반려동물",
                it: "Animale eliminato"
            )
        case .plant:
            L10n.current.tr(
                zh: "已删除的植物",
                en: "Deleted plant",
                de: "Gelöschte Pflanze",
                es: "Planta eliminada",
                pt: "Planta excluída",
                fr: "Plante supprimée",
                ja: "削除された植物",
                ko: "삭제된 식물",
                it: "Pianta eliminata"
            )
        }
    }
}

@MainActor
private struct ZenPlantManagementRoute: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Query private var plants: [Plant]
    @State private var showingEditor = false
    @State private var showingArchiveConfirmation = false
    @State private var showingDeleteConfirmation = false

    let onClose: () -> Void

    init(id: UUID, onClose: @escaping () -> Void) {
        _plants = Query(filter: #Predicate<Plant> { $0.id == id })
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Group {
                if let plant = plants.first {
                    List {
                        Button {
                            showingEditor = true
                        } label: {
                            Label(
                                L10n.current.tr(
                                    zh: "编辑资料",
                                    en: "Edit profile",
                                    de: "Profil bearbeiten",
                                    es: "Editar perfil",
                                    pt: "Editar perfil",
                                    fr: "Modifier le profil",
                                    ja: "プロフィールを編集",
                                    ko: "프로필 편집",
                                    it: "Modifica profilo"
                                ),
                                systemImage: "pencil"
                            )
                        }
                        .accessibilityIdentifier("zen-plant-edit-action")

                        Button(role: .destructive) {
                            showingArchiveConfirmation = true
                        } label: {
                            Label(
                                L10n.current.tr(
                                    zh: "归档植物",
                                    en: "Archive plant",
                                    de: "Pflanze archivieren",
                                    es: "Archivar planta",
                                    pt: "Arquivar planta",
                                    fr: "Archiver la plante",
                                    ja: "植物をアーカイブ",
                                    ko: "식물 보관",
                                    it: "Archivia pianta"
                                ),
                                systemImage: "archivebox"
                            )
                        }
                        .accessibilityIdentifier("zen-plant-archive-action")

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(
                                L10n.current.tr(
                                    zh: "删除植物",
                                    en: "Delete plant",
                                    de: "Pflanze löschen",
                                    es: "Eliminar planta",
                                    pt: "Excluir planta",
                                    fr: "Supprimer la plante",
                                    ja: "植物を削除",
                                    ko: "식물 삭제",
                                    it: "Elimina pianta"
                                ),
                                systemImage: "trash"
                            )
                        }
                        .accessibilityIdentifier("zen-plant-delete-action")
                    }
                    .sheet(isPresented: $showingEditor) {
                        EditPlantSheet(plant: plant)
                            .ohanaSheetPagePresentation()
                    }
                    .alert(
                        L10n.current.tr(
                            zh: "归档植物？",
                            en: "Archive plant?",
                            de: "Pflanze archivieren?",
                            es: "¿Archivar la planta?",
                            pt: "Arquivar a planta?",
                            fr: "Archiver la plante ?",
                            ja: "植物をアーカイブしますか？",
                            ko: "식물을 보관할까요?",
                            it: "Archiviare la pianta?"
                        ),
                        isPresented: $showingArchiveConfirmation
                    ) {
                        Button(L10n.current.tr(
                            zh: "取消",
                            en: "Cancel",
                            de: "Abbrechen",
                            es: "Cancelar",
                            pt: "Cancelar",
                            fr: "Annuler",
                            ja: "キャンセル",
                            ko: "취소",
                            it: "Annulla"
                        ), role: .cancel) {}
                        Button(L10n.current.tr(
                            zh: "归档",
                            en: "Archive",
                            de: "Archivieren",
                            es: "Archivar",
                            pt: "Arquivar",
                            fr: "Archiver",
                            ja: "アーカイブ",
                            ko: "보관",
                            it: "Archivia"
                        ), role: .destructive) {
                            archive(plant)
                        }
                    } message: {
                        Text(L10n.current.tr(
                            zh: "档案与历史会保留，之后不再出现在佛系首页。",
                            en: "The profile and history stay, and this plant leaves Zen Home.",
                            de: "Profil und Verlauf bleiben erhalten; die Pflanze verschwindet von Zen Home.",
                            es: "El perfil y el historial se conservarán, pero la planta dejará de aparecer en Inicio zen.",
                            pt: "O perfil e o histórico serão mantidos, mas a planta sairá do Início zen.",
                            fr: "Le profil et l’historique seront conservés, mais la plante quittera l’accueil Zen.",
                            ja: "プロフィールと履歴は残りますが、植物は佛系ホームに表示されなくなります。",
                            ko: "프로필과 기록은 유지되지만 식물은 마음 편한 홈에서 사라져요.",
                            it: "Il profilo e la cronologia resteranno, ma la pianta non apparirà più nella Home Zen."
                        ))
                    }
                    .alert(
                        L10n.current.tr(
                            zh: "删除植物？",
                            en: "Delete plant?",
                            de: "Pflanze löschen?",
                            es: "¿Eliminar la planta?",
                            pt: "Excluir a planta?",
                            fr: "Supprimer la plante ?",
                            ja: "植物を削除しますか？",
                            ko: "식물을 삭제할까요?",
                            it: "Eliminare la pianta?"
                        ),
                        isPresented: $showingDeleteConfirmation
                    ) {
                        Button(L10n.current.tr(
                            zh: "取消",
                            en: "Cancel",
                            de: "Abbrechen",
                            es: "Cancelar",
                            pt: "Cancelar",
                            fr: "Annuler",
                            ja: "キャンセル",
                            ko: "취소",
                            it: "Annulla"
                        ), role: .cancel) {}
                        Button(L10n.current.tr(
                            zh: "删除",
                            en: "Delete",
                            de: "Löschen",
                            es: "Eliminar",
                            pt: "Excluir",
                            fr: "Supprimer",
                            ja: "削除",
                            ko: "삭제",
                            it: "Elimina"
                        ), role: .destructive) {
                            delete(plant)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        L10n.current.tr(
                            zh: "植物已不可用",
                            en: "Plant unavailable",
                            de: "Pflanze nicht verfügbar",
                            es: "Planta no disponible",
                            pt: "Planta indisponível",
                            fr: "Plante indisponible",
                            ja: "植物を利用できません",
                            ko: "식물을 사용할 수 없어요",
                            it: "Pianta non disponibile"
                        ),
                        systemImage: "leaf"
                    )
                }
            }
            .navigationTitle(plants.first?.name ?? L10n.current.tr(
                zh: "管理植物",
                en: "Manage plant",
                de: "Pflanze verwalten",
                es: "Gestionar planta",
                pt: "Gerenciar planta",
                fr: "Gérer la plante",
                ja: "植物を管理",
                ko: "식물 관리",
                it: "Gestisci pianta"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.current.tr(
                        zh: "完成",
                        en: "Done",
                        de: "Fertig",
                        es: "Listo",
                        pt: "Concluído",
                        fr: "Terminé",
                        ja: "完了",
                        ko: "완료",
                        it: "Fatto"
                    ), action: onClose)
                }
            }
        }
    }

    private func archive(_ plant: Plant) {
        let result = MemberCommandExecutor(context: modelContext, services: appServices).archivePlant(
            plant,
            date: Date(),
            note: "zen.plant.archive"
        )
        if result.didPersist { onClose() }
    }

    private func delete(_ plant: Plant) {
        let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
            plant,
            note: "zen.plant.delete"
        )
        if result.didPersist { onClose() }
    }
}

private enum ZenExperienceRoute: Identifiable, Equatable {
    case add(EntityType)
    case human(UUID)
    case pet(UUID)
    case plant(UUID)
    case shop
    case gacha
    case critters
    case analytics
    case personalPlan

    var id: String {
        switch self {
        case let .add(type): "add:\(type.rawValue)"
        case let .human(id): "human:\(id.uuidString)"
        case let .pet(id): "pet:\(id.uuidString)"
        case let .plant(id): "plant:\(id.uuidString)"
        case .shop: "shop"
        case .gacha: "gacha"
        case .critters: "critters"
        case .analytics: "analytics"
        case .personalPlan: "personal-plan"
        }
    }
}
