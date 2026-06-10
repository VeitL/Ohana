import SwiftUI

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let tertiaryText: Color
    let reduceTransparency: Bool
    private let content: Content

    init(
        title: String,
        tertiaryText: Color,
        reduceTransparency: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.tertiaryText = tertiaryText
        self.reduceTransparency = reduceTransparency
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.goPrimary)
                    .frame(width: 3, height: 14) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(title.uppercased())
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(tertiaryText)
                    .tracking(1.2)
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(
                reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
    }
}
