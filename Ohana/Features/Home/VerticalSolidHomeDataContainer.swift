//
//  VerticalSolidHomeDataContainer.swift
//  Ohana
//
//  SwiftData query boundary for verticalSolid home.
//

import SwiftData
import SwiftUI

struct HomeReadModelRefreshKey: Hashable {
    let revisionValue: Int
    let walletProjectionRevisionValue: Int
    let dayToken: Int
    let activeHumanIdRaw: String
    let hiddenPetIDsRaw: String
    let homeCardOrderRaw: String
    let showDummyCards: Bool
    let petBondVaultRevision: Int
    let equippedTitleRaw: String
    let quickActionItemsRaw: String
    let language: String

    static func dayToken(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }
}

struct HomeCreatedEntitySignal: Equatable {
    let entityID: UUID
    let token: UUID

    init(entityID: UUID, token: UUID = UUID()) {
        self.entityID = entityID
        self.token = token
    }
}

struct VerticalSolidHomeDataContainer: View {
    private static let postRevisionRefreshDelayMilliseconds: UInt64 = 260
    private static let postLanguageRefreshDelayMilliseconds: UInt64 = 720

    let onOpenPet: (UUID, PetDetailTab) -> Void
    let onOpenHuman: (UUID) -> Void
    let onOpenPlant: (UUID) -> Void
    let createdEntitySignal: HomeCreatedEntitySignal?
    let onCreatedEntitySignalHandled: (HomeCreatedEntitySignal) -> Void
    let onPresentAccountSwitcher: () -> Void
    let onPresentAddEntity: (EntityType) -> Void
    let onPresentAppSheet: (AppSheetRoute) -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void
    let onPresentCrewRoster: (CrewRosterMode) -> Void
    let onPresentFunctionMenu: (FMDest?) -> Void
    let onPresentHumanWeightQuick: (UUID) -> Void
    let onPresentOasisReward: () -> Void
    let onPresentPetWeightQuick: (UUID) -> Void
    let onPresentQuickMoment: (UUID) -> Void
    let onPresentSettings: () -> Void
    let onPresentStreakDetail: () -> Void
    let onPresentWalk: (UUID) -> Void
    let cardStateResetToken: UUID

    @StateObject private var readModelStore = HomeReadModelStore()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @AppStorage(PetBondVaultStore.revisionKey) private var petBondVaultRevision = 0
    @AppStorage("shop_equipped_title") private var equippedTitleRaw = ""
    @AppStorage("quickActionItems_v2") private var quickActionItemsRaw = ""
    @State private var observedHomeRevision = HomeRevision()
    @State private var observedWalletProjectionRevision = HomeRevision()
    @State private var currentDayToken = HomeReadModelRefreshKey.dayToken(for: Date())
    @State private var refreshKeyStateTask: Task<Void, Never>?
    @State private var languageRefreshTask: Task<Void, Never>?
    @State private var readModelLanguage = AppLanguage.code
    @State private var pendingObservedHomeRevision: HomeRevision?
    @State private var pendingObservedWalletProjectionRevision: HomeRevision?
    @State private var pendingDayTokenRefresh = false

