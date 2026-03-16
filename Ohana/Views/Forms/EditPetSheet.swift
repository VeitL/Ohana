//
//  EditPetSheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct EditPetSheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    @State private var showDuplicateNameAlert = false
    @State private var name = ""
    @State private var species = ""
    @State private var breed = ""
    @State private var avatarEmoji = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var gender = "unknown"
    @State private var isNeutered = false
    @State private var microchipID = ""
    @State private var vetContact = ""
    @State private var allergies = ""
    @State private var birthCountry = ""
    @State private var birthCity = ""
    @State private var foodBrand = ""
    @State private var dailyPortionGrams: Double = 0
    @State private var notes = ""
    @State private var themeColorHex = ""

    /// 全岛重名检查（忽略大小写/空格，排除自身原名）
    private var isNameDuplicate: Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        let original  = pet.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty, candidate != original else { return false }
        let petNames   = allPets.map   { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        let humanNames = allHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        return petNames.contains(candidate) || humanNames.contains(candidate)
    }

    var body: some View {
        OhanaSheetWrapper(title: "编辑 \(pet.name)", onDismiss: { dismiss() }) {
            VStack(spacing: 24) {
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("基本信息")
                        formField("名字", text: $name)
                        formField("物种", text: $species)
                        formField("品种", text: $breed)
                        formField("头像 Emoji", text: $avatarEmoji)
                        
                        Picker("性别", selection: $gender) {
                            Text("♂ 男孩").tag("male")
                            Text("♀ 女孩").tag("female")
                            Text("未知").tag("unknown")
                        }
                        .pickerStyle(.segmented)
                        
                        Toggle("已绝育", isOn: $isNeutered)
                            .tint(.arkCoral)
                    }
                    .padding(16)
                }
                
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("日期")
                        Toggle("设置生日", isOn: $hasBirthday)
                            .tint(.arkCoral)
                        if hasBirthday {
                            DatePicker("生日", selection: $birthday, displayedComponents: .date)
                        }
                    }
                    .padding(16)
                }
                
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("出生地")
                        formField("国家", text: $birthCountry)
                        formField("城市", text: $birthCity)
                    }
                    .padding(16)
                }
                
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("健康信息")
                        formField("芯片号", text: $microchipID)
                        formField("兽医联系方式", text: $vetContact)
                        formField("过敏原", text: $allergies)
                    }
                    .padding(16)
                }
                
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("饮食")
                        formField("粮食品牌", text: $foodBrand)
                        HStack {
                            Text("每日喂食量 (g)")
                                .font(OhanaFont.footnote(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", value: $dailyPortionGrams, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                    .padding(16)
                }
                
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("主题色")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                            ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                                Button { themeColorHex = tc.hexValue } label: {
                                    ZStack {
                                        Circle().fill(tc.color).frame(width: 38, height: 38)
                                        if themeColorHex.uppercased() == tc.hexValue.uppercased() {
                                            Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 38, height: 38)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader("备注")
                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .background(Color.primary.opacity(0.05))
                    }
                    .padding(16)
                }
                
                Button {
                    if isNameDuplicate { showDuplicateNameAlert = true; return }
                    save()
                } label: {
                    Text("保存")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.goLime, in: Capsule())
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .onAppear { loadData() }
        .alert("名字已被占用 🏠", isPresented: $showDuplicateNameAlert) {
            Button("好的，我换一个", role: .cancel) { }
        } message: {
            Text("Ohana 里已经有一个叫「\(name.trimmingCharacters(in: .whitespaces))」的家人啦，换一个名字吧！")
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(.primary.opacity(0.4))
                .tracking(1.2)
                .textCase(.uppercase)
            Spacer()
        }
    }
    
    private func formField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(OhanaFont.caption(.medium))
                .foregroundStyle(.primary.opacity(0.4))
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func loadData() {
        name = pet.name
        species = pet.species
        breed = pet.breed
        avatarEmoji = pet.avatarEmoji
        birthday = pet.birthday ?? Date()
        hasBirthday = pet.birthday != nil
        gender = pet.gender
        isNeutered = pet.isNeutered
        microchipID = pet.microchipID
        vetContact = pet.vetContact
        allergies = pet.allergies
        birthCountry = pet.birthCountry
        birthCity = pet.birthCity
        foodBrand = pet.foodBrand
        dailyPortionGrams = pet.dailyPortionGrams
        notes = pet.notes
        themeColorHex = pet.themeColorHex
    }
    
    private func save() {
        pet.name = name
        pet.species = species
        pet.breed = breed
        pet.avatarEmoji = avatarEmoji.isEmpty ? "🐾" : avatarEmoji
        pet.birthday = hasBirthday ? birthday : nil
        pet.gender = gender
        pet.isNeutered = isNeutered
        pet.microchipID = microchipID
        pet.vetContact = vetContact
        pet.allergies = allergies
        pet.birthCountry = birthCountry
        pet.birthCity = birthCity
        pet.foodBrand = foodBrand
        pet.dailyPortionGrams = dailyPortionGrams
        pet.notes = notes
        if !themeColorHex.isEmpty { pet.themeColorHex = themeColorHex }
        modelContext.safeSave()
        dismiss()
    }
}
