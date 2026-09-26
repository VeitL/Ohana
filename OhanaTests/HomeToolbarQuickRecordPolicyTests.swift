import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Ohana

@MainActor
struct HomeToolbarQuickRecordPolicyTests {
    @Test func actionIsLimitedToMemberAndPlantTabs() {
        #expect(HomeToolbarQuickRecordPolicy.isVisible(for: .home))
        #expect(HomeToolbarQuickRecordPolicy.isVisible(for: .plants))
        #expect(!HomeToolbarQuickRecordPolicy.isVisible(for: .calendar))
        #expect(!HomeToolbarQuickRecordPolicy.isVisible(for: .oasis))
    }

    @Test func homeTargetsKeepActiveRealHumansAndPetsInCardOrder() {
        let human = makeCard(name: "Ari", isHuman: true)
        let memorialHuman = makeCard(name: "Bo", isHuman: true, hasPassedAway: true)
        let memorialPet = makeCard(name: "Momo", hasPassedAway: true)
        let pet = makeCard(name: "Nori")
        let electronicPet = makeCard(name: "Pixel", isElectronicPet: true)
        let dummy = makeCard(name: "Preview", isDummy: true, isReal: false)
        let humanActions = [
            "humanWeight",
            "humanWorkout",
            "humanMedication",
            "humanNote",
            "humanExpense",
            "humanAllFeatures",
            "futureReadOnlyFeature"
        ].map { makeQuickAction($0, entityID: human.id, kind: .human) }
        let petActions = ["weight", "allFeatures", "futureReadOnlyFeature"]
            .map { makeQuickAction($0, entityID: pet.id, kind: .pet) }

        let targets = HomeToolbarQuickRecordPolicy.targets(
            for: .home,
            cards: [human, memorialHuman, memorialPet, pet, electronicPet, dummy],
            plants: [],
            quickActionsByCardID: [
                human.id: humanActions,
                pet.id: petActions
            ],
            localization: L10n("en")
        )

        #expect(targets.map(\.entityID) == [human.id, pet.id])
        #expect(targets.map(\.kind) == [.human, .pet])
        #expect(targets.map(\.name) == ["Ari", "Nori"])
        #expect(
            targets[0].quickActions.map(\.actionType)
                == ["humanWeight", "humanMetrics", "humanWorkout", "humanMedication", "humanNote"]
        )
        #expect(targets[1].quickActions.map(\.actionType) == ["weight"])
    }

    @Test func petTargetsExposeOnlyRecordCatalogActions() {
        let pet = makeCard(name: "Nori")
        let recordActions = [
            "walk", "feed", "water", "potty", "litter", "waterChange", "filterClean",
            "groom", "health", "medication", "expense", "weight", "play", "moment",
            "cageCleaning", "freeFlight", "misting", "substrateChange"
        ]
        let candidates = (recordActions + ["allFeatures", "futureReadOnlyFeature"])
            .map { makeQuickAction($0, entityID: pet.id, kind: .pet) }

        let target = HomeToolbarQuickRecordPolicy.targets(
            for: .home,
            cards: [pet],
            plants: [],
            quickActionsByCardID: [pet.id: candidates]
        ).first

        #expect(target?.quickActions.map(\.actionType) == recordActions)
    }

    @Test func persistedLegacyHumanExpenseShortcutIsNotRestoredOrSaved() throws {
        let human = Human(name: "Ari")
        let legacyExpense = makeQuickAction("humanExpense", entityID: human.id, kind: .human)
        let weight = makeQuickAction("humanWeight", entityID: human.id, kind: .human)
        let raw = try #require(String(data: JSONEncoder().encode([legacyExpense, weight]), encoding: .utf8))

        let restored = ExpandedQuickActionStore.humanItems(
            raw: raw,
            human: human,
            localization: L10n("en")
        )
        #expect(restored.map(\.actionType) == ["humanWeight"])

        let savedRaw = ExpandedQuickActionStore.savingHumanItems(
            [legacyExpense, weight],
            human: human,
            currentItems: restored,
            raw: raw
        )
        let saved = ExpandedQuickActionStore.humanItems(
            raw: savedRaw,
            human: human,
            localization: L10n("en")
        )
        #expect(saved.map(\.actionType) == ["humanWeight"])
    }

    @Test func petAllShortcutIsAlwaysLastForDefaultsAndStoredLegacyOrder() throws {
        let pet = Pet(name: "Nori", species: "dog")
        let defaults = ExpandedQuickActionDefaults.items(
            for: pet,
            localization: L10n("en"),
            waterManagementLabel: "Water"
        )
        #expect(defaults.last?.actionType == "allFeatures")

        let legacyOrder = defaults.suffix(1) + defaults.dropLast()
        let rawData = try JSONEncoder().encode(Array(legacyOrder))
        let raw = try #require(String(data: rawData, encoding: .utf8))
        let restored = ExpandedQuickActionStore.petItems(
            raw: raw,
            pet: pet,
            defaultItems: defaults,
            waterLabel: "Water",
            managementLabel: "Water"
        )

        #expect(restored.last?.actionType == "allFeatures")
        #expect(restored.count(where: { $0.actionType == "allFeatures" }) == 1)
        #expect(restored.count <= QuickActionLimit.maxItemsPerEntity)

        let savedRaw = ExpandedQuickActionStore.savingPetItems(
            Array(legacyOrder),
            pet: pet,
            currentItems: restored,
            raw: raw
        )
        let savedData = try #require(savedRaw.data(using: .utf8))
        let persisted = try JSONDecoder().decode(
            [QuickActionItem].self,
            from: savedData
        ).filter { $0.entityId == pet.id }
        #expect(persisted.last?.actionType == "allFeatures")
        #expect(persisted.count(where: { $0.actionType == "allFeatures" }) == 1)
    }

    @Test func completedSingleUsePetActionsFallBackToDetail() {
        let petID = UUID()
        let litter = makeQuickAction("litter", entityID: petID, kind: .pet)
        let play = makeQuickAction("play", entityID: petID, kind: .pet)
        let completedQuickState = HomeQuickActionRenderSnapshot(
            status: nil,
            isCompleted: true,
            isLocked: false,
            menuPolicy: HomeQuickActionMenuPolicySnapshot(
                showsMenu: true,
                showsQuickButton: true
            )
        )
        let pendingQuickState = HomeQuickActionRenderSnapshot(
            status: nil,
            isCompleted: false,
            isLocked: false,
            menuPolicy: HomeQuickActionMenuPolicySnapshot(
                showsMenu: true,
                showsQuickButton: true
            )
        )
        let detailOnlyState = HomeQuickActionRenderSnapshot(
            status: nil,
            isCompleted: false,
            isLocked: false,
            menuPolicy: HomeQuickActionMenuPolicySnapshot(
                showsMenu: true,
                showsQuickButton: false
            )
        )

        #expect(!HomeToolbarQuickRecordPolicy.usesPetPrimaryAction(for: litter, state: completedQuickState))
        #expect(HomeToolbarQuickRecordPolicy.usesPetPrimaryAction(for: litter, state: pendingQuickState))
        #expect(HomeToolbarQuickRecordPolicy.usesPetPrimaryAction(for: play, state: completedQuickState))
        #expect(!HomeToolbarQuickRecordPolicy.usesPetPrimaryAction(for: play, state: detailOnlyState))
    }

    @Test func sharedPetSubtypeCatalogMatchesCardActionsAndAvoidsEnglishFallback() {
        let expectedIDs = [
            "groom": ["bath", "teeth", "nails", "brushing", "ears"],
            "potty": PottyType.allCases.map(\.rawValue),
            "health": ["vaccine", "deworming", "visit"]
        ]
        let englishTitles = expectedIDs.keys.reduce(into: [String: [String]]()) { result, actionType in
            result[actionType] = HomeQuickActionOptionCatalog.options(
                for: actionType,
                localization: L10n("en")
            ).map(\.title)
        }

        for (actionType, ids) in expectedIDs {
            let englishOptions = HomeQuickActionOptionCatalog.options(
                for: actionType,
                localization: L10n("en")
            )
            let expectedEnglishTitles = englishTitles[actionType] ?? []
            #expect(englishOptions.map(\.id) == ids)
            #expect(HomeQuickActionOptionCatalog.hasOptions(for: actionType))

            for languageCode in AppLanguage.supported.map(\.code) where languageCode != "en" {
                let localizedTitles = HomeQuickActionOptionCatalog.options(
                    for: actionType,
                    localization: L10n(languageCode)
                ).map(\.title)
                #expect(localizedTitles.count == expectedEnglishTitles.count)
                #expect(zip(localizedTitles, expectedEnglishTitles).allSatisfy { $0.0 != $0.1 })
            }
        }
        #expect(!HomeQuickActionOptionCatalog.hasOptions(for: "weight"))
        #expect(HomeQuickActionOptionCatalog.options(for: "weight", localization: L10n("en")).isEmpty)
    }

    @Test func plantTargetsExcludeArchivedPlants() {
        let active = Plant(name: "Fern")
        let archived = Plant(name: "Pothos")
        archived.archivedAt = Date()

        let targets = HomeToolbarQuickRecordPolicy.targets(
            for: .plants,
            cards: [],
            plants: [makePlantSnapshot(active), makePlantSnapshot(archived)]
        )

        #expect(targets.map(\.entityID) == [active.id])
        #expect(targets.map(\.kind) == [.plant])
    }

    @Test func healthDataQuickActionIsLocalizedForEveryRegisteredLanguage() {
        let expectedByLanguage = [
            "zh": "健康数据",
            "en": "Health data",
            "de": "Gesundheitsdaten",
            "es": "Datos de salud",
            "pt": "Dados de saúde",
            "fr": "Données de santé",
            "ja": "健康データ",
            "ko": "건강 데이터",
            "it": "Dati sanitari"
        ]
        #expect(Set(expectedByLanguage.keys) == Set(AppLanguage.supported.map(\.code)))
        let human = makeCard(name: "Ari", isHuman: true)

        for (language, expected) in expectedByLanguage {
            let target = HomeToolbarQuickRecordPolicy.targets(
                for: .home,
                cards: [human],
                plants: [],
                localization: L10n(language)
            ).first
            let healthData = target?.quickActions.first { $0.actionType == "humanMetrics" }
            #expect(healthData?.label == expected)
        }
    }

    @Test func exoticPetQuickRecordLabelsAreLocalizedForEveryRegisteredLanguage() {
        let expectedMisting = [
            "zh": "喷水",
            "en": "Mist",
            "de": "Sprühen",
            "es": "Rociar",
            "pt": "Borrifar",
            "fr": "Brumiser",
            "ja": "霧吹き",
            "ko": "분무",
            "it": "Nebulizza"
        ]
        let expectedSubstrateChange = [
            "zh": "换垫材",
            "en": "Substrate",
            "de": "Substrat",
            "es": "Cambiar sustrato",
            "pt": "Trocar substrato",
            "fr": "Changer le substrat",
            "ja": "床材交換",
            "ko": "바닥재 교체",
            "it": "Cambia substrato"
        ]
        let supportedCodes = Set(AppLanguage.supported.map(\.code))
        #expect(Set(expectedMisting.keys) == supportedCodes)
        #expect(Set(expectedSubstrateChange.keys) == supportedCodes)

        for languageCode in AppLanguage.supported.map(\.code) {
            let localization = L10n(languageCode)
            #expect(localization.quickActionLabel(for: "misting") == expectedMisting[languageCode])
            #expect(
                localization.quickActionLabel(for: "substrateChange")
                    == expectedSubstrateChange[languageCode]
            )
        }
    }

    @Test func bottomContextActionMatchesEachRootPageAndIsLocalized() {
        #expect(HomeBottomContextAction.action(for: .home) == .quickRecord)
        #expect(HomeBottomContextAction.action(for: .plants) == .quickRecord)
        #expect(HomeBottomContextAction.action(for: .calendar) == .addEvent)
        #expect(HomeBottomContextAction.action(for: .oasis) == .injectEnergy)
        #expect(HomeBottomContextAction.addEvent.icon == "calendar.badge.plus")
        #expect(HomeBottomContextAction.injectEnergy.icon == "bolt.fill")

        for action in [
            HomeBottomContextAction.quickRecord,
            .addEvent,
            .injectEnergy
        ] {
            let english = action.accessibilityLabel(L10n("en"))
            #expect(!english.isEmpty)
            for languageCode in AppLanguage.supported.map(\.code) where languageCode != "en" {
                #expect(action.accessibilityLabel(L10n(languageCode)) != english)
            }
        }

        for action in [HomeBottomContextAction.addEvent, .injectEnergy] {
            let english = action.accessibilityHint(L10n("en"))
            #expect(!english.isEmpty)
            for languageCode in AppLanguage.supported.map(\.code) where languageCode != "en" {
                #expect(action.accessibilityHint(L10n(languageCode)) != english)
            }
        }

        let disabledReasons: [HomeBottomContextActionDisabledReason] = [
            .loading,
            .insufficientCoconuts(required: 10),
            .inProgress,
            .unavailable
        ]
        for reason in disabledReasons {
            let english = reason.accessibilityDescription(L10n("en"))
            #expect(!english.isEmpty)
            for languageCode in AppLanguage.supported.map(\.code) where languageCode != "en" {
                #expect(reason.accessibilityDescription(L10n(languageCode)) != english)
            }
        }
    }

    @Test func quickRecordActionRelayUsesTheLatestRoutingContext() {
        let target = HomeToolbarQuickRecordTarget(
            entityID: UUID(),
            name: "Nori",
            kind: .pet,
            quickActions: []
        )
        let relay = HomeQuickRecordActionRelay()
        var handledRevision = ""

        relay.update { _, _, _ in handledRevision = "old" }
        relay.update { routedTarget, _, _ in
            handledRevision = routedTarget.id
        }
        relay.perform(target: target, action: nil, optionID: nil)

        #expect(handledRevision == target.id)
    }

    @Test func splitIslandQuickRecordMenuWiresExistingRoutes() throws {
        let toolbarSource = try source("Ohana/Features/Home/Views/FocusHomeHeaderView.swift")
        let nativeToolbarSource = toolbarSource.components(separatedBy: "struct HomeQuickRecordMenu").first
            ?? toolbarSource
        let quickMenuSource = toolbarSource.components(separatedBy: "struct HomeQuickRecordMenu").last ?? ""
        let bottomBarSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeBottomBar.swift")
        let homeSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView.swift")
        let routingSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+Routing.swift")
        let plantRouteSource = try source("Ohana/Features/Home/HomePlantCareLogRouteContainer.swift")

        #expect(nativeToolbarSource.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(nativeToolbarSource.contains("ToolbarItemGroup(placement: .topBarTrailing)"))
        #expect(!nativeToolbarSource.contains("home-quick-record-action"))
        #expect(toolbarSource.contains("struct HomeQuickRecordMenu: View, Equatable"))
        #expect(quickMenuSource.contains("static func == (lhs: HomeQuickRecordMenu, rhs: HomeQuickRecordMenu)"))
        #expect(quickMenuSource.contains("lhs.quickRecordTargets == rhs.quickRecordTargets"))
        #expect(!quickMenuSource.contains("routeValidationRevision"))
        #expect(quickMenuSource.contains("lhs.actionRelay === rhs.actionRelay"))
        #expect(quickMenuSource.contains("actionRelay.perform(target:"))
        #expect(quickMenuSource.contains(".accessibilityIdentifier(\"home-quick-record-action\")"))
        #expect(quickMenuSource.contains("quickRecordTargets.isEmpty ? quickRecordEmptyTitle : quickRecordAccessibilityHint"))
        #expect(quickMenuSource.contains("unavailableAccessibilityHint"))
        #expect(quickMenuSource.contains("ForEach(target.quickActions)"))
        #expect(quickMenuSource.contains("HomeQuickActionOptionCatalog.options("))
        #expect(quickMenuSource.contains("actionRelay.perform(target: target, action: action, optionID: option.id)"))
        #expect(quickMenuSource.contains("quickRecordTargetAccessibilityLabel(target)"))
        #expect(quickMenuSource.contains("\\(target.name): \\(action.displayLabel(localization: localization))"))
        #expect(quickMenuSource.contains("\\(target.accessibilityIdentifier)-\\(action.actionType)"))
        #expect(quickMenuSource.contains("\\(target.accessibilityIdentifier)-\\(action.actionType)-\\(option.id)"))
        #expect(quickMenuSource.contains("ja: \"すばやく記録\""))
        #expect(bottomBarSource.contains("GlassEffectContainer(spacing: 10)"))
        #expect(bottomBarSource.contains(".glassEffect(.regular.interactive(), in: Capsule())"))
        #expect(bottomBarSource.contains(".glassEffect(.regular.tint(Color.goPrimary).interactive(), in: Circle())"))
        #expect(bottomBarSource.contains(".accessibilityValue(accessibilityPosition)"))
        #expect(bottomBarSource.contains("OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥"))
        #expect(bottomBarSource.contains("HomeQuickRecordPopoutControl("))
        #expect(bottomBarSource.contains(".ohanaStaggeredMenuItem("))
        #expect(bottomBarSource.contains("onQuickRecord(target, action, optionID)"))
        #expect(!bottomBarSource.contains("@StateObject private var quickRecordActionRelay"))
        #expect(!bottomBarSource.contains("routeRevision"))
        #expect(bottomBarSource.contains(".onChange(of: selectedTab)"))
        #expect(bottomBarSource.contains("milliseconds: canAnimate ? 390 : 0"))
        #expect(bottomBarSource.contains("ForEach(Array(items.enumerated())"))
        #expect(bottomBarSource.contains("ForEach(visibleTabs)"))
        #expect(bottomBarSource.contains(".matchedGeometryEffect("))
        #expect(bottomBarSource.contains("allowsSelectionMotion ? VerticalHomeTabTransitionPolicy.selectionAnimation"))
        #expect(bottomBarSource.contains(".transition(.opacity)"))
        #expect(routingSource.contains("controller.select(tab)"))
        #expect(!routingSource.contains("withAnimation(canAnimate ? VerticalHomeTabTransitionPolicy.selectionAnimation"))
        #expect(homeSource.contains("VerticalSolidHomeBottomBar("))
        #expect(homeSource.contains("allowsSelectionMotion: canAnimate"))
        #expect(homeSource.contains("quickRecordTargets: homeToolbarQuickRecordTargets"))
        #expect(!homeSource.contains("quickRecordRouteRevision"))
        #expect(homeSource.contains("onQuickRecord: openHomeToolbarQuickRecord"))
        #expect(routingSource.contains("openCalendarAddEvent(plants: embeddedCalendarPlants)"))
        #expect(routingSource.contains("injectEmbeddedOasisEnergy()"))
        #expect(routingSource.contains("guard islandCoconutBalance >= cost"))
        #expect(routingSource.contains("treeManager.canUseInjectionPackage(cost:"))
        #expect(routingSource.contains("oasisEnergyInjectionTask == nil"))
        #expect(routingSource.contains("pendingOasisEnergyInjectionCount == 0"))
        #expect(routingSource.contains("interaction.expandedActions(for: card.id).candidateItems"))
        #expect(routingSource.contains("openQuickActionOption(action, card: card, optionId: optionID)"))
        #expect(routingSource.contains("HomeToolbarQuickRecordPolicy.usesPetPrimaryAction("))
        #expect(routingSource.contains("openQuickActionItem(action, card: card, usesPrimaryAction: usesPrimaryAction)"))
        #expect(routingSource.contains("openQuickActionItem(action, card: card, usesPrimaryAction: true)"))
        #expect(routingSource.contains("routeCoordinator.openSheet(.humanMetrics(target.entityID))"))
        #expect(routingSource.contains("routeCoordinator.showHumanPrivacy()"))
        #expect(routingSource.contains("routeCoordinator.openSheet(.plantCareLog(target.entityID, initialCareType: .customNote))"))
        #expect(plantRouteSource.contains("candidate.isArchived ? nil : candidate"))
    }

    @Test func memberCreationReturnsHomeWithoutRosterIntermediateCopy() throws {
        let presentationSource = try source("Ohana/App/RouteContainers/AppRouteDestinationContainers.swift")
        let rosterSource = try source("Ohana/Features/CrewRoster/Views/CrewRosterOverlay.swift")
        let completionSource = rosterSource.components(separatedBy: "private func completeInlineAddEntity()").last?
            .components(separatedBy: "private func resetPendingInlineAddEntity()").first ?? ""

        #expect(presentationSource.contains("onPetSavedFromAddEntity: handlePetSavedFromAddEntity"))
        #expect(presentationSource.contains("onHumanSavedFromAddEntity: handleHumanSavedFromAddEntity"))
        #expect(presentationSource.contains("coordinator.completeMemberCreation()"))
        #expect(!completionSource.contains("transaction.disablesAnimations = true"))
        #expect(!completionSource.contains("runAfterNextFrame"))
        #expect(completionSource.contains("guard let savedTarget else"))
        #expect(completionSource.contains("activeFullScreenRoute = nil"))
        #expect(completionSource.contains("onInlinePetSaved(savedPet)"))
        #expect(completionSource.contains("onInlineHumanSaved(savedHuman)"))
        #expect(presentationSource.contains("onInlinePetSaved: { pet in\n                        onPetSavedFromAddEntity(pet)"))
        #expect(presentationSource.contains("onInlineHumanSaved: { human in\n                        onHumanSavedFromAddEntity(human)"))
        #expect(!rosterSource.contains("档案、钱包与成员管理"))
        #expect(!rosterSource.contains("请更换搜索内容或成员类型"))
        #expect(!rosterSource.contains("添加宠物或人类成员开始照顾"))
    }

    private func makeQuickAction(
        _ actionType: String,
        entityID: UUID,
        kind: EntityKind
    ) -> QuickActionItem {
        QuickActionItem(
            label: actionType,
            icon: "circle",
            colorHex: "5B6AFF",
            petId: kind == .pet ? entityID : nil,
            actionType: actionType,
            entityId: entityID,
            entityKind: kind
        )
    }

    private func makeCard(
        name: String,
        isHuman: Bool = false,
        hasPassedAway: Bool = false,
        isElectronicPet: Bool = false,
        isDummy: Bool = false,
        isReal: Bool = true
    ) -> FocusCard {
        FocusCard(
            id: UUID(),
            name: name,
            kind: isHuman ? "Human" : "Pet",
            emoji: "",
            color: .blue,
            streak: 0,
            coconutBalance: 0,
            hasPassedAway: hasPassedAway,
            isHuman: isHuman,
            isElectronicPet: isElectronicPet,
            isDummy: isDummy,
            isReal: isReal,
            actions: []
        )
    }

    private func makePlantSnapshot(_ plant: Plant) -> VerticalSolidHomePlantSnapshot {
        VerticalSolidHomePlantSnapshot(
            id: plant.id,
            modelID: plant.persistentModelID,
            name: plant.name,
            subtitle: "",
            emoji: "🌱",
            themeHex: "4CAF50",
            roomName: "",
            avatarImageSignature: "",
            avatarImageAssetName: nil,
            isArchived: plant.isArchived,
            needsCare: false,
            hasDueWatering: false,
            hasDueFertilizing: false,
            dueCareTypes: [],
            overdueCareTypes: [],
            dueCareCount: 0,
            overdueCareCount: 0,
            careDifficultyText: "",
            attentionText: "",
            todoText: ""
        )
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
