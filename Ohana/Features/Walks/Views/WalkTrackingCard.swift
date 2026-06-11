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
    let snapshot: WalkTrackingSnapshot
    var onCloseSummaryToPetCard: (() -> Void)?
    var onStopWalk: ([Pet]) -> Void
    var onSaveWeeklyGoal: (Double) -> Void

    @Environment(AppServices.self) var appServices
    var mgr: PetWalkingManaging { appServices.walking }
    var locationMgr: LocationProviding { appServices.location }
    @AppStorage("appLanguage") var appLanguage: String = "zh"
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
    @State var selectedSharedWalkPetIds: Set<UUID> = []
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
        routeCoordinates(from: locationMgr.collectedLocations, maxCount: 320)
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

                walkSummaryBackFace
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(summaryRotation >= 90 ? 1 : 0)
                    .allowsHitTesting(showSummaryBack)
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
            }
        }
        .onAppear {
            selectedSharedWalkPetIds = SharedPetSelectionMemory.restoredSelection(
                sourcePet: pet,
                scope: "walk.shared",
                candidates: sameSpeciesWalkPets,
                defaultToAll: false
            )
            if case .finished = mgr.phase, mgr.currentPet?.id == pet.id {
                presentSummaryBack(animated: false)
            }
            updateRainbowRouteFlow()
        }
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
