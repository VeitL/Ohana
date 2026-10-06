//
//  QuickFeedButtons.swift
//  Ohana
//
//  Shared feeding form buttons.
//

import SwiftUI

struct FoodPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(Color.arkInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
