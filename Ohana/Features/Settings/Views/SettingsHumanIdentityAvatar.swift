//
//  SettingsHumanIdentityAvatar.swift
//  Ohana
//

import SwiftUI

struct SettingsHumanIdentityAvatar: View {
    let human: SettingsHumanSnapshot
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.goPrimary.opacity(0.20) : Color.ohanaControlFill)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2))

            Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
    }
}
