//
//  CoconutShopView+Popups.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    func purchaseConfirmation(item: ShopItem) -> some View {
        let funding = fundingPreview(for: item)
        return VStack(alignment: .leading, spacing: 20) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        itemPreview(item, isEquipped: itemState(item).isEquipped)
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                        purchaseItemCopy(item)
                    }
                } else {
                    HStack(spacing: 12) {
                        itemPreview(item, isEquipped: itemState(item).isEquipped)
                            .frame(width: 86, height: 86)
                            .accessibilityHidden(true)
                        purchaseItemCopy(item)
                    }
                }
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(l.tr(zh: "本次兑换：\(item.cost)🥥", en: "This redemption: \(item.cost)🥥", de: "Diese Einlösung: \(item.cost)🥥"))
                } icon: {
                    Image(systemName: "c.circle.fill") // a11y: allow decorative currency symbol; Label provides the redemption cost text.
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goYellow)

                Text(l.tr(
                    zh: "执行前会重新校验余额；以下是按当前余额计算的预计出资。",
                    en: "Balances are revalidated before purchase. This is the contribution preview using current balances.",
                    de: "Die Guthaben werden vor dem Kauf erneut geprüft. Dies ist die Vorschau mit den aktuellen Guthaben.",
                    es: "Los saldos se vuelven a comprobar antes de comprar. Esta es la aportación prevista con los saldos actuales.",
                    pt: "Os saldos são verificados novamente antes da compra. Esta é a previsão com os saldos atuais.",
                    fr: "Les soldes sont revérifiés avant l’achat. Voici la répartition prévue avec les soldes actuels.",
                    ja: "購入直前に残高を再確認します。以下は現在の残高による支払い予定です。",
                    ko: "구매 직전에 잔액을 다시 확인합니다. 아래는 현재 잔액 기준 예상 분담액입니다.",
                    it: "I saldi vengono ricontrollati prima dell’acquisto. Questa è la ripartizione prevista con i saldi attuali."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                ForEach(funding) { contribution in
                    HStack(spacing: 8) {
                        Image(systemName: contribution.isPrimary ? "person.crop.circle.fill" : "person.2.fill")
                            .foregroundStyle(contribution.isPrimary ? Color.goTeal : Color.goYellow)
                            .accessibilityHidden(true)
                        Text(contribution.name)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        Spacer()
                        Text("\(contribution.amount)🥥")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goYellow)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(contribution.name) \(contribution.amount)🥥")
                }
            }

            finalSaleNotice

            if let purchaseErrorMessage {
                Label(purchaseErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goOrange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.goOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                    .accessibilityIdentifier("coconut-shop-purchase-error")
            }

            Button {
                confirmPurchase(item)
            } label: {
                HStack(spacing: 8) {
                    if purchaseInFlightItemID == item.id {
                        ProgressView()
                            .tint(Color.ohanaPrimaryActionText)
                    } else if purchaseRetryBlocked {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90") // a11y: allow decorative status symbol; the adjacent text names the recovery action.
                    } else {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    }
                    Text(
                        purchaseInFlightItemID == item.id
                            ? l.tr(zh: "兑换中…", en: "Redeeming…", de: "Wird eingelöst…")
                            : purchaseRetryBlocked
                                ? l.tr(zh: "关闭后稍后重试", en: "Close and try later", de: "Schließen und später erneut versuchen")
                            : l.tr(zh: "确认兑换", en: "Confirm redemption", de: "Einlösen bestätigen")
                    )
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(purchaseInFlightItemID != nil || purchaseRetryBlocked)
            .accessibilityIdentifier("coconut-shop-confirm-purchase-\(item.id)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coconut-shop-purchase-popup-\(item.id)")
    }

    private var finalSaleNotice: some View {
        Label {
            Text(l.tr(
                zh: "确认后即为最终成交，不可撤销或退款。若应用暂时失败，商品或权益会保留并继续恢复，不会再次扣款。",
                en: "Confirmation is final and cannot be cancelled or refunded. If application is delayed, the item or entitlement remains and recovery continues without another charge.",
                de: "Die Bestätigung ist endgültig und kann weder storniert noch erstattet werden. Bei verzögerter Anwendung bleibt der Artikel erhalten und die Wiederherstellung läuft ohne erneute Belastung weiter.",
                es: "La confirmación es definitiva y no se puede cancelar ni reembolsar. Si la aplicación se retrasa, el artículo se conserva y la recuperación continúa sin otro cargo.",
                pt: "A confirmação é definitiva e não pode ser cancelada nem reembolsada. Se a aplicação atrasar, o item permanece e a recuperação continua sem nova cobrança.",
                fr: "La confirmation est définitive, sans annulation ni remboursement. Si l’application est retardée, l’article reste acquis et la récupération continue sans nouveau débit.",
                ja: "確定後の購入は取り消し・返金できません。適用が遅れた場合も商品や権利は保持され、再課金なしで復旧を続けます。",
                ko: "확정된 구매는 취소하거나 환불할 수 없습니다. 적용이 지연되어도 상품이나 권리는 유지되며 추가 결제 없이 복구가 계속됩니다.",
                it: "La conferma è definitiva e non può essere annullata o rimborsata. Se l’applicazione tarda, l’articolo resta acquisito e il recupero continua senza nuovi addebiti."
            ))
        } icon: {
            Image(systemName: "checkmark.shield.fill") // a11y: allow decorative icon; Label text carries the complete final-sale notice
        }
        .font(OhanaFont.caption(.bold))
        .foregroundStyle(Color.goOrange)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.goOrange.opacity(0.12),
            in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
        )
        .accessibilityIdentifier("coconut-shop-final-sale-notice")
    }

    func purchaseItemCopy(_ item: ShopItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name(l))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(primaryText)
            Text(item.description(l))
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func pickerContent(_ picker: ShopPicker) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch picker {
            case .avatarTarget:
                Text(l.tr(zh: "库存 \(Avatar2DAccess.extraPassCount) 张", en: "\(Avatar2DAccess.extraPassCount) available", de: "\(Avatar2DAccess.extraPassCount) verfügbar"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(secondaryText)
                targetList
            case .popoutPet:
                Text(l.tr(zh: "选择一个宠物作为破框卡片素材。", en: "Choose a pet for the popout card artwork.", de: "Wähle ein Tier als Motiv für die Popout-Karte."))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(secondaryText)
                petPickerList
            case .cashExchange:
                cashExchangeForm
            }
        }
        .padding(20)
    }

    func pickerTitle(_ picker: ShopPicker) -> String {
        switch picker {
        case .avatarTarget:
            l.tr(zh: "选择头像对象", en: "Choose avatar target", de: "Avatar-Ziel wählen")
        case .popoutPet:
            l.tr(zh: "绑定破框卡片", en: "Bind popout card", de: "Popout-Karte binden")
        case .cashExchange:
            l.tr(zh: "货币兑换", en: "Cash exchange", de: "Geldtausch")
        }
    }

    var targetList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if Avatar2DAccess.extraPassCount <= 0 {
                    emptyPickerText(l.tr(zh: "暂无可用头像券。", en: "No avatar passes available.", de: "Keine Avatarpässe verfügbar."))
                } else if activeHumans.isEmpty, activePets.isEmpty {
                    emptyPickerText(l.tr(zh: "请先创建一个人类或宠物成员。", en: "Create a human or pet first.", de: "Erstelle zuerst einen Menschen oder ein Tier."))
                } else {
                    ForEach(activeHumans) { human in
                        targetRow(icon: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji, title: human.name, subtitle: l.tr(zh: "人类", en: "Human", de: "Mensch")) {
                            upgradeHumanTo2DAvatar(human)
                        }
                    }
                    ForEach(activePets) { pet in
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
                if activePets.isEmpty {
                    emptyPickerText(l.tr(zh: "还没有宠物可以绑定。", en: "No pet to bind yet.", de: "Noch kein Tier zum Binden."))
                } else {
                    ForEach(activePets) { pet in
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
                Image(systemName: "chevron.forward") // a11y: allow decorative icon covered by surrounding text or control
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

    func toastView(_ toast: ShopToast) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: toast.icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .ohanaSymbolPulse(trigger: toast.id)
                Text(toast.message)
                    .font(OhanaFont.callout(.black))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(toast.tint, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .shadow(color: toast.tint.opacity(0.32), radius: 18, x: 0, y: 8) // ui-v4: allow toast elevation
            .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(toast.message)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("coconut-shop-toast")
    }
}
