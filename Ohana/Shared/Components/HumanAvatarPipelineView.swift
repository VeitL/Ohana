import SwiftData
import SwiftUI

struct HumanAvatarPipelineView: View {
    let human: Human
    let size: CGFloat
    var fallbackScale: CGFloat = 0.56
    var showsBackground: Bool = true
    var backgroundOpacity: Double = 0.22
    var clipsToCircle: Bool = true

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current

    private var signature: String? {
        human.hasAvatarImageAttachment ? human.avatarThumbnailSignature : nil
    }

    private var pipelineKey: String {
        "human-avatar-\(human.id.uuidString)-\(signature ?? "empty")-\(Int(size.rounded()))"
    }

    var body: some View {
        ZStack {
            if showsBackground {
                Circle()
                    .fill(Color(hex: human.themeColor).opacity(backgroundOpacity))
            }

            if let signature,
               let image = avatarPipeline.cachedImage(for: human.id, signature: signature) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: size * fallbackScale))
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .task(id: pipelineKey) {
            await prepareAvatarImage()
        }
        .onDisappear {
            AvatarPipelineRegistry.current.cancel(key: pipelineKey)
        }
    }

    @MainActor
    private func prepareAvatarImage() async {
        guard let signature,
              human.hasAvatarImageAttachment else {
            AvatarPipelineRegistry.current.cancel(key: pipelineKey)
            return
        }

        let humanID = human.id
        let modelID = human.persistentModelID
        let key = pipelineKey
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        guard let data = await loader.humanAvatarImageData(modelID: modelID),
              !Task.isCancelled,
              human.id == humanID,
              self.signature == signature else {
            return
        }

        AvatarPipelineRegistry.current.preload(
            payloads: [FocusWalletAvatarCache.Payload(id: humanID, data: data)],
            key: key,
            delayMilliseconds: 24
        )
    }
}
