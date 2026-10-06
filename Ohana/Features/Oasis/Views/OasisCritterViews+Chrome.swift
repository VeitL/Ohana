//
//  OasisCritterViews+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension OasisCritterCodexView {
    var pageBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if mode == .codex { collectionStrip } else { selectedDetail }
            }
            .padding(18)
        }
        .navigationTitle(headerTitle(entry: nil))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            OhanaModalToolbar(onClose: close)
            ToolbarItem(placement: .primaryAction) { coconutBalanceButton }
        }
        .navigationDestination(isPresented: Binding(
            get: { focusedCodexCatalogId != nil },
            set: { if !$0 { focusedCodexCatalogId = nil; lastInteractionOutcome = nil } }
        )) {
            ScrollView { selectedDetail.padding(18) }
                .navigationTitle(headerTitle(entry: focusedCodexCatalogId.flatMap { OasisUpgradeRewardCatalog.critter(id: $0) }))
                .navigationBarTitleDisplayMode(.inline)
        }
    }







    func close() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    func headerTitle(entry: OasisElectronicPetCatalogEntry?) -> String {
        if let entry {
            return entry.name(l)
        }
        return mode == .codex
            ? l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album")
            : l.tr(zh: "电子宠物小窝", en: "Critter Nest", de: "Critter-Nest")
    }

    func headerSubtitle(entry: OasisElectronicPetCatalogEntry?) -> String {
        if let entry {
            return entry.tagline(l)
        }
        return mode == .codex
            ? l.tr(zh: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) 已唤醒", en: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) awake", de: "\(ownedCount)/\(OasisUpgradeRewardCatalog.critters.count) wach")
            : l.tr(zh: "状态、照护和今日小愿望", en: "Status, care, and today's wish", de: "Status, Pflege und heutiger Wunsch")
    }
}
