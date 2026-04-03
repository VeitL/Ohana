//
//  PetMedicationView.swift
//  Ohana
//
//  ArkSchemaV24：宠物用药管理页 + 详情 Sheet
//

import SwiftUI
import SwiftData

struct PetMedicationView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false
    @State private var selectedMedication: PetMedication?

    private var activeMeds: [PetMedication] {
        pet.medications.filter { $0.isActiveToday }.sorted { $0.createdAt > $1.createdAt }
    }
    private var inactiveMeds: [PetMedication] {
        pet.medications.filter { !$0.isActiveToday }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 16) {
                        if pet.medications.isEmpty {
                            emptyState
                        } else {
                            if !activeMeds.isEmpty {
                                sectionHeader("当前用药")
                                ForEach(activeMeds) { med in
                                    medCard(med)
                                }
                            }
                            if !inactiveMeds.isEmpty {
                                sectionHeader("历史用药")
                                ForEach(inactiveMeds) { med in
                                    medCard(med)
                                }
                            }
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("\(pet.name) · 用药")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color(hex: "FF5A00"))
                            .font(.system(size: 26))
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddPetMedicationSheet(pet: pet)
            }
            .sheet(item: $selectedMedication) { med in
                PetMedicationDetailSheet(pet: pet, medication: med)
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color(hex: "FF5A00").opacity(0.85))
            Text("暂无用药记录")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text("记录宠物当前的药物，按时提醒不漏服")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddSheet = true
            } label: {
                Text("添加用药")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Med Card
    private func medCard(_ med: PetMedication) -> some View {
        Button {
            selectedMedication = med
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: med.colorHex))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(med.name.isEmpty ? "未命名药物" : med.name)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(med.frequency.emoji)
                            .font(.system(size: 13))
                    }
                    HStack(spacing: 8) {
                        if !med.dosage.isEmpty {
                            Text(med.dosage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Text(med.frequency.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(med.statusLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(med.isActiveToday ? .black : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(med.isActiveToday ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .goTranslucentCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(med)
                modelContext.safeSave()
            } label: {
                Label("删除", systemImage: "trash")
            }
            Button {
                med.isActive.toggle()
                modelContext.safeSave()
            } label: {
                Label(med.isActive ? "停用" : "恢复", systemImage: med.isActive ? "pause.circle" : "play.circle")
            }
        }
    }
}
