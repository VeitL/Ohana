//
//  AddEntityView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

enum EntityType: String, CaseIterable {
    case pet = "宠物"
    case human = "家庭成员"
    case plant = "植物"
    
    var icon: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .human: return "person.fill"
        case .plant: return "leaf.fill"
        }
    }
    
    var emoji: String {
        switch self {
        case .pet: return "🐾"
        case .human: return "👤"
        case .plant: return "🌱"
        }
    }
    
    var color: Color {
        switch self {
        case .pet: return Color.arkCoral
        case .human: return Color(hex: "667eea")
        case .plant: return Color.arkMint
        }
    }

    var isAvailable: Bool {
        switch self {
        case .pet, .human, .plant: return true
        }
    }
}

struct AddEntityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appUIStyle") private var appUIStyle: String = "classic"
    @State private var selectedType: EntityType?

    private var isMaterial: Bool { appUIStyle == "material" }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? Color.white : Color(hex: "1C1C1E") }
    private let accent = Color(hex: "FF5A00")
    private var textSec: Color { colorScheme == .light ? Color(hex: "8E8E93") : Color(hex: "64748B") }
    /// 添加宠物：深色模式图标纯白、无顶栏磨砂底；人类/植物保持系统顶栏
    private var toolbarNavIconTint: Color {
        if selectedType == .pet {
            return colorScheme == .light ? .black : .white
        }
        return .primary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isMaterial { matBg.ignoresSafeArea() } else { ArkBackgroundView() }

                if let type = selectedType {
                    switch type {
                    case .pet:
                        AddPetWizardView(onComplete: { dismiss() })
                    case .human:
                        AddHumanWizardView(onComplete: { dismiss() })
                    case .plant:
                        AddPlantView(onComplete: { dismiss() })
                    }
                } else {
                    entitySelector
                }
            }
            .id(selectedType?.rawValue ?? "selector")
            .navigationTitle(selectedType == nil ? "添加家人" : selectedType!.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(selectedType == .pet ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedType != nil {
                        Button("返回") {
                            withAnimation(.easeInOut(duration: 0.22)) { selectedType = nil }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private var entitySelector: some View {
        VStack(spacing: 20) {
            Spacer()

            // Header
            VStack(spacing: 6) {
                Text("添加新成员")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("选择要加入岛屿的类型")
                    .font(.system(size: 15)).foregroundStyle(.primary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            // Entity type cards
            VStack(spacing: 12) {
                ForEach(EntityType.allCases, id: \.rawValue) { type in
                    Button {
                        guard type.isAvailable else { return }
                        withAnimation(.spring(response: 0.4)) { selectedType = type }
                    } label: {
                        entityCard(type)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!type.isAvailable)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func entityCard(_ type: EntityType) -> some View {
        let iconBg = type.color.opacity(type.isAvailable ? 0.18 : 0.07)
        let fgOpacity: Double = type.isAvailable ? 1 : 0.45

        return HStack(spacing: 16) {
            ZStack {
                Circle().fill(iconBg).frame(width: 56, height: 56)
                Text(type.emoji)
                    .font(.system(size: 28))
                    .opacity(fgOpacity)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(type.rawValue)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(fgOpacity))
                    if !type.isAvailable {
                        Text("开发中")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "FF9500"))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(hex: "FF9500").opacity(0.12), in: Capsule())
                    }
                }
                Text(typeDescription(type))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(type.isAvailable ? 0.65 : 0.35))
            }

            Spacer()

            Image(systemName: type.isAvailable ? "chevron.right" : "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.primary.opacity(type.isAvailable ? 0.45 : 0.28))
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .opacity(type.isAvailable ? 1 : 0.65)
    }
    
    private func typeDescription(_ type: EntityType) -> String {
        switch type {
        case .pet: return "添加你的毛孩子、小怪兽"
        case .human: return "添加家庭成员"
        case .plant: return "添加绿植花卉"
        }
    }
}

#Preview {
    AddEntityView()
        .modelContainer(SharedModelContainer.make())
}
