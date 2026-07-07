//
//  WalkTrackingCard.swift
//  Ohana
//
//  遛狗追踪卡片：地图铺满卡片背景，控制面板以玻璃层叠加。
//

import MapKit
import SwiftData
import SwiftUI

struct WalkTrackingCard: View {
    let pet: Pet
    let allPets: [Pet]
    let allHumans: [Human]
    let snapshot: WalkTrackingSnapshot
    var onCloseSummaryToPetCard: (() -> Void)?
    var onStopWalk: ([Pet], [String]) -> WalkStopRewardSummary
    var onSaveWeeklyGoal: (Double) -> PetWalkGoalCommandResult

    @Environment(AppServices.self) var appServices
    @Environment(\.modelContext) var modelContext
    var mgr: PetWalkingManaging { appServices.walking }
    var locationMgr: LocationProviding { appServices.location }
    @AppStorage("appLanguage") var appLanguage: String = "zh"
    @AppStorage("currentActiveHumanId") var activeHumanId: String = ""
    @AppStorage(RainbowWalkEffectKeys.route) var equipFxRainbowRoute = false
    @AppStorage(RainbowWalkEffectKeys.poop) var equipFxRainbowPoop = false
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared

    @State var showFloatingPoop = false
    @State var showWalkDetail: PetWalkLog? = nil
    @State var showSummaryBack = false
    @State var isClosingSummaryBack = false
    @State var summaryRotation: Double = 0
    @State var showingGoalSetter = false
    @State var goalDraft: Double = 0
    @State var lastStopRewardSummary: WalkStopRewardSummary?
    @State var selectedSharedWalkPetIds: Set<UUID> = []
    @State var selectedSharedWalkExecutorIds: Set<String> = []
    @State var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State var rainbowRoutePhase: CGFloat = 0

    var isActivePet: Bool {
        mgr.currentPet?.id == pet.id || mgr.phase == .idle
    }

    var isWalking: Bool {
        guard isActivePet else { return false }
        switch mgr.phase {
        case .running, .paused: return true
        default: return false
        }
    }

    var isRunningWalk: Bool {
        guard isActivePet else { return false }
        if case .running = mgr.phase { return true }
        return false
    }

    var sameSpeciesWalkPets: [Pet] {
        SharedPetTargetResolver.sameSpeciesTargets(sourcePet: pet, allPets: allPets)
    }

    var selectedWalkTargets: [Pet] {
        let selected = sameSpeciesWalkPets.filter { selectedSharedWalkPetIds.contains($0.id) }
        return SharedPetTargetResolver.normalizedTargets(selected, fallback: pet)
    }

    var activeWalkHumanId: String? {
        guard !activeHumanId.isEmpty,
              allHumans.contains(where: { $0.id.uuidString == activeHumanId }) else {
            return nil
        }
        return activeHumanId
    }

    var selectedWalkExecutorIds: [String] {
        let selected = allHumans
            .map(\.id.uuidString)
            .filter { selectedSharedWalkExecutorIds.contains($0) }
        return SharedCareParticipantIDs.normalized(selected, preferredFirst: activeWalkHumanId)
    }

    var walkClockInterval: TimeInterval {
        guard walkSurfaceGate.allowsRefresh else { return 60 }
        return workloadPolicy.refreshInterval(
            default: 1,
            throttled: 15,
            paused: 60,
            isVisible: isWalking,
            allowDuringActiveWalk: true
        )
    }

    var liveRouteCoordinates: [CLLocationCoordinate2D] {
        let live = routeCoordinates(from: locationMgr.collectedLocations, maxCount: 320)
        guard isWalking, snapshot.hasRecoverableWalkCheckpoint else { return live }
        return snapshot.latestRouteCoordinates + live
    }

    var livePoopMarkers: [WalkPoopMarker] {
        isActivePet ? mgr.activePoopMarkers : []
    }

    var shouldAnimateRainbowWalkEffects: Bool {
        walkSurfaceGate.allowsAmbientMotion
    }

    var walkSurfaceGate: SurfaceActivityGate {
        workloadPolicy.surfaceGate(
            isVisible: isWalking,
            isLive: isActivePet,
            allowsAmbientOptIn: equipFxRainbowRoute || equipFxRainbowPoop,
            allowDuringActiveWalk: true
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                trackingFrontFace
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(summaryRotation < 90 ? 1 : 0)
                    .allowsHitTesting(!showSummaryBack)

                if showSummaryBack || isClosingSummaryBack {
                    walkSummaryBackFace
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(summaryRotation >= 90 ? 1 : 0)
                        .allowsHitTesting(showSummaryBack)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .rotation3DEffect(.degrees(summaryRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if showSummaryBack {
                    summaryMapToolbar
                        .padding(.top, 26)
                        .padding(.trailing, 24)
                        .zIndex(200)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .clipped()
        .sheet(item: $showWalkDetail) { walk in WalkDetailView(walk: walk, pet: pet) }
        .sheet(isPresented: $showingGoalSetter) {
            walkGoalSetterSheet
                .ohanaCompactSheetPresentation(detents: [.height(320)])
        }
        .onChange(of: mgr.showSummary) { _, newVal in
            if newVal, mgr.currentPet?.id == pet.id {
                presentSummaryBack()
                mgr.showSummary = false
            }
        }
        .onChange(of: mgr.phase) { _, newPhase in
            if case .finished = newPhase, mgr.currentPet?.id == pet.id {
                presentSummaryBack()
            } else if case .running = newPhase {
                lastStopRewardSummary = nil
            }
        }
        .onAppear {
            selectedSharedWalkPetIds = SharedPetSelectionMemory.restoredSelection(
                sourcePet: pet,
                scope: "walk.shared",
                candidates: sameSpeciesWalkPets,
                defaultToAll: false
            )
            refreshDefaultWalkExecutors()
            if case .finished = mgr.phase, mgr.currentPet?.id == pet.id {
                presentSummaryBack(animated: false)
            }
            updateRainbowRouteFlow()
        }
        .onChange(of: activeHumanId) { _, _ in refreshDefaultWalkExecutors() }
        .onChange(of: allHumans.map(\.id)) { _, _ in refreshDefaultWalkExecutors() }
        .onChange(of: shouldAnimateRainbowWalkEffects) { _, _ in updateRainbowRouteFlow() }
    }
}

struct WalkMapSnapshotImage: View {
    let data: Data

    @State var image: UIImage?

    var signature: String {
        FocusWalletAvatarCache.signature(for: data)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.arkInk.opacity(0.18)
            }
        }
        .task(id: signature) {
            image = await MapSnapshotImageDecoder.decode(data)
        }
    }
}
