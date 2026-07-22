//
//  EditPetSheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct EditPetContentSheet: View {
    let pet: Pet
    let allPets: [Pet]
    let allHumans: [Human]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showDuplicateNameAlert = false
    @State private var name = ""
    @State private var species = ""
    @State private var breed = ""
    @State private var avatarEmoji = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var gender = ""
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
    @State private var primaryPersonalityTagID = ""
    private var l: L10n { L10n(appLanguage) }

    /// 全岛重名检查（忽略大小写/空格，排除自身原名）
    private var isNameDuplicate: Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        let original = pet.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty, candidate != original else { return false }
        let petNames = allPets.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        let humanNames = allHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        return petNames.contains(candidate) || humanNames.contains(candidate)
    }

    var body: some View {
        OhanaSheetWrapper(title: l.tr(zh: "编辑 \(pet.name)", en: "Edit \(pet.name)", de: "\(pet.name) bearbeiten"), onDismiss: { dismiss() }) {
            VStack(spacing: 24) {
                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "基本信息", en: "Basic info", de: "Basisdaten"))
                        formField(l.tr(zh: "名字", en: "Name", de: "Name"), text: $name)
                        formField(l.tr(zh: "物种", en: "Species", de: "Tierart"), text: $species)
                        formField(l.tr(zh: "品种", en: "Breed", de: "Rasse"), text: $breed)

                        Picker(l.tr(zh: "主性格", en: "Primary vibe", de: "Hauptcharakter"), selection: $primaryPersonalityTagID) {
                            if primaryPersonalityTagID.isEmpty {
                                Text(l.tr(zh: "请选择", en: "Choose", de: "Auswählen")).tag("")
                            }
                            ForEach(primaryPersonalityOptionIDs, id: \.self) { id in
                                Text(PetPersonalityTag.displayTitle(for: id, l: l)).tag(id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.goPrimary)
                        .accessibilityIdentifier("edit-pet-primary-personality-picker")

                        Picker(l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), selection: $gender) {
                            Text(l.tr(zh: "♂ 男孩", en: "♂ Boy", de: "♂ Junge")).tag("boy")
                            Text(l.tr(zh: "♀ 女孩", en: "♀ Girl", de: "♀ Mädchen")).tag("girl")
                        }
                        .pickerStyle(.segmented)

                        Toggle(l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"), isOn: $isNeutered)
                            .tint(.arkCoral)
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "日期", en: "Dates", de: "Daten"))
                        Toggle(l.tr(zh: "设置生日", en: "Set birthday", de: "Geburtstag setzen"), isOn: $hasBirthday)
                            .tint(.arkCoral)
                        if hasBirthday {
                            DatePicker(l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), selection: $birthday, displayedComponents: .date)
                        }
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "出生地", en: "Birthplace", de: "Geburtsort"))
                        formField(l.tr(zh: "国家", en: "Country", de: "Land"), text: $birthCountry)
                        formField(l.tr(zh: "城市", en: "City", de: "Stadt"), text: $birthCity)
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "健康信息", en: "Health info", de: "Gesundheit"))
                        formField(l.tr(zh: "芯片号", en: "Microchip", de: "Chipnummer"), text: $microchipID)
                        formField(l.tr(zh: "兽医联系方式", en: "Vet contact", de: "Tierarztkontakt"), text: $vetContact)
                        formField(l.tr(zh: "过敏原", en: "Allergies", de: "Allergien"), text: $allergies)
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "饮食", en: "Food", de: "Futter"))
                        formField(l.tr(zh: "粮食品牌", en: "Food brand", de: "Futtermarke"), text: $foodBrand)
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 12) {
                                dailyPortionLabel
                                Spacer(minLength: 8)
                                dailyPortionInput
                                    .frame(minWidth: 104, idealWidth: 124, maxWidth: 150)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                dailyPortionLabel
                                dailyPortionInput
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "主题色", en: "Theme color", de: "Designfarbe"))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                            ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                                Button { themeColorHex = tc.hexValue } label: {
                                    ZStack {
                                        Circle().fill(tc.color).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                                        if themeColorHex.uppercased() == tc.hexValue.uppercased() {
                                            Circle().strokeBorder(Color.ohanaCardSurface, lineWidth: 2.5).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                                            Image(systemName: "checkmark").accessibilityHidden(true)
                                                .font(OhanaFont.adaptive(size: 11, weight: .black))
                                                .foregroundStyle(Color.ohanaPrimaryText)
                                        }
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    .padding(16)
                }

                UltimateGlassCard {
                    VStack(spacing: 16) {
                        sectionHeader(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.chip))
                            .background(Color.primary.opacity(0.05))
                    }
                    .padding(16)
                }

                Button {
                    if isNameDuplicate { showDuplicateNameAlert = true
                        return
                    }
                    save()
                } label: {
                    Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.goPrimary, in: Capsule())
                }
                .padding(.top, 8)
                .disabled(Pet.canonicalSex(gender) == nil)
            }
            .padding(.vertical, 16)
        }
        .onAppear { loadData() }
        .alert(l.tr(zh: "名字已被占用 🏠", en: "Name already used 🏠", de: "Name schon vergeben 🏠"), isPresented: $showDuplicateNameAlert) {
            Button(l.tr(zh: "好的，我换一个", en: "OK, I'll change it", de: "OK, ich ändere ihn"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "Ohana 里已经有一个叫「\(name.trimmingCharacters(in: .whitespaces))」的家人啦，换一个名字吧！", en: "There is already a family member named \"\(name.trimmingCharacters(in: .whitespaces))\" in Ohana. Choose another name.", de: "In Ohana gibt es schon ein Familienmitglied namens \"\(name.trimmingCharacters(in: .whitespaces))\". Wähle einen anderen Namen."))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                .tracking(1.2)
                .textCase(.uppercase)
            Spacer()
        }
    }

    private func formField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(OhanaFont.caption(.medium))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: OhanaRadius.badge))
        }
    }

    private var dailyPortionTextBinding: Binding<String> {
        Binding(
            get: {
                dailyPortionGrams > 0 ? String(format: "%.0f", dailyPortionGrams) : ""
            },
            set: { value in
                dailyPortionGrams = CountryDecimalInput.parse(value, countryCode: AppCountry.code) ?? 0
            }
        )
    }

    private var dailyPortionLabel: some View {
        Text(l.tr(zh: "每日喂食量 (g)", en: "Daily portion (g)", de: "Tagesportion (g)"))
            .font(OhanaFont.footnote(.medium))
            .foregroundStyle(Color.ohanaSecondaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var dailyPortionInput: some View {
        InlineNumericInput(
            text: dailyPortionTextBinding,
            placeholder: "0",
            unit: "g",
            maxFractionDigits: 0,
            accent: Color.goPrimary,
            step: 5,
            valueFont: OhanaFont.callout(.bold),
            valueAlignment: .trailing,
            fill: Color.ohanaControlFill,
            cornerRadius: OhanaRadius.chip,
            horizontalPadding: 8,
            verticalPadding: 6
        )
    }

    private func loadData() {
        name = pet.name
        species = pet.species
        breed = pet.breed
        avatarEmoji = pet.avatarEmoji
        birthday = pet.birthday ?? Date()
        hasBirthday = pet.birthday != nil
        gender = Pet.canonicalSex(pet.gender) ?? ""
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
        primaryPersonalityTagID = pet.personalityTagIdList.first ?? ""
    }

    private func save() {
        let input = PetProfileCommandInput(
            name: name,
            avatarImageData: pet.avatarImageData,
            avatarEmoji: avatarEmoji,
            species: species,
            breed: breed,
            gender: gender,
            isNeutered: isNeutered,
            birthday: hasBirthday ? birthday : nil,
            homeDate: pet.homeDate,
            themeHex: themeColorHex.isEmpty ? pet.safeThemeColorHex : themeColorHex,
            notes: notes,
            microchipID: microchipID,
            vetContact: vetContact,
            allergies: allergies,
            birthCountry: birthCountry,
            birthCity: birthCity,
            foodBrand: foodBrand,
            dailyPortionGrams: dailyPortionGrams,
            personalityTagIDs: primaryPersonalityTagID.isEmpty
                ? nil
                : PetPrimaryPersonalitySelection.replacingPrimary(
                    in: pet.personalityTagIdList,
                    with: primaryPersonalityTagID
                )
        )
        commandQueue.enqueue(.memberProfile(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updatePetProfile(
                pet,
                input: input,
                note: "editPet.profile"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private var primaryPersonalityOptionIDs: [String] {
        var ids = PetPersonalityTag.primaryChoices.map(\.id)
        if !primaryPersonalityTagID.isEmpty,
           !ids.contains(primaryPersonalityTagID) {
            ids.insert(primaryPersonalityTagID, at: 0)
        }
        return ids
    }
}
