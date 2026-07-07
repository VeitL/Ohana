//
//  CoconutShopView+Commands.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    func openCashExchangeForm() {
        guard CoconutExchangeFeatureGate.isEnabled else {
            activePicker = nil
            return
        }
        if exchangeReceiverId.isEmpty {
            exchangeReceiverId = otherHumans.first?.id.uuidString ?? ""
        }
        if exchangeOptionId.isEmpty {
            exchangeOptionId = exchangeOptions.first?.id ?? ""
        }
        activePicker = .cashExchange
    }

    func createExchange() {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let sender = currentHuman, let receiver = selectedExchangeReceiver, let option = selectedExchangeOption else { return }
        do {
            try appServices.coconutExchange.createRequest(
                sender: sender,
                receiver: receiver,
                option: option,
                note: exchangeNote,
                context: modelContext
            )
            activePicker = nil
            exchangeNote = ""
            showToast(l.tr(zh: "兑换申请已发出", en: "Exchange sent", de: "Tausch gesendet"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    func confirmExchange(_ request: CoconutExchangeRequest) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let currentHuman else { return }
        do {
            try appServices.coconutExchange.confirm(request, by: currentHuman, context: modelContext)
            showToast(l.tr(zh: "已确认收到", en: "Marked received", de: "Erhalt bestätigt"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    func cancelExchange(_ request: CoconutExchangeRequest) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let currentHuman else { return }
        do {
            try appServices.coconutExchange.cancel(request, by: currentHuman, context: modelContext)
            showToast(l.tr(zh: "已取消并退回椰子", en: "Cancelled and refunded", de: "Abgebrochen und erstattet"), icon: "arrow.uturn.backward.circle.fill", tint: Color.goTeal)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    func exchangeErrorMessage(_ error: Error) -> String {
        guard let exchangeError = error as? CoconutExchangeError else {
            return error.localizedDescription
        }
        switch exchangeError {
        case .featureDisabled:
            return l.tr(zh: "货币兑换暂未开放。", en: "Cash exchange is not available yet.", de: "Geldtausch ist noch nicht verfügbar.")
        case .sameReceiver:
            return l.tr(zh: "不能发给自己。", en: "You cannot send this to yourself.", de: "Du kannst es nicht an dich selbst senden.")
        case .insufficientBalance:
            return l.tr(zh: "椰子余额不足。", en: "Not enough coconuts.", de: "Nicht genug Kokosnüsse.")
        case .invalidReceiver:
            return l.tr(zh: "请选择一个家庭成员。", en: "Choose a family member.", de: "Wähle ein Familienmitglied.")
        case .notPending:
            return l.tr(zh: "这个兑换已经处理。", en: "This exchange was already handled.", de: "Dieser Tausch wurde bereits bearbeitet.")
        case .notSender:
            return l.tr(zh: "只有发起人可以取消。", en: "Only the sender can cancel.", de: "Nur der Absender kann abbrechen.")
        case .notReceiver:
            return l.tr(zh: "只有接收人可以确认。", en: "Only the receiver can confirm.", de: "Nur der Empfänger kann bestätigen.")
        case .memberInactive:
            return l.tr(zh: "纪念成员不能进行货币兑换。", en: "Memorial members cannot use cash exchange.", de: "Gedenkmitglieder können den Geldtausch nicht verwenden.")
        case let .persistenceFailed(message):
            return message ?? l.tr(zh: "兑换保存失败，请重试。", en: "Could not save the exchange. Please try again.", de: "Der Tausch konnte nicht gespeichert werden. Bitte versuche es erneut.")
        }
    }

    func confirmPurchase(_ item: ShopItem) {
        if let descriptor = item.appIcon {
            purchaseAndApplyAppIcon(item, descriptor: descriptor)
        } else {
            purchase(item)
        }
    }

    func purchaseAndApplyAppIcon(_ item: ShopItem, descriptor: AppIconShopDescriptor) {
        guard canAfford(item) else { return }
        enqueueShopPurchase(item, note: "coconutShop.appIcon") { result in
            appServices.appIcons.setIcon(descriptor) { applyResult in
                switch applyResult {
                case .success:
                    selectedAppIcon = descriptor.itemId
                    pendingPurchaseItem = nil
                    showPurchaseSuccess(item)
                case let .failure(error):
                    refundPurchase(item, purchase: result, reason: "appIconApplyFailed")
                    pendingPurchaseItem = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
                }
            }
        }
    }

    func applyAppIcon(_ descriptor: AppIconShopDescriptor, successMessage: String) {
        appServices.appIcons.setIcon(descriptor) { result in
            switch result {
            case .success:
                selectedAppIcon = descriptor.itemId
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast(successMessage, icon: "checkmark.circle.fill", tint: Color.goPrimary)
            case let .failure(error):
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            }
        }
    }

    func purchase(_ item: ShopItem) {
        enqueueShopPurchase(item, note: "coconutShop.purchase") { result in
            if item.isConsumable {
                guard activateBoost(item) else {
                    refundPurchasedConsumable(item, purchase: result)
                    pendingPurchaseItem = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    showToast(
                        l.tr(
                            zh: "本周期已使用，已退回 \(item.cost)🥥",
                            en: "Already used this period. Refunded \(item.cost)🥥",
                            de: "In diesem Zeitraum schon genutzt. \(item.cost)🥥 erstattet"
                        ),
                        icon: "arrow.uturn.backward.circle.fill",
                        tint: Color.goOrange
                    )
                    return
                }
            } else {
                activateOwnedItem(item)
            }

            pendingPurchaseItem = nil
            showPurchaseSuccess(item)

            if item.id == "fx_popout_card" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    openPopoutPetPicker()
                }
            } else if item.id == Avatar2DAccess.shopItemId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    openAvatarUpgradeTargetPicker()
                }
            }
        }
    }

    func enqueueShopPurchase(_ item: ShopItem, note: String, onSuccess: @escaping @MainActor (ShopPurchaseCommandResult) -> Void) {
        commandQueue.enqueue(.shopPurchase(humanID: currentHuman?.id, itemID: item.id)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).purchase(
                item: item,
                buyer: currentHuman,
                itemName: l.tr(
                    zh: "兑换「\(item.name(l))」",
                    en: "Redeemed \(item.name(l))",
                    de: "\(item.name(l)) eingelöst"
                ),
                note: note
            )
            guard handleShopPurchaseResult(result) else { return }
            onSuccess(result)
        }
    }

    func handleShopPurchaseResult(_ result: ShopPurchaseCommandResult) -> Bool {
        guard result.didPurchase else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            switch result.failure {
            case .missingActiveHuman:
                showToast(
                    l.tr(
                        zh: "请先选择一个家庭成员。",
                        en: "Choose a family member first.",
                        de: "Wähle zuerst ein Familienmitglied."
                    ),
                    icon: "exclamationmark.triangle.fill",
                    tint: Color.goOrange
                )
            case let .insufficientBalance(missing):
                showToast(
                    l.tr(
                        zh: "还差 \(missing)🥥",
                        en: "Need \(missing)🥥 more",
                        de: "Noch \(missing)🥥 nötig"
                    ),
                    icon: "exclamationmark.triangle.fill",
                    tint: Color.goOrange
                )
            case .walletFrozen:
                showToast(
                    l.tr(
                        zh: "该钱包已冻结，历史仍可查看。",
                        en: "This wallet is frozen. History remains available.",
                        de: "Dieses Wallet ist eingefroren. Der Verlauf bleibt sichtbar."
                    ),
                    icon: "lock.fill",
                    tint: Color.goOrange
                )
            case .persistenceFailed:
                showToast(
                    l.tr(
                        zh: "兑换没有保存成功，请稍后再试。",
                        en: "Purchase was not saved. Try again.",
                        de: "Einlösen wurde nicht gespeichert. Versuch es erneut."
                    ),
                    icon: "exclamationmark.triangle.fill",
                    tint: Color.goOrange
                )
            case nil:
                showToast(
                    l.tr(
                        zh: "兑换失败，请稍后再试。",
                        en: "Purchase failed. Try again.",
                        de: "Einlösen fehlgeschlagen. Versuch es erneut."
                    ),
                    icon: "exclamationmark.triangle.fill",
                    tint: Color.goOrange
                )
            }
            return false
        }
        return true
    }

    func showPurchaseSuccess(_ item: ShopItem) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        spawnConfetti()
        let message = item.isConsumable
            ? l.tr(zh: "「\(item.name(l))」已生效", en: "\(item.name(l)) is active", de: "\(item.name(l)) ist aktiv")
            : l.tr(zh: "「\(item.name(l))」已加入百宝箱", en: "\(item.name(l)) unlocked", de: "\(item.name(l)) freigeschaltet")
        showToast(message, icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }

    func showToast(_ message: String, icon: String, tint: Color) {
        toastTask?.cancel()
        withAnimation(GoMotion.feedback) {
            toast = ShopToast(message: message, icon: icon, tint: tint)
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            await MainActor.run {
                withAnimation(GoMotion.feedback) {
                    toast = nil
                }
            }
        }
    }

    func spawnConfetti() {
        confettiItems = (0 ..< 12).map { index in
            ConfettiDrop(emoji: ["🥥", "✦", "●", "✨"].randomElement() ?? "🥥", x: CGFloat.random(in: 36 ... 360), delay: Double(index) * 0.025)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            confettiItems.removeAll()
        }
    }

    @discardableResult
    func activateBoost(_ item: ShopItem) -> Bool {
        appServices.shopPurchaseFulfillment.fulfillConsumable(
            item: item,
            context: modelContext,
            services: appServices
        )
    }

    func refundPurchasedConsumable(_ item: ShopItem, purchase: ShopPurchaseCommandResult) {
        refundPurchase(item, purchase: purchase, reason: "consumableActivationFailed")
    }

    func refundPurchase(_ item: ShopItem, purchase: ShopPurchaseCommandResult, reason: String) {
        let title = l.tr(
            zh: "退回「\(item.name(l))」",
            en: "Refunded \(item.name(l))",
            de: "\(item.name(l)) erstattet"
        )
        do {
            try appServices.shopPurchaseFulfillment.refundPurchase(
                item: item,
                purchase: purchase,
                humans: humans,
                context: modelContext,
                services: appServices,
                title: title,
                reason: reason
            )
        } catch {
            modelContext.rollback()
            appServices.coconutWallet.refreshQuestProjection(context: modelContext, manager: appServices.questManager)
            showToast(
                l.tr(
                    zh: "退款没有保存成功，请稍后再试。",
                    en: "Refund was not saved. Try again.",
                    de: "Erstattung wurde nicht gespeichert. Versuch es erneut."
                ),
                icon: "exclamationmark.triangle.fill",
                tint: Color.goOrange
            )
        }
    }

    func activateOwnedItem(_ item: ShopItem) {
        switch item.id {
        case "fx_lime_glow":
            equipFxLimeGlow = true
        case "fx_rainbow":
            equipFxRainbow = true
        case "fx_rainbow_poop":
            equipFxRainbowPoop = true
        case "fx_popout_card":
            equipFxPopoutCard = true
        case "fx_stars":
            equipFxStars = true
        case "fx_firework":
            equipFxFirework = true
        case let itemID where OasisPlantDecorID.isPlantDecor(itemID):
            equipPlantDecor(itemID)
        case "title_guardian", "title_pioneer", "title_chef":
            equippedTitle = item.id
        default:
            break
        }
    }

    func toggleOwnedItem(_ item: ShopItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch item.id {
        case "fx_lime_glow":
            equipFxLimeGlow.toggle()
        case "fx_rainbow":
            equipFxRainbow.toggle()
        case "fx_rainbow_poop":
            equipFxRainbowPoop.toggle()
        case "fx_popout_card":
            equipFxPopoutCard.toggle()
            if equipFxPopoutCard, !pets.contains(where: { $0.cardStyleRaw == "popout" }) {
                openPopoutPetPicker()
            }
        case "fx_stars":
            equipFxStars.toggle()
        case "fx_firework":
            equipFxFirework.toggle()
        case let itemID where OasisPlantDecorID.isPlantDecor(itemID):
            togglePlantDecor(itemID)
        case "title_guardian", "title_pioneer", "title_chef":
            equippedTitle = equippedTitle == item.id ? "" : item.id
        default:
            break
        }
        showToast(ownedItemStatus(for: item), icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }

    func ownedItemStatus(for item: ShopItem) -> String {
        switch item.id {
        case "fx_lime_glow":
            return equipFxLimeGlow ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_rainbow":
            return equipFxRainbow ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_rainbow_poop":
            return equipFxRainbowPoop ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_popout_card":
            if !equipFxPopoutCard {
                return l.tr(zh: "未启用", en: "Off", de: "Aus")
            }
            return activePets.contains { $0.cardStyleRaw == "popout" }
                ? l.tr(zh: "已启用 · 可更换", en: "On · Change", de: "Aktiv · Ändern")
                : l.tr(zh: "选择宠物/素材", en: "Choose pet/asset", de: "Tier/Motiv wählen")
        case "fx_stars":
            return equipFxStars ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_firework":
            return equipFxFirework ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case let itemID where OasisPlantDecorID.isPlantDecor(itemID):
            return isPlantDecorEquipped(itemID)
                ? l.tr(zh: "已布置", en: "Placed", de: "Platziert")
                : l.tr(zh: "未布置", en: "Not placed", de: "Nicht platziert")
        case "title_guardian", "title_pioneer", "title_chef":
            return equippedTitle == item.id ? l.tr(zh: "已装备", en: "Equipped", de: "Ausgerüstet") : l.tr(zh: "未装备", en: "Not equipped", de: "Nicht ausgerüstet")
        default:
            return item.isPurchased ? l.tr(zh: "已拥有", en: "Owned", de: "Besitzt") : ""
        }
    }

    func isOwnedItemEquipped(_ item: ShopItem) -> Bool {
        switch item.id {
        case "fx_lime_glow": equipFxLimeGlow
        case "fx_rainbow": equipFxRainbow
        case "fx_rainbow_poop": equipFxRainbowPoop
        case "fx_popout_card": equipFxPopoutCard && activePets.contains { $0.cardStyleRaw == "popout" }
        case "fx_stars": equipFxStars
        case "fx_firework": equipFxFirework
        case let itemID where OasisPlantDecorID.isPlantDecor(itemID): isPlantDecorEquipped(itemID)
        case "title_guardian", "title_pioneer", "title_chef": equippedTitle == item.id
        default: false
        }
    }

    func showsShopSwitch(for item: ShopItem) -> Bool {
        if item.id == Avatar2DAccess.shopItemId {
            return Avatar2DAccess.extraPassCount > 0
        }
        if item.category == .title_ {
            return item.isPurchased
        }
        if item.category == .plantDecor {
            return item.isPurchased
        }
        return item.isPurchased && isToggleableEffect(item)
    }

    func isToggleableEffect(_ item: ShopItem) -> Bool {
        switch item.id {
        case "fx_lime_glow", "fx_rainbow", "fx_rainbow_poop", "fx_popout_card", "fx_stars", "fx_firework":
            true
        default:
            false
        }
    }

    func equipPlantDecor(_ itemID: String) {
        switch OasisPlantDecorID.slot(for: itemID) {
        case .scene:
            equippedPlantDecorScene = itemID
        case .potSkin:
            equippedPlantPotSkin = itemID
        case nil:
            break
        }
    }

    func togglePlantDecor(_ itemID: String) {
        switch OasisPlantDecorID.slot(for: itemID) {
        case .scene:
            equippedPlantDecorScene = equippedPlantDecorScene == itemID ? "" : itemID
        case .potSkin:
            equippedPlantPotSkin = equippedPlantPotSkin == itemID ? "" : itemID
        case nil:
            break
        }
    }

    func isPlantDecorEquipped(_ itemID: String) -> Bool {
        OasisPlantDecorStore.isEquipped(
            itemID,
            equippedSceneID: equippedPlantDecorScene,
            equippedPotSkinID: equippedPlantPotSkin
        )
    }

    func shopTogglePill(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? Color.goPrimary : Color.ohanaControlFill)
            .frame(width: 46, height: 26)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(isOn ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.58))
                    .frame(width: 18, height: 18) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .padding(.horizontal, 4)
            }
            .animation(GoMotion.selection, value: isOn)
            .accessibilityLabel(isOn ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus"))
    }

    func activeConsumableStatus(for item: ShopItem) -> String? {
        let snapshot = appServices.shopInventory.consumableSnapshot()
        switch item.id {
        case "boost_double":
            return snapshot.isDoubleRewardBoostActive ? l.tr(zh: "已激活", en: "Active", de: "Aktiv") : nil
        case "boost_streak":
            if let expiry = snapshot.streakShieldExpiry, expiry > Date() {
                return l.tr(zh: "保护中", en: "Protected", de: "Geschützt")
            }
            return nil
        case Avatar2DAccess.shopItemId:
            let count = Avatar2DAccess.extraPassCount
            return count > 0 ? l.tr(zh: "库存 \(count) 张", en: "\(count) available", de: "\(count) verfügbar") : nil
        default:
            return nil
        }
    }

    func openAvatarUpgradeTargetPicker() {
        guard Avatar2DAccess.extraPassCount > 0 else {
            showToast(l.tr(zh: "当前没有可用的 2.5D 头像券。", en: "No 2.5D avatar pass available.", de: "Kein 2,5D-Avatarpass verfügbar."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        activePicker = .avatarTarget
    }

    func openPopoutPetPicker() {
        if activePets.count == 1 {
            equipPopoutPet = activePets.first
        } else {
            activePicker = .popoutPet
        }
    }

    func upgradeHumanTo2DAvatar(_ human: Human) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.avatar2DUpgrade(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).upgradeHumanTo2DAvatar(
                human,
                note: "coconutShop.avatar2D.human"
            )
            handleAvatar2DUpgradeResult(result, name: human.name)
        }
    }

    func upgradePetTo2DAvatar(_ pet: Pet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.avatar2DUpgrade(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).upgradePetTo2DAvatar(
                pet,
                note: "coconutShop.avatar2D.pet"
            )
            handleAvatar2DUpgradeResult(result, name: pet.name)
        }
    }

    func handleAvatar2DUpgradeResult(_ result: Avatar2DUpgradeCommandResult, name: String) {
        guard result.didUpgrade else {
            let message: String = switch result.failure {
            case .missingProfile:
                result.kind == EntityKind.human.rawValue
                    ? l.tr(zh: "请先补充性别或生日资料后再试。", en: "Add gender or birthday details first.", de: "Ergänze zuerst Geschlecht oder Geburtstag.")
                    : l.tr(zh: "请先补充物种或品种资料后再试。", en: "Add species or breed details first.", de: "Ergänze zuerst Art oder Rasse.")
            case .noPass, nil:
                l.tr(zh: "当前没有可用的 2.5D 头像券。", en: "No 2.5D avatar pass available.", de: "Kein 2,5D-Avatarpass verfügbar.")
            case .memberInactive:
                l.tr(zh: "纪念成员不能再升级头像。", en: "Memorial members cannot upgrade avatars.", de: "Gedenkmitglieder können Avatare nicht mehr aktualisieren.")
            case .persistenceFailed:
                l.tr(zh: "头像保存失败，请稍后重试。", en: "Could not save the avatar. Try again in a moment.", de: "Der Avatar konnte nicht gespeichert werden. Versuche es gleich erneut.")
            }
            showToast(message, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        appServices.domainRevisions.publishAvatar2DUpgrade(result, note: "shop.avatar2D.purchase")
        activePicker = nil
        showToast(l.tr(zh: "\(name) 已升级 2.5D 头像", en: "\(name) now has a 2.5D avatar", de: "\(name) hat jetzt einen 2,5D-Avatar"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }
}
