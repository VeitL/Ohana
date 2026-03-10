//
//  ArkBackgroundView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

struct ArkBackgroundView: View {
    var level: IslandLevel = .seedling

    @State private var animate1 = false
    @State private var animate2 = false
    @State private var animate3 = false

    var body: some View {
        ZStack {
            // 基础深蓝底色
            Color.goDeepNavy
                .ignoresSafeArea()

            // 光晕 1
            Circle()
                .fill(Color.goLime)
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .opacity(0.06)
                .offset(x: animate1 ? 150 : -120, y: animate1 ? 250 : -200)
                .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate1)

            // 光晕 2
            Circle()
                .fill(Color.goPrimary)
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .opacity(0.08)
                .offset(x: animate2 ? -200 : 150, y: animate2 ? 100 : -150)
                .animation(.easeInOut(duration: 15).repeatForever(autoreverses: true), value: animate2)

            // 光晕 3
            Circle()
                .fill(Color.goMint)
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .opacity(0.05)
                .offset(x: animate3 ? 100 : -150, y: animate3 ? -250 : 300)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate3)

            // 微妙噪点纹理保留
            NoiseTextureView()
                .opacity(0.015)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            animate1 = true
            animate2 = true
            animate3 = true
        }
    }
}

#Preview {
    ArkBackgroundView()
}
