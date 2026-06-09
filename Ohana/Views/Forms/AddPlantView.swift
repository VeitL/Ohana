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

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name = ""
    @State private var species = ""
    @State private var location = ""
    @State private var avatarEmoji = "🌱"
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    @State private var isSaving = false

    private let plantEmojis = ["🌱", "🌿", "🍀", "🌵", "🌻", "🌹", "🌺", "🪴", "🌳", "🎋", "🌾", "💐"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 16)

                Text(avatarEmoji)
                    .font(OhanaFont.adaptive(size: 64))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(plantEmojis, id: \.self) { emoji in
                        Button {
                            avatarEmoji = emoji
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(emoji)
                                .font(OhanaFont.adaptive(size: 28))
                                .frame(width: 46, height: 46)
                                .background(
                                    avatarEmoji == emoji
                                        ? Color.goLime.opacity(0.22)
                                        : Color.ohanaControlFill.opacity(0.68),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            avatarEmoji == emoji ? Color.goLime.opacity(0.55) : Color.ohanaCardSurface.opacity(0.16),
                                            lineWidth: avatarEmoji == emoji ? 1.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    goFormField("名称", text: $name, placeholder: "我的绿萝")
                    goFormField("品种", text: $species, placeholder: "绿萝、多肉…")
                    goFormField("位置", text: $location, placeholder: "客厅、阳台…")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("浇水周期")
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper("每 \(wateringInterval) 天", value: $wateringInterval, in: 1...90)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .tint(Color.goLime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .goTranslucentCard(cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("施肥周期")
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Stepper("每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1...365)
                            .foregroundStyle(Color.ohanaPrimaryText)
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
                    Text(name.isEmpty ? "请先输入名称" : (isSaving ? "正在添加…" : "添加植物 🌿"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(name.isEmpty ? Color.ohanaTertiaryText : Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            name.isEmpty ? Color.ohanaControlFill.opacity(0.72) : Color.goLime,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 36)
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private func goFormField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.ohanaCardSurface.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 18)
    }

    private func savePlant() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isSaving else { return }

        let input = PlantCreationCommandInput(
            name: name,
            species: species,
            location: location,
            avatarEmoji: avatarEmoji,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval
        )
        let command = DomainCommand.memberCreation(entityID: input.id, kind: EntityKind.plant.rawValue)

        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            PlantCreationCommandExecutor(context: modelContext).createPlant(
                input: input,
                note: "plant.creation"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
        }
    }
}
