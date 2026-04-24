//
//  AddPlantView.swift
//  Ohana
//
//  GO UI：由 `AddEntityView` 提供 `GoIslandWizardBackdrop`，本页使用岛景上的玻璃卡与青柠强调。
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 16)

                Text(avatarEmoji)
                    .font(.system(size: 64))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(plantEmojis, id: \.self) { emoji in
                        Button {
                            avatarEmoji = emoji
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 46, height: 46)
                                .background(
                                    avatarEmoji == emoji
                                        ? Color.goLime.opacity(0.22)
                                        : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            avatarEmoji == emoji ? Color.goLime.opacity(0.55) : Color.white.opacity(0.1),
                                            lineWidth: avatarEmoji == emoji ? 1.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    goFormField("名称", text: $name, placeholder: "我的绿萝")
                    goFormField("品种", text: $species, placeholder: "绿萝、多肉…")
                    goFormField("位置", text: $location, placeholder: "客厅、阳台…")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("浇水周期")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper("每 \(wateringInterval) 天", value: $wateringInterval, in: 1...90)
                            .foregroundStyle(.white)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("施肥周期")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper("每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1...365)
                            .foregroundStyle(.white)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: 18)
                }
                .padding(.horizontal, 20)

                Button {
                    savePlant()
                } label: {
                    Text(name.isEmpty ? "请先输入名称" : "添加植物 🌿")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(name.isEmpty ? .white.opacity(0.35) : Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            name.isEmpty ? Color.white.opacity(0.1) : Color.goLime,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(name.isEmpty)
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 36)
            }
        }
    }

    private func goFormField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(0.6)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 18)
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
