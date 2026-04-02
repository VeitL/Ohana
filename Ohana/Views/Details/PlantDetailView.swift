//
//  PlantDetailView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct PlantDetailView: View {
    let plant: Plant
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Household.createdAt) private var households: [Household]
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        ZStack {
            ArkBackgroundView()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    heroCard
                    wateringCard
                    fertilizingCard
                    quickActions
                    notesCard
                    deleteSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditSheet = true } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlantSheet(plant: plant)
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                modelContext.delete(plant)
                modelContext.safeSave()
                dismiss()
            }
        } message: {
            Text("确定要删除 \(plant.name) 吗？")
        }
    }
    
    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkMint.opacity(0.6), Color(hex: "27AE60")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Text(plant.avatarEmoji)
                    .font(.system(size: 52))
            }
            .shadow(color: Color.arkMint.opacity(0.3), radius: 12)
            
            VStack(spacing: 8) {
                Text(plant.name)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    if !plant.species.isEmpty {
                        Text(plant.species)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    if !plant.location.isEmpty {
                        Text("📍 \(plant.location)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .ohanaGlassStyle(cornerRadius: 32)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Watering Card
    private var wateringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("浇水状态")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }
            
            if let days = plant.daysSinceWatered {
                let progress = min(1.0, Double(days) / Double(plant.wateringIntervalDays))
                let color: Color = progress < 0.5 ? .blue : (progress < 0.8 ? .yellow : .red)
                
                HStack {
                    Text("距上次浇水 \(days) 天")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("周期 \(plant.wateringIntervalDays) 天")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: progress)
                    .tint(color)
                
                if plant.needsWatering {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text("该浇水了！")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("还没有浇水记录")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: 20)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Fertilizing Card
    private var fertilizingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                Text("施肥状态")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }
            
            if let days = plant.daysSinceFertilized {
                let progress = min(1.0, Double(days) / Double(plant.fertilizingIntervalDays))
                let color: Color = progress < 0.5 ? .green : (progress < 0.8 ? .yellow : .red)
                
                HStack {
                    Text("距上次施肥 \(days) 天")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("周期 \(plant.fertilizingIntervalDays) 天")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: progress)
                    .tint(color)
                
                if plant.needsFertilizing {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text("该施肥了！")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("还没有施肥记录")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: 20)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                waterPlant()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                    Text("浇水")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }
            }
            
            Button {
                fertilizePlant()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                    Text("施肥")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Notes Card
    private var notesCard: some View {
        Group {
            if !plant.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(.purple)
                        Text("备注")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    Text(plant.notes)
                        .font(.system(size: 14))
                }
                .padding(16)
                .ohanaGlassStyle(cornerRadius: 20)
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Delete Section
    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除植物")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Actions
    private func waterPlant() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        plant.lastWateredDate = Date()

        let log = PlantCareLog(date: Date(), careType: .watering)
        log.plant = plant
        modelContext.insert(log)

        let event = Event(
            title: "💧 给 \(plant.name) 浇水",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
    }

    private func fertilizePlant() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        plant.lastFertilizedDate = Date()

        let log = PlantCareLog(date: Date(), careType: .fertilizing)
        log.plant = plant
        modelContext.insert(log)

        let event = Event(
            title: "🌿 给 \(plant.name) 施肥",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.fertilizing.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        modelContext.insert(event)
        modelContext.safeSave()
    }
}

// MARK: - Edit Plant Sheet
struct EditPlantSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var species = ""
    @State private var location = ""
    @State private var avatarEmoji = ""
    @State private var wateringInterval = 7
    @State private var fertilizingInterval = 30
    @State private var notes = ""
    
    var body: some View {
        OhanaSheetWrapper(title: "编辑植物", onDismiss: { dismiss() }) {
            VStack(spacing: 20) {
                formField("名称", text: $name)
                formField("品种", text: $species)
                formField("位置", text: $location)
                formField("头像 Emoji", text: $avatarEmoji)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("浇水周期")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Stepper("每 \(wateringInterval) 天", value: $wateringInterval, in: 1...90)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("施肥周期")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Stepper("每 \(fertilizingInterval) 天", value: $fertilizingInterval, in: 1...365)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("备注")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button { save() } label: {
                    Text("保存").capsuleButton()
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            name = plant.name
            species = plant.species
            location = plant.location
            avatarEmoji = plant.avatarEmoji
            wateringInterval = plant.wateringIntervalDays
            fertilizingInterval = plant.fertilizingIntervalDays
            notes = plant.notes
        }
    }
    
    private func formField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private func save() {
        plant.name = name
        plant.species = species
        plant.location = location
        plant.avatarEmoji = avatarEmoji.isEmpty ? "🌱" : avatarEmoji
        plant.wateringIntervalDays = wateringInterval
        plant.fertilizingIntervalDays = fertilizingInterval
        plant.notes = notes
        modelContext.safeSave()
        dismiss()
    }
}
