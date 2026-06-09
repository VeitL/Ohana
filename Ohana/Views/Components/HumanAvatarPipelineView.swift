import SwiftUI

struct HumanAvatarPipelineView: View {
    let human: Human
    let size: CGFloat
    var fallbackScale: CGFloat = 0.56
    var showsBackground: Bool = true
    var backgroundOpacity: Double = 0.22
    var clipsToCircle: Bool = true

    @ObservedObject private var avatarPipeline = AvatarPipeline.shared

    private var signature: String? {
        human.avatarImageData.map { FocusWalletAvatarCache.signature(for: $0) }
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

            if human.avatarImageData != nil,
               let signature,
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
        .task(id: signature) {
            guard let data = human.avatarImageData else { return }
            AvatarPipeline.shared.preload(
                payloads: [FocusWalletAvatarCache.Payload(id: human.id, data: data)],
                key: pipelineKey,
                delayMilliseconds: 24
            )
        }
        .onDisappear {
            AvatarPipeline.shared.cancel(key: pipelineKey)
        }
    }
}
