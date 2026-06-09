import SwiftUI
import UIKit

struct AsyncDecodedImageView<Content: View, Placeholder: View>: View {
    let data: Data?
    private let content: (UIImage) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(
        data: Data?,
        @ViewBuilder content: @escaping (UIImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.data = data
        self.content = content
        self.placeholder = placeholder
    }

    private var decodeKey: String {
        guard let data else { return "none" }
        return "\(data.count)-\(data.hashValue)"
    }

    var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                placeholder()
            }
        }
        .task(id: decodeKey) {
            await decodeImage()
        }
    }

    @MainActor
    private func decodeImage() async {
        guard let data else {
            image = nil
            return
        }
        let decoded = await AttachmentImageDecoder.decode(data)
        guard !Task.isCancelled else { return }
        image = decoded
    }
}