    init(
        onOpenPet: @escaping (UUID, PetDetailTab) -> Void,
        onOpenHuman: @escaping (UUID) -> Void,
        onOpenPlant: @escaping (UUID) -> Void,
        createdEntitySignal: HomeCreatedEntitySignal?,
        onCreatedEntitySignalHandled: @escaping (HomeCreatedEntitySignal) -> Void = { _ in },
        onPresentAccountSwitcher: @escaping () -> Void,
        onPresentAddEntity: @escaping (EntityType) -> Void,
        onPresentAppSheet: @escaping (AppSheetRoute) -> Void,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void,
        onPresentCrewRoster: @escaping (CrewRosterMode) -> Void,
        onPresentFunctionMenu: @escaping (FMDest?) -> Void,
        onPresentHumanWeightQuick: @escaping (UUID) -> Void,
        onPresentOasisReward: @escaping () -> Void,
        onPresentPetWeightQuick: @escaping (UUID) -> Void,
        onPresentQuickMoment: @escaping (UUID) -> Void,
        onPresentSettings: @escaping () -> Void,
        onPresentStreakDetail: @escaping () -> Void,
        onPresentWalk: @escaping (UUID) -> Void,
        cardStateResetToken: UUID
    ) {
        self.onOpenPet = onOpenPet
        self.onOpenHuman = onOpenHuman
        self.onOpenPlant = onOpenPlant
        self.createdEntitySignal = createdEntitySignal
        self.onCreatedEntitySignalHandled = onCreatedEntitySignalHandled
        self.onPresentAccountSwitcher = onPresentAccountSwitcher
        self.onPresentAddEntity = onPresentAddEntity
        self.onPresentAppSheet = onPresentAppSheet
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onPresentCrewRoster = onPresentCrewRoster
        self.onPresentFunctionMenu = onPresentFunctionMenu
        self.onPresentHumanWeightQuick = onPresentHumanWeightQuick
        self.onPresentOasisReward = onPresentOasisReward
        self.onPresentPetWeightQuick = onPresentPetWeightQuick
        self.onPresentQuickMoment = onPresentQuickMoment
        self.onPresentSettings = onPresentSettings
        self.onPresentStreakDetail = onPresentStreakDetail
        self.onPresentWalk = onPresentWalk
        self.cardStateResetToken = cardStateResetToken
    }

    var body: some View {
        let payload = readModelStore.payload
        VerticalSolidHomeView(
            onOpenPet: onOpenPet,
            onOpenHuman: onOpenHuman,
            onOpenPlant: onOpenPlant,
            createdEntitySignal: createdEntitySignal,
            onCreatedEntitySignalHandled: onCreatedEntitySignalHandled,
            onPresentAccountSwitcher: onPresentAccountSwitcher,
            onPresentAddEntity: onPresentAddEntity,
            onPresentAppSheet: onPresentAppSheet,
            onPresentCoconutLog: onPresentCoconutLog,
            onPresentCrewRoster: onPresentCrewRoster,
            onPresentFunctionMenu: onPresentFunctionMenu,
            onPresentHumanWeightQuick: onPresentHumanWeightQuick,
            onPresentOasisReward: onPresentOasisReward,
            onPresentPetWeightQuick: onPresentPetWeightQuick,
            onPresentQuickMoment: onPresentQuickMoment,
            onPresentSettings: onPresentSettings,
            onPresentStreakDetail: onPresentStreakDetail,
            onPresentWalk: onPresentWalk,
            cardStateResetToken: cardStateResetToken,
            payload: payload
        )
        .task(id: refreshKey) {
            readModelStore.requestRefresh(
                context: modelContext,
                activeHumanIdRaw: activeHumanIdRaw,
                hiddenPetIDsRaw: hiddenPetIDsRaw,
                homeCardOrderRaw: homeCardOrderRaw,
                showDummyCards: showDummyCards,
                petBondVaultRevision: petBondVaultRevision,
                equippedTitleRaw: equippedTitleRaw,
                quickActionItemsRaw: quickActionItemsRaw,
                language: readModelLanguage,
                externalRevision: observedHomeRevision,
                force: !payload.snapshot.isReady
            )
        }
        .onAppear {
            scheduleRefreshKeyStateSync(
                revision: appServices.domainRevisions.homeRevision,
                walletProjectionRevision: appServices.domainRevisions.walletProjectionRevision,
                refreshDayToken: true
            )
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            scheduleRefreshKeyStateSync(revision: revision, walletProjectionRevision: nil, refreshDayToken: false)
        }
        .onReceive(appServices.domainRevisions.walletProjectionUpdates) { revision in
            scheduleRefreshKeyStateSync(revision: nil, walletProjectionRevision: revision, refreshDayToken: false)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            scheduleRefreshKeyStateSync(
                revision: appServices.domainRevisions.homeRevision,
                walletProjectionRevision: appServices.domainRevisions.walletProjectionRevision,
                refreshDayToken: true
            )
        }
        .onChange(of: appLanguage) { _, newValue in
            scheduleReadModelLanguageSync(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            scheduleRefreshKeyStateSync(revision: nil, walletProjectionRevision: nil, refreshDayToken: true)
        }
        .task(id: currentDayToken) {
            await updateDayTokenAfterNextMidnight()
        }
        .onDisappear {
            refreshKeyStateTask?.cancel()
            refreshKeyStateTask = nil
            languageRefreshTask?.cancel()
            languageRefreshTask = nil
            readModelStore.cancel()
        }
    }

    private var refreshKey: HomeReadModelRefreshKey {
        HomeReadModelRefreshKey(
            revisionValue: observedHomeRevision.value,
            walletProjectionRevisionValue: observedWalletProjectionRevision.value,
            dayToken: currentDayToken,
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            petBondVaultRevision: petBondVaultRevision,
            equippedTitleRaw: equippedTitleRaw,
            quickActionItemsRaw: quickActionItemsRaw,
            language: readModelLanguage
        )
    }

    private func scheduleReadModelLanguageSync(_ rawLanguage: String) {
        let normalized = AppLanguage.normalize(rawLanguage)
        guard readModelLanguage != normalized else {
            languageRefreshTask?.cancel()
            languageRefreshTask = nil
            return
        }

        languageRefreshTask?.cancel()
        languageRefreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: Self.postLanguageRefreshDelayMilliseconds) {
            guard readModelLanguage != normalized else {
                languageRefreshTask = nil
                return
            }
            readModelLanguage = normalized
            languageRefreshTask = nil
        }
    }

