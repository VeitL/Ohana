//
//  FocusHomeStackLayerView.swift
//  Ohana
//
//  Top-level collapsed home composition: header, Today Focus, empty state, and wallet stack.
//

import SwiftUI

struct FocusHomeStackLayerView<Header: View, TodayFocus: View, Wallet: View>: View {
    var topInset: CGFloat
    var isEmptyState: Bool
    var cardMargin: CGFloat
    var onAddPet: () -> Void
    var onAddHuman: () -> Void
    @ViewBuilder var header: (CGFloat) -> Header
    @ViewBuilder var todayFocus: () -> TodayFocus
    @ViewBuilder var wallet: () -> Wallet

    var body: some View {
        VStack(spacing: 0) {
            header(topInset)

            todayFocus()
                .offset(y: -20)
                .padding(.bottom, -10)

            if isEmptyState {
                Spacer(minLength: 0)
                EmptyStateWelcomeCard(
                    onAddPet: onAddPet,
                    onAddHuman: onAddHuman
                )
                .padding(.horizontal, cardMargin)
                .padding(.bottom, 24)
            } else {
                wallet()
                    .padding(.horizontal, cardMargin)
            }
        }
    }
}
