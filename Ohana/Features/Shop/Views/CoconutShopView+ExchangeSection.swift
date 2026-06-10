//
//  CoconutShopView+ExchangeSection.swift
//  Ohana
//

import SwiftUI
import SwiftData

extension CoconutShopView {
    var cashExchangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                openCashExchangeForm()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.goYellow.opacity(colorScheme == .dark ? 0.2 : 0.16))
                        Image(systemName: "banknote.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 25, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goYellow)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "家庭线下兑现", en: "Family cash note", de: "Familien-Auszahlung"))
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(primaryText)
                        Text(l.tr(
                            zh: "只记录谁兑换给谁，不处理真实支付。",
                            en: "Records who should pay whom offline. No real payment in app.",
                            de: "Notiert nur, wer offline zahlt. Keine echte Zahlung in der App."
                        ))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 25, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                        .ohanaSymbolPulse(trigger: activePicker?.id ?? "")
                        .ohanaPing(
                            trigger: incomingPendingExchanges.count,
                            accent: Color.goYellow,
                            isEnabled: !incomingPendingExchanges.isEmpty
                        )
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if !incomingPendingExchanges.isEmpty {
                exchangeList(
                    title: l.tr(zh: "待你确认", en: "Waiting for you", de: "Wartet auf dich"),
                    requests: incomingPendingExchanges,
                    mode: .incoming
                )
            }

            if !outgoingPendingExchanges.isEmpty {
                exchangeList(
                    title: l.tr(zh: "已发出", en: "Sent", de: "Gesendet"),
                    requests: outgoingPendingExchanges,
                    mode: .outgoing
                )
            }

            if incomingPendingExchanges.isEmpty && outgoingPendingExchanges.isEmpty {
                Text(l.tr(
                    zh: "暂无待处理兑换。兑换是家庭内部的线下兑现记录，确认收到后才完成。",
                    en: "No pending exchanges. Exchanges are offline family notes and finish after the receiver confirms.",
                    de: "Keine offenen Tausche. Sie sind Offline-Notizen und werden erst nach Bestätigung abgeschlossen."
                ))
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    enum ExchangeListMode {
        case incoming
        case outgoing
    }

    func exchangeList(title: String, requests: [CoconutExchangeRequest], mode: ExchangeListMode) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(tertiaryText)
            ForEach(requests) { request in
                exchangeRow(request, mode: mode)
            }
        }
    }

    func exchangeRow(_ request: CoconutExchangeRequest, mode: ExchangeListMode) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(request.senderName) → \(request.receiverName)")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(primaryText)
                Text("\(CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)) · \(request.coconutCost)🥥")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            switch mode {
            case .incoming:
                Button {
                    confirmExchange(request)
                } label: {
                    Text(l.tr(zh: "已收到", en: "Received", de: "Erhalten"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            case .outgoing:
                Button {
                    cancelExchange(request)
                } label: {
                    Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
