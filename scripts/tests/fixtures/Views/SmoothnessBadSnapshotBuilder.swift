// Audit fixture: every marked line must trigger the named audit-smoothness-risk rule.
// The file lives under a Views/ path and is named *SnapshotBuilder.swift on purpose,
// so both the path-scoped and filename-scoped rules apply.
import SwiftData
import SwiftUI

struct SmoothnessBadFixture: View {
    @Query private var pets: [Pet] // rule: broad-query-high-frequency

    var body: some View {
        let image = UIImage(data: Data()) // rule: sync-image-decode-in-view
        let decoded = Task { await AttachmentImageDecoder.decode(Data()) } // rule: direct-attachment-image-decode-in-view
        let avatarProbe = pet.avatarImageData?.count // rule: render-external-storage-signature
        let localAvatarKey = avatarImageData?.count // rule: render-local-media-data-key
        let avatarSignature = pet.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) // rule: render-external-storage-signature-map
        let directAvatar = PetAvatarPortraitView(imageData: pet.avatarImageData, fallbackText: "🐾", themeColor: .blue, size: 44) // rule: render-live-avatar-data-parameter
        let avatarPipelineBlob = human.avatarImageData // rule: avatar-pipeline-direct-human-blob-read
        let featureHubLiveAvatar = pet.hasAvatarImageAttachment ? pet.avatarImageData : nil // rule: feature-hub-live-avatar-provider
        let imageData: Data = log.imageData // rule: weekly-photo-memory-eager-blob
        if let milestonePhotoData = milestone.photoData { // rule: milestone-photo-eager-blob
            _ = milestonePhotoData
        }
        if let petPhotoData = photoLog.imageData { // rule: pet-photo-log-eager-blob
            _ = petPhotoData
        }
        if let plantPhotoData = log.photoData { // rule: plant-care-log-eager-blob
            _ = plantPhotoData
        }
        let avatarTransparency = PetAvatarTransparencyCache.isTransparentAvatar(pet.avatarImageData ?? Data()) // rule: render-avatar-transparency-probe
        let photoPresenceProbe = plant.careLogs.first { $0.photoData != nil } // rule: render-photo-data-presence-probe
        let imagePresenceProbe = pet.photoLogs.first { $0.imageData.isEmpty } // rule: render-image-data-presence-probe
        let documentAttachmentProbe = pet.documents.first?.attachments.map(\.data) // rule: render-document-attachment-data-probe
        let exportSummaryText = "expensive"
        let timer = Timer.publish(every: 1, on: .main, in: .common) // rule: runtime-loop-in-view
        _ = (image, decoded, avatarProbe, localAvatarKey, avatarSignature, directAvatar, avatarPipelineBlob, featureHubLiveAvatar, imageData, avatarTransparency, photoPresenceProbe, imagePresenceProbe, documentAttachmentProbe, timer)
        return VStack {
            Text("bad")
            ShareLink(item: exportSummaryText) { // rule: eager-sharelink-export
                Text("Share")
            }
        }
            .onAppear {
                Task { @MainActor in // rule: main-actor-aggregation
                    let descriptor = FetchDescriptor<Pet>()
                    _ = try? modelContext.fetch(descriptor) // rule: view-imperative-fetch
                }
                Task.detached { // rule: detached-task-in-view
                    print("escapes route cancellation")
                }
            }
    }

    func petPhotoBlob(photoLog: PetPhotoLog) -> Data {
        return photoLog.imageData // rule: pet-photo-log-eager-blob
    }
}
