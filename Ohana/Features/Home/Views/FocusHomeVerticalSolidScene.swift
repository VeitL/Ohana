//
//  FocusHomeVerticalSolidScene.swift
//  Ohana
//
//  Real-data portrait solid card scene for the selectable home style.
//

import SwiftUI
import UIKit

struct FocusHomeVerticalSolidScene<QuickActions: View, ContextMenuContent: View>: View {
    let cards: [FocusCard]
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let selectedCardId: UUID?
    var preparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    var heroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    let progress: CGFloat
    var heroDirection: Int = 0
    var arrivingCardId: UUID?
    let reduceMotion: Bool
    let localization: L10n
    let allowsAmbientFloat: Bool
    var isVisible: Bool = true
    var walkPresentationRevision: Int = 0
    var embedsQuickActionsInCard: Bool = false
    var freezesInactiveCollapsedGeometryDuringHero: Bool = false
    var externalInactiveCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = [:]
    var externalInactiveCollapsedGeometrySelectionId: UUID?
    var collapsedTopInset: CGFloat = 0
    var collapsedVerticalBias: CGFloat = FocusHomeVerticalSolidCollapsedLayoutPolicy.defaultVerticalBias
    var collapsedLayoutMode: FocusHomeVerticalSolidCollapsedLayoutMode = .balanced
    var expandedVerticalPlacement: FocusHomeVerticalSolidExpandedVerticalPlacement = .sceneCenter
    var avatarCacheRevision: Int = 0
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusHomeVerticalSolidHeroSnapshot) -> Void
    let onCollapse: () -> Void
    var onInactiveCollapsedGeometryFrozen: ([UUID: FocusHomeInactiveHeroCollapsedGeometry], UUID) -> Void = { _, _ in }
    let onWalkCardMinimizeToFloatingControl: () -> Void
    let onOpenDetails: (FocusCard) -> Void

    @Environment(AppServices.self) private var appServices
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var ambientFloatPhase = false
    @State private var ambientFloatResumeProgress: CGFloat = 0
    @State private var ambientFloatCycleTask: Task<Void, Never>?
    @State private var animatedArrivalCardId: UUID?
    @State private var arrivalProgress: CGFloat = 1
    @State private var arrivalCleanupTask: Task<Void, Never>?
    @State private var inactiveHeroCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = [:]
    @State private var inactiveHeroCollapsedGeometrySelectionId: UUID?
    @State private var expandedInteractionMountedCardId: UUID?
    @State private var expandedInteractionReveal: CGFloat = 0
    @State private var expandedInteractionRevealTask: Task<Void, Never>?
    @GestureState private var expandedDragY: CGFloat = 0

    private var l: L10n { localization }

    private var selectedCard: FocusCard? {
        if let activeHeroSnapshot {
            return activeHeroSnapshot.card
        }

        return selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    private var activeHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot? {
        guard let selectedCardId else {
            return nil
        }

        if let heroSnapshot,
           heroSnapshot.card.id == selectedCardId {
            return heroSnapshot
        }

        if let prepared = preparedHeroSnapshots[selectedCardId] {
            return prepared
        }

        guard let index = cards.firstIndex(where: { $0.id == selectedCardId }) else {
            return nil
        }

        let card = cards[index]
        return FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private var isExpandedInteractionReady: Bool {
        FocusHomeExpandedInteractionPolicy.isExpandedControlReady(
            selectedCardId: selectedCardId,
            heroDirection: heroDirection,
            progress: progress
        )
    }

    private var isExpandedInteractionMounted: Bool {
        guard let selectedCardId else { return false }
        return expandedInteractionMountedCardId == selectedCardId || isExpandedInteractionReady
    }

    private var isExpandedCollapseReady: Bool {
        FocusHomeExpandedInteractionPolicy.isExpandedCollapseReady(
            selectedCardId: selectedCardId,
            progress: progress
        )
    }

    private var canHitCollapsedCards: Bool {
        FocusHomeExpandedInteractionPolicy.canHitCollapsedCards(
            selectedCardId: selectedCardId,
            heroDirection: heroDirection,
            progress: progress
        )
    }

    var body: some View {
        GeometryReader { geo in
            sceneContent(in: geo)
            .onAppear {
                updateAmbientFloatCycle()
                prepareArrivalIfNeeded()
                updateExpandedInteractionMount()
                updateInactiveHeroCollapsedGeometry(
                    size: geo.size,
                    selectedCardId: selectedCardId
                )
            }
            .onChange(of: selectedCardId) { _, newValue in
                updateInactiveHeroCollapsedGeometry(
                    size: geo.size,
                    selectedCardId: newValue
                )
                updateAmbientFloatCycle()
            }
            .onChange(of: expandedInteractionLifecycleKey) { _, _ in
                updateExpandedInteractionMount()
            }
            .onChange(of: isVisible) { _, _ in
                updateAmbientFloatCycle()
            }
            .onChange(of: canFloatCards) { _, _ in
                updateAmbientFloatCycle()
            }
            .onChange(of: arrivalKey) { _, _ in
                prepareArrivalIfNeeded()
            }
            .onDisappear {
                stopAmbientFloatCycle()
                arrivalCleanupTask?.cancel()
                arrivalCleanupTask = nil
                animatedArrivalCardId = nil
                arrivalProgress = 1
                expandedInteractionRevealTask?.cancel()
                expandedInteractionRevealTask = nil
                expandedInteractionMountedCardId = nil
                expandedInteractionReveal = 0
            }
        }
    }

    private func sceneContent(in geo: GeometryProxy) -> some View {
        let visibleCenterX = visibleCenterX(in: geo)
        return ZStack {
            if canHitCollapsedCards {
                collapsedHitLayer(in: geo.size)
                    .zIndex(FocusHomeCollapsedHitLayerPolicy.zIndex(selectedCardId: selectedCardId))
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onCollapse() }
                    .zIndex(1)
            }

            if let selectedCard, !embedsQuickActionsInCard {
                if walkTrackingPet(for: selectedCard, isSelected: true) == nil {
                    quickActionLayer(for: selectedCard, in: geo.size, visibleCenterX: visibleCenterX)
                        .zIndex(32)
                }
            }

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cardLayer(for: card, index: index, in: geo.size, visibleCenterX: visibleCenterX)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private var arrivalKey: String {
        [
            arrivingCardId?.uuidString ?? "",
            cards.map(\.id.uuidString).joined(separator: "|"),
            isVisible ? "visible" : "hidden"
        ].joined(separator: "#")
    }

    private var expandedInteractionLifecycleKey: String {
        [
            selectedCardId?.uuidString ?? "none",
            "\(heroDirection)",
            isExpandedInteractionReady ? "ready" : "not-ready",
            reduceMotion ? "reduced" : "full"
        ].joined(separator: "#")
    }

    private func prepareArrivalIfNeeded() {
        guard isVisible,
              selectedCardId == nil,
              let arrivingCardId,
              cards.contains(where: { $0.id == arrivingCardId }),
              animatedArrivalCardId != arrivingCardId else { return }
        arrivalCleanupTask?.cancel()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedArrivalCardId = arrivingCardId
            arrivalProgress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 40) {
            guard animatedArrivalCardId == arrivingCardId else { return }
            withAnimation(reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero) {
                arrivalProgress = 1
            }
        }
        arrivalCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 980) {
            guard animatedArrivalCardId == arrivingCardId else { return }
            animatedArrivalCardId = nil
            arrivalProgress = 1
            arrivalCleanupTask = nil
        }
    }

    private func updateInactiveHeroCollapsedGeometry(
        size: CGSize,
        selectedCardId: UUID?
    ) {
        guard freezesInactiveCollapsedGeometryDuringHero else { return }
        guard let selectedCardId else {
            setInactiveHeroCollapsedGeometry([:], selectionId: nil)
            return
        }
        guard inactiveHeroCollapsedGeometrySelectionId != selectedCardId
                || inactiveHeroCollapsedGeometry.isEmpty else { return }

        setInactiveHeroCollapsedGeometry(
            inactiveCollapsedGeometry(size: size, selectedCardId: selectedCardId),
            selectionId: selectedCardId
        )
    }

    private func inactiveCollapsedGeometry(
        size: CGSize,
        selectedCardId: UUID,
        includesAmbientFloat: Bool = false
    ) -> [UUID: FocusHomeInactiveHeroCollapsedGeometry] {
        Dictionary(
            uniqueKeysWithValues: cards.enumerated()
                .filter { _, card in card.id != selectedCardId }
                .map { index, card in
                    let frame = collapsedFrame(index: index, count: cards.count, in: size)
                    let floating = includesAmbientFloat
                        ? floatingTransform(index: index, isSelected: false)
                        : (x: 0, y: 0, rotation: 0)
                    return (
                        card.id,
                        FocusHomeInactiveHeroCollapsedGeometry(
                            frame: frame.offsetBy(dx: floating.x, dy: floating.y),
                            rotation: collapsedRotation(index: index) + floating.rotation
                        )
                    )
                }
        )
    }

    private func setInactiveHeroCollapsedGeometry(
        _ next: [UUID: FocusHomeInactiveHeroCollapsedGeometry],
        selectionId: UUID?
    ) {
        guard inactiveHeroCollapsedGeometry != next
                || inactiveHeroCollapsedGeometrySelectionId != selectionId else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            inactiveHeroCollapsedGeometry = next
            inactiveHeroCollapsedGeometrySelectionId = selectionId
        }
        if let selectionId {
            onInactiveCollapsedGeometryFrozen(next, selectionId)
        }
    }

    private func inactiveHeroCollapsedGeometry(for cardId: UUID) -> FocusHomeInactiveHeroCollapsedGeometry? {
        FocusHomeInactiveHeroGeometrySourcePolicy.geometry(
            cardId: cardId,
            selectedCardId: selectedCardId,
            local: inactiveHeroCollapsedGeometry,
            localSelectionId: inactiveHeroCollapsedGeometrySelectionId,
            external: externalInactiveCollapsedGeometry,
            externalSelectionId: externalInactiveCollapsedGeometrySelectionId,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero
        )
    }

    private func arrivalTransform(for card: FocusCard) -> (scale: CGFloat, rotation: Double, flip: Double, y: CGFloat, opacity: Double) {
        guard card.id == animatedArrivalCardId, selectedCardId == nil, !reduceMotion else {
            return (1, 0, 0, 0, 1)
        }
        let p = eased(arrivalProgress)
        return (
            scale: lerp(HomeJoinHandoffMotion.scale, 1, p),
            rotation: Double(lerp(HomeJoinHandoffMotion.rotation, 0, p)),
            flip: Double(lerp(HomeJoinHandoffMotion.flip, 0, p)),
            y: lerp(HomeJoinHandoffMotion.y, 0, p),
            opacity: Double(lerp(HomeJoinHandoffMotion.opacity, 1, p))
        )
    }

    private func visibleCenterX(in geo: GeometryProxy) -> CGFloat {
        geo.size.width / 2
    }

    private func cardLayer(for card: FocusCard, index: Int, in size: CGSize, visibleCenterX: CGFloat) -> some View {
        let isSelected = card.id == selectedCardId
        let motionSnapshot = isSelected ? activeHeroSnapshot : nil
        let renderCard = motionSnapshot?.card ?? card
        let renderIndex = motionSnapshot?.index ?? index
        let isExpandedSurface = isSelected
        let frame = frame(
            for: renderCard,
            index: renderIndex,
            snapshot: motionSnapshot,
            in: size,
            visibleCenterX: visibleCenterX
        )
        let arrival = arrivalTransform(for: renderCard)
        let dragY = isExpandedSurface ? max(0, expandedDragY) : 0
        let frozenInactiveGeometry = isExpandedSurface ? nil : inactiveHeroCollapsedGeometry(for: renderCard.id)
        let freezesInactiveLayer = FocusHomeInactiveHeroLayerPolicy.disablesImplicitAnimations(
            selectedCardId: selectedCardId,
            cardId: renderCard.id,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero
        )
        let floating = frozenInactiveGeometry == nil
            ? floatingTransform(index: renderIndex, isSelected: isSelected)
            : (x: 0, y: 0, rotation: 0)
        let rotation = rotation(
            for: renderCard,
            index: renderIndex,
            snapshot: motionSnapshot,
            isSelected: isExpandedSurface
        ) + floating.rotation + arrival.rotation
        let scale = (isExpandedSurface ? max(0.94, 1 - dragY / 1400) : inactiveScale(for: renderCard)) * arrival.scale
        let opacity = inactiveOpacity(for: renderCard) * arrival.opacity
        let zIndex = zIndex(for: renderIndex, isSelected: isSelected)
        let visualProgress = isExpandedSurface ? progress : 0
        let cornerRadius = lerp(FocusHomeVerticalSolidCollapsedLayoutPolicy.cardCornerRadius, 42, eased(visualProgress))
        let frozenAvatarSource = motionSnapshot?.avatarSource ?? preparedHeroSnapshots[card.id]?.avatarSource
            ?? (selectedCardId == nil ? nil : FocusHomeFrozenAvatarSource.cached(for: renderCard))
        let walkTrackingPet = isExpandedInteractionMounted ? walkTrackingPet(for: renderCard, isSelected: isExpandedSurface) : nil
        let embeddedQuickActionsMounted = FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            isExpandedInteractionMounted: isExpandedInteractionMounted
        )
        let embeddedQuickActionReveal = FocusHomeEmbeddedQuickActionThawPolicy.reveal(
            isMounted: embeddedQuickActionsMounted,
            postHeroReveal: expandedInteractionReveal
        )
        let embeddedQuickActionsReady = FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionMounted: isExpandedInteractionMounted,
            reveal: embeddedQuickActionReveal
        )
        let showsEmbeddedQuickActions = FocusHomeEmbeddedQuickActionPresentationPolicy.isVisible(
            embedsQuickActionsInCard: embedsQuickActionsInCard,
            isExpandedSurface: isExpandedSurface,
            hasWalkTrackingCard: walkTrackingPet != nil,
            isMounted: embeddedQuickActionsMounted
        )

        return cardTapLayer(
            FocusHomeWalkCardFlip(
                walkPet: walkTrackingPet,
                reduceMotion: reduceMotion,
                walkCardPadding: 10,
                retainsWalkPetDuringClose: isExpandedInteractionReady,
                onMinimizeToFloatingWalkControl: onWalkCardMinimizeToFloatingControl
            ) {
                ZStack(alignment: .bottom) {
                    FocusHomeVerticalSolidCardSurface(
                        card: renderCard,
                        progress: visualProgress,
                        reduceMotion: reduceMotion,
                        localization: localization,
                        frozenAvatarSource: frozenAvatarSource,
                        allowsLiveAvatarFallback: selectedCardId == nil && motionSnapshot == nil
                    )

                    if embedsQuickActionsInCard,
                       isExpandedInteractionReady,
                       FocusHomeEmbeddedCardCollapseHitPolicy.isMounted(
                           isExpandedSurface: isExpandedSurface,
                           hasWalkTrackingCard: walkTrackingPet != nil
                       ) {
                        embeddedCardCollapseHitLayer(
                            for: renderCard,
                            frame: frame,
                            protectsQuickActionDock: FocusHomeEmbeddedCardCollapseHitPolicy.protectsQuickActionDock(
                                quickActionsAreVisible: showsEmbeddedQuickActions
                            )
                        )
                            .zIndex(10)
                    }

                    if showsEmbeddedQuickActions {
                        embeddedQuickActionLayer(
                            for: renderCard,
                            frame: frame,
                            reveal: embeddedQuickActionReveal,
                            isReady: embeddedQuickActionsReady
                        )
                        .zIndex(24)
                    }

                    if showsDetailButton(
                        for: renderCard,
                        isExpandedSurface: isExpandedSurface,
                        isExpandedControlReady: isExpandedInteractionReady,
                        walkTrackingPet: walkTrackingPet
                    ) {
                        expandedDetailButton(for: renderCard, frame: frame, reveal: embeddedQuickActionReveal)
                            .zIndex(16)
                    }
                }
            }
            .id(walkTrackingIdentity(for: renderCard, walkPet: walkTrackingPet))
            .frame(width: frame.width, height: frame.height)
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(.degrees(arrival.flip), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: frame.midX + floating.x, y: frame.midY + dragY + floating.y + arrival.y)
            .zIndex(zIndex)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contextMenu { contextMenu(renderCard) },
            isExpandedSurface: isExpandedSurface,
            walkTrackingPet: walkTrackingPet
        )
        .simultaneousGesture(collapseDragGesture(isEnabled: isExpandedSurface && isExpandedCollapseReady && walkTrackingPet == nil))
        .allowsHitTesting(isExpandedSurface)
        .accessibilityHidden(selectedCardId != nil && !isExpandedSurface)
        .animation(FocusHomeAmbientFloatPolicy.phaseAnimation, value: ambientFloatPhase)
        .animation(FocusHomeAmbientFloatPolicy.resumeAnimation, value: ambientFloatResumeProgress)
        .transaction { transaction in
            guard freezesInactiveLayer else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    @ViewBuilder
    private func cardTapLayer(
        _ content: some View,
        isExpandedSurface: Bool,
        walkTrackingPet: Pet?
    ) -> some View {
        if embedsQuickActionsInCard {
            content
        } else {
            content
                .onTapGesture {
                    guard walkTrackingPet == nil else { return }
                    handleCardTap(isSelected: isExpandedSurface)
                }
        }
    }

    private func walkTrackingPet(for card: FocusCard, isSelected: Bool) -> Pet? {
        guard isSelected,
              !card.isHuman,
              appServices.walking.isWalkCardExpandedSurfaceVisible,
              let walkingPet = appServices.walking.currentPet,
              walkingPet.id == card.id,
              !walkingPet.hasPassedAway else {
            return nil
        }

        switch appServices.walking.phase {
        case .running, .paused, .finished:
            return walkingPet
        case .idle:
            return nil
        }
    }

    private func walkTrackingIdentity(for card: FocusCard, walkPet: Pet?) -> String {
        FocusHomeWalkCardIdentityPolicy.identity(
            cardID: card.id,
            walkPetID: walkPet?.id,
            phase: appServices.walking.phase,
            presentationRevision: walkPresentationRevision
        )
    }

    private func handleCardTap(isSelected: Bool) {
        guard isSelected else { return }
        onCollapse()
    }

    private var canFloatCards: Bool {
        surfaceGate.allowsAmbientMotion
    }

    private var surfaceGate: SurfaceActivityGate {
        workloadPolicy.surfaceGate(
            isVisible: FocusHomeAmbientFloatPolicy.isSurfaceVisibleForAmbient(
                isVisible: isVisible,
                selectedCardId: selectedCardId,
                progress: progress
            ),
            isCovered: FocusHomeAmbientFloatPolicy.isSurfaceCovered(
                selectedCardId: selectedCardId,
                progress: progress
            ),
            isLive: isVisible,
            allowsAmbientOptIn: FocusHomeAmbientFloatPolicy.allowsAmbientOptIn(
                isEnabled: allowsAmbientFloat,
                reduceMotion: reduceMotion
            )
        )
    }

    private func updateAmbientFloatCycle() {
        guard canFloatCards else {
            stopAmbientFloatCycle()
            return
        }
        startAmbientFloatCycleIfNeeded()
    }

    private func startAmbientFloatCycleIfNeeded() {
        if ambientFloatResumeProgress < 1 {
            withAnimation(FocusHomeAmbientFloatPolicy.resumeAnimation) {
                ambientFloatResumeProgress = 1
            }
        }
        guard ambientFloatCycleTask == nil else { return }
        ambientFloatCycleTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: FocusHomeAmbientFloatPolicy.phaseDurationNanoseconds)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                withAnimation(FocusHomeAmbientFloatPolicy.phaseAnimation) {
                    ambientFloatPhase.toggle()
                }
            }
        }
    }

    private func stopAmbientFloatCycle() {
        ambientFloatCycleTask?.cancel()
        ambientFloatCycleTask = nil
        guard ambientFloatResumeProgress != 0 else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            ambientFloatResumeProgress = 0
        }
    }

    private func quickActionLayer(for card: FocusCard, in size: CGSize, visibleCenterX: CGFloat) -> some View {
        let frame = expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX)
        let reveal = reduceMotion ? 1 : smooth(progress, 0.42, 0.72)
        let quickHeight = CGFloat(132)
        let width = min(size.width - 18, 380)
        let y = min(size.height - safeBottom - 122, frame.maxY + 92)
        return FocusHomeVerticalSolidQuickActionLayer(
            content: quickActions(card),
            width: width,
            height: quickHeight,
            reveal: reveal,
            isReady: FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
                isExpandedInteractionMounted: isExpandedInteractionMounted,
                reveal: reveal
            )
        )
        .position(x: frame.midX, y: y)
    }

    private func embeddedQuickActionLayer(
        for card: FocusCard,
        frame: CGRect,
        reveal: CGFloat,
        isReady: Bool
    ) -> some View {
        let dockWidth = max(0, frame.width - 18)
        let dockHeight = embeddedQuickActionDockHeight(for: frame)
        return FocusHomeVerticalSolidQuickActionLayer(
            content: quickActions(card),
            width: dockWidth,
            height: dockHeight,
            reveal: reveal,
            isReady: isReady
        )
        .padding(.horizontal, 11)
        .padding(.bottom, 8)
        .offset(y: (1 - reveal) * 18)
        .zIndex(12)
    }

    private func updateExpandedInteractionMount() {
        expandedInteractionRevealTask?.cancel()
        expandedInteractionRevealTask = nil

        guard let selectedCardId else {
            resetExpandedInteractionMount()
            return
        }

        if isExpandedInteractionReady {
            setExpandedInteractionMountedCardId(selectedCardId)
            setExpandedInteractionReveal(1)
            return
        }

        guard heroDirection > 0 else {
            resetExpandedInteractionMount()
            return
        }

        let mountedCardId = selectedCardId
        resetExpandedInteractionMount()
        expandedInteractionRevealTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: FocusHomePostHeroControlRevealPolicy.preloadDelayMilliseconds(reduceMotion: reduceMotion)
        ) {
            guard selectedCardId == mountedCardId,
                  heroDirection > 0 else {
                expandedInteractionRevealTask = nil
                return
            }

            setExpandedInteractionMountedCardId(mountedCardId)
            guard !reduceMotion else {
                setExpandedInteractionReveal(1)
                expandedInteractionRevealTask = nil
                return
            }

            withAnimation(FocusHomePostHeroControlRevealPolicy.animation) {
                expandedInteractionReveal = 1
            }

            expandedInteractionRevealTask = nil
        }
    }

    private func resetExpandedInteractionMount() {
        setExpandedInteractionMountedCardId(nil)
        setExpandedInteractionReveal(0)
    }

    private func setExpandedInteractionMountedCardId(_ cardId: UUID?) {
        guard expandedInteractionMountedCardId != cardId else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            expandedInteractionMountedCardId = cardId
        }
    }

    private func setExpandedInteractionReveal(_ value: CGFloat) {
        guard expandedInteractionReveal != value else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            expandedInteractionReveal = value
        }
    }

    private func embeddedCardCollapseHitLayer(
        for card: FocusCard,
        frame: CGRect,
        protectsQuickActionDock: Bool
    ) -> some View {
        let hitHeight = FocusHomeEmbeddedCardCollapseHitPolicy.hitHeight(
            frameHeight: frame.height,
            quickActionDockHeight: embeddedQuickActionDockHeight(for: frame),
            protectsQuickActionDock: protectsQuickActionDock
        )

        return Rectangle()
            .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible expanded card collapse hit zone without covering embedded actions
            .contentShape(Rectangle())
            .frame(width: frame.width, height: hitHeight)
            .offset(y: -(frame.height - hitHeight))
            .onTapGesture {
                OhanaFeedback.light()
                onCollapse()
            }
            .accessibilityLabel(card.name)
            .accessibilityIdentifier(expandedCollapseAccessibilityIdentifier(for: card))
            .accessibilityHint(l.tr(
                zh: "点击返回首页",
                en: "Tap to return home",
                de: "Tippen, um zur Startseite zurückzukehren"
            ))
            .accessibilityAddTraits(.isButton)
    }

    private func showsDetailButton(
        for card: FocusCard,
        isExpandedSurface: Bool,
        isExpandedControlReady: Bool,
        walkTrackingPet: Pet?
    ) -> Bool {
        isExpandedSurface
            && isExpandedControlReady
            && walkTrackingPet == nil
            && !card.isElectronicPet
    }

    private func expandedDetailButton(for card: FocusCard, frame: CGRect, reveal: CGFloat) -> some View {
        VStack {
            HStack {
                Spacer(minLength: 0)
                Button {
                    OhanaFeedback.light()
                    onOpenDetails(card)
                } label: {
                    Image(systemName: detailButtonIcon(for: card))
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.arkInk.opacity(0.42))
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.goCardWhite.opacity(0.28), lineWidth: 1)
                                }
                        )
                        .shadow(color: Color.arkInk.opacity(0.24), radius: 10, x: 0, y: 6) // ui-v4: allow floating detail button depth over saturated member card
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(detailButtonAccessibilityLabel(for: card))
                .accessibilityIdentifier(expandedDetailAccessibilityIdentifier(for: card))
                .accessibilityHint(l.tr(
                    zh: "打开这张卡片的资料页",
                    en: "Open this card's detail page",
                    de: "Detailseite dieser Karte öffnen"
                ))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
        .padding(.trailing, 14)
        .frame(width: frame.width, height: frame.height, alignment: .topTrailing)
        .opacity(Double(reveal))
        .offset(y: -(1 - reveal) * FocusHomePostHeroControlRevealPolicy.detailButtonOffset)
        .allowsHitTesting(FocusHomeExpandedInteractionPolicy.isDetailButtonInteractive(
            isExpandedInteractionMounted: isExpandedInteractionMounted,
            reveal: reveal
        ))
    }

    private func detailButtonIcon(for card: FocusCard) -> String {
        if card.isPlant { return "leaf.circle.fill" }
        return card.isHuman ? "person.crop.circle.fill" : "pawprint.circle.fill"
    }

    private func detailButtonAccessibilityLabel(for card: FocusCard) -> String {
        if card.isPlant {
            return l.tr(zh: "打开植物详情", en: "Open plant details", de: "Pflanzendetails öffnen")
        }
        if card.isHuman {
            return l.tr(zh: "打开人类详情", en: "Open human details", de: "Menschendetails öffnen")
        }
        return l.tr(zh: "打开宠物详情", en: "Open pet details", de: "Haustierdetails öffnen")
    }

    private func expandedDetailAccessibilityIdentifier(for card: FocusCard) -> String {
        if card.isPlant { return "home-expanded-detail-plant" }
        return card.isHuman ? "home-expanded-detail-human" : "home-expanded-detail-pet"
    }

    private func expandedCollapseAccessibilityIdentifier(for card: FocusCard) -> String {
        if card.isPlant { return "home-expanded-collapse-plant" }
        return card.isHuman ? "home-expanded-collapse-human" : "home-expanded-collapse-pet"
    }

    private func cardAccessibilityIdentifier(for card: FocusCard) -> String {
        let kind = if card.isPlant {
            "plant"
        } else if card.isHuman {
            "human"
        } else {
            "pet"
        }
        return "home-card-\(kind)-\(card.name)"
    }

    private func embeddedQuickActionDockHeight(for frame: CGRect) -> CGFloat {
        min(max(frame.height * 0.34, 188), 224)
    }

    private func collapsedHitLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if FocusHomeCollapsedHitLayerPolicy.includes(cardId: card.id, selectedCardId: selectedCardId) {
                    let frame = collapsedFrame(index: index, count: cards.count, in: size)
                    let floating = floatingTransform(index: index, isSelected: false)
                    let cornerRadius = CGFloat(30)
                    let inactiveGeometry = freezesInactiveCollapsedGeometryDuringHero
                        ? inactiveCollapsedGeometry(
                            size: size,
                            selectedCardId: card.id,
                            includesAmbientFloat: true
                        )
                        : [:]

                    Button {
                        if freezesInactiveCollapsedGeometryDuringHero {
                            setInactiveHeroCollapsedGeometry(inactiveGeometry, selectionId: card.id)
                        }
                        onSelect(
                            preparedHeroSnapshot(for: card, index: index)
                                .freezingCollapsedGeometry(
                                    frame: frame.offsetBy(dx: floating.x, dy: floating.y),
                                    rotation: collapsedRotation(index: index) + floating.rotation,
                                    inactiveCollapsedGeometry: inactiveGeometry
                                )
                        )
                    } label: {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible vertical home card hit zone
                            .frame(width: frame.width, height: frame.height)
                            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                        .buttonStyle(.plain) // ui-v4: allow transparent hit proxy; the hero transition supplies visible feedback
                        .rotationEffect(.degrees(collapsedRotation(index: index) + floating.rotation))
                        .position(x: frame.midX + floating.x, y: frame.midY + floating.y)
                        .zIndex(100 + collapsedZIndex(index: index, count: cards.count))
                        .accessibilityLabel(card.name)
                        .accessibilityIdentifier(cardAccessibilityIdentifier(for: card))
                        .accessibilityHint(l.tr(
                            zh: "点击放大卡片",
                            en: "Tap to expand card",
                            de: "Tippen, um die Karte zu vergrößern"
                        ))
                }
            }
        }
    }

    private func frame(
        for card: FocusCard,
        index: Int,
        snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        in size: CGSize,
        visibleCenterX: CGFloat
    ) -> CGRect {
        let stableCollapsed = collapsedFrame(index: index, count: cards.count, in: size)
        let preparedCollapsed = FocusHomeInactiveHeroGeometryPolicy.collapsedFrame(
            stableFrame: stableCollapsed,
            preparedFrame: preparedHeroSnapshots[card.id]?.collapsedFrame,
            frozenFrame: inactiveHeroCollapsedGeometry(for: card.id)?.frame,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero,
            selectedCardId: selectedCardId,
            cardId: card.id
        )
        guard card.id == selectedCardId else {
            return selectedCardId == nil ? stableCollapsed : preparedCollapsed
        }

        let collapsed = collapsedFrame(for: snapshot, stableFrame: stableCollapsed)
        if reduceMotion {
            return progress > 0.5
                ? expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX, collapsedFrame: collapsed)
                : collapsed
        }

        let expanded = expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX, collapsedFrame: collapsed)
        return WalletHeroTimeline.activeFrame(from: collapsed, to: expanded, progress: progress)
    }

    private func collapsedFrame(
        for snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        stableFrame: CGRect
    ) -> CGRect {
        snapshot?.collapsedFrame ?? stableFrame
    }

    private func zIndex(for index: Int, isSelected: Bool) -> Double {
        guard isSelected else {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if embedsQuickActionsInCard, heroDirection > 0 {
            return expandedCardZIndex()
        }

        if progress <= 0.001 {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if heroDirection < 0, progress < 0.035 {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if embedsQuickActionsInCard {
            return expandedCardZIndex()
        }

        return 24
    }

    private func expandedCardZIndex() -> Double {
        let inactiveMax = (0 ..< cards.count)
            .map { collapsedZIndex(index: $0, count: cards.count) }
            .max() ?? 0
        return max(24, inactiveMax + 40)
    }

    private func rotation(
        for card: FocusCard,
        index: Int,
        snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        isSelected: Bool
    ) -> Double {
        let stableCollapsed = collapsedRotation(index: index)
        guard isSelected, selectedCardId != nil else {
            return FocusHomeInactiveHeroRotationPolicy.rotation(
                stableRotation: stableCollapsed,
                frozenRotation: inactiveHeroCollapsedGeometry(for: card.id)?.rotation,
                freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero,
                selectedCardId: selectedCardId,
                cardId: card.id
            )
        }

        let collapsed = snapshot?.collapsedRotation ?? stableCollapsed
        if reduceMotion {
            return progress > 0.5 ? 0 : collapsed
        }

        return collapsed * Double(1 - eased(progress))
    }

    private func preparedHeroSnapshot(for card: FocusCard, index: Int) -> FocusHomeVerticalSolidHeroSnapshot {
        preparedHeroSnapshots[card.id] ?? FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private func collapsedFrame(index: Int, count: Int, in size: CGSize) -> CGRect {
        let availableHeight = max(260, size.height - collapsedTopInset)
        let offsets = collapsedOffsets(count: count)
        let safeIndex = min(max(index, 0), max(offsets.count - 1, 0))
        let offset = offsets[safeIndex]
        let xValues = offsets.map(\.width)
        let yValues = offsets.map(\.height)
        let horizontalSpan = max(1.0, (xValues.max() ?? 0) - (xValues.min() ?? 0) + 1.0)
        let verticalSpan = max(
            FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio,
            (yValues.max() ?? 0) - (yValues.min() ?? 0) + FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
        )
        let preferredWidth = min(max(size.width * (count <= 1 ? 0.43 : 0.37), 112), count >= 5 ? 144 : 166)
        let width = max(
            104,
            min(
                preferredWidth,
                max(104, (size.width - 24) / horizontalSpan),
                max(104, (availableHeight - 18) / verticalSpan)
            )
        )
        let height = width * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
        let verticalBias = availableHeight * FocusHomeVerticalSolidCollapsedLayoutPolicy.clampedVerticalBias(collapsedVerticalBias)
        let center = CGPoint(
            x: size.width / 2,
            y: collapsedTopInset + availableHeight / 2 + verticalBias
        )
        let x = center.x + offset.width * width
        let y = center.y + offset.height * width
        return CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }

    private func expandedFrame(
        for _: FocusCard?,
        in size: CGSize,
        visibleCenterX: CGFloat,
        collapsedFrame: CGRect? = nil
    ) -> CGRect {
        let aspectRatio = FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
        let maxWidth: CGFloat = embedsQuickActionsInCard ? 386 : 390
        let horizontalInset: CGFloat = embedsQuickActionsInCard ? 18 : 22
        let safeTopInset = safeTop
        let bottomInset = embedsQuickActionsInCard ? CGFloat(0) : safeBottom + 28
        let availableWidth = max(220, size.width - horizontalInset)
        let availableHeight = max(320, size.height - safeTopInset - bottomInset)
        let width = min(availableWidth, maxWidth, availableHeight / aspectRatio)
        let height = width * aspectRatio
        let centeredTargetY = safeTopInset + availableHeight / 2 - (embedsQuickActionsInCard ? 2 : 0)
        let minimumY = safeTopInset + height / 2
        let maximumY = safeTopInset + availableHeight - height / 2
        let targetY: CGFloat
        switch expandedVerticalPlacement {
        case .sceneCenter:
            targetY = centeredTargetY
        case .collapsedCardCenter:
            let anchoredY = collapsedFrame?.midY ?? centeredTargetY
            targetY = min(max(anchoredY, minimumY), max(minimumY, maximumY))
        case let .viewportTop(topInset, scrollOffsetY):
            let anchoredY = max(0, scrollOffsetY) + max(0, topInset) + height / 2
            targetY = min(max(anchoredY, minimumY), max(minimumY, maximumY))
        }
        return CGRect(
            x: visibleCenterX - width / 2,
            y: targetY - height / 2,
            width: width,
            height: height
        )
    }

    private func collapsedOffsets(count: Int) -> [CGSize] {
        FocusHomeVerticalSolidCollapsedLayoutPolicy.offsets(count: count, mode: collapsedLayoutMode)
    }

    private func collapsedRotation(index: Int) -> Double {
        let rotations: [Double] = [-10.5, 7.4, -4.2, 10.8, -6.6, 5.1, 2.9, -12.0, 8.2, -2.6, 11.4, -7.8]
        return rotations[index % rotations.count]
    }

    private func collapsedZIndex(index: Int, count: Int) -> Double {
        if count >= 5 {
            let offsets = collapsedOffsets(count: count)
            let safeIndex = min(max(index, 0), max(offsets.count - 1, 0))
            return Double(offsets[safeIndex].height * 100) + Double(safeIndex) * 0.01
        }

        let depths: [Double] = [6, 5, 4, 3, 2, 1]
        return depths[index % depths.count]
    }

    private func floatingTransform(index: Int, isSelected: Bool) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        guard canFloatCards, !isSelected else { return (0, 0, 0) }
        let wave = FocusHomeAmbientFloatPolicy.wave(index: index, isRaisedPhase: ambientFloatPhase)
        return (0, CGFloat(wave) * FocusHomeAmbientFloatPolicy.yAmplitude * ambientFloatResumeProgress, 0)
    }

    private func inactiveOpacity(for card: FocusCard) -> Double {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        return reduceMotion ? 0 : Double(1 - smooth(progress, 0, 0.16))
    }

    private func inactiveScale(for card: FocusCard) -> CGFloat {
        FocusHomeInactiveHeroVisualPolicy.scale(
            selectedCardId: selectedCardId,
            cardId: card.id,
            progress: progress,
            reduceMotion: reduceMotion,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero
        )
    }

    private func collapseDragGesture(isEnabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($expandedDragY) { value, state, _ in
                guard isEnabled, value.translation.height > 0 else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard isEnabled else { return }
                if value.translation.height > 84 || value.predictedEndTranslation.height > 150 {
                    onCollapse()
                }
            }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func eased(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private func smooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return eased((value - start) / (end - start))
    }
}
