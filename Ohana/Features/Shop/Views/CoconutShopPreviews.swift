//
//  CoconutShopPreviews.swift
//  Ohana
//
//  Preview tiles used by CoconutShopView.
//

import SwiftUI

struct ShopAppliedPreview: View {
    let item: ShopItem
    let human: Human?
    let pet: Pet?
    let isEquipped: Bool
    let appLanguage: String

    @State private var animate = false

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color {
        switch item.category {
        case .appIcon: Color.goPrimary
        case .avatar2d: Color.goTeal
        case .cashExchange: Color.goYellow
        case .effect: Color.goPurple
        case .title_: Color.goYellow
        case .boost: Color.goOrange
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.22),
                            Color.ohanaControlFill,
                            Color.ohanaCardSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            switch item.category {
            case .avatar2d:
                avatarPassPreview
            case .effect:
                effectPreview
            case .title_:
                titlePreview
            case .boost:
                boostPreview
            case .cashExchange:
                cashPreview
            case .appIcon:
                EmptyView()
            }

            if isEquipped {
                Image(systemName: "checkmark.seal.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .onAppear {
            withAnimation(GoMotion.page) {
                animate = true
            }
        }
    }

    private var avatarPassPreview: some View {
        HStack(spacing: 9) {
            VStack(spacing: 3) {
                memberAvatar(size: 36)
                Text(l.tr(zh: "当前", en: "Now", de: "Jetzt"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Image(systemName: "arrow.right") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(accent)
            VStack(spacing: 3) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 48, height: 42)
                    petAvatar(size: 54)
                        .offset(y: animate ? -4 : 2)
                }
                Text("2.5D")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var effectPreview: some View {
        switch item.id {
        case "fx_popout_card":
            popoutCardPreview
        case "fx_lime_glow":
            limeGlowPreview
        case "fx_rainbow":
            rainbowRoutePreview
        case "fx_rainbow_poop":
            rainbowPoopPreview
        case "fx_stars":
            stardustPreview
        case "fx_firework":
            fireworkPreview
        default:
            stardustPreview
        }
    }

    private var popoutCardPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .fill(Color(hex: pet?.safeThemeColorHex ?? "5A67D8").opacity(0.34))
                .frame(height: 58)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            popoutSubject(size: 92)
                .rotation3DEffect(.degrees(-4), axis: (x: 0, y: 1, z: 0), anchor: .bottomLeading, perspective: 0.55)
                .shadow(color: Color.arkInk.opacity(0.28), radius: 14, x: 0, y: 9) // ui-v4: allow popout preview depth
                .offset(x: 16, y: animate ? -18 : -7)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet?.name ?? l.tr(zh: "宠物", en: "Pet", de: "Tier"))
                    .font(OhanaFont.caption(.black))
                Text(l.tr(zh: "破框悬浮", en: "Popout", de: "Popout"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.leading, 86)
            .padding(.bottom, 24)
        }
    }

    private var limeGlowPreview: some View {
        HStack(spacing: 10) {
            petAvatar(size: 50)
                .padding(5)
                .background(Color.goPrimary.opacity(0.22), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.goPrimary.opacity(animate ? 0.82 : 0.28), lineWidth: 2)
                        .scaleEffect(animate ? 1.10 : 0.88)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "打卡完成", en: "Check-in done", de: "Check-in fertig"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("+2🥥")
                    .font(OhanaFont.metric(size: 20, .black))
                    .foregroundStyle(Color.goPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var rainbowRoutePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.walk") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text(l.tr(zh: "遛狗路线", en: "Walk route", de: "Gassi-Route"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("1.8 km")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            HStack(spacing: 0) {
                ForEach([Color.goRed, .goOrange, .goYellow, .goTeal, .goPurple], id: \.description) { color in
                    Capsule()
                        .fill(color)
                        .frame(height: 7)
                        .scaleEffect(x: animate ? 1 : 0.45, anchor: .leading)
                }
            }
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
    }

    private var rainbowPoopPreview: some View {
        HStack(spacing: 12) {
            RainbowPoopPin(isRainbow: true, isFlowing: animate, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "路线事件", en: "Route event", de: "Routenereignis"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "便便标记发光", en: "Poop marker glows", de: "Kotmarker leuchtet"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var stardustPreview: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 28, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "每日委托", en: "Daily quest", de: "Tagesquest"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "星尘反馈", en: "Stardust feedback", de: "Sternenstaub"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            ForEach(0 ..< 5, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(OhanaFont.adaptive(size: 9 + CGFloat(index), weight: .black))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.goYellow : Color.goPurple)
                    .offset(x: CGFloat(index * 18 - 26), y: animate ? CGFloat(-22 + index * 3) : 4)
                    .opacity(animate ? 1 : 0)
            }
        }
    }

    private var fireworkPreview: some View {
        ZStack {
            VStack(spacing: 4) {
                Image(systemName: "rosette") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 34, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goYellow)
                    .scaleEffect(animate ? 1 : 0.72)
                Text(l.tr(zh: "里程碑庆典", en: "Milestone", de: "Meilenstein"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            ForEach(0 ..< 8, id: \.self) { index in
                Circle()
                    .fill([Color.goYellow, .goOrange, .goPurple, .goTeal][index % 4])
                    .frame(width: 5, height: 5) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .offset(
                        x: animate ? cos(CGFloat(index) * .pi / 4) * 42 : 0,
                        y: animate ? sin(CGFloat(index) * .pi / 4) * 28 : 0
                    )
            }
        }
    }

    private var titlePreview: some View {
        HStack(spacing: 10) {
            memberAvatar(size: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(human?.name ?? l.tr(zh: "当前用户", en: "Current user", de: "Aktueller Nutzer"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(item.name(l))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.goYellow, in: Capsule())
                    .scaleEffect(animate ? 1 : 0.86)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var boostPreview: some View {
        switch item.id {
        case "boost_double":
            rewardBoostPreview(from: "+0", to: "+15XP +8🥥", icon: "bolt.fill")
        case "boost_streak":
            streakShieldPreview
        case "boost_tree", "boost_tree_large":
            treeEnergyPreview
        case "boost_backdate_single", "boost_backdate_pack":
            backdatePreview
        default:
            rewardBoostPreview(from: "+2🥥", to: "+4🥥", icon: "bolt.fill")
        }
    }

    private func rewardBoostPreview(from: String, to: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 24, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goOrange)
                .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goOrange.opacity(0.16), in: Circle())
            Text(from)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Image(systemName: "arrow.right") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(to)
                .font(OhanaFont.metric(size: 21, .black))
                .foregroundStyle(Color.goYellow)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var streakShieldPreview: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .foregroundStyle(Color.goTeal)
                Text(l.tr(zh: "连击保护", en: "Streak shield", de: "Streak-Schutz"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }
            HStack(spacing: 5) {
                ForEach(0 ..< 7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                        .fill(index == 4 ? Color.goTeal : Color.goPrimary.opacity(0.72))
                        .frame(height: 18)
                        .overlay {
                            if index == 4 {
                                Image(systemName: "shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 8, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.arkInk)
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private var treeEnergyPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "tree.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 30, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goTeal)
            VStack(alignment: .leading, spacing: 8) {
                Text(l.tr(zh: "生命树能量", en: "Tree energy", de: "Baumenergie"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.ohanaCardSurface)
                        Capsule()
                            .fill(Color.goPrimary)
                            .frame(width: proxy.size.width * (animate ? 0.72 : 0.36))
                    }
                }
                .frame(height: 9)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var backdatePreview: some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(l.tr(zh: "昨天", en: "Yest.", de: "Gest."))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                Text("✓")
                    .font(OhanaFont.metric(size: 24, .black))
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 54, height: 58)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "补签入库", en: "Backdate pass", de: "Nachtragspass"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.id == "boost_backdate_pack" ? "×3" : "×1")
                    .font(OhanaFont.metric(size: 22, .black))
                    .foregroundStyle(Color.goYellow)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var cashPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "banknote.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 28, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("1000🥥 → \(CoconutExchangeOption.options().dropFirst().first?.formattedAmount ?? "$1")")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "家庭线下确认", en: "Offline confirm", de: "Offline bestätigen"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func memberAvatar(size: CGFloat) -> some View {
        Text(human?.avatarEmoji ?? "👤")
            .font(.system(size: size * 0.58))
            .frame(width: size, height: size)
            .background(Color.ohanaCardSurface, in: Circle())
    }

    @ViewBuilder
    private func petAvatar(size: CGFloat) -> some View {
        if let pet {
            PetSilhouetteView(
                species: pet.species,
                coatColor: Color(hex: pet.coatColor.isEmpty ? "E8C49A" : pet.coatColor),
                eyeColor: Color(hex: pet.eyeColor.isEmpty ? "6B3A2A" : pet.eyeColor),
                isAnimationEnabled: false
            )
            .frame(width: size, height: size)
        } else {
            Image(systemName: "pawprint.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(accent)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func popoutSubject(size: CGFloat) -> some View {
        petAvatar(size: size)
    }
}

struct AppIconPreview: View {
    let descriptor: AppIconShopDescriptor
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: descriptor.gradientHex.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: descriptor.previewSymbol)
                    .font(OhanaFont.adaptive(size: 42, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(descriptor.itemId == "appicon_minimal_o" ? Color.arkInk : Color.ohanaPrimaryActionText)
            }

            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 19, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var assetName: String {
        descriptor.alternateIconName ?? "AppIcon"
    }
}
