//
//  HumanPasscodePad.swift
//  Ohana
//
//  Shared passcode keypad.
//

import SwiftData
import SwiftUI

struct HumanPasscodePad: View {
    @Binding var pin: String
    var accent: Color
    var onComplete: () -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "delete"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                ForEach(0 ..< 4, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? accent : Color.primary.opacity(0.16))
                        .frame(width: 12, height: 12) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .animation(GoMotion.feedback, value: pin.count)
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(height: 46)
                    } else {
                        Button {
                            press(key)
                        } label: {
                            Group {
                                if key == "delete" {
                                    Image(systemName: "delete.left.fill") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                } else {
                                    Text(key)
                                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                }
                            }
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private func press(_ key: String) {
        if key == "delete" {
            if !pin.isEmpty { pin.removeLast() }
            return
        }
        guard pin.count < 4 else { return }
        pin.append(key)
        if pin.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                onComplete()
            }
        }
    }
}
