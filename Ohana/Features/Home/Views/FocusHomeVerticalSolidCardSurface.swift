//
//  FocusHomeVerticalSolidCardSurface.swift
//  Ohana
//
//  Render surface for cards in the vertical solid home motion scene.
//

import SwiftUI
import UIKit

struct FocusHomeVerticalSolidCardSurface: View {
    let card: FocusCard
    let progress: CGFloat
    let reduceMotion: Bool
    let localization: L10n
    let frozenAvatarSource: FocusHomeFrozenAvatarSource?
    var allowsLiveAvatarFallback: Bool = true

    private var accent: Color {
        card.themeColorHex.isEmpty ? card.color : Color(hex: card.themeColorHex)
    }

    private var visualProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var l: L10n {
        localization
    }

    private var cornerRadius: CGFloat {
        lerp(30, 44, visualProgress)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let p = visualProgress
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let avatarSource = frozenAvatarSource
                ?? (allowsLiveAvatarFallback ? FocusHomeFrozenAvatarSource.live(for: card) : .placeholder)
            let usesFullWidthPhoto = avatarSource.image != nil && !avatarSource.isTransparent

            ZStack(alignment: .topLeading) {
                shape
                    .fill(cardGradient)
                    .overlay {
                        shape
                            .strokeBorder(borderGradient, lineWidth: lerp(1, 1.25, p))
                    }

                if let image = avatarSource.image, usesFullWidthPhoto {
                    WalletCardVerticalPhotoBlendLayer(
                        image: image,
                        width: w,
                        height: h,
                        themeColorHex: card.themeColorHex,
                        shadowDepth: lerp(0.90, 1.08, p)
                    )
                    .zIndex(1)
                }

                bottomQuickActionGradient(height: h, progress: p)
                    .zIndex(2)

                VStack(alignment: .leading, spacing: 0) {
                    header(progress: p)
                        .padding(.top, lerp(16, 24, p))
                        .padding(.horizontal, lerp(15, 22, p))

                    Spacer(minLength: 0)

                    avatar(image: avatarSource.image, transparent: avatarSource.isTransparent, width: w, height: h)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(x: avatarHorizontalOffset(width: w, progress: p))
                        .frame(height: h * lerp(0.42, 0.36, p))
                        .padding(.leading, lerp(10, 18, p))
                        .padding(.trailing, lerp(10, 18, p))

                    bottomInfo(progress: p)
                        .padding(.horizontal, lerp(15, 18, p))
                        .padding(.bottom, lerp(16, 236, p))
                }
                .zIndex(4)

                rightInfoColumn(width: w, height: h, progress: p)
                    .zIndex(5)
            }
            .clipShape(shape)
            .saturation(card.hasPassedAway ? 0 : 1)
            .shadow(color: Color.arkInk.opacity(lerp(0.20, 0.28, p)), radius: lerp(15, 24, p), x: 0, y: lerp(10, 18, p)) // ui-v4: allow intentional home card depth
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name), \(card.kind)")
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.mix(with: .white, by: lerp(0.10, 0.12, visualProgress)),
                accent,
                accent.mix(with: .black, by: lerp(0.30, 0.34, visualProgress))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.goCardWhite.opacity(lerp(0.20, 0.28, visualProgress)),
                accent.mix(with: .white, by: 0.12).opacity(lerp(0.42, 0.58, visualProgress)),
                Color.arkInk.opacity(lerp(0.12, 0.18, visualProgress))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func header(progress p: CGFloat) -> some View {
        let reveal = expandedContentProgress(p)
        let compactHeaderOpacity = Double(1 - reveal)
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: lerp(3, 4, p)) {
                Text(card.name)
                    .font(.system(size: lerp(17, 28, p), weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .shadow(color: Color.arkInk.opacity(0.58), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text

                Text(card.kind)
                    .font(.system(size: lerp(9, 12, p), weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .shadow(color: Color.arkInk.opacity(0.46), radius: 4, x: 0, y: 1) // ui-v4: allow requested legibility shadow on card text
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(compactHeaderOpacity)

            Spacer(minLength: 0)

            Text(statusBadge)
                .font(.system(size: lerp(10, 12, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, lerp(9, 12, p))
                .padding(.vertical, lerp(5, 7, p))
                .background(statusBadgeBackground, in: Capsule())
                .shadow(color: Color.arkInk.opacity(0.58), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
                .opacity(compactHeaderOpacity)
        }
    }

    @ViewBuilder
    private func avatar(image: UIImage?, transparent: Bool, width: CGFloat, height: CGFloat) -> some View {
        let avatarWidth = width * (card.isHuman ? lerp(0.56, 0.66, visualProgress) : lerp(0.68, 0.88, visualProgress))
        let avatarHeight = height * (card.isHuman ? lerp(0.42, 0.46, visualProgress) : lerp(0.48, 0.58, visualProgress))
        if image != nil, !transparent {
            Color.clear
                .frame(
                    width: avatarWidth,
                    height: avatarHeight,
                    alignment: .bottom
                )
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(
                    width: avatarWidth,
                    height: avatarHeight,
                    alignment: .bottom
                )
                .offset(y: card.isHuman ? lerp(0, -20, visualProgress) : lerp(0, -34, visualProgress))
                .shadow(color: Color.goCardWhite.opacity(transparent ? 0.20 : 0.08), radius: 3, y: 0) // ui-v4: allow intentional avatar cutout crispness
                .shadow(color: Color.arkInk.opacity(transparent ? 0.28 : 0.16), radius: 18, y: 12) // ui-v4: allow intentional avatar depth
        } else {
            Image(systemName: avatarSymbol)
                .font(.system(size: width * lerp(0.43, 0.47, visualProgress), weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.92))
                .frame(width: width * 0.78, height: height * 0.36)
        }
    }

    private func avatarHorizontalOffset(width: CGFloat, progress p: CGFloat) -> CGFloat {
        let leadingPadding = lerp(CGFloat(10), CGFloat(18), p)
        let trailingPadding = lerp(CGFloat(10), CGFloat(18), p)
        let baseCenterOffset = (trailingPadding - leadingPadding) / 2
        let expandedShift = card.isHuman ? CGFloat(0) : -width * (card.isElectronicPet ? 0.045 : 0.085)
        return baseCenterOffset + lerp(0, expandedShift, p)
    }

    private func rightInfoColumn(width: CGFloat, height: CGFloat, progress p: CGFloat) -> some View {
        let reveal = smooth(p, 0.30, 0.64)
        let sideWidth = max(128, width * 0.46)
        return VStack(alignment: .trailing, spacing: lerp(3, 5, p)) {
            Spacer(minLength: 0)
            if card.isHuman {
                humanInfoStack(progress: p)
            } else if card.isElectronicPet {
                electronicPetInfoStack(progress: p)
            } else {
                petInfoStack(progress: p)
            }
        }
        .padding(.trailing, 18)
        .padding(.bottom, lerp(22, 250, p))
        .frame(width: sideWidth, height: height, alignment: .bottomTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(Double(reveal))
        .scaleEffect(lerp(0.985, 1, reveal), anchor: .bottomTrailing)
        .offset(y: lerp(8, 0, reveal))
        .allowsHitTesting(false)
    }

    private func humanInfoStack(progress p: CGFloat) -> some View {
        let details = [card.zodiacText, card.mbtiText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return VStack(alignment: .trailing, spacing: lerp(3, 5, p)) {
            Text(details.first ?? "OHANA MEMBER")
                .font(.system(size: lerp(15, 20, p), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text

            if details.count > 1 {
                Text(details.dropFirst().joined(separator: " · "))
                    .font(.system(size: lerp(9, 11, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }
        }
    }

    private func petInfoStack(progress p: CGFloat) -> some View {
        let meta = [card.humanEquivalentAgeText, card.zodiacText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "未知" }
        return VStack(alignment: .trailing, spacing: lerp(4, 7, p)) {
            petAgeMetric(progress: p)

            Text(petTogetherHeadline)
                .font(.system(size: lerp(15, 20, p), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty {
                Text(hint)
                    .font(.system(size: lerp(8.5, 10.5, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.82))
                    .lineLimit(p > 0.72 ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }

            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(.system(size: lerp(8.5, 10, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.76))
                    .lineLimit(p > 0.72 ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }
        }
    }

    @ViewBuilder
    private func petAgeMetric(progress p: CGFloat) -> some View {
        if let age = expandedAgeParts {
            HStack(alignment: .firstTextBaseline, spacing: lerp(3, 5, p)) {
                Text(age.number)
                    .font(.system(size: lerp(26, 52, p), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())

                Text(age.unit)
                    .font(.system(size: lerp(10, 16, p), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(cardPrimaryText)
            .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text
        }
    }

    private var expandedAgeParts: (number: String, unit: String)? {
        guard let rawAge = card.ageText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawAge.isEmpty
        else {
            return nil
        }
        let numberPrefix = rawAge.prefix { character in
            character.isNumber || character == "." || character == ","
        }
        guard !numberPrefix.isEmpty else {
            return nil
        }
        let unit = rawAge
            .dropFirst(numberPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            number: String(numberPrefix),
            unit: unit.isEmpty ? l.tr(zh: "岁", en: "year", de: "Jahr") : unit
        )
    }

    private func electronicPetInfoStack(progress p: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: lerp(3, 5, p)) {
            Text(l.tr(zh: "电子宠物", en: "Critter", de: "Critter"))
                .font(.system(size: lerp(15, 20, p), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText)
                .lineLimit(1)
                .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty {
                Text(hint)
                    .font(.system(size: lerp(8.5, 10.5, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }

            if let ageText = card.ageText {
                Text(ageText)
                    .font(.system(size: lerp(8.5, 10, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.76))
                    .lineLimit(1)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }
        }
    }

    @ViewBuilder
    private func bottomInfo(progress p: CGFloat) -> some View {
        let reveal = expandedContentProgress(p)
        compactFooter(progress: p)
            .opacity(Double(1 - reveal))
    }

    private func compactFooter(progress p: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(primaryMetric)
                .font(.system(size: lerp(31, 36, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
                .shadow(color: Color.arkInk.opacity(0.60), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
            Text(metricUnit)
                .font(.system(size: lerp(11, 15, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .shadow(color: Color.arkInk.opacity(0.46), radius: 4, x: 0, y: 1) // ui-v4: allow requested legibility shadow on card text
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedContentProgress(_ progress: CGFloat) -> CGFloat {
        smooth(progress, 0.18, 0.58)
    }

    private func bottomQuickActionGradient(height: CGFloat, progress p: CGFloat) -> some View {
        let reveal = smooth(p, 0.36, 0.72)
        return LinearGradient(
            colors: [
                Color.arkInk.opacity(0),
                Color.arkInk.opacity(0.36 * Double(reveal)),
                Color.arkInk.opacity(0.78 * Double(reveal))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height * lerp(0.34, 0.48, reveal))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var petTogetherHeadline: String {
        if let snapshotText = card.togetherHeadlineText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !snapshotText.isEmpty {
            return snapshotText
        }
        guard card.daysTogetherText != nil else {
            return l.tr(zh: "新成员", en: "New Family", de: "Neue Familie")
        }
        if card.daysTogether < 0 {
            let days = abs(card.daysTogether)
            return l.tr(zh: "\(days) 天后到家", en: "\(days) Days Until Home", de: "\(days) Tage bis Zuhause")
        }
        return l.tr(zh: "相伴 \(card.daysTogether) 天", en: "\(card.daysTogether) Days Together", de: "\(card.daysTogether) Tage zusammen")
    }

    private var cardPrimaryText: Color {
        WalletPetCardTheme.prefersDarkForeground(for: card.themeColorHex) ? Color.arkInk : Color.goCardWhite
    }

    private func cardSecondaryText(opacity: Double) -> Color {
        cardPrimaryText.opacity(opacity)
    }

    private var statusBadge: String {
        if let statusBadgeText = card.statusBadgeText {
            return statusBadgeText
        }
        if card.isHuman { return "🥥" }
        if card.streak > 0 { return "\(card.streak)" }
        return "OK"
    }

    private var statusBadgeBackground: Color {
        card.statusBadgeIsWarning ? Color.goRed : accent
    }

    private var primaryMetric: String {
        card.homePrimaryMetricValue
    }

    private var metricUnit: String {
        card.homePrimaryMetricUnit
    }

    private var avatarSymbol: String {
        if card.isElectronicPet { return "leaf.fill" }
        if card.isHuman { return "person.fill" }
        let species = (card.petSpecies ?? card.kind).lowercased()
        if species.contains("dog") || species.contains("狗") { return "dog.fill" }
        if species.contains("cat") || species.contains("猫") { return "cat.fill" }
        if species.contains("bird") || species.contains("鸟") { return "bird.fill" }
        if species.contains("fish") || species.contains("鱼") { return "fish.fill" }
        return "pawprint.fill"
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: CGFloat) -> Double {
        a + (b - a) * Double(min(max(t, 0), 1))
    }

    private func eased(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private func smooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return eased((value - start) / (end - start))
    }
}
