//
//  AddWizardGameComponents.swift
//  Ohana
//
//  Shared lightweight RPG-style creation components for human and pet wizards.
//

import SwiftUI

enum AddWizardThemePalette {
    static let gridColumnCount = 10

    // Apple-style compact grid. Excludes Ohana's reserved goLime/goBlue primary colors.
    static let memberOptions: [(hex: String, label: String)] = [
        ("FFFFFF", "白"), ("F2F2F7", "雾灰"), ("D1D5DB", "浅灰"), ("9CA3AF", "银灰"), ("6B7280", "石墨"),
        ("374151", "深灰"), ("111827", "墨黑"), ("2D1B69", "夜紫"), ("3B1D4A", "深莓"), ("143642", "深海"),
        ("164E63", "孔雀"), ("1E3A8A", "海军"), ("312E81", "靛夜"), ("4C1D95", "紫夜"), ("831843", "莓红"),
        ("7F1D1D", "暗红"), ("7C2D12", "陶土"), ("78350F", "咖啡"), ("713F12", "古金"), ("365314", "苔绿"),
        ("0E7490", "湖青"), ("1D4ED8", "皇家蓝"), ("4338CA", "紫蓝"), ("6D28D9", "紫罗兰"), ("BE185D", "玫莓"),
        ("B91C1C", "酒红"), ("C2410C", "橘红"), ("B45309", "琥珀"), ("A16207", "橄榄金"), ("4D7C0F", "森林"),
        ("0891B2", "海青"), ("2563EB", "明蓝"), ("4F46E5", "靛蓝"), ("7C3AED", "电紫"), ("DB2777", "亮粉"),
        ("DC2626", "红"), ("EA580C", "橙"), ("D97706", "蜜橙"), ("CA8A04", "芥末"), ("65A30D", "叶绿"),
        ("06B6D4", "冰青"), ("60A5FA", "天蓝"), ("818CF8", "薰衣草"), ("A78BFA", "淡紫"), ("F472B6", "粉"),
        ("FB7185", "珊瑚"), ("F97316", "暖橙"), ("F59E0B", "金"), ("EAB308", "向日葵"), ("84CC16", "青叶"),
        ("A5F3FC", "浅青"), ("BFDBFE", "雾蓝"), ("C7D2FE", "浅靛"), ("DDD6FE", "浅紫"), ("FBCFE8", "浅粉"),
        ("FECACA", "浅红"), ("FED7AA", "浅橙"), ("FDE68A", "奶油"), ("FEF3C7", "米黄"), ("D9F99D", "嫩叶")
    ]
}

struct AddWizardJoinCelebrationOverlay: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = .goPrimary

    var body: some View {
        ZStack {
            Color.ohanaPrimaryText.opacity(0.26)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 72, height: 72)
                    Image(systemName: systemImage)
                        .font(OhanaFont.adaptive(size: 30, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.arkInk)
                }
                VStack(spacing: 5) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: min(ScreenCompat.width - 42, 360))
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}
