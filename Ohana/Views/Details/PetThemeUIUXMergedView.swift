//
//  PetThemeUIUXMergedView.swift
//  Ohana
//
//  合并页：宠物主题 UI/UX 规范 + Material UI 测试
//

import SwiftUI

struct PetThemeUIUXMergedView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case petTheme = "宠物主题规范"
        case material = "Material UI"
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .petTheme

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 12) {
                Picker("规范模块", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .petTheme:
                        HomeControlUITestView(embeddedInMergedPage: true)
                    case .material:
                        MaterialDesignTestView(embeddedInMergedPage: true)
                    }
                }
            }
        }
        .navigationTitle("宠物主题 UI/UX 规范页")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PetThemeUIUXMergedView()
    }
}
