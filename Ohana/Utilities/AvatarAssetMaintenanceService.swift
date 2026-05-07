//
//  AvatarAssetMaintenanceService.swift
//  Ohana
//
//  Keeps stored profile images near their largest display size so SwiftData
//  startup queries do not repeatedly load oversized camera assets.
//

import Foundation
import SwiftData
import UIKit

@MainActor
enum AvatarAssetMaintenanceService {
    nonisolated private static let maxStoredPixel: CGFloat = 900
    nonisolated private static let largeAssetThreshold = 700_000

    private struct AvatarPayload: Sendable {
        let id: UUID
        let data: Data
    }

    static func compactStoredAvatars(context: ModelContext) async {
        let existingPets = (try? context.fetch(FetchDescriptor<Pet>())) ?? []
        let petPayloads = existingPets.compactMap { pet -> AvatarPayload? in
            guard let data = pet.avatarImageData else { return nil }
            return AvatarPayload(id: pet.id, data: data)
        }

        let existingHumans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        let humanPayloads = existingHumans.compactMap { human -> AvatarPayload? in
            guard let data = human.avatarImageData else { return nil }
            return AvatarPayload(id: human.id, data: data)
        }

        let updates = await Task.detached(priority: .utility) {
            let petUpdates = petPayloads.compactMap { payload -> (UUID, Data)? in
                guard let compacted = compactedAvatarData(from: payload.data) else { return nil }
                return (payload.id, compacted)
            }
            let humanUpdates = humanPayloads.compactMap { payload -> (UUID, Data)? in
                guard let compacted = compactedAvatarData(from: payload.data) else { return nil }
                return (payload.id, compacted)
            }
            return (petUpdates, humanUpdates)
        }.value

        var didChange = false
        let pets = (try? context.fetch(FetchDescriptor<Pet>())) ?? []
        let compactedPets = Dictionary(uniqueKeysWithValues: updates.0)
        for pet in pets where compactedPets[pet.id] != nil {
            guard let compacted = compactedPets[pet.id] else { continue }
            pet.avatarImageData = compacted
            didChange = true
        }

        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        let compactedHumans = Dictionary(uniqueKeysWithValues: updates.1)
        for human in humans where compactedHumans[human.id] != nil {
            guard let compacted = compactedHumans[human.id] else { continue }
            human.avatarImageData = compacted
            didChange = true
        }

        if didChange {
            context.safeSave()
        }
    }

    nonisolated private static func compactedAvatarData(from data: Data) -> Data? {
        guard data.count > largeAssetThreshold, let image = UIImage(data: data) else { return nil }

        let preservesAlpha = ImageCutoutService.isTransparentPNG(data)
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxStoredPixel || data.count > largeAssetThreshold else { return nil }

        let targetImage: UIImage
        if longest > maxStoredPixel {
            let scale = maxStoredPixel / longest
            let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = !preservesAlpha
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = image
        }

        let encoded = preservesAlpha
            ? targetImage.pngData()
            : targetImage.jpegData(compressionQuality: 0.88)
        guard let encoded, encoded.count < data.count else { return nil }
        return encoded
    }
}
