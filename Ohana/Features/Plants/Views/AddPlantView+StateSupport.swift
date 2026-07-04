//
//  AddPlantView+StateSupport.swift
//  Ohana
//
//  Created by Codex on 04.07.26.
//

import SwiftUI

extension AddPlantView {
    enum AddPlantFocusField: Hashable {
        case name
        case species
        case catalogSearch
        case room
        case location
        case potMaterial
        case soil
        case source
    }

    var plantEmojis: [String] {
        ["🌱", "🌿", "🍀", "🌵", "🌻", "🌹", "🌺", "🪴", "🌳", "🎋", "🌾", "💐"]
    }

    var selectedCatalog: PlantCatalogEntry? {
        selectedCatalogID.isEmpty ? nil : PlantCatalog.entry(id: selectedCatalogID)
    }

    var l: L10n { L10n(appLanguage) }

    var groupedCatalogEntries: [PlantCatalogEntry] {
        AddPlantCatalogPickerModel.entries(for: selectedCatalogGroup)
    }

    var commonRoomOptions: [String] {
        AddPlantChoiceLibrary.roomOptions(l)
    }

    var commonSpotOptions: [String] {
        AddPlantChoiceLibrary.spotOptions(l)
    }

    var commonPotMaterialOptions: [String] {
        AddPlantChoiceLibrary.potMaterialOptions(l)
    }

    var commonSoilOptions: [String] {
        AddPlantChoiceLibrary.soilOptions(l)
    }

    var commonSourceOptions: [String] {
        AddPlantChoiceLibrary.sourceOptions(l)
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSpecies: String {
        species.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedRoomName: String {
        roomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var usesCustomRoomEntry: Bool {
        !trimmedRoomName.isEmpty && !commonRoomOptions.contains(trimmedRoomName)
    }

    var usesCustomLocationEntry: Bool {
        !trimmedLocation.isEmpty && !commonSpotOptions.contains(trimmedLocation)
    }

    var catalogMatches: [PlantCatalogSearchResult] {
        PlantCatalog.searchResults(catalogQuery, limit: 8)
    }

    var profilePreviewName: String {
        trimmedName.isEmpty ? l.tr(zh: "新植物", en: "New plant", de: "Neue Pflanze") : trimmedName
    }

    var profilePreviewSpecies: String {
        if let selectedCatalog {
            return selectedCatalog.localizedCommonName
        }
        if !trimmedSpecies.isEmpty {
            return trimmedSpecies
        }
        return l.tr(zh: "品种可选", en: "Species optional", de: "Art optional")
    }

    var carePlanPreviewSummary: String {
        l.tr(
            zh: "浇水 \(wateringInterval) 天 · 施肥 \(fertilizingInterval) 天 · \(lightLevel.displayName)",
            en: "Water \(wateringInterval)d · fertilize \(fertilizingInterval)d · \(lightLevel.displayName)",
            de: "Gießen \(wateringInterval) T. · düngen \(fertilizingInterval) T. · \(lightLevel.displayName)"
        )
    }

    var carePlanPreviewDetail: String {
        if let selectedCatalog {
            return l.tr(
                zh: "已使用资料库默认值：\(selectedCatalog.localizedCommonName)",
                en: "Using catalog defaults for \(selectedCatalog.localizedCommonName)",
                de: "Katalogwerte für \(selectedCatalog.localizedCommonName) aktiv"
            )
        }
        return l.tr(
            zh: "不知道品种也可以先用默认节奏，之后按记录调整。",
            en: "If the species is unknown, start with this simple cadence and adjust from later logs.",
            de: "Ist die Art unbekannt, starte mit diesem einfachen Rhythmus und passe ihn später an."
        )
    }

    var duplicateDraft: PlantDuplicateScanDraft {
        PlantDuplicateScanDraft(
            name: name,
            species: species,
            roomName: roomName,
            location: location,
            catalogSpeciesId: selectedCatalogID
        )
    }

    var duplicateCandidates: [PlantDuplicateCandidate] {
        PlantProfileUXPolicy.duplicateCandidates(
            draft: duplicateDraft,
            existingPlants: existingPlantSnapshots
        )
    }

    var currentDuplicateAcknowledgementKey: String {
        PlantProfileUXPolicy.duplicateAcknowledgementKey(for: duplicateDraft)
    }

    var requiresDuplicateAcknowledgement: Bool {
        !duplicateCandidates.isEmpty && duplicateAcknowledgementKey != currentDuplicateAcknowledgementKey
    }
}
