//
//  FocusHomeCardContextMenu.swift
//  Ohana
//
//  Context-menu actions for wallet cards, separated from the home container.
//

import SwiftData
import SwiftUI

struct FocusHomeCardContextMenu: View {
    let card: FocusCard
    let pets: [Pet]
    let currentUserId: String?
    let modelContext: ModelContext
    let onWaterManagement: (Pet) -> Void
    let onOpenPet: (Pet) -> Void

    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }

    var body: some View {
        if card.isReal, !card.isDummy, !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            Button {
                quickFeed(pet)
            } label: {
                Label(l.tr(zh: "喂食 \(pet.name)", en: "Feed \(pet.name)", de: "\(pet.name) fuettern"), systemImage: "fork.knife")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWaterManagement(pet)
            } label: {
                Label(l.tr(zh: "水管理", en: "Water", de: "Wasser"), systemImage: "water.waves")
            }

            Button {
                quickPotty(pet)
            } label: {
                Label(l.tr(zh: "噗噗打卡", en: "Poop check-in", de: "Kot erfassen"), systemImage: "drop.circle")
            }

            Divider()

            Button {
                onOpenPet(pet)
            } label: {
                Label(l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"), systemImage: "arrow.right.circle")
            }
        }
    }

    private func quickFeed(_ pet: Pet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let petID = pet.id
        commandQueue.enqueue(.quickCare(entityID: petID, action: "feed")) {
            commandExecutor.performQuickAction(
                HomePetQuickActionRequest(
                    action: .feed,
                    petID: petID,
                    executorID: currentUserId,
                    now: Date()
                ),
                actions: HomePetQuickActionActions(
                antiRepeatTitle: l.tr(zh: "近期已喂食", en: "Recently fed", de: "Kuerzlich gefuettert"),
                antiRepeatMessage: { warning in
                    l.tr(
                        zh: "\(warning.executorName) \(warning.minutesAgo)分钟前已喂过",
                        en: "\(warning.executorName) fed \(warning.minutesAgo) minutes ago",
                        de: "\(warning.executorName) hat vor \(warning.minutesAgo) Minuten gefuettert"
                    )
                },
                openFeedDetail: { _, _ in },
                showAntiRepeat: { _, _, pendingAction in pendingAction() },
                startWalk: { _ in },
                openWaterManagement: { waterPetID in
                    if let target = pets.first(where: { $0.id == waterPetID }) {
                        onWaterManagement(target)
                    }
                },
                openMedication: { _ in },
                feedback: { _ in }
                )
            )
        }
    }

    private func quickPotty(_ pet: Pet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let petID = pet.id
        let raw = PottyType.perfectPoop.rawValue
        commandQueue.enqueue(.quickCare(entityID: petID, action: "potty:\(raw)")) {
            commandExecutor.applyPottyCheckIn(
                raw: raw,
                petID: petID,
                executorId: currentUserId,
                feedback: { _ in }
            )
        }
    }
}
