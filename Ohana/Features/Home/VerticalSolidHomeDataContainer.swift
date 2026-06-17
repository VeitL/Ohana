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
    let dayToken: Int
    let activeHumanIdRaw: String
    let hiddenPetIDsRaw: String
    let homeCardOrderRaw: String
    let showDummyCards: Bool
    let petBondVaultRevision: Int
    let equippedTitleRaw: String
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
    let onPresentOasisReward: () -> Void
    let onPresentQuickMoment: (UUID) -> Void
    let onPresentSettings: () -> Void
    let onPresentStreakDetail: () -> Void
    let onPresentWalk: (UUID) -> Void

    @StateObject private var readModelStore = HomeReadModelStore()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenPetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @AppStorage("debugShowDummyCards") private var showDummyCards = false
    @AppStorage(PetBondVaultStore.revisionKey) private var petBondVaultRevision = 0
    @AppStorage("shop_equipped_title") private var equippedTitleRaw = ""
    @State private var observedHomeRevision = HomeRevision()
    @State private var currentDayToken = HomeReadModelRefreshKey.dayToken(for: Date())
    @State private var refreshKeyStateTask: Task<Void, Never>?
    @State private var pendingObservedHomeRevision: HomeRevision?
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
        onPresentOasisReward: @escaping () -> Void,
        onPresentQuickMoment: @escaping (UUID) -> Void,
        onPresentSettings: @escaping () -> Void,
        onPresentStreakDetail: @escaping () -> Void,
        onPresentWalk: @escaping (UUID) -> Void
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
        self.onPresentOasisReward = onPresentOasisReward
        self.onPresentQuickMoment = onPresentQuickMoment
        self.onPresentSettings = onPresentSettings
        self.onPresentStreakDetail = onPresentStreakDetail
        self.onPresentWalk = onPresentWalk
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
            onPresentOasisReward: onPresentOasisReward,
            onPresentQuickMoment: onPresentQuickMoment,
            onPresentSettings: onPresentSettings,
            onPresentStreakDetail: onPresentStreakDetail,
            onPresentWalk: onPresentWalk,
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
                language: appLanguage,
                externalRevision: observedHomeRevision,
                force: !payload.snapshot.isReady
            )
        }
        .onAppear {
            scheduleRefreshKeyStateSync(
                revision: appServices.domainRevisions.homeRevision,
                refreshDayToken: true
            )
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            scheduleRefreshKeyStateSync(revision: revision, refreshDayToken: false)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            scheduleRefreshKeyStateSync(
                revision: appServices.domainRevisions.homeRevision,
                refreshDayToken: true
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            scheduleRefreshKeyStateSync(revision: nil, refreshDayToken: true)
        }
        .task(id: currentDayToken) {
            await updateDayTokenAfterNextMidnight()
        }
        .onDisappear {
            refreshKeyStateTask?.cancel()
            refreshKeyStateTask = nil
            readModelStore.cancel()
        }
    }

    private var refreshKey: HomeReadModelRefreshKey {
        HomeReadModelRefreshKey(
            revisionValue: observedHomeRevision.value,
            dayToken: currentDayToken,
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            petBondVaultRevision: petBondVaultRevision,
            equippedTitleRaw: equippedTitleRaw,
            language: appLanguage
        )
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

    private func scheduleRefreshKeyStateSync(
        revision: HomeRevision?,
        refreshDayToken: Bool
    ) {
        if let revision {
            pendingObservedHomeRevision = revision
        }
        pendingDayTokenRefresh = pendingDayTokenRefresh || refreshDayToken
        guard refreshKeyStateTask == nil else { return }
        let delayMilliseconds: UInt64 = pendingObservedHomeRevision == nil ? 0 : Self.postRevisionRefreshDelayMilliseconds
        refreshKeyStateTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            let revision = pendingObservedHomeRevision
            let shouldRefreshDayToken = pendingDayTokenRefresh
            pendingObservedHomeRevision = nil
            pendingDayTokenRefresh = false

            if let revision {
                setObservedHomeRevision(revision)
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
