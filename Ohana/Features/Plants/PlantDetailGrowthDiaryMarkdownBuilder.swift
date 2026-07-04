//
//  PlantDetailGrowthDiaryMarkdownBuilder.swift
//  Ohana
//
//  Created by Codex on 04.07.26.
//

import Foundation

nonisolated enum PlantDetailGrowthDiaryMarkdownBuilder {
    static func markdown(
        plantID: UUID,
        plantName: String,
        species: String,
        location: String,
        createdAt: Date,
        acquiredDate: Date?,
        healthStatusRaw: String,
        logs: [PlantDetailLogSnapshot],
        languageCode: String
    ) -> String {
        let l = L10n(languageCode)
        let payload = PlantGrowthDiaryExportPayload(
            schemaVersion: 1,
            exportedAt: Date(),
            plantID: plantID,
            plantName: plantName,
            species: species,
            location: location,
            createdAt: createdAt,
            acquiredDate: acquiredDate,
            healthStatusRaw: healthStatusRaw,
            entries: logs.reversed().map { log in
                PlantGrowthDiaryExportEntry(
                    id: log.id,
                    date: log.date,
                    careTypeRaw: log.careType.rawValue,
                    careTypeTitle: log.careType.displayName(l: l),
                    note: log.note,
                    healthStatusRaw: log.healthStatusRaw.isEmpty ? nil : log.healthStatusRaw,
                    hasPhoto: log.hasPhoto,
                    photoByteCount: 0,
                    photoBase64: nil
                )
            }
        )
        return PlantGrowthDiaryExportService.markdown(
            for: payload,
            includePhotoPlaceholders: true,
            languageCode: languageCode
        )
    }
}
