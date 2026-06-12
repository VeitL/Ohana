//
//  CoconutShopView+Popups.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    func purchaseConfirmation(item: ShopItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            popupHeader(
                icon: item.appIcon == nil ? item.emoji : "",
                sfSymbol: item.appIcon?.previewSymbol,
                title: l.tr(zh: "确认兑换", en: "Confirm unlock", de: "Einlösen bestätigen"),
                subtitle: item.name(l)
            ) {
                pendingPurchaseItem = nil
            }

            HStack(spacing: 12) {
                itemPreview(item)
                    .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.description(l))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(secondaryText)
                    Text(l.tr(zh: "将消耗 \(item.cost) 个椰子。", en: "Costs \(item.cost) coconuts.", de: "Kostet \(item.cost) Kokosnüsse."))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goYellow)
                }
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))

            Button {
                confirmPurchase(item)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    Text(l.tr(zh: "兑换 / 使用", en: "Unlock / Use", de: "Einlösen / Nutzen"))
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    func pickerContent(_ picker: ShopPicker) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch picker {
            case .avatarTarget:
                popupHeader(icon: "🖼️", sfSymbol: nil, title: l.tr(zh: "选择头像对象", en: "Choose avatar target", de: "Avatar-Ziel wählen"), subtitle: l.tr(zh: "库存 \(Avatar2DAccess.extraPassCount) 张", en: "\(Avatar2DAccess.extraPassCount) available", de: "\(Avatar2DAccess.extraPassCount) verfügbar")) {
                    activePicker = nil
                }
                targetList
            case .popoutPet:
                popupHeader(icon: "🃏", sfSymbol: nil, title: l.tr(zh: "绑定破框卡片", en: "Bind popout card", de: "Popout-Karte binden"), subtitle: l.tr(zh: "选择一个宠物", en: "Choose one pet", de: "Wähle ein Tier")) {
                    activePicker = nil
                }
                petPickerList
            case .cashExchange:
                popupHeader(icon: "💱", sfSymbol: nil, title: l.tr(zh: "货币兑换", en: "Cash exchange", de: "Geldtausch"), subtitle: l.tr(zh: "家庭内部线下兑现记录", en: "Offline family note", de: "Offline-Familiennotiz")) {
                    activePicker = nil
                }
                cashExchangeForm
            }
        }
    }

    var targetList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if Avatar2DAccess.extraPassCount <= 0 {
                    emptyPickerText(l.tr(zh: "暂无可用头像券。", en: "No avatar passes available.", de: "Keine Avatarpässe verfügbar."))
                } else if humans.isEmpty, pets.isEmpty {
                    emptyPickerText(l.tr(zh: "请先创建一个人类或宠物成员。", en: "Create a human or pet first.", de: "Erstelle zuerst einen Menschen oder ein Tier."))
                } else {
                    ForEach(humans) { human in
                        targetRow(icon: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji, title: human.name, subtitle: l.tr(zh: "人类", en: "Human", de: "Mensch")) {
                            upgradeHumanTo2DAvatar(human)
                        }
                    }
                    ForEach(pets) { pet in
                        targetRow(icon: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji, title: pet.name, subtitle: l.tr(zh: "宠物", en: "Pet", de: "Tier")) {
                            upgradePetTo2DAvatar(pet)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 360)
    }

    var petPickerList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if pets.isEmpty {
                    emptyPickerText(l.tr(zh: "还没有宠物可以绑定。", en: "No pet to bind yet.", de: "Noch kein Tier zum Binden."))
                } else {
                    ForEach(pets) { pet in
                        targetRow(icon: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji, title: pet.name, subtitle: pet.species) {
                            activePicker = nil
                            equipPopoutPet = pet
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 340)
    }

    var cashExchangeForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            if currentHuman == nil {
                emptyPickerText(l.tr(zh: "请先创建当前人类账户。", en: "Create a current human account first.", de: "Erstelle zuerst ein aktuelles Menschenkonto."))
            } else if otherHumans.isEmpty {
                emptyPickerText(l.tr(zh: "需要至少另一位家庭成员才能兑换。", en: "Add another family member before exchanging.", de: "Füge zuerst ein weiteres Familienmitglied hinzu."))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.tr(zh: "接收人", en: "Receiver", de: "Empfänger"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(tertiaryText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(otherHumans) { human in
                                exchangeChip(
                                    title: human.name,
                                    isSelected: exchangeReceiverId == human.id.uuidString || (exchangeReceiverId.isEmpty && selectedExchangeReceiver?.id == human.id)
                                ) {
                                    withAnimation(GoMotion.feedback) {
                                        exchangeReceiverId = human.id.uuidString
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(l.tr(zh: "档位", en: "Amount", de: "Betrag"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(tertiaryText)
                    ForEach(exchangeOptions) { option in
                        Button {
                            withAnimation(GoMotion.feedback) {
                                exchangeOptionId = option.id
                            }
                        } label: {
                            HStack {
                                Text("\(option.coconutCost)🥥")
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(primaryText)
                                Spacer()
                                Text(option.formattedAmount)
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(exchangeOptionId == option.id || (exchangeOptionId.isEmpty && selectedExchangeOption?.id == option.id) ? Color.goPrimary : secondaryText)
                            }
                            .padding(12)
                            .background(
                                exchangeOptionId == option.id || (exchangeOptionId.isEmpty && selectedExchangeOption?.id == option.id)
                                    ? Color.goPrimary.opacity(colorScheme == .dark ? 0.2 : 0.14)
                                    : Color.ohanaCardSurface,
                                in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                TextField(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"), text: $exchangeNote, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(primaryText)
                    .padding(14)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

                Button {
                    createExchange()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        Text(exchangeConfirmTitle)
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(canCreateExchange ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canCreateExchange)
            }
        }
    }

    var exchangeConfirmTitle: String {
        guard let option = selectedExchangeOption else {
            return l.tr(zh: "确认兑换", en: "Confirm exchange", de: "Tausch bestätigen")
        }
        return l.tr(
            zh: "消耗 \(option.coconutCost)🥥",
            en: "Spend \(option.coconutCost)🥥",
            de: "\(option.coconutCost)🥥 ausgeben"
        )
    }

    var canCreateExchange: Bool {
        guard CoconutExchangeFeatureGate.isEnabled else { return false }
        guard let option = selectedExchangeOption else { return false }
        return selectedExchangeReceiver != nil && currentHumanBalance >= option.coconutCost
    }

    func exchangeChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : primaryText)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isSelected ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func targetRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(primaryText)
                    Text(subtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(tertiaryText)
                }
                Spacer()
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func emptyPickerText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.callout(.bold))
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    func popupHeader(icon: String, sfSymbol: String?, title: String, subtitle: String, close: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .fill(Color.ohanaControlFill)
                if let sfSymbol {
                    Image(systemName: sfSymbol)
                        .font(OhanaFont.adaptive(size: 21, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                } else {
                    Text(icon)
                        .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            OhanaPopupCloseButton(tint: primaryText, action: close)
        }
    }

    func inlinePopup(@ViewBuilder content: @escaping () -> some View) -> some View {
        GeometryReader { proxy in
            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: pendingPurchaseItem != nil || activePicker != nil) {
                LinearGradient(
                    colors: [Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12), Color.black.opacity(colorScheme == .dark ? 0.46 : 0.24)], // ui-v4: allow modal scrim
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    pendingPurchaseItem = nil
                    activePicker = nil
                }

                VStack(spacing: 0) {
                    OhanaPopupDragHandle(tint: primaryText.opacity(0.24))
                        .padding(.top, 8)
                        .gesture(
                            DragGesture(minimumDistance: 12).onEnded { value in
                                if value.translation.height > 32 {
                                    withAnimation(GoMotion.page) {
                                        pendingPurchaseItem = nil
                                        activePicker = nil
                                    }
                                }
                            }
                        )
                    VStack(spacing: 0) {
                        content()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 22)
                }
                .frame(maxWidth: .infinity)
                .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.inlinePopup) }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.22), radius: 34, x: 0, y: -10) // ui-v4: allow lifted overlay shadow
                .padding(.horizontal, 6)
                .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
            }
            .animation(GoMotion.page, value: pendingPurchaseItem?.id)
            .animation(GoMotion.page, value: activePicker?.id)
        }
    }

    func toastView(_ toast: ShopToast) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: toast.icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .ohanaSymbolPulse(trigger: toast.id)
                Text(toast.message)
                    .font(OhanaFont.callout(.black))
                    .lineLimit(2)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(toast.tint, in: Capsule())
            .shadow(color: toast.tint.opacity(0.32), radius: 18, x: 0, y: 8) // ui-v4: allow toast elevation
            .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
