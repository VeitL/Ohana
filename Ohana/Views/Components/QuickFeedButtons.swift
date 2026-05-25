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
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
