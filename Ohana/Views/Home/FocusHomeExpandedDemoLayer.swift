//
//  FocusHomeExpandedDemoLayer.swift
//  Ohana
//
//  Full-screen expanded demo-card shell extracted from the main home view.
//

import SwiftUI

struct FocusHomeExpandedDemoLayer<FabOverlay: View>: View {
    let card: FocusCard
    let outerCornerRadius: CGFloat
    let windowSize: CGSize
    let safeAreaTop: CGFloat
    let floatingFabBottomPadding: CGFloat
    let namespace: Namespace.ID
    let expandedId: UUID?
    let transitionAnimation: Animation
    let isInlineRecordOverlayPresented: Bool
    @Binding var detailFooterVisible: Bool
    @Binding var dragOffset: CGFloat
    let onClose: () -> Void
    @ViewBuilder let fabOverlay: () -> FabOverlay

    var body: some View {
        let safeB = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets
            .bottom ?? 0
        let padding = K.focusCardPadding
        let fullW = windowSize.width
        let fullH = windowSize.height
        let heroW = fullW - padding * 2
        let heroH = max(200, fullH * 0.55 - padding)
        let cardCornerRadius = max(4, min(outerCornerRadius - padding, heroW / 2 - 1, heroH / 2 - 1))
        let bgColor = card.color.mix(with: K.bg, by: 0.18)

        let shellSourceDetail = expandedId == card.id
        let artSourceDetail = expandedId == card.id

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(bgColor)
                .matchedGeometryEffect(id: HeroShellID(cardId: card.id), in: namespace, isSource: shellSourceDetail)
                .frame(width: fullW, height: fullH)
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    heroCardView(card: card, width: heroW, height: heroH)
                        .matchedGeometryEffect(id: HeroArtID(cardId: card.id), in: namespace, isSource: artSourceDetail)
                        .frame(width: heroW, height: heroH)
                        .padding(.init(top: padding, leading: padding, bottom: 0, trailing: padding))
                }
                .frame(width: fullW, height: padding + heroH, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))

                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(card.name)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(K.ink.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, padding)

                    goStyleActions(card: card)
                        .padding(.horizontal, padding)
                        .padding(.top, 12)

                    Spacer(minLength: 0)

                    if card.isDummy {
                        Text("DEMO DATA")
                            .fcMicro()
                            .foregroundStyle(K.ink.opacity(0.16))
                            .padding(.bottom, safeB + 6)
                    }
                }
                .offset(y: detailFooterVisible ? 0 : 28)
                .opacity(detailFooterVisible ? 1 : 0)
                .animation(GoMotion.quick, value: detailFooterVisible)

                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: [.top, .leading, .trailing])

            VStack {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        close()
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    Spacer()
                }
                .padding(.leading, padding + 4)
                .padding(.top, safeAreaTop + 8)
                Spacer()
            }
            .allowsHitTesting(true)

            if !isInlineRecordOverlayPresented {
                fabOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, floatingFabBottomPadding)
                    .allowsHitTesting(true)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
        }
        .frame(width: fullW, height: fullH)
        .offset(y: max(0, dragOffset))
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 80 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        close()
                    } else {
                        withAnimation(transitionAnimation) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .ignoresSafeArea(.all)
    }

    private func close() {
        detailFooterVisible = false
        withAnimation(transitionAnimation) {
            onClose()
            dragOffset = 0
        }
    }

    private func heroCardView(card: FocusCard, width: CGFloat, height: CGFloat) -> some View {
        let avatarEntry = FocusWalletAvatarCache.entry(for: card.id, data: card.avatarImageData)
        let avatarImage = avatarEntry.image

        return ZStack {
            LinearGradient(
                colors: [
                    card.color.mix(with: .white, by: 0.28),
                    card.color,
                    card.color.mix(with: .black, by: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width, height: height)

            Group {
                if let img = avatarImage {
                    if avatarEntry.isTransparent {
                        expandedTransparentAvatarLayer(img, card: card, width: width, height: height)
                    } else {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                    }
                } else if card.isHuman {
                    FocusHumanPortrait(emoji: card.emoji, color: card.color)
                } else if let species = card.petSpecies {
                    PetSilhouetteView(
                        species: normalizeSpecies(species),
                        coatColor: card.coatColor,
                        eyeColor: card.eyeColor,
                        patternName: card.patternName,
                        isAnimationEnabled: false
                    )
                    .scaleEffect(1.55)
                    .offset(y: 12)
                } else {
                    Text(card.emoji)
                        .font(.system(size: height * 0.40))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            LinearGradient(
                colors: [.clear, card.color.mix(with: .black, by: 0.10).opacity(0.50)],
                startPoint: UnitPoint(x: 0.5, y: 0.45),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }

    private func expandedTransparentAvatarLayer(_ image: UIImage, card: FocusCard, width: CGFloat, height: CGFloat) -> some View {
        let avatarWidth = width * (card.isHuman ? 0.72 : 0.78)
        let avatarHeight = height * (card.isHuman ? 0.98 : 0.92)
        let offsetX = width * (card.isHuman ? 0.05 : 0.04)
        let offsetY = card.isHuman ? 0 : -height * 0.02

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: avatarWidth, height: avatarHeight, alignment: .bottom)
            .frame(width: width, height: height, alignment: .bottomLeading)
            .offset(x: offsetX, y: offsetY)
            .shadow(color: Color.ohanaPrimaryText.opacity(0.18), radius: 4) // ui-v4: allow avatar asset grounding
            .shadow(color: Color.arkInk.opacity(0.24), radius: 18, x: 0, y: 10) // ui-v4: allow avatar asset grounding
    }

    private func goStyleActions(card: FocusCard) -> some View {
        let actions = card.actions
        let columns = min(actions.count, 4)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
            spacing: 10
        ) {
            ForEach(actions) { goActionCell(action: $0) }
        }
    }

    private func goActionCell(action: FocusCard.Action) -> some View {
        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: action.colorHex).opacity(0.92))
                Text(action.label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.65)
                    .foregroundStyle(K.ink.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.ohanaControlFill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.ink.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func normalizeSpecies(_ species: String) -> String {
        let lower = species.lowercased()
        if species.contains("猫") || lower.contains("cat") { return "猫" }
        if species.contains("狗") || lower.contains("dog") { return "狗" }
        if species.contains("兔") || lower.contains("rabbit") { return "兔子" }
        if species.contains("仓鼠") || lower.contains("hamster") { return "仓鼠" }
        if species.contains("鸟") || lower.contains("bird") { return "鸟" }
        return species
    }
}

private extension Text {
    func fcMicro(weight: Font.Weight = .medium) -> some View {
        self
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
