//
//  PlantFocusCardAdapter.swift
//  Ohana
//
//  Maps Plant records into the shared wallet-card render model.
//

import Foundation
import SwiftData
import SwiftUI

extension FocusCard {
    nonisolated static func fromPlant(
        _ plant: Plant,
        catalog: PlantCatalogEntry? = nil,
        nextTask: PlantCareTaskSnapshot? = nil,
        includeAvatarData: Bool = false,
        localization l: L10n = L10n.current
    ) -> FocusCard {
        let safeName = plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? l.tr(zh: "植物", en: "Plant", de: "Pflanze")
            : plant.name
        let safeSpecies = plant.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (catalog?.latinName ?? l.tr(zh: "植物", en: "Plant", de: "Pflanze"))
            : plant.species
        let days = max(0, Calendar.current.dateComponents([.day], from: plant.createdAt, to: Date()).day ?? 0)
        let needsCare = nextTask?.daysUntilDue ?? 1 <= 0 || plant.needsWatering || plant.needsFertilizing
        let status = needsCare
            ? l.tr(zh: "待照护", en: "Needs care", de: "Braucht Pflege")
            : plant.healthStatus.displayName
        let assetName = catalog?.catalogImageAssetName ?? PlantCatalogMedia.localFoliage.assetName
        let hasAvatarAttachment = plant.hasAvatarImageAttachment
        let avatarData = includeAvatarData && hasAvatarAttachment ? plant.avatarImageData : nil
        let theme = plant.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "2ED3B7"
            : plant.themeColorHex
        let primaryAction = nextTask.map {
            Action(
                label: $0.careType.displayName(l: l).uppercased(),
                icon: plantWalletIcon(for: $0.careType),
                colorHex: plantWalletColorHex(for: $0.careType)
            )
        } ?? Action(label: l.tr(zh: "浇水", en: "WATER", de: "GIESSEN"), icon: "drop.fill", colorHex: "00D4AA")

        return FocusCard(
            id: plant.id,
            modelID: plant.persistentModelID,
            name: safeName,
            kind: safeSpecies,
            emoji: plant.avatarEmoji.isEmpty ? "leaf.fill" : plant.avatarEmoji,
            color: Color(hex: theme),
            streak: 0,
            coconutBalance: max(0, plant.careLogs.count),
            createdAt: plant.createdAt,
            daysTogetherText: l.tr(zh: "\(days) 天", en: "\(days) days", de: "\(days) Tage"),
            togetherHeadlineText: l.tr(zh: "养护 \(days) 天", en: "\(days) days in care", de: "\(days) Tage Pflege"),
            ageText: status,
            personalityHint: plant.location.isEmpty ? plant.roomName : plant.location,
            avatarImageData: avatarData,
            avatarImageSignature: hasAvatarAttachment ? plant.avatarThumbnailSignature : "asset:\(assetName)",
            avatarImageAssetName: hasAvatarAttachment ? nil : assetName,
            cardStyleRaw: "classic",
            petSpecies: safeSpecies,
            themeColorHex: theme,
            daysTogether: days,
            breed: catalog?.localizedCommonName ?? safeSpecies,
            statusBadgeText: status,
            statusBadgeIsWarning: needsCare || plant.healthStatus == .stressed,
            isPlant: true,
            isReal: true,
            actions: [
                primaryAction,
                .init(label: l.tr(zh: "施肥", en: "FERTILIZE", de: "DUENGEN"), icon: "leaf.fill", colorHex: "9EF06A"),
                .init(label: l.tr(zh: "记录", en: "NOTE", de: "NOTIZ"), icon: "note.text", colorHex: "A78BFA"),
                .init(label: l.tr(zh: "详情", en: "DETAIL", de: "DETAIL"), icon: "arrow.right.circle.fill", colorHex: "BDEFA4")
            ]
        )
    }

    private nonisolated static func plantWalletIcon(for type: PlantCareType) -> String {
        switch type {
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .photo: "camera.fill"
        case .newLeaf: "sparkles"
        case .yellowLeaf, .pestFound: "exclamationmark.triangle.fill"
        case .pestCheck: "magnifyingglass"
        case .repotting: "shippingbox.fill"
        case .pruning: "scissors"
        case .misting: "cloud.drizzle.fill"
        case .rotating: "arrow.triangle.2.circlepath"
        case .leafCleaning: "hands.sparkles.fill"
        case .customNote: "note.text"
        }
    }

    private nonisolated static func plantWalletColorHex(for type: PlantCareType) -> String {
        switch type {
        case .watering, .misting: "00D4AA"
        case .fertilizing, .newLeaf, .leafCleaning: "9EF06A"
        case .photo, .customNote: "A78BFA"
        case .yellowLeaf, .pestFound, .pestCheck: "F59E0B"
        case .repotting, .pruning, .rotating: "2ED3B7"
        }
    }
}
