//
//  OasisRewardView+Chrome.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Navy Background

    var navyBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating blob — lime
            Ellipse()
                .fill(Color.goPrimary.opacity(0.12))
                .frame(width: 260, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: -160)

            // Floating blob — blue
            Ellipse()
                .fill(Color(hex: "5B6AFF").opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 100, y: 80)

            // Floating blob — purple
            Ellipse()
                .fill(Color(hex: "A855F7").opacity(0.13))
                .frame(width: 200, height: 180)
                .blur(radius: 65)
                .offset(x: -60, y: 340)
        }
    }

    // MARK: - Header

    var oasisFixedToolbar: some View {
        HStack(spacing: 8) {
            oasisToolbarButton(systemName: "xmark") {
                dismiss()
            }
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))

            Spacer()

            oasisToolbarButton(systemName: "info.circle") {
                openSheet(.coconutRules)
            }
            .accessibilityLabel(l.tr(zh: "椰子规则", en: "Coconut rules", de: "Kokosnuss-Regeln"))
            oasisToolbarButton(systemName: "shippingbox.fill") {
                openSheet(.inventory)
            }
            .accessibilityLabel(l.tr(zh: "库存", en: "Inventory", de: "Inventar"))
        }
    }

    var oasisHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "OASIS · 绿洲", en: "OASIS", de: "OASE"))
                    .font(OhanaFont.caption(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(l.tr(zh: "生命之树", en: "Life Tree", de: "Lebensbaum"))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Spacer()
            headerCoconutBalanceButton
        }
        .accessibilityIdentifier("oasis-screen")
    }

    var headerCoconutBalanceButton: some View {
        CoconutBalanceCapsule(
            balance: activeHumanCoconutBalance,
            showsDeltaAnimation: true,
            deltaAnimationContext: "oasis-\(currentActiveHumanId.isEmpty ? "global" : currentActiveHumanId)"
        ) {
            presentCoconutLog()
        }
        .accessibilityLabel(l.tr(
            zh: "椰子资产 \(activeHumanCoconutBalance)",
            en: "Coconut balance \(activeHumanCoconutBalance)",
            de: "Kokosnuss-Guthaben \(activeHumanCoconutBalance)"
        ))
        .accessibilityHint(l.tr(zh: "打开椰子历史", en: "Open coconut history", de: "Kokosnuss-Verlauf öffnen"))
    }

    func presentCoconutLog() {
        onPresentCoconutLog?(nil)
    }
}
