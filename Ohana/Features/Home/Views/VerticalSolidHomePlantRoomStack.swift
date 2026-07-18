//
//  VerticalSolidHomePlantRoomStack.swift
//  Ohana
//
//  Room-level fan of the existing plant wallet cards.
//

import SwiftUI

struct VerticalSolidHomePlantRoomStack: View {
    let summary: VerticalSolidHomePlantRoomSummary
    let cards: [FocusCard]
    let containerWidth: CGFloat
    let localization: L10n
    let reduceMotion: Bool
    let avatarCacheRevision: Int
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var l: L10n { localization }

    private var visibleCards: [FocusCard] {
        Array(cards.prefix(VerticalSolidHomePlantRoomStackLayout.maxVisibleCards))
    }

    private var cardWidth: CGFloat {
        VerticalSolidHomePlantRoomStackLayout.cardWidth(containerWidth: containerWidth)
    }

    private var cardHeight: CGFloat {
        cardWidth * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
    }

    private var compactCornerRadius: CGFloat {
        max(
            16,
            FocusHomeVerticalSolidCollapsedLayoutPolicy.cardCornerRadius
                * cardWidth / VerticalSolidHomePlantExpandedGridLayout.minimumReadableRenderWidth
        )
    }

    var body: some View {
        Button {
            onOpen()
        } label: {
            ZStack {
                ForEach(Array(visibleCards.enumerated()).reversed(), id: \.element.id) { position, card in
                    cardLayer(card, position: position)
                }
            }
            .frame(
                width: containerWidth,
                height: VerticalSolidHomePlantRoomStackLayout.stackHeight(containerWidth: containerWidth)
            )
            .contentShape(Rectangle())
            .accessibilityHidden(true)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(l.tr(
            zh: "轻点展开这个房间的植物卡片",
            en: "Tap to open the plant cards in this room",
            de: "Tippen, um die Pflanzenkarten dieses Raums zu öffnen"
        ))
        .accessibilityIdentifier("home-plants-room-stack-\(identifier(summary.id))")
    }

    private func cardLayer(_ card: FocusCard, position: Int) -> some View {
        let transform = VerticalSolidHomePlantRoomStackLayout.transform(position: position)
        return ZStack(alignment: .bottom) {
            VerticalSolidHomePlantCompactCardSurface(
                card: card,
                displayWidth: cardWidth,
                reduceMotion: reduceMotion,
                localization: localization,
                avatarCacheRevision: avatarCacheRevision
            )

            if position == 0 {
                frontCardFooter
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(
            cornerRadius: compactCornerRadius,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(
                cornerRadius: compactCornerRadius,
                style: .continuous
            )
                .strokeBorder(
                    Color.ohanaGlassStroke.opacity(colorScheme == .dark ? 0.72 : 0.52),
                    lineWidth: position == 0 ? 1.2 : 0.8
                )
        }
        .shadow( // ui-v4: allow plant room card-stack depth distinguishes overlapping cards
            color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.13), // ui-v4: allow neutral adaptive shadow grounds colored wallet-card artwork
            radius: position == 0 ? 10 : 7,
            x: 0,
            y: position == 0 ? 7 : 4
        )
        .saturation(max(0.76, 1 - Double(position) * 0.055))
        .scaleEffect(transform.scale)
        .rotationEffect(.degrees(transform.rotationDegrees))
        .offset(x: transform.xOffset, y: transform.yOffset)
        .zIndex(Double(visibleCards.count - position))
        .accessibilityHidden(true)
    }

    private var frontCardFooter: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)

                Text(roomSummaryText)
                    .font(OhanaFont.adaptive(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            Spacer(minLength: 1)

            Image(systemName: "chevron.right") // a11y: allow decorative chevron is hidden and the room-stack Button is labeled
                .font(OhanaFont.adaptive(size: 8, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(width: 24, height: 24)
                .background(Color.ohanaControlFill.opacity(0.96), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.ohanaCardSurfaceElevated.opacity(colorScheme == .dark ? 0.94 : 0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ohanaDivider)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private var roomSummaryText: String {
        if summary.dueCount > 0 {
            return l.tr(
                zh: "\(summary.plantCount) 株 · \(summary.dueCount) 待照护",
                en: "\(summary.plantCount) plants · \(summary.dueCount) due",
                de: "\(summary.plantCount) Pflanzen · \(summary.dueCount) fällig"
            )
        }
        return l.tr(
            zh: "\(summary.plantCount) 株 · 状态良好",
            en: "\(summary.plantCount) plants · Good",
            de: "\(summary.plantCount) Pflanzen · Gut"
        )
    }

    private var accessibilityLabel: String {
        if summary.dueCount > 0 {
            return l.tr(
                zh: "\(summary.title)，\(summary.plantCount) 株植物，\(summary.dueCount) 株待照护",
                en: "\(summary.title), \(summary.plantCount) plants, \(summary.dueCount) need care",
                de: "\(summary.title), \(summary.plantCount) Pflanzen, \(summary.dueCount) fällig"
            )
        }
        return l.tr(
            zh: "\(summary.title)，\(summary.plantCount) 株植物，状态良好",
            en: "\(summary.title), \(summary.plantCount) plants, all good",
            de: "\(summary.title), \(summary.plantCount) Pflanzen, alles gut"
        )
    }

    private func identifier(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

struct VerticalSolidHomePlantCompactCardSurface: View {
    let card: FocusCard
    let displayWidth: CGFloat
    let reduceMotion: Bool
    let localization: L10n
    let avatarCacheRevision: Int

    private var renderWidth: CGFloat {
        max(displayWidth, VerticalSolidHomePlantExpandedGridLayout.minimumReadableRenderWidth)
    }

    private var renderHeight: CGFloat {
        renderWidth * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
    }

    private var displayHeight: CGFloat {
        displayWidth * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
    }

    private var scale: CGFloat {
        guard renderWidth > 0 else { return 1 }
        return displayWidth / renderWidth
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            FocusHomeVerticalSolidCardSurface(
                card: card,
                progress: 0,
                reduceMotion: reduceMotion,
                localization: localization,
                frozenAvatarSource: FocusHomeFrozenAvatarSource.cached(for: card)
            )
            .frame(width: renderWidth, height: renderHeight)
            .scaleEffect(scale, anchor: .topLeading)
            .id("\(card.id.uuidString)-\(avatarCacheRevision)")
        }
        .frame(width: displayWidth, height: displayHeight, alignment: .topLeading)
        .clipped()
        .accessibilityHidden(true)
    }
}
