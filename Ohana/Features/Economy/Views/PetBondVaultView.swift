//
//  PetBondVaultView.swift
//  Ohana
//
//  Pet-only bond coconut wallet and unlocks.
//

import SwiftData
import SwiftUI

struct PetBondVaultContentView: View {
    let pet: Pet
    let walletLedgerEntries: [CoconutLedgerEntry]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var unlockedIDs: Set<String> = []
    @State private var toast: String?
    @State private var activePreviewItem: PetBondVaultItem?

    private var l: L10n { L10n(appLanguage) }
    private var petLogs: [CoconutLogEntry] {
        walletLedgerEntries
            .filter { $0.ownerKind == .pet && $0.ownerId == pet.id.uuidString && $0.delta != 0 }
            .map { $0.asCoconutLogEntry() }
            .filter { $0.actorId == pet.id.uuidString }
            .prefix(6)
            .map(\.self)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    balanceSummary
                    unlockGrid
                    recentLogs
                    boundaryNote
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }

            if let toast {
                Text(toast)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.goPrimary, in: Capsule())
                    .padding(.bottom, 22)
            }

            if let activePreviewItem {
                PetBondVaultPreviewOverlay(
                    item: activePreviewItem,
                    pet: pet,
                    appLanguage: appLanguage,
                    close: { closePreview() }
                )
                .zIndex(20)
            }
        }
        .petMemorialTone(isActive: pet.hasPassedAway)
        .onAppear {
            unlockedIDs = PetBondVaultStore.unlockedIDs(for: pet.id)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageData: pet.avatarImageData,
                emoji: pet.avatarEmoji,
                fallback: pet.speciesEmoji,
                tint: Color(hex: pet.safeThemeColorHex)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "宠物小金库", en: "Bond Vault", de: "Bindungs-Tresor"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(pet.name)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(l.tr(zh: "成长椰子 / Bond Coconuts", en: "Bond Coconuts", de: "Bindungskokosnüsse"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            }
            .buttonStyle(ScaleButtonStyle())
            .contentShape(Circle())
        }
    }

    private var balanceSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("🥥")
                    .font(OhanaFont.adaptive(size: 26)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text("\(pet.coconutBalance)")
                    .font(OhanaFont.largeTitle(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .contentTransition(.numericText())
                Text(l.tr(zh: "成长椰子", en: "bond coconuts", de: "Bindungskokos"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Text(l.tr(
                zh: "只属于 \(pet.name)：用于宠物外观、成长故事和纪念装饰，不能兑换现金或支付家庭悬赏。",
                en: "Only for \(pet.name): pet cosmetics, growth stories, and memorial decor. It cannot be cashed out or used for family bounties.",
                de: "Nur für \(pet.name): Haustierdesigns, Wachstumsgeschichten und Erinnerungsdeko. Nicht auszahlbar und nicht für Familienprämien nutzbar."
            ))
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unlockGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                l.tr(zh: "可解锁内容", en: "Unlocks", de: "Freischaltungen"),
                subtitle: l.tr(zh: "消耗该宠物自己的成长椰子", en: "Uses this pet's own bond balance", de: "Nutzt nur das eigene Haustierguthaben")
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PetBondVaultCatalog.items) { item in
                    unlockCard(item)
                }
            }
        }
    }

    private func unlockCard(_ item: PetBondVaultItem) -> some View {
        let unlocked = unlockedIDs.contains(item.id)
        let canUnlock = pet.coconutBalance >= item.cost && !unlocked
        let tint = Color(hex: item.tintHex)

        return VStack(alignment: .leading, spacing: 11) {
            PetBondVaultAppliedPreview(item: item, pet: pet, appLanguage: appLanguage, compact: true)
                .frame(height: 104)

            HStack {
                Image(systemName: item.icon)
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tint)
                Spacer()
                Text(unlocked ? l.tr(zh: "已解锁", en: "Owned", de: "Aktiv") : "\(item.cost)🥥")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(unlocked ? Color.goTeal : Color.ohanaPrimaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(l.text(item.title))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(l.text(item.subtitle))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                Button {
                    openPreview(item)
                } label: {
                    Text(l.tr(zh: "预览", en: "Preview", de: "Vorschau"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    unlock(item)
                } label: {
                    Text(actionTitle(for: item, unlocked: unlocked))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(canUnlock ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(canUnlock ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canUnlock)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 258, alignment: .topLeading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .animation(GoMotion.feedback, value: unlockedIDs)
    }

    private var recentLogs: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                l.tr(zh: "最近获得", en: "Recent", de: "Zuletzt"),
                subtitle: l.tr(zh: "只显示 \(pet.name) 的成长椰子流水", en: "Only \(pet.name)'s bond coconut activity", de: "Nur \(pet.name)s Bindungskokos-Verlauf")
            )

            if petLogs.isEmpty {
                Text(l.tr(zh: "还没有成长椰子记录。完成喂食、喂水、陪玩或健康护理后会出现在这里。", en: "No bond coconut activity yet. Feeding, watering, play, and health care will appear here.", de: "Noch keine Einträge. Füttern, Wasser, Spielen und Gesundheitspflege erscheinen hier."))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(petLogs) { log in
                        HStack(spacing: 10) {
                            Text(log.emoji).font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.title)
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)
                                Text(log.timeAgoString)
                                    .font(OhanaFont.caption2(.semibold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            Spacer()
                            Text(log.amount > 0 ? "+\(log.amount)" : "\(log.amount)")
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(log.amount > 0 ? Color.goTeal : Color.goOrange)
                        }
                        .padding(12)
                        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    }
                }
            }
        }
    }

    private var boundaryNote: some View {
        Label {
            Text(l.tr(
                zh: "人类椰子用于商店、悬赏和货币兑换；宠物成长椰子只用于这个宠物自己的成长与纪念。",
                en: "Human coconuts pay for the shop, bounties, and exchange records; pet bond coconuts stay with this pet.",
                de: "Menschen-Kokos bezahlt Shop, Prämien und Umtausch; Haustier-Bindungskokos bleibt bei diesem Tier."
            ))
            .font(OhanaFont.caption2(.black))
        } icon: {
            Image(systemName: "lock.shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(subtitle)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private func actionTitle(for item: PetBondVaultItem, unlocked: Bool) -> String {
        if unlocked {
            return l.tr(zh: "已拥有", en: "Owned", de: "Besitzt")
        }
        if pet.coconutBalance >= item.cost {
            return l.tr(zh: "解锁", en: "Unlock", de: "Freischalten")
        }
        return l.tr(
            zh: "还差 \(item.cost - pet.coconutBalance)🥥",
            en: "\(item.cost - pet.coconutBalance)🥥 short",
            de: "\(item.cost - pet.coconutBalance)🥥 fehlen"
        )
    }

    private func unlock(_ item: PetBondVaultItem) {
        let title = l.tr(
            zh: "\(pet.name) 解锁 \(l.text(item.title))",
            en: "\(pet.name) unlocked \(l.text(item.title))",
            de: "\(pet.name) hat \(l.text(item.title)) freigeschaltet"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.petBondVaultUnlock(petID: pet.id, itemID: item.id)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).unlockBondVaultItem(
                item,
                pet: pet,
                title: title,
                note: "petBondVault.unlock"
            )
            unlockedIDs = PetBondVaultStore.unlockedIDs(for: pet.id)
            if result.didUnlock {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast(l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet"))
            } else if result.failure == .insufficientBalance {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showToast(l.tr(zh: "椰子不足", en: "Not enough coconuts", de: "Nicht genug Kokosnüsse"))
            }
        }
    }

    private func openPreview(_ item: PetBondVaultItem) {
        withAnimation(GoMotion.page) {
            activePreviewItem = item
        }
    }

    private func closePreview() {
        withAnimation(GoMotion.page) {
            activePreviewItem = nil
        }
    }

    private func showToast(_ text: String) {
        withAnimation(GoMotion.feedback) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(GoMotion.quick) { toast = nil }
        }
    }
}

private struct PetBondVaultPreviewOverlay: View {
    let item: PetBondVaultItem
    let pet: Pet
    let appLanguage: String
    let close: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: true) {
            Color.black.opacity(0.28) // ui-v4: allow modal scrim
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            VStack(spacing: 0) {
                OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                    .padding(.top, 4)
                    .gesture(dragGesture)

                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color(hex: item.tintHex))
                        .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.text(item.title))
                            .font(OhanaFont.title3(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "购买前先看看真实效果", en: "Preview the applied look before buying", de: "Vorschau vor dem Freischalten"))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer()
                    OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: close)
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 14)

                PetBondVaultAppliedPreview(item: item, pet: pet, appLanguage: appLanguage, compact: false)
                    .frame(height: item.previewKind == .storyStyleAnimation ? 230 : 210)
                    .padding(.horizontal, 18)

                Text(previewCaption)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                Button(action: close) {
                    Text(l.tr(zh: "看好了", en: "Looks good", de: "Sieht gut aus"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
            .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.inlinePopup) }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.inlinePopup, style: .continuous))
            .shadow(color: Color.black.opacity(0.54), radius: 46, x: 0, y: -16) // ui-v4: allow liftedAlert inline popup shadow
            .shadow(color: Color(hex: "0B102C").opacity(0.38), radius: 26, x: 0, y: 12) // ui-v4: allow liftedAlert inline popup shadow
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
            .offset(y: dragOffset)
        }
    }

    private var previewCaption: String {
        switch item.previewKind {
        case .cardBorder:
            l.tr(zh: "边框会直接出现在这只宠物的首页卡片上。", en: "The border appears on this pet's home card.", de: "Der Rahmen erscheint auf der Haustierkarte.")
        case .nameplate:
            l.tr(zh: "铭牌会贴在名字旁，让这只宠物更有专属感。", en: "The nameplate sits by the name for a personal touch.", de: "Das Schild sitzt neben dem Namen.")
        case .storyStyleAnimation:
            l.tr(zh: "故事样式会用于记录中心的回忆卡，预览以动画展示。", en: "Story style applies to diary cards; this preview animates the look.", de: "Der Stil gilt für Tagebuchkarten und wird animiert gezeigt.")
        case .oasisNest:
            l.tr(zh: "Oasis 装饰会用于这只宠物的小窝展示。", en: "Oasis decor is for this pet's nest display.", de: "Oase-Deko gilt für das Nest dieses Haustiers.")
        case .memorialFrame:
            l.tr(zh: "纪念相框只是预览黑白纪念效果，不会改变宠物状态。", en: "This previews the memorial frame without changing pet status.", de: "Nur Vorschau, der Status bleibt unverändert.")
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 78 || value.predictedEndTranslation.height > 130 {
                    close()
                } else {
                    withAnimation(GoMotion.page) {
                        dragOffset = 0
                    }
                }
            }
    }
}

