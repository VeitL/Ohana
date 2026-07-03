//
//  PlantDashboardView+WalletDeck.swift
//  Ohana
//
//  Wallet-card deck and expanded-card interactions for Plants mode.
//

import SwiftUI

extension PlantDashboardView {
    var plantWalletDeck: some View {
        let cards = plantWalletCards
        let sections = plantWalletCardSections(from: cards)
        return LazyVStack(spacing: PlantDashboardWalletSectionPolicy.sectionSpacing) {
            ForEach(sections) { section in
                plantWalletDeckSection(section)
                    .id(section.id)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            preparePlantHeroSnapshots(for: cards)
            reconcilePlantWalletSelection(cards: cards)
        }
        .onChange(of: plantWalletCardsSignature(cards)) { _, _ in
            preparePlantHeroSnapshots(for: cards)
            reconcilePlantWalletSelection(cards: cards)
        }
        .accessibilityIdentifier("plant-dashboard-wallet-deck")
    }

    func plantWalletDeckSection(_ section: PlantDashboardWalletCardSection) -> some View {
        let sectionSelectedCardId = section.contains(cardID: expandedPlantCardID) ? expandedPlantCardID : nil
        let sectionHeroSnapshot = section.contains(cardID: plantHeroSnapshot?.card.id) ? plantHeroSnapshot : nil
        let sectionProgress = sectionSelectedCardId == nil ? 0 : plantHeroProgress
        let sectionHeroDirection = sectionSelectedCardId == nil ? 0 : plantHeroDirection

        return ZStack {
            FocusHomeVerticalSolidScene(
                cards: section.cards,
                safeTop: 0,
                safeBottom: 0,
                selectedCardId: sectionSelectedCardId,
                preparedHeroSnapshots: plantPreparedHeroSnapshots,
                heroSnapshot: sectionHeroSnapshot,
                progress: sectionProgress,
                heroDirection: sectionHeroDirection,
                arrivingCardId: nil,
                reduceMotion: reduceMotion,
                localization: l,
                allowsAmbientFloat: false,
                isVisible: selectedDashboardMode == .plants,
                embedsQuickActionsInCard: true,
                freezesInactiveCollapsedGeometryDuringHero: true,
                collapsedTopInset: 0,
                collapsedVerticalBias: FocusHomeVerticalSolidCollapsedLayoutPolicy.bottomExtendedVerticalBias,
                quickActions: { card in
                    plantEmbeddedQuickActions(for: card)
                },
                contextMenu: { _ in EmptyView() },
                onSelect: expandPlantWalletCard,
                onCollapse: collapsePlantWalletCard,
                onWalkCardMinimizeToFloatingControl: {},
                onOpenDetails: { card in
                    onOpenPlant(card.id)
                }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: plantWalletDeckHeight(for: section.cards.count))
        .accessibilityIdentifier("plant-dashboard-wallet-section-\(section.ordinal)")
    }

    func plantWalletDeckHeight(for count: Int) -> CGFloat {
        PlantDashboardWalletSectionPolicy.sectionHeight(cardCount: count)
    }

    func plantWalletCardSections(from cards: [FocusCard]) -> [PlantDashboardWalletCardSection] {
        let sectionSize = PlantDashboardWalletSectionPolicy.maxCardsPerSection
        guard !cards.isEmpty, sectionSize > 0 else { return [] }
        return stride(from: 0, to: cards.count, by: sectionSize).enumerated().map { ordinal, start in
            let end = min(start + sectionSize, cards.count)
            return PlantDashboardWalletCardSection(ordinal: ordinal, cards: Array(cards[start ..< end]))
        }
    }

    func plantWalletCardsSignature(_ cards: [FocusCard]) -> String {
        cards.map {
            [
                $0.id.uuidString,
                $0.name,
                $0.statusBadgeText ?? "",
                $0.avatarImageSignature,
                $0.themeColorHex
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    func plantEmbeddedQuickActions(for card: FocusCard) -> some View {
        guard let plant = visiblePlants.first(where: { $0.id == card.id }) else {
            return VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: [],
                localization: l,
                shouldReduceWork: reduceMotion,
                forcesSubmenusBelow: false
            )
        }
        let nextTask = appServices.plantCarePlans.nextTask(for: plant)
        return VerticalHomeEmbeddedQuickActions(
            title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
            items: plantEmbeddedActionItems(for: plant, nextTask: nextTask),
            localization: l,
            itemsRevision: "\(plant.id.uuidString)-\(nextTask?.careType.rawValue ?? "none")-\(nextTask?.daysUntilDue ?? 999)",
            shouldReduceWork: reduceMotion,
            forcesSubmenusBelow: false
        )
    }

    func plantEmbeddedActionItems(
        for plant: Plant,
        nextTask: PlantCareTaskSnapshot?
    ) -> [VerticalHomeEmbeddedAction] {
        let wateringStatus = nextTask?.careType == .watering ? nextTask.map { dueText(for: $0) } : nil
        let fertilizingStatus = nextTask?.careType == .fertilizing ? nextTask.map { dueText(for: $0) } : nil
        return [
            VerticalHomeEmbeddedAction(
                id: "plant-\(plant.id.uuidString)-water",
                title: l.tr(zh: "浇水", en: "Water", de: "Gießen"),
                icon: "drop.fill",
                actionType: "plantWater",
                statusText: wateringStatus,
                isCompleted: false,
                showsAttention: nextTask?.careType == .watering && (nextTask?.daysUntilDue ?? 1) <= 0,
                primaryIcon: "checkmark",
                detailIcon: "clock.arrow.circlepath",
                showsMenu: false,
                showsQuickButton: true,
                quickAccessibilityLabel: l.tr(zh: "记录浇水", en: "Log watering", de: "Gießen erfassen"),
                detailAccessibilityLabel: l.tr(zh: "查看植物详情", en: "View plant details", de: "Pflanzendetails ansehen"),
                detailAction: { onOpenPlant(plant.id) },
                action: { openCareLogSheet(for: plant, type: .watering) }
            ),
            VerticalHomeEmbeddedAction(
                id: "plant-\(plant.id.uuidString)-fertilize",
                title: l.tr(zh: "施肥", en: "Fertilize", de: "Düngen"),
                icon: "leaf.fill",
                actionType: "plantFertilize",
                statusText: fertilizingStatus,
                isCompleted: false,
                showsAttention: nextTask?.careType == .fertilizing && (nextTask?.daysUntilDue ?? 1) <= 0,
                primaryIcon: "checkmark",
                detailIcon: "calendar",
                showsMenu: false,
                showsQuickButton: true,
                quickAccessibilityLabel: l.tr(zh: "记录施肥", en: "Log fertilizing", de: "Düngen erfassen"),
                detailAccessibilityLabel: l.tr(zh: "查看植物详情", en: "View plant details", de: "Pflanzendetails ansehen"),
                detailAction: { onOpenPlant(plant.id) },
                action: { openCareLogSheet(for: plant, type: .fertilizing) }
            ),
            VerticalHomeEmbeddedAction(
                id: "plant-\(plant.id.uuidString)-growth",
                title: l.tr(zh: "成长", en: "Growth", de: "Wachstum"),
                icon: "camera.fill",
                actionType: "plantGrowth",
                isCompleted: false,
                primaryIcon: "plus",
                detailIcon: "photo.stack.fill",
                showsMenu: false,
                showsQuickButton: true,
                quickAccessibilityLabel: l.tr(zh: "记录成长", en: "Log growth", de: "Wachstum erfassen"),
                detailAccessibilityLabel: l.tr(zh: "查看植物详情", en: "View plant details", de: "Pflanzendetails ansehen"),
                detailAction: { onOpenPlant(plant.id) },
                action: { openCareLogSheet(for: plant, type: nextTask?.careType == .photo ? .photo : .newLeaf) }
            ),
            VerticalHomeEmbeddedAction(
                id: "plant-\(plant.id.uuidString)-detail",
                title: l.tr(zh: "详情", en: "Detail", de: "Detail"),
                icon: "arrow.right.circle.fill",
                actionType: "plantDetail",
                isCompleted: false,
                primaryIcon: "arrow.right",
                detailIcon: "info.circle.fill",
                showsMenu: false,
                showsQuickButton: true,
                quickAccessibilityLabel: l.tr(zh: "打开植物详情", en: "Open plant details", de: "Pflanzendetails öffnen"),
                detailAccessibilityLabel: l.tr(zh: "打开植物详情", en: "Open plant details", de: "Pflanzendetails öffnen"),
                detailAction: { onOpenPlant(plant.id) },
                action: { onOpenPlant(plant.id) }
            )
        ]
    }

    func expandPlantWalletCard(_ snapshot: FocusHomeVerticalSolidHeroSnapshot) {
        let card = snapshot.card
        let canReopenSettledCard = expandedPlantCardID == card.id
            && plantHeroDirection == 0
            && plantHeroProgress <= 0.06
        guard expandedPlantCardID != card.id || canReopenSettledCard else { return }
        plantCollapseCleanupTask?.cancel()
        plantCollapseCleanupTask = nil
        plantHeroGeneration += 1
        let generation = plantHeroGeneration
        OhanaFeedback.light()
        withoutPlantWalletAnimation {
            expandedPlantCardID = card.id
            plantHeroSnapshot = snapshot
            plantHeroDirection = 1
            plantHeroProgress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame {
            guard generation == plantHeroGeneration,
                  expandedPlantCardID == card.id,
                  plantHeroDirection == 1 else { return }
            withAnimation(plantWalletHeroAnimation, completionCriteria: .removed) {
                plantHeroProgress = 1
            } completion: {
                completePlantWalletExpand(cardID: card.id, generation: generation)
            }
        }
    }

    func collapsePlantWalletCard() {
        guard let selectedID = expandedPlantCardID else { return }
        OhanaFeedback.light()
        plantCollapseCleanupTask?.cancel()
        plantHeroGeneration += 1
        let generation = plantHeroGeneration
        let collapseSnapshot = plantHeroSnapshot
            ?? plantPreparedHeroSnapshots[selectedID]
            ?? makePlantHeroSnapshot(for: selectedID)
        guard let collapseSnapshot else { return }

        withoutPlantWalletAnimation {
            plantHeroSnapshot = collapseSnapshot
            plantHeroDirection = -1
        }
        withAnimation(plantWalletHeroAnimation, completionCriteria: .removed) {
            plantHeroProgress = 0
        } completion: {
            completePlantWalletCollapse(cardID: selectedID, generation: generation)
        }
    }

    func completePlantWalletExpand(cardID: UUID, generation: Int) {
        guard generation == plantHeroGeneration,
              expandedPlantCardID == cardID,
              plantHeroDirection == 1 else { return }
        withoutPlantWalletAnimation {
            plantHeroProgress = 1
            plantHeroDirection = 0
        }
    }

    func completePlantWalletCollapse(cardID: UUID, generation: Int) {
        guard generation == plantHeroGeneration,
              expandedPlantCardID == cardID,
              plantHeroDirection == -1 else { return }
        withoutPlantWalletAnimation {
            plantHeroProgress = 0
            plantHeroDirection = 0
        }
        plantCollapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame {
            guard generation == plantHeroGeneration,
                  expandedPlantCardID == cardID,
                  plantHeroDirection == 0 else { return }
            plantCollapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame {
                guard generation == plantHeroGeneration,
                      expandedPlantCardID == cardID,
                      plantHeroDirection == 0 else { return }
                withoutPlantWalletAnimation {
                    expandedPlantCardID = nil
                    plantHeroSnapshot = nil
                }
                plantCollapseCleanupTask = nil
            }
        }
    }

    func makePlantHeroSnapshot(for cardID: UUID) -> FocusHomeVerticalSolidHeroSnapshot? {
        for section in plantWalletCardSections(from: plantWalletCards) {
            guard let index = section.cards.firstIndex(where: { $0.id == cardID }) else { continue }
            let card = section.cards[index]
            return FocusHomeVerticalSolidHeroSnapshot(
                card: card,
                index: index,
                avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
            )
        }
        return nil
    }

    func preparePlantHeroSnapshots(for cards: [FocusCard]) {
        let next = Dictionary(
            uniqueKeysWithValues: plantWalletCardSections(from: cards).flatMap { section in
                section.cards.enumerated().map { index, card in
                    (
                        card.id,
                        FocusHomeVerticalSolidHeroSnapshot(
                            card: card,
                            index: index,
                            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
                        )
                    )
                }
            }
        )
        withoutPlantWalletAnimation {
            plantPreparedHeroSnapshots = next
            if let selectedID = expandedPlantCardID,
               let refreshed = next[selectedID],
               plantHeroDirection == 0 {
                plantHeroSnapshot = refreshed.preservingCollapsedGeometry(from: plantHeroSnapshot)
            }
        }
    }

    func reconcilePlantWalletSelection(cards: [FocusCard]) {
        guard let selectedID = expandedPlantCardID,
              !cards.contains(where: { $0.id == selectedID }) else { return }
        plantCollapseCleanupTask?.cancel()
        plantCollapseCleanupTask = nil
        plantHeroGeneration += 1
        withoutPlantWalletAnimation {
            expandedPlantCardID = nil
            plantHeroSnapshot = nil
            plantHeroProgress = 0
            plantHeroDirection = 0
        }
    }

    func withoutPlantWalletAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    var plantWalletHeroAnimation: Animation {
        reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero
    }

    func plantListRow(_ plant: Plant) -> some View {
        let nextTask = appServices.plantCarePlans.nextTask(for: plant)
        let isExpanded = expandedPlantCardID == plant.id
        let card = FocusCard.fromPlant(
            plant,
            catalog: PlantCatalog.entry(id: plant.catalogSpeciesId),
            nextTask: nextTask,
            localization: l
        )
        return VStack(spacing: isExpanded ? 10 : 0) {
            FocusHomeWalletCardContent(
                card: card,
                namespace: plantWalletNamespace,
                heroNamespace: plantWalletHeroNamespace,
                expandedId: expandedPlantCardID,
                isHeroExpanded: isExpanded,
                heroProgress: isExpanded ? 1 : 0,
                avatarCacheRevision: 0,
                walkTrackingPet: nil,
                usesMatchedGeometry: false,
                reduceMotion: false,
                presentation: .plant,
                expandedCardHeight: 330,
                cardCornerRadius: HeroAnim.stackCardCorner,
                equipFxLimeGlow: nextTask?.daysUntilDue ?? 1 <= 0,
                equipFxPopoutCard: false
            )
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous))
            .onTapGesture {
                toggleExpandedPlantCard(plant.id)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        guard isExpanded, value.translation.height < -58 else { return }
                        collapseExpandedPlantCard()
                    }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(plantCardAccessibilityLabel(for: plant, nextTask: nextTask))
            .accessibilityAddTraits(isExpanded ? .isSelected : [])
            .accessibilityIdentifier("plant-dashboard-plant-open-\(plant.id.uuidString)")

            if isExpanded {
                plantWalletQuickActions(for: plant, nextTask: nextTask)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(GoMotion.page, value: isExpanded)
        .accessibilityIdentifier("plant-dashboard-plant-row-\(plant.name)")
    }

    func plantWalletQuickActions(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> some View {
        VStack(spacing: 8) {
            Button {
                onOpenPlant(plant.id)
            } label: {
                HStack(spacing: 7) {
                    Capsule()
                        .fill(Color.goCardWhite.opacity(0.68))
                        .frame(width: 42, height: 5) // a11y: allow decorative drag handle inside a 44pt detail button
                        .accessibilityHidden(true)
                    Image(systemName: "chevron.down") // a11y: allow decorative disclosure glyph; button text labels the action.
                        .font(OhanaFont.adaptive(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .accessibilityHidden(true)
                    Text(l.tr(zh: "查看详情", en: "View details", de: "Details ansehen"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "查看\(plant.name)详情", en: "View details for \(plant.name)", de: "Details für \(plant.name) ansehen"))
            .accessibilityIdentifier("plant-dashboard-plant-detail-handle-\(plant.id.uuidString)")

            HStack(spacing: 8) {
                plantWalletQuickActionButton(
                    id: "water",
                    icon: "drop.fill",
                    title: l.tr(zh: "浇水", en: "Water", de: "Gießen"),
                    tint: Color.goTeal
                ) {
                    openCareLogSheet(for: plant, type: .watering)
                }
                .accessibilityIdentifier("plant-dashboard-plant-quick-care-\(plant.id.uuidString)")

                plantWalletQuickActionButton(
                    id: "fertilize",
                    icon: "leaf.fill",
                    title: l.tr(zh: "施肥", en: "Fertilize", de: "Düngen"),
                    tint: Color.goLime
                ) {
                    openCareLogSheet(for: plant, type: .fertilizing)
                }
                .accessibilityIdentifier("plant-dashboard-plant-quick-fertilize-\(plant.id.uuidString)")

                plantWalletQuickActionButton(
                    id: "growth",
                    icon: "camera.fill",
                    title: l.tr(zh: "成长", en: "Growth", de: "Wachstum"),
                    tint: Color.goYellow
                ) {
                    openCareLogSheet(for: plant, type: nextTask?.careType == .photo ? .photo : .newLeaf)
                }
                .accessibilityIdentifier("plant-dashboard-plant-growth-\(plant.id.uuidString)")

                plantWalletQuickActionButton(
                    id: "detail",
                    icon: "arrow.right.circle.fill",
                    title: l.tr(zh: "详情", en: "Detail", de: "Detail"),
                    tint: Color.goTeal
                ) {
                    onOpenPlant(plant.id)
                }
                .accessibilityIdentifier("plant-dashboard-plant-detail-\(plant.id.uuidString)")
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke.opacity(0.58), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-wallet-actions-\(plant.id.uuidString)")
    }

    func plantWalletQuickActionButton(
        id: String,
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(id == "water" || id == "fertilize" ? Color.arkInk : tint)
                    .frame(width: 44, height: 44)
                    .background(tint, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 66)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier("plant-dashboard-wallet-action-\(id)")
    }

    func plantListMetricPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    func plantListBadges(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> some View {
        let profilePercent = plantProfileCompletionPercent(for: plant)
        return HStack(spacing: 6) {
            if let nextTask, nextTask.daysUntilDue <= 0 {
                plantListBadge(
                    icon: careSymbol(for: nextTask.careType),
                    text: nextTask.careType.displayName(l: l),
                    tint: careTint(for: nextTask.careType)
                )
            }

            if plant.healthStatus == .watching || plant.healthStatus == .stressed {
                plantListBadge(
                    icon: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "eye.fill",
                    text: plant.healthStatus.displayName,
                    tint: plant.healthStatus == .stressed ? Color.goRed : Color.goYellow
                )
            }

            plantListBadge(
                icon: "info.circle.fill",
                text: "\(plantCareScore(for: plant))%",
                tint: plant.healthStatus == .stressed ? Color.goRed : Color.goLime
            )

            plantListBadge(
                icon: "checkmark.seal.fill",
                text: "\(profilePercent)%",
                tint: profilePercent >= 80 ? Color.goLime : Color.goYellow
            )
        }
        .lineLimit(1)
    }

    func plantListBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
    }

    func plantListCarePlanSummary(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> String {
        if let nextTask {
            return [
                nextTask.title,
                dueText(for: nextTask),
                nextTask.subtitle
            ].joined(separator: " · ")
        }

        if plant.careLogs.isEmpty {
            return l.tr(
                zh: "还没有护理记录，先完成一次浇水或观察。",
                en: "No care log yet. Start with watering or a small observation.",
                de: "Noch kein Pflegeeintrag. Beginne mit Gießen oder einer Beobachtung."
            )
        }

        return l.tr(
            zh: "当前没有 7 天内任务，可以补照片或整理档案。",
            en: "No task in the 7-day window. Add a photo or tidy the profile.",
            de: "Keine Aufgabe im 7-Tage-Fenster. Foto ergänzen oder Profil ordnen."
        )
    }

    func plantListQuickCareAccessibilityLabel(
        for plant: Plant,
        nextTask: PlantCareTaskSnapshot?
    ) -> String {
        if let nextTask {
            let careTypeName = nextTask.careType.displayName(l: l)
            return l.tr(
                zh: "完成\(plant.name)的\(careTypeName)",
                en: "Complete \(careTypeName) for \(plant.name)",
                de: "\(careTypeName) für \(plant.name) erledigen"
            )
        }
        return l.tr(
            zh: "记录\(plant.name)的一次浇水",
            en: "Log watering for \(plant.name)",
            de: "Gießen für \(plant.name) erfassen"
        )
    }

    func plantProfileCompletionPercent(for plant: Plant) -> Int {
        let total = 5
        var completed = 0
        if !plant.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completed += 1
        }
        if !plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !plant.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completed += 1
        }
        if plant.potDiameterCm > 0 || !plant.soilType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completed += 1
        }
        if PlantCatalog.entry(id: plant.catalogSpeciesId) != nil {
            completed += 1
        }
        if !plant.careLogs.isEmpty {
            completed += 1
        }
        return Int((Double(completed) / Double(total) * 100).rounded())
    }
}
