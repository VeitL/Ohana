//
//  CrewRosterInlineProfileEditors.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

struct CrewRosterPetProfileEditor: View {
    let pet: Pet
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name = ""
    @State private var species = ""
    @State private var breed = ""
    @State private var gender = "unknown"
    @State private var isNeutered = false
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasHomeDate = false
    @State private var homeDate = Date()
    @State private var themeHex = ""
    @State private var notes = ""

    private let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]

    var body: some View {
        CrewRosterEditorShell(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "编辑宠物" : name,
            subtitle: "宠物基本信息",
            tint: Color(hex: resolvedThemeHex),
            onCancel: onCancel,
            onSave: saveChanges
        ) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorMenuRow(title: "物种", icon: "pawprint.fill", selection: $species, options: speciesOptions)
            CrewRosterEditorTextField(title: "品种", text: $breed, icon: "tag.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorSegmentedRow(
                title: "性别",
                selection: $gender,
                options: [("male", "男孩"), ("female", "女孩"), ("unknown", "未知")]
            )
            CrewRosterEditorToggleRow(title: "已绝育", icon: "checkmark.seal.fill", isOn: $isNeutered)
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorDateToggleRow(title: "到家日", icon: "house.fill", isOn: $hasHomeDate, date: $homeDate)
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
        .onAppear(perform: loadState)
    }

    private var resolvedThemeHex: String {
        themeHex.isEmpty ? pet.safeThemeColorHex : themeHex
    }

    private func loadState() {
        name = pet.name
        species = pet.species.isEmpty ? "其他" : pet.species
        breed = pet.breed
        gender = pet.gender.isEmpty ? "unknown" : pet.gender
        isNeutered = pet.isNeutered
        hasBirthday = pet.birthday != nil
        birthday = pet.birthday ?? Date()
        hasHomeDate = pet.homeDate != nil
        homeDate = pet.homeDate ?? Date()
        themeHex = pet.safeThemeColorHex
        notes = pet.notes
    }

    private func saveChanges() {
        let input = PetProfileCommandInput(
            name: name,
            avatarImageData: pet.avatarImageData,
            species: species,
            breed: breed,
            gender: gender,
            isNeutered: isNeutered,
            birthday: hasBirthday ? birthday : nil,
            homeDate: hasHomeDate ? homeDate : nil,
            themeHex: themeHex,
            notes: notes
        )
        commandQueue.enqueue(.memberProfile(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
            MemberCommandExecutor(context: modelContext, services: appServices).updatePetProfile(
                pet,
                input: input,
                note: "crew.inline.profile.pet"
            )
            onSave()
        }
    }
}

struct CrewRosterHumanProfileEditor: View {
    let human: Human
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name = ""
    @State private var role = "member"
    @State private var gender = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var bloodType = ""
    @State private var mbti = ""
    @State private var nationality = ""
    @State private var city = ""
    @State private var themeHex = ""
    @State private var notes = ""

    private let bloodTypeOptions = ["未填写", "A", "B", "AB", "O"]
    private let mbtiOptions = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

    var body: some View {
        CrewRosterEditorShell(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "编辑成员" : name,
            subtitle: "人类基本信息",
            tint: Color(hex: resolvedThemeHex),
            onCancel: onCancel,
            onSave: saveChanges
        ) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorSegmentedRow(
                title: "权限",
                selection: $role,
                options: [("owner", "管理者"), ("member", "成员")]
            )
            CrewRosterEditorMenuRow(
                title: "性别/身份",
                icon: "person.fill",
                selection: $gender,
                options: HumanProfileOptions.genderOptions.map(\.key)
            )
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorMenuRow(title: "血型", icon: "drop.fill", selection: $bloodType, options: bloodTypeOptions)
            CrewRosterEditorMenuRow(title: "MBTI", icon: "brain.head.profile", selection: $mbti, options: mbtiOptions)
            CrewRosterEditorTextField(title: "国籍", text: $nationality, icon: "globe.asia.australia.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "现居地", text: $city, icon: "location.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
        .onAppear(perform: loadState)
    }

    private var resolvedThemeHex: String {
        themeHex.isEmpty ? human.safeThemeColorHex : themeHex
    }

    private func loadState() {
        name = human.name
        role = HumanProfileOptions.normalizedRole(human.role)
        gender = HumanProfileOptions.normalizedGender(human.genderRaw)
        hasBirthday = human.birthday != nil
        birthday = human.birthday ?? Date()
        bloodType = human.bloodType.isEmpty ? "未填写" : human.bloodType
        mbti = human.mbti.isEmpty ? "未填写" : human.mbti.uppercased()
        nationality = human.nationality
        city = human.city
        themeHex = human.safeThemeColorHex
        notes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
    }

    private func saveChanges() {
        let input = HumanProfileCommandInput(
            name: name,
            avatarImageData: human.avatarImageData,
            avatarEmoji: human.avatarEmoji,
            role: role,
            gender: gender,
            birthday: hasBirthday ? birthday : nil,
            bloodType: bloodType,
            heightText: human.heightCm > 0 ? String(human.heightCm) : "",
            mbti: mbti,
            nationality: nationality,
            city: city,
            themeHex: themeHex,
            notes: notes,
            preservedNoteParts: []
        )
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "crew.inline.profile.human"
            )
            onSave()
        }
    }
}

struct CrewRosterPlantProfileEditor: View {
    let plant: Plant
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name = ""
    @State private var species = ""
    @State private var location = ""
    @State private var wateringDays = 7
    @State private var fertilizingDays = 30
    @State private var themeHex = ""
    @State private var notes = ""

    var body: some View {
        CrewRosterEditorShell(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "编辑植物" : name,
            subtitle: "植物基本信息",
            tint: Color(hex: resolvedThemeHex),
            onCancel: onCancel,
            onSave: saveChanges
        ) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "品种", text: $species, icon: "leaf.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorTextField(title: "位置", text: $location, icon: "location.fill") // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            CrewRosterEditorStepperRow(title: "浇水间隔", icon: "drop.fill", value: $wateringDays, range: 1 ... 60, unit: "天")
            CrewRosterEditorStepperRow(title: "施肥间隔", icon: "sparkles", value: $fertilizingDays, range: 1 ... 120, unit: "天")
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        }
        .onAppear(perform: loadState)
    }

    private var resolvedThemeHex: String {
        themeHex.isEmpty ? plant.themeColorHex : themeHex
    }

    private func loadState() {
        name = plant.name
        species = plant.species
        location = plant.location
        wateringDays = plant.wateringIntervalDays
        fertilizingDays = plant.fertilizingIntervalDays
        themeHex = plant.themeColorHex
        notes = plant.notes
    }

    private func saveChanges() {
        let input = PlantProfileCommandInput(
            name: name,
            avatarImageData: plant.avatarImageData,
            avatarEmoji: plant.avatarEmoji,
            species: species,
            location: location,
            wateringIntervalDays: wateringDays,
            fertilizingIntervalDays: fertilizingDays,
            themeHex: themeHex,
            notes: notes
        )
        commandQueue.enqueue(.memberProfile(entityID: plant.id, kind: EntityKind.plant.rawValue)) {
            MemberCommandExecutor(context: modelContext, services: appServices).updatePlantProfile(
                plant,
                input: input,
                note: "crew.inline.profile.plant"
            )
            onSave()
        }
    }
}
