import SwiftUI

struct GlobalCoconutButtonOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                CoconutBalanceCapsule {
                    isPresented = true
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
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
