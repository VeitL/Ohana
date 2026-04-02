import SwiftUI

struct GlobalCoconutButtonOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button { isPresented = true } label: {
                    HStack(spacing: 5) {
                        Text("🥥").font(.system(size: 15))
                        Text("\(QuestManager.shared.coconutCount)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: QuestManager.shared.coconutCount)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.goYellow.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.goYellow.opacity(0.3), lineWidth: 1))
                    .shadow(color: Color.goYellow.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
            Spacer()
        }
        // 让按钮始终位于最上层右上角，不被 safe area/导航栏挤压
        .safeAreaPadding(.top, 44)
        .allowsHitTesting(true)
    }
}
