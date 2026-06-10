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
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }

    var body: some View {
        if card.isReal, !card.isDummy, !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            Button {
                quickFeed(pet)
            } label: {
                Label("喂食 \(pet.name)", systemImage: "fork.knife")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWaterManagement(pet)
            } label: {
                Label("水管理", systemImage: "water.waves")
            }

            Button {
                quickPotty(pet)
            } label: {
                Label("噗噗打卡", systemImage: "drop.circle")
            }

            Divider()

            Button {
                onOpenPet(pet)
            } label: {
                Label("查看详情", systemImage: "arrow.right.circle")
            }
        }
    }

    private func quickFeed(_ pet: Pet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let petID = pet.id
        commandQueue.enqueue(.quickCare(entityID: petID, action: "feed")) {
            commandExecutor.performActionType(
                "feed",
                petID: petID,
                executorId: currentUserId,
                now: Date(),
                antiRepeatTitle: "近期已喂食",
                antiRepeatMessage: { warning in "\(warning.executorName) \(warning.minutesAgo)分钟前已喂过" },
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