private struct PetBondVaultAppliedPreview: View {
    let item: PetBondVaultItem
    let pet: Pet
    let appLanguage: String
    let compact: Bool

    @State private var animate = false

    private var l: L10n { L10n(appLanguage) }
    private var tint: Color { Color(hex: item.tintHex) }

    var body: some View {
        Group {
            switch item.previewKind {
            case .cardBorder:
                miniPetCard(showBorder: true, showNameplate: false, memorial: false)
            case .nameplate:
                miniPetCard(showBorder: false, showNameplate: true, memorial: false)
            case .storyStyleAnimation:
                storyStylePreview
            case .oasisNest:
                oasisNestPreview
            case .memorialFrame:
                miniPetCard(showBorder: true, showNameplate: true, memorial: true)
            }
        }
        .onAppear {
            withAnimation(GoMotion.page) {
                animate = true
            }
        }
    }

    private func miniPetCard(showBorder: Bool, showNameplate: Bool, memorial: Bool) -> some View {
        RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous)
            .fill(cardGradient)
            .overlay {
                HStack(spacing: compact ? 8 : 16) {
                    petAvatar(size: compact ? 62 : 110)
                        .scaleEffect(animate ? 1 : 0.88)
                    VStack(alignment: .leading, spacing: compact ? 5 : 9) {
                        HStack(spacing: 6) {
                            Text(pet.name)
                                .font(compact ? OhanaFont.caption(.black) : OhanaFont.title3(.black))
                                .foregroundStyle(Color.white) // ui-v4: allow preview text on vivid card art
                                .lineLimit(1)
                            if showNameplate {
                                Text(l.tr(zh: "羁绊", en: "Bond", de: "Bindung"))
                                    .font(OhanaFont.caption2(.black))
                                    .foregroundStyle(Color.arkInk)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.goYellow, in: Capsule())
                                    .scaleEffect(animate ? 1 : 0.72)
                            }
                        }
                        Text(memorial ? l.tr(zh: "纪念相框", en: "Memorial frame", de: "Erinnerungsrahmen") : l.tr(zh: "成长卡片预览", en: "Card preview", de: "Kartenvorschau"))
                            .font(compact ? OhanaFont.caption2(.black) : OhanaFont.caption(.black))
                            .foregroundStyle(Color.white.opacity(0.78)) // ui-v4: allow preview text on vivid card art
                    }
                    Spacer(minLength: 0)
                }
                .padding(compact ? 12 : 18)
            }
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous)
                        .strokeBorder(tint.opacity(0.86), lineWidth: compact ? 2 : 3)
                        .shadow(color: tint.opacity(0.40), radius: compact ? 10 : 20) // ui-v4: allow purchased decoration preview glow
                }
            }
            .grayscale(memorial ? 1 : 0)
            .saturation(memorial ? 0.2 : 1)
    }

    private var storyStylePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous)
                .fill(Color.ohanaControlFill)

            VStack(alignment: .leading, spacing: compact ? 8 : 13) {
                HStack(spacing: 8) {
                    petAvatar(size: compact ? 34 : 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "今天的小事", en: "A tiny moment", de: "Ein kleiner Moment"))
                            .font(compact ? OhanaFont.caption(.black) : OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(pet.name)
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Image(systemName: "sparkles") // a11y: allow decorative icon covered by surrounding text or control
                        .font(.system(size: compact ? 12 : 16, weight: .black))
                        .foregroundStyle(tint)
                }

                HStack(spacing: compact ? 7 : 10) {
                    storyPhotoTile(icon: "photo.fill", delay: 0)
                    storyPhotoTile(icon: "heart.fill", delay: 0.08)
                    storyPhotoTile(icon: "pawprint.fill", delay: 0.16)
                }

                Text(l.tr(zh: "阳光很好，TA 看起来很开心。", en: "Good light. A happy little memory.", de: "Schönes Licht. Eine kleine Erinnerung."))
                    .font(compact ? OhanaFont.caption2(.black) : OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 8)
            }
            .padding(compact ? 12 : 18)
        }
    }

    private func storyPhotoTile(icon: String, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: compact ? 13 : 18, style: .continuous)
            .fill(tint.opacity(0.18))
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: compact ? 13 : 18, weight: .black))
                    .foregroundStyle(tint)
            }
            .frame(height: compact ? 34 : 64)
            .scaleEffect(animate ? 1 : 0.82)
            .opacity(animate ? 1 : 0)
            .animation(GoMotion.page.delay(delay), value: animate)
    }

    private var oasisNestPreview: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.goTeal.opacity(0.28), Color.goPurple.opacity(0.16), Color.ohanaControlFill],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Ellipse()
                .fill(tint.opacity(0.20))
                .frame(width: compact ? 98 : 176, height: compact ? 26 : 42)
                .blur(radius: 5)
                .offset(y: compact ? -12 : -16)

            petAvatar(size: compact ? 72 : 128)
                .offset(y: animate ? (compact ? -12 : -18) : 0)

            HStack {
                Image(systemName: "leaf.fill") // a11y: allow decorative icon covered by surrounding text or control
                Text(l.tr(zh: "Oasis 小窝", en: "Oasis nest", de: "Oase-Nest"))
            }
            .font(compact ? OhanaFont.caption2(.black) : OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ohanaCardSurface, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(compact ? 10 : 16)
        }
    }

    private func petAvatar(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            pet: pet,
            size: size,
            showsBackground: false,
            transparentScale: 0.92,
            transparentYOffset: 0.04
        )
    }

    private var cardGradient: LinearGradient {
        let base = Color(hex: pet.safeThemeColorHex)
        return LinearGradient(
            colors: [
                base.mix(with: .white, by: 0.24),
                base,
                base.mix(with: .black, by: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
