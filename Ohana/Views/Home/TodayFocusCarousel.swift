//
//  TodayFocusCarousel.swift
//  Ohana
//
//  Horizontal home cards for the collapsed GO home screen.
//

import SwiftUI

struct TodayFocusCarousel<Content: View>: View {
    let cardMargin: CGFloat
    let animation: Animation
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(280, proxy.size.width - (cardMargin * 2))
            TabView {
                content(cardWidth)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .automatic))
            .animation(animation, value: cardWidth)
        }
        .frame(height: 192)
        .padding(.top, 12)
    }
}
