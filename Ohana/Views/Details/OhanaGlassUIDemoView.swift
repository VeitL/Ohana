//
//  OhanaGlassUIDemoView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

struct OhanaGlassUIDemoView: View {
    var body: some View {
        ZStack {
            // 背景层：强制使用动态背景
            ArkBackgroundView()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Stats 模块
                    statsSection
                    
                    // Info 卡片
                    infoCard
                    
                    // 功能入口
                    actionButtons
                    
                    Spacer(minLength: 60)
                }
                .padding(.top, 60) // 给透明 Navbar 留白
                .padding(.horizontal, 20)
            }
            .contentMargins(.bottom, 40)
            
            // 顶部的透明导航栏毛玻璃遮罩
            VStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 100)
                    .ignoresSafeArea(.all, edges: .top)
                    .overlay(
                        Text("Dynamic Glass UI")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.top, 40)
                    )
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ohana UI 规范")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("基于 Apple iOS 全新材质系统的动态化设计语言。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            Spacer()
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 16) {
            glassStatBox(title: "活跃度", value: "92", unit: "%", icon: "bolt.fill", color: Color.goLime)
            glassStatBox(title: "满意度", value: "4.9", unit: "分", icon: "star.fill", color: Color.goYellow)
        }
    }
    
    private func glassStatBox(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.2), in: Circle())
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        // Glass UI 核心修饰符
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("设计说明")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(.primary.opacity(0.3))
            }
            
            Text("这是一种高度自适应环境背景的拟态组件结构。相比传统的纯色卡片，它能让底层的光晕动画隐约透过，提供极强的空间纵深感。同时利用极细的白色描边（strokeBorder）物理化光线反射边缘。")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {}) {
                HStack {
                    Text("主要操作交互")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20).padding(.vertical, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button(action: {}) {
                HStack {
                    Text("次要高亮交互")
                    Spacer()
                    Image(systemName: "sparkles")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goPrimary)
                .padding(.horizontal, 20).padding(.vertical, 16)
                // 结合主题色和毛玻璃的质感叠加
                .background(Color.goPrimary.opacity(0.1))
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.goPrimary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    OhanaGlassUIDemoView()
        .preferredColorScheme(.dark)
}
