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
        case .pet, .human: return true
        case .plant: return false
        }
    }
}

struct AddEntityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: EntityType?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                
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
            .navigationTitle(selectedType == nil ? "添加家人" : selectedType!.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedType != nil {
                        Button {
                            withAnimation { selectedType = nil }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.white)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var entitySelector: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("选择要添加的类型")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            ForEach(EntityType.allCases, id: \.rawValue) { type in
                Button {
                    guard type.isAvailable else { return }
                    withAnimation(.spring(response: 0.4)) {
                        selectedType = type
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(type.color.opacity(type.isAvailable ? 0.2 : 0.08))
                                .frame(width: 52, height: 52)
                            Text(type.emoji)
                                .font(.system(size: 28))
                                .opacity(type.isAvailable ? 1 : 0.4)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(type.rawValue)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(type.isAvailable ? .white : .white.opacity(0.35))
                                if !type.isAvailable {
                                    Text("开发中")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.goYellow)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Color.goYellow.opacity(0.15), in: Capsule())
                                }
                            }
                            Text(typeDescription(type))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(type.isAvailable ? 0.6 : 0.25))
                        }
                        
                        Spacer()
                        
                        Image(systemName: type.isAvailable ? "chevron.right" : "lock.fill")
                            .foregroundStyle(.white.opacity(type.isAvailable ? 0.3 : 0.2))
                    }
                    .padding(16)
                    .ohanaGlassStyle(cornerRadius: 20)
                    .opacity(type.isAvailable ? 1 : 0.7)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
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
