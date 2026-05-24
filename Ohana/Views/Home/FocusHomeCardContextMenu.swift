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

    var body: some View {
        if card.isReal && !card.isDummy && !card.isHuman,
           let pet = pets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let log = PetCareLog(
                    date: Date(),
                    type: .feeding,
                    amountGrams: pet.dailyPortionGrams,
                    note: PetCareLog.manualFeedNoteMarker,
                    pet: pet,
                    executorId: currentUserId
                )
                modelContext.insert(log)
                modelContext.safeSave()
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
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: currentUserId)
                modelContext.insert(log)
                modelContext.safeSave()
            } label: {
                Label("便便记录", systemImage: "drop.circle")
            }

            Divider()

            Button {
                onOpenPet(pet)
            } label: {
                Label("查看详情", systemImage: "arrow.right.circle")
            }
        }
    }
}
