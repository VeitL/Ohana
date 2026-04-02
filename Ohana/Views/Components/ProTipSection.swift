//
//  ProTipSection.swift
//  Ohana
//
//  魔法粘贴引导卡片 - 优化可读性版本
//  适配深色/浅色模式，高对比度设计
//

import SwiftUI

struct ProTipSection: View {
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - 配色方案（深浅模式自适应）
    private var cardBg: Color {
        colorScheme == .light 
            ? Color(hex: "FFF8F0")  // 浅暖白
            : Color(hex: "2A2520")  // 深暖灰
    }
    
    private var cardBorder: Color {
        colorScheme == .light
            ? Color(hex: "FF5A00").opacity(0.4)
            : Color(hex: "FF8A4A").opacity(0.5)
    }
    
    private var titleColor: Color {
        colorScheme == .light ? .primary : .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: 标题行
            HStack(spacing: 10) {
                // 魔法图标
                ZStack {
                    Circle()
                        .fill(Color(hex: "FF5A00").opacity(colorScheme == .light ? 0.12 : 0.25))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "FF5A00"))
                }
                
                Text("解锁 3D 悬浮卡片")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)
                
                Spacer()
                
                // 新功能标签
                Text("NEW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "FF5A00"), in: Capsule())
            }
            
            // MARK: 步骤说明
            VStack(alignment: .leading, spacing: 8) {
                StepRow(
                    icon: "1.circle.fill",
                    text: "在系统相册中",
                    highlightText: "长按宠物主体",
                    suffix: "",
                    highlightColor: Color(hex: "FF5A00")
                )
                
                StepRow(
                    icon: "2.circle.fill",
                    text: "点击",
                    highlightText: "拷贝",
                    suffix: "保存到剪贴板",
                    highlightColor: Color(hex: "FF5A00")
                )
                
                StepRow(
                    icon: "3.circle.fill",
                    text: "返回 Ohana，点击下方",
                    highlightText: "粘贴按钮",
                    suffix: "",
                    highlightColor: Color(hex: "FF5A00")
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(cardBorder, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - 步骤行组件
private struct StepRow: View {
    let icon: String
    let text: String
    let highlightText: String
    let suffix: String
    let highlightColor: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(highlightColor)
                .frame(width: 24)
            
            Group {
                Text(text)
                    .foregroundStyle(.primary.opacity(0.8))
                + Text(highlightText)
                    .bold()
                    .foregroundStyle(highlightColor)
                + Text(suffix)
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .font(.system(size: 14, weight: .medium))
            
            Spacer()
        }
    }
}

// MARK: - 预览
#Preview {
    ZStack {
        Color(hex: "1C1C1E").ignoresSafeArea()
        ProTipSection()
            .padding(.horizontal, 20)
    }
}

#Preview("Light Mode") {
    ZStack {
        Color(hex: "F2F2F7").ignoresSafeArea()
        ProTipSection()
            .padding(.horizontal, 20)
    }
}
