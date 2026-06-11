//
//  ExpandedQuickActionsSection+LegacyAndPrompt.swift
//  Ohana
//

import SwiftUI
import UniformTypeIdentifiers

struct LegacyExpandedQuickModulesView: View {
    let card: FocusCard
    let titleForAction: (String) -> String
    let onAction: (FocusCard.Action) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(card.actions.prefix(4)) { action in
                Button {
                    onAction(action)
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        OhanaQuickActionIcon(
                            actionType: action.label,
                            fallbackSystemName: action.icon,
                            size: 30,
                            color: Color.ohanaFunctionalIcon
                        )
                        .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

                        VStack(alignment: .leading, spacing: 1) {
                            Text(titleForAction(action.label))
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(card.isReal && !card.isHuman ? "快速打卡" : "查看")
                                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaTertiaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("\(card.name) \(titleForAction(action.label))")
            }
        }
    }
}

struct ExpandedFirstSuccessPrompt: View {
    let onFeed: () -> Void
    let onPlay: () -> Void
    let onMoment: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            button(title: "喂食", actionType: "feed", icon: "fork.knife", action: onFeed)
            button(title: "陪玩", actionType: "play", icon: "tennisball.fill", action: onPlay)
            button(title: "记录", actionType: "moment", icon: "camera.fill", action: onMoment)
        }
        .padding(8)
        .background(Color.ohanaCardSurface.opacity(0.52), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.26), lineWidth: 1)
        )
    }

    func button(title: String, actionType: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.medium()
            action()
        } label: {
            VStack(spacing: 6) {
                OhanaQuickActionIcon(
                    actionType: actionType,
                    fallbackSystemName: icon,
                    size: 28,
                    color: Color.goPrimary
                )
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
