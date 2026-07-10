import Foundation
import SwiftData
import Testing
import UIKit
@testable import Ohana

@MainActor
@Suite(.serialized)
struct AvatarAssetMaintenanceServiceTests {
    @Test func batchAdvancesAcrossPetAndHumanSourcesWithoutExceedingItsLimit() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for index in 0 ..< 3 {
            context.insert(Pet(name: "Pet \(index)", species: "猫"))
        }
        for index in 0 ..< 2 {
            context.insert(Human(name: "Human \(index)"))
        }
        try context.save()

        let actor = AvatarAssetMaintenanceActor(modelContainer: container)
        let first = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(first.scannedRecordCount == 2)
        #expect(first.compactedRecordCount == 0)
        #expect(first.nextCursor.source == .pet)
        #expect(first.nextCursor.offset == 2)
        #expect(!first.didComplete)

        let second = try await actor.runBatch(
            cursor: first.nextCursor,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(second.scannedRecordCount == 2)
        #expect(second.nextCursor.source == .human)
        #expect(second.nextCursor.offset == 1)
        #expect(!second.didComplete)

        let third = try await actor.runBatch(
            cursor: second.nextCursor,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(third.scannedRecordCount == 1)
        #expect(third.nextCursor.source == .complete)
        #expect(third.nextCursor.offset == 0)
        #expect(third.didComplete)
    }

    @Test func expiredDeadlineReturnsTheOriginalCursorWithoutScanning() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Pet(name: "Momo", species: "猫"))
        try context.save()

        let actor = AvatarAssetMaintenanceActor(modelContainer: container)
        let result = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 4,
            deadline: Date().addingTimeInterval(-1)
        )

        #expect(result.scannedRecordCount == 0)
        #expect(result.compactedRecordCount == 0)
        #expect(result.nextCursor == .initial)
        #expect(!result.didComplete)
    }

    @Test func batchCompactsLargeAvatarAndPersistsProgressBeforeFinalCompletion() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let originalData = try makeLargeJPEG()
        #expect(originalData.count > 700_000)

        let pet = Pet(name: "Momo", species: "猫")
        pet.avatarImageData = originalData
        context.insert(pet)
        try context.save()

        let actor = AvatarAssetMaintenanceActor(modelContainer: container)
        let first = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 1,
            deadline: .distantFuture
        )
        #expect(first.scannedRecordCount == 1)
        #expect(first.compactedRecordCount == 1)
        #expect(!first.didComplete)

        let verificationContext = ModelContext(container)
        let petID = pet.id
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { candidate in
                candidate.id == petID
            }
        )
        descriptor.fetchLimit = 1
        let compactedData = try #require(verificationContext.fetch(descriptor).first?.avatarImageData)
        #expect(compactedData.count < originalData.count)

        let final = try await actor.runBatch(
            cursor: first.nextCursor,
            maximumRecordCount: 1,
            deadline: .distantFuture
        )
        #expect(final.didComplete)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeLargeJPEG() throws -> Data {
        let width = 1024
        let height = 1024
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var state: UInt32 = 0x9E37_79B9

        for index in stride(from: 0, to: pixels.count, by: 4) {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            pixels[index] = UInt8(truncatingIfNeeded: state)
            pixels[index + 1] = UInt8(truncatingIfNeeded: state >> 8)
            pixels[index + 2] = UInt8(truncatingIfNeeded: state >> 16)
            pixels[index + 3] = 255
        }

        let data = Data(pixels)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let provider = try #require(CGDataProvider(data: data as CFData))
        let image = try #require(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
        return try #require(UIImage(cgImage: image).jpegData(compressionQuality: 0.98))
    }
}