    private func refreshCurrentDayToken() {
        let token = HomeReadModelRefreshKey.dayToken(for: Date())
        guard currentDayToken != token else { return }
        currentDayToken = token
    }

    private func setObservedHomeRevision(_ revision: HomeRevision) {
        guard observedHomeRevision != revision else { return }
        observedHomeRevision = revision
    }

    private func setObservedWalletProjectionRevision(_ revision: HomeRevision) {
        guard observedWalletProjectionRevision != revision else { return }
        observedWalletProjectionRevision = revision
    }

    private func scheduleRefreshKeyStateSync(
        revision: HomeRevision?,
        walletProjectionRevision: HomeRevision?,
        refreshDayToken: Bool
    ) {
        if let revision {
            pendingObservedHomeRevision = revision
        }
        if let walletProjectionRevision {
            pendingObservedWalletProjectionRevision = walletProjectionRevision
        }
        pendingDayTokenRefresh = pendingDayTokenRefresh || refreshDayToken
        guard refreshKeyStateTask == nil else { return }
        let delayMilliseconds: UInt64 = pendingObservedHomeRevision == nil && pendingObservedWalletProjectionRevision == nil
            ? 0
            : Self.postRevisionRefreshDelayMilliseconds
        refreshKeyStateTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            let revision = pendingObservedHomeRevision
            let walletProjectionRevision = pendingObservedWalletProjectionRevision
            let shouldRefreshDayToken = pendingDayTokenRefresh
            pendingObservedHomeRevision = nil
            pendingObservedWalletProjectionRevision = nil
            pendingDayTokenRefresh = false

            if let revision {
                setObservedHomeRevision(revision)
            }
            if let walletProjectionRevision {
                setObservedWalletProjectionRevision(walletProjectionRevision)
            }
            if shouldRefreshDayToken {
                refreshCurrentDayToken()
            }
            refreshKeyStateTask = nil
        }
    }

    private func updateDayTokenAfterNextMidnight() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? Date(timeIntervalSinceNow: 24 * 60 * 60)
        let nanoseconds = UInt64(max(1.0, next.timeIntervalSinceNow) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        guard !Task.isCancelled else { return }
        await MainActor.run {
            refreshCurrentDayToken()
        }
    }
}
