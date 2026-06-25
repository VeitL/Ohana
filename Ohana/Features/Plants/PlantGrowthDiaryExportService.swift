//
//  PlantGrowthDiaryExportService.swift
//  Ohana
//
//  Creates portable plant growth diary exports without making full-photo
//  payloads the default path.
//

import Foundation

struct PlantGrowthDiaryExportPayload: Codable, Equatable {
    var schemaVersion: Int
    var exportedAt: Date
    var plantID: UUID
    var plantName: String
    var species: String
    var location: String
    var createdAt: Date
    var acquiredDate: Date?
    var healthStatusRaw: String
    var entries: [PlantGrowthDiaryExportEntry]
}

struct PlantGrowthDiaryExportEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var careTypeRaw: String
    var careTypeTitle: String
    var note: String
    var healthStatusRaw: String?
    var hasPhoto: Bool
    var photoByteCount: Int
    var photoBase64: String?
}

@MainActor
enum PlantGrowthDiaryExportService {
    static func makePayload(
        for plant: Plant,
        exportedAt: Date = Date(),
        includePhotos: Bool = false
    ) -> PlantGrowthDiaryExportPayload {
        let entries = plant.careLogs
            .sorted { $0.date < $1.date }
            .map { log in
                PlantGrowthDiaryExportEntry(
                    id: log.id,
                    date: log.date,
                    careTypeRaw: log.careType.rawValue,
                    careTypeTitle: log.careType.displayName,
                    note: log.note,
                    healthStatusRaw: log.healthStatusRaw.isEmpty ? nil : log.healthStatusRaw,
                    hasPhoto: log.photoData != nil,
                    photoByteCount: log.photoData?.count ?? 0,
                    photoBase64: includePhotos ? log.photoData?.base64EncodedString() : nil
                )
            }

        return PlantGrowthDiaryExportPayload(
            schemaVersion: 1,
            exportedAt: exportedAt,
            plantID: plant.id,
            plantName: plant.name,
            species: plant.species,
            location: plant.location,
            createdAt: plant.createdAt,
            acquiredDate: plant.acquiredDate,
            healthStatusRaw: plant.healthStatusRaw,
            entries: entries
        )
    }

    static func jsonData(
        for plant: Plant,
        exportedAt: Date = Date(),
        includePhotos: Bool = false
    ) throws -> Data {
        let payload = makePayload(for: plant, exportedAt: exportedAt, includePhotos: includePhotos)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func markdown(
        for plant: Plant,
        exportedAt: Date = Date(),
        includePhotoPlaceholders: Bool = true,
        languageCode: String = AppLanguage.code
    ) -> String {
        markdown(
            for: makePayload(for: plant, exportedAt: exportedAt, includePhotos: false),
            includePhotoPlaceholders: includePhotoPlaceholders,
            languageCode: languageCode
        )
    }

    static func markdown(
        for payload: PlantGrowthDiaryExportPayload,
        includePhotoPlaceholders: Bool = true,
        languageCode: String = AppLanguage.code
    ) -> String {
        let l = L10n(languageCode)
        let formatter = ISO8601DateFormatter()
        let species = payload.species.isEmpty ? l.tr(zh: "未知", en: "Unknown") : payload.species
        let location = payload.location.isEmpty ? l.tr(zh: "未设置", en: "Unspecified") : payload.location
        var lines: [String] = [
            "# \(payload.plantName)",
            "",
            "- \(l.tr(zh: "物种", en: "Species")): \(species)",
            "- \(l.tr(zh: "位置", en: "Location")): \(location)",
            "- \(l.tr(zh: "当前健康", en: "Current health")): \(payload.healthStatusRaw)",
            "- \(l.tr(zh: "导出时间", en: "Exported at")): \(formatter.string(from: payload.exportedAt))",
            ""
        ]

        for entry in payload.entries {
            lines.append("## \(formatter.string(from: entry.date)) · \(entry.careTypeTitle)")
            if let healthStatusRaw = entry.healthStatusRaw {
                lines.append("- \(l.tr(zh: "健康", en: "Health")): \(healthStatusRaw)")
            }
            if !entry.note.isEmpty {
                lines.append(entry.note)
            }
            if includePhotoPlaceholders, entry.hasPhoto {
                let photoLabel = l.tr(zh: "照片", en: "Photo")
                let sourceCopy = l.tr(
                    zh: "保留在 Ohana 备份/导出源中",
                    en: "kept in the Ohana backup/export source"
                )
                lines.append("- \(photoLabel): \(entry.photoByteCount) bytes, \(sourceCopy)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
