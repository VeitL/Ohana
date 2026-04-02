//
//  AddPlantView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct AddPlantView: View {
    let onComplete: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var species = ""
    @State private var location = ""
    @State private var avatarEmoji = "🌱"
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    
    private let plantEmojis = ["🌱", "🌿", "🍀", "🌵", "🌻", "🌹", "🌺", "🪴", "🌳", "🎋", "🌾", "💐"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                // Emoji 选择
                Text(avatarEmoji)
                    .font(.system(size: 60))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(plantEmojis, id: \.self) { emoji in
                        Button {
                            avatarEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(
                                    avatarEmoji == emoji ? Color.arkMint.opacity(0.3) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 16) {
                    formField("名称", text: $name, placeholder: "我的绿萝")
                    formField("品种", text: $species, placeholder: "绿萝、多肉...")
                    formField("位置", text: $location, placeholder: "客厅、阳台...")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("浇水周期")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.6))
                        Stepper("每 \(wateringInterval) 天", value: $wateringInterval, in: 1...90)
                            .foregroundStyle(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("施肥周期")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.6))
                        Stepper("每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1...365)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 24)
                
                Button {
                    savePlant()
                } label: {
                    Text("添加植物 🌿")
                        .neonCapsuleButton()
                }
                .padding(.horizontal, 24)
                .disabled(name.isEmpty)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    private func formField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .padding(12)
                .ohanaGlassStyle(cornerRadius: 12)
        }
    }
    
    private func savePlant() {
        let plant = Plant(
            name: name,
            species: species,
            location: location,
            avatarEmoji: avatarEmoji,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval
        )
        modelContext.insert(plant)
        modelContext.safeSave()
        onComplete()
    }
}
