//
//  CoconutShopView+Commands.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension CoconutShopView {
    func retryRecovery(for itemID: String) {
        guard recoveryInFlightItemID == nil,
              purchaseSettlements[itemID] == .needsAttention,
              ShopManualRecoveryActionPolicy.canRetry(
                  reasonCode: purchaseSettlementReasons[itemID]
              ) else { return }
        recoveryInFlightItemID = itemID
        commandQueue.enqueue(.shopPurchase(humanID: currentHuman?.id, itemID: itemID)) {
            let result = retryPurchaseRecovery(itemID)
            handleRecoveryResult(result, itemID: itemID)
        }
    }

    private func handleRecoveryResult(
        _ result: ShopPurchaseManualRecoveryResult,
        itemID: String
    ) {
        switch result.disposition {
        case .fulfilled:
            blockedPurchaseItemIDs.remove(itemID)
            OhanaFeedback.success()
            showToast(
                l.tr(
                    zh: "兑换已安全完成，没有再次扣款。",
                    en: "The redemption completed safely without another charge.",
                    de: "Die Einlösung wurde ohne erneute Belastung sicher abgeschlossen."
                ),
                icon: "checkmark.circle.fill",
                tint: Color.goPrimary
            )
        case .refunded:
            blockedPurchaseItemIDs.remove(itemID)
            OhanaFeedback.success()
            showToast(
                l.tr(
                    zh: "原付款已安全退回，没有再次扣款。",
                    en: "The original payment was safely refunded without another charge.",
                    de: "Die ursprüngliche Zahlung wurde ohne erneute Belastung sicher erstattet."
                ),
                icon: "arrow.uturn.backward.circle.fill",
                tint: Color.goTeal
            )
        case .retryScheduled:
            blockedPurchaseItemIDs.remove(itemID)
            OhanaFeedback.warning()
            showToast(
                l.tr(
                    zh: "恢复已继续，仍在安全结算；不会再次扣款。",
                    en: "Recovery resumed and is still settling safely; there is no second charge.",
                    de: "Die Wiederherstellung wurde fortgesetzt und wird sicher verarbeitet; es erfolgt keine zweite Belastung."
                ),
                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tint: Color.goTeal
            )
        case .stillNeedsAttention:
            OhanaFeedback.warning()
            showToast(
                purchaseRecoveryReasonMessage(result.reasonCode),
                icon: "exclamationmark.triangle.fill",
                tint: Color.goOrange
            )
        }
        refreshData()
        _ = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
            guard recoveryInFlightItemID == itemID else { return }
            recoveryInFlightItemID = nil
        }
    }

    func purchaseRecoveryReasonMessage(_ reason: String?) -> String {
        switch reason {
        case "catalogItemMissing":
            l.tr(
                zh: "商品定义目前不可用；本机兑换记录已保留，请在商品恢复后重试。",
                en: "The item definition is unavailable. The local redemption record is preserved; retry after the item returns.",
                de: "Die Artikeldefinition ist nicht verfügbar. Der lokale Einlösungsdatensatz bleibt erhalten; versuche es erneut, sobald der Artikel zurück ist."
            )
        case "catalogPriceChanged":
            l.tr(
                zh: "商品价格与原付款记录不一致，已停止自动处理以避免错误结算。",
                en: "The current item price does not match the original payment, so automatic settlement remains stopped.",
                de: "Der aktuelle Artikelpreis stimmt nicht mit der ursprünglichen Zahlung überein; die automatische Abwicklung bleibt daher gestoppt."
            )
        case "missingFundingSnapshot":
            l.tr(
                zh: "原付款成员明细不完整，无法确认应退给谁；本机记录不会被删除。",
                en: "The original payer snapshot is incomplete, so a safe refund recipient cannot be confirmed. The local record will not be removed.",
                de: "Die ursprüngliche Zahlerübersicht ist unvollständig; ein sicherer Erstattungsempfänger kann nicht bestätigt werden. Der lokale Datensatz wird nicht entfernt."
            )
        case "invalidFundingSnapshot":
            l.tr(
                zh: "原付款明细未通过安全校验；系统会仅依据原始扣款账本尝试重建，不会再次扣款。",
                en: "The original payer details failed validation. Recovery will only use the original debit ledger and cannot charge again.",
                de: "Die ursprünglichen Zahlerdaten haben die Sicherheitsprüfung nicht bestanden. Die Wiederherstellung verwendet nur das ursprüngliche Belastungsjournal und belastet nicht erneut."
            )
        case "missingOrFrozenRefundRecipient":
            l.tr(
                zh: "原付款成员不存在或钱包已冻结；恢复该成员后可重新尝试退款。",
                en: "An original payer is missing or has a frozen wallet. Restore that member before retrying the refund.",
                de: "Ein ursprünglicher Zahler fehlt oder hat ein eingefrorenes Wallet. Stelle das Mitglied wieder her, bevor du die Erstattung erneut versuchst."
            )
        case "unsupportedFulfillmentKind":
            l.tr(
                zh: "当前商品无法使用安全的自动发放流程，本机兑换记录会继续保留。",
                en: "This item does not currently support safe automatic fulfillment. The local redemption record remains preserved.",
                de: "Dieser Artikel unterstützt derzeit keine sichere automatische Bereitstellung. Der lokale Einlösungsdatensatz bleibt erhalten."
            )
        case "invalidPurchaseSnapshot":
            l.tr(
                zh: "商品与原兑换记录不一致，自动结算已安全停止；本机记录会继续保留。",
                en: "The item does not match the original redemption record, so automatic settlement remains safely stopped. The local record is preserved.",
                de: "Der Artikel stimmt nicht mit dem ursprünglichen Einlösungsdatensatz überein; die automatische Abwicklung bleibt sicher gestoppt. Der lokale Datensatz bleibt erhalten."
            )
        case "legacyFulfillmentUnverifiable":
            l.tr(
                zh: "旧版兑换可能已经发放，但缺少可靠的幂等凭据；为避免重复发放或错误退款，已停止自动处理。",
                en: "This legacy redemption may already have been fulfilled but lacks reliable idempotency evidence. Automatic processing is stopped to avoid a duplicate grant or incorrect refund.",
                de: "Diese ältere Einlösung wurde möglicherweise bereits erfüllt, besitzt aber keinen verlässlichen Idempotenznachweis. Die automatische Verarbeitung wurde gestoppt, um eine doppelte Gewährung oder falsche Erstattung zu vermeiden."
            )
        case "manualReviewAttemptUnavailable":
            l.tr(
                zh: "恢复记录刚刚发生变化，请重新载入商店后再检查。",
                en: "The recovery record just changed. Reload the shop and check again.",
                de: "Der Wiederherstellungsdatensatz hat sich gerade geändert. Lade den Shop neu und prüfe erneut."
            )
        case "manualRecoveryPersistenceFailed":
            l.tr(
                zh: "恢复状态未能安全保存；本机记录保持不变，请稍后重试。",
                en: "The recovery state could not be saved safely. The local record is unchanged; try again later.",
                de: "Der Wiederherstellungsstatus konnte nicht sicher gespeichert werden. Der lokale Datensatz bleibt unverändert; versuche es später erneut."
            )
        case "unrecognizedManualReviewReason", nil:
            l.tr(
                zh: "这笔兑换仍需安全检查；本机记录会保留，也不会再次扣款。",
                en: "This redemption still needs a safety review. Its local record remains preserved and it cannot be charged again.",
                de: "Diese Einlösung benötigt weiterhin eine Sicherheitsprüfung. Der lokale Datensatz bleibt erhalten und wird nicht erneut belastet."
            )
        case let reason?:
            l.tr(
                zh: "这笔兑换仍需安全检查（\(reason)）；本机记录会保留，也不会再次扣款。",
                en: "This redemption still needs a safety review (\(reason)). Its local record remains preserved and it cannot be charged again.",
                de: "Diese Einlösung benötigt weiterhin eine Sicherheitsprüfung (\(reason)). Der lokale Datensatz bleibt erhalten und wird nicht erneut belastet."
            )
        }
    }

    var purchaseRecoverySafetyHint: String {
        l.tr(
            zh: "仅检查并继续原兑换，不会创建新订单或再次扣款。",
            en: "Checks and continues the original redemption only. It will not create a new order or charge again.",
            de: "Prüft und setzt nur die ursprüngliche Einlösung fort. Es wird keine neue Bestellung erstellt und nicht erneut belastet."
        )
    }

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
            refreshData()
            showToast(l.tr(zh: "兑换申请已发出", en: "Exchange sent", de: "Tausch gesendet"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
        } catch {
            OhanaFeedback.error()
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    func confirmExchange(_ request: CoconutExchangeRequest) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let currentHuman else { return }
        do {
            try appServices.coconutExchange.confirm(request, by: currentHuman, context: modelContext)
            refreshData()
            showToast(l.tr(zh: "已确认收到", en: "Marked received", de: "Erhalt bestätigt"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
        } catch {
            OhanaFeedback.error()
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    func cancelExchange(_ request: CoconutExchangeRequest) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let currentHuman else { return }
        do {
            try appServices.coconutExchange.cancel(request, by: currentHuman, context: modelContext)
            refreshData()
            showToast(l.tr(zh: "已取消并退回椰子", en: "Cancelled and refunded", de: "Abgebrochen und erstattet"), icon: "arrow.uturn.backward.circle.fill", tint: Color.goTeal)
        } catch {
            OhanaFeedback.error()
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
        guard purchaseInFlightItemID == nil else { return }
        guard !purchaseRetryBlocked else { return }
        guard purchaseReadiness(for: item) == .ready || (item.id == SupporterPackCatalog.supporterIconItemID && hasSupporterPack) else {
            showReadinessFailure(for: item)
            return
        }
        purchaseErrorMessage = nil
        purchaseInFlightItemID = item.id

        if item.id == SupporterPackCatalog.supporterIconItemID,
           hasSupporterPack,
           let descriptor = item.appIcon {
            appServices.appIcons.setIcon(descriptor) { result in
                purchaseInFlightItemID = nil
                switch result {
                case .success:
                    selectedAppIcon = descriptor.itemId
                    pendingPurchaseItem = nil
                    OhanaFeedback.success()
                    showToast(
                        l.tr(zh: "App Icon 已切换", en: "App Icon changed", de: "App Icon geändert"),
                        icon: "checkmark.circle.fill",
                        tint: Color.goPrimary
                    )
                case let .failure(error):
                    OhanaFeedback.error()
                    setPurchaseError(error.localizedDescription)
                }
            }
            return
        }
        if let descriptor = item.appIcon {
            purchaseAndApplyAppIcon(item, descriptor: descriptor)
        } else {
            purchase(item)
        }
    }

    func purchaseAndApplyAppIcon(_ item: ShopItem, descriptor: AppIconShopDescriptor) {
        enqueueShopPurchase(item, note: "coconutShop.appIcon") { result in
            appServices.appIcons.setIcon(descriptor) { applyResult in
                switch applyResult {
                case .success:
                    do {
                        let completed = try appServices.shopPurchaseFulfillment.completeAppIconPurchase(
                            item: item,
                            purchase: result,
                            context: modelContext
                        )
                        guard completed else {
                            purchaseInFlightItemID = nil
                            setPurchaseError(
                                pendingAppIconFinalizationMessage,
                                itemID: item.id,
                                blocksRetry: true
                            )
                            refreshData()
                            return
                        }
                        selectedAppIcon = descriptor.itemId
                        blockedPurchaseItemIDs.remove(item.id)
                        purchaseInFlightItemID = nil
                        pendingPurchaseItem = nil
                        refreshData()
                        showPurchaseSuccess(item)
                    } catch {
                        purchaseInFlightItemID = nil
                        OhanaFeedback.warning()
                        setPurchaseError(
                            pendingAppIconFinalizationMessage,
                            itemID: item.id,
                            blocksRetry: true
                        )
                        refreshData()
                    }
                case let .failure(error):
                    let refunded = refundPurchase(item, purchase: result, reason: "appIconApplyFailed")
                    purchaseInFlightItemID = nil
                    OhanaFeedback.error()
                    let message = refunded
                        ? l.tr(
                            zh: "图标切换失败，已退回 \(item.cost)🥥。\(error.localizedDescription)",
                            en: "The icon could not be changed. \(item.cost)🥥 was refunded. \(error.localizedDescription)",
                            de: "Das Symbol konnte nicht geändert werden. \(item.cost)🥥 wurden erstattet. \(error.localizedDescription)"
                        )
                        : l.tr(
                            zh: "图标切换失败，退款也未能保存。请不要重复兑换并稍后重试。",
                            en: "The icon change failed and the refund could not be saved. Do not redeem again; try later.",
                            de: "Symbolwechsel und Erstattung konnten nicht gespeichert werden. Nicht erneut einlösen; später versuchen."
                        )
                    setPurchaseError(message, itemID: item.id, blocksRetry: !refunded)
                    if !refunded { refreshData() }
                }
            }
        }
    }

    func applyAppIcon(_ descriptor: AppIconShopDescriptor, successMessage: String) {
        appServices.appIcons.setIcon(descriptor) { result in
            switch result {
            case .success:
                selectedAppIcon = descriptor.itemId
                OhanaFeedback.success()
                showToast(successMessage, icon: "checkmark.circle.fill", tint: Color.goPrimary)
            case let .failure(error):
                OhanaFeedback.error()
                showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            }
        }
    }

    func purchase(_ item: ShopItem) {
        enqueueShopPurchase(item, note: "coconutShop.purchase") { result in
            if item.isConsumable {
                guard activateBoost(item, purchase: result) else {
                    let refunded = refundPurchasedConsumable(item, purchase: result)
                    purchaseInFlightItemID = nil
                    OhanaFeedback.warning()
                    let message = refunded
                        ? l.tr(
                            zh: "这个道具当前无法生效，已退回 \(item.cost)🥥。",
                            en: "This item could not be activated. \(item.cost)🥥 was refunded.",
                            de: "Dieser Artikel konnte nicht aktiviert werden. \(item.cost)🥥 wurden erstattet."
                        )
                        : l.tr(
                            zh: "道具未能生效，退款也未能保存。请不要重复兑换并稍后重试。",
                            en: "The item was not activated and the refund could not be saved. Do not redeem again; try later.",
                            de: "Artikel und Erstattung konnten nicht gespeichert werden. Nicht erneut einlösen; später versuchen."
                        )
                    setPurchaseError(message, itemID: item.id, blocksRetry: !refunded)
                    if !refunded { refreshData() }
                    return
                }
            } else {
                activateOwnedItem(item)
            }

            blockedPurchaseItemIDs.remove(item.id)
            purchaseInFlightItemID = nil
            pendingPurchaseItem = nil
            refreshData()
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
            purchaseInFlightItemID = nil
            OhanaFeedback.error()
            let message = switch result.failure {
            case .missingActiveHuman:
                l.tr(
                    zh: "请先选择一个家庭成员。",
                    en: "Choose a family member first.",
                    de: "Wähle zuerst ein Familienmitglied."
                )
            case let .insufficientBalance(missing):
                l.tr(
                    zh: "还差 \(missing)🥥",
                    en: "Need \(missing)🥥 more",
                    de: "Noch \(missing)🥥 nötig"
                )
            case .walletFrozen:
                l.tr(
                    zh: "该钱包已冻结，历史仍可查看。",
                    en: "This wallet is frozen. History remains available.",
                    de: "Dieses Wallet ist eingefroren. Der Verlauf bleibt sichtbar."
                )
            case .backupOrRestoreInProgress:
                l.tr(
                    zh: "正在备份或恢复数据，请完成后再兑换。",
                    en: "A backup or restore is in progress. Redeem after it finishes.",
                    de: "Eine Sicherung oder Wiederherstellung läuft. Löse den Artikel danach ein."
                )
            case .persistenceFailed:
                l.tr(
                    zh: "兑换没有保存成功，未完成扣款。请重试。",
                    en: "The redemption was not saved and no completed charge was recorded. Try again.",
                    de: "Die Einlösung wurde nicht gespeichert und nicht abgeschlossen. Bitte erneut versuchen."
                )
            case .invalidItem:
                l.tr(
                    zh: "商品信息已更新，请关闭商店后重新打开。",
                    en: "This item changed. Close and reopen the shop.",
                    de: "Dieser Artikel wurde geändert. Schließe den Shop und öffne ihn erneut."
                )
            case nil:
                l.tr(
                    zh: "兑换失败，请稍后再试。",
                    en: "Purchase failed. Try again.",
                    de: "Einlösen fehlgeschlagen. Versuch es erneut."
                )
            }
            setPurchaseError(message)
            return false
        }
        return true
    }

    func setPurchaseError(
        _ message: String,
        itemID: String? = nil,
        blocksRetry: Bool = false
    ) {
        purchaseErrorMessage = message
        purchaseRetryBlocked = blocksRetry
        if blocksRetry, let itemID {
            blockedPurchaseItemIDs.insert(itemID)
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    func showPurchaseSuccess(_ item: ShopItem) {
        OhanaFeedback.success()
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
        UIAccessibility.post(notification: .announcement, argument: message)
        toastTask = Task {
            do {
                try await Task.sleep(for: .seconds(4))
            } catch {
                return
            }
            await MainActor.run {
                withAnimation(GoMotion.feedback) {
                    toast = nil
                }
            }
        }
    }

    @discardableResult
    func activateBoost(_ item: ShopItem, purchase: ShopPurchaseCommandResult) -> Bool {
        guard let attemptID = purchase.attemptID else { return false }
        return appServices.shopPurchaseFulfillment.fulfillConsumable(
            item: item,
            attemptID: attemptID,
            context: modelContext,
            services: appServices
        )
    }

    var pendingAppIconFinalizationMessage: String {
        l.tr(
            zh: "图标已经切换，但兑换记录仍在安全收尾。请先关闭商店，稍后重新打开；不要重复兑换。",
            en: "The icon changed, but the redemption record is still being finalized. Close and reopen the shop later; do not redeem again.",
            de: "Das Symbol wurde geändert, aber der Einlösedatensatz wird noch abgeschlossen. Schließe den Shop und öffne ihn später erneut; nicht erneut einlösen."
        )
    }

    func refundPurchasedConsumable(_ item: ShopItem, purchase: ShopPurchaseCommandResult) -> Bool {
        refundPurchase(item, purchase: purchase, reason: "consumableActivationFailed")
    }

    func refundPurchase(_ item: ShopItem, purchase: ShopPurchaseCommandResult, reason: String) -> Bool {
        let title = l.tr(
            zh: "退回「\(item.name(l))」",
            en: "Refunded \(item.name(l))",
            de: "\(item.name(l)) erstattet"
        )
        do {
            let didRefund = try appServices.shopPurchaseFulfillment.refundPurchase(
                item: item,
                purchase: purchase,
                humans: humans,
                context: modelContext,
                services: appServices,
                title: title,
                reason: reason
            )
            if didRefund {
                blockedPurchaseItemIDs.remove(item.id)
                refreshData()
            }
            return didRefund
        } catch {
            modelContext.rollback()
            appServices.coconutWallet.refreshQuestProjection(context: modelContext, manager: appServices.questManager)
            return false
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

    func isPlantDecorEquipped(_ itemID: String) -> Bool {
        OasisPlantDecorStore.isEquipped(
            itemID,
            equippedSceneID: equippedPlantDecorScene,
            equippedPotSkinID: equippedPlantPotSkin
        )
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
