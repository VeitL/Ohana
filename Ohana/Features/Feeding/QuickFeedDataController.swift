//
//  QuickFeedDataController.swift
//  Ohana
//
//  Route-scoped data cache for heavier QuickFeed detail surfaces.
//

import Combine
import Foundation

@MainActor
final class QuickFeedDataController: ObservableObject {
    @Published var loadedCareLogs: [PetCareLog] = []
    @Published var loadedFoodRecords: [PetFoodRecord] = []
    @Published var hasLoadedFullCareLogs = false
    @Published var hasLoadedFullFoodRecords = false

    func observedCareLogs(fallback: [PetCareLog]) -> [PetCareLog] {
        hasLoadedFullCareLogs ? loadedCareLogs : fallback
    }

    func observedFoodRecords(fallback: [PetFoodRecord]) -> [PetFoodRecord] {
        hasLoadedFullFoodRecords ? loadedFoodRecords : fallback
    }

    func loadFullCareLogs(
        petID: UUID,
        feedingType: String,
        fallback: [PetCareLog],
        force: Bool = false,
        fetcher: (UUID, String, [PetCareLog]) -> [PetCareLog]
    ) {
        guard force || !hasLoadedFullCareLogs else { return }
        loadedCareLogs = fetcher(petID, feedingType, fallback)
        hasLoadedFullCareLogs = true
    }

    func loadFullFoodRecords(
        petID: UUID,
        fallback: [PetFoodRecord],
        force: Bool = false,
        fetcher: (UUID, [PetFoodRecord]) -> [PetFoodRecord]
    ) {
        guard force || !hasLoadedFullFoodRecords else { return }
        loadedFoodRecords = fetcher(petID, fallback)
        hasLoadedFullFoodRecords = true
    }
}
