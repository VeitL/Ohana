//
//  MemberProfileCompletenessPolicy.swift
//  Ohana
//
//  Stable, presentation-independent profile completion rules.
//

import Foundation

nonisolated enum MemberProfileCompletionKind: String, Sendable {
    case human
    case pet
    case plant
}

nonisolated enum MemberProfileCompletionCategory: String, CaseIterable, Hashable, Sendable {
    case humanAppearance
    case humanLifeStage
    case humanBodyProfile
    case humanPersonalityContext
    case petLifeStage
    case petBodyProfile
    case petPersonalityAppearance
    case petDailyCare
    case plantIdentityAppearance
    case plantAcquisition
    case plantPlacementEnvironment
    case plantPottingGrowthStory

    var kind: MemberProfileCompletionKind {
        switch self {
        case .humanAppearance, .humanLifeStage, .humanBodyProfile, .humanPersonalityContext:
            .human
        case .petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare:
            .pet
        case .plantIdentityAppearance, .plantAcquisition,
             .plantPlacementEnvironment, .plantPottingGrowthStory:
            .plant
        }
    }

    func localizedTitle(_ l: L10n) -> String {
        switch self {
        case .humanAppearance:
            l.tr(
                zh: "形象", en: "Appearance", de: "Erscheinungsbild",
                es: "Imagen", pt: "Aparência", fr: "Apparence",
                ja: "イメージ", ko: "외형", it: "Aspetto"
            )
        case .humanLifeStage:
            l.tr(
                zh: "生日阶段", en: "Birthday & age", de: "Geburtstag & Alter",
                es: "Cumpleaños y edad", pt: "Aniversário e idade", fr: "Anniversaire et âge",
                ja: "誕生日と年齢", ko: "생일과 나이", it: "Compleanno ed età"
            )
        case .humanBodyProfile:
            l.tr(
                zh: "性别与身份", en: "Gender & identity", de: "Geschlecht & Identität",
                es: "Género e identidad", pt: "Gênero e identidade", fr: "Genre et identité",
                ja: "性別と本人情報", ko: "성별 및 정체성", it: "Genere e identità"
            )
        case .humanPersonalityContext:
            l.tr(
                zh: "其他资料", en: "More details", de: "Weitere Angaben",
                es: "Más datos", pt: "Mais detalhes", fr: "Autres informations",
                ja: "その他の情報", ko: "기타 정보", it: "Altri dettagli"
            )
        case .petLifeStage:
            l.tr(
                zh: "生日与到家日", en: "Birthday & home date", de: "Geburtstag & Einzug",
                es: "Cumpleaños y llegada", pt: "Aniversário e chegada", fr: "Anniversaire et arrivée",
                ja: "誕生日とお迎え日", ko: "생일과 입양일", it: "Compleanno e arrivo"
            )
        case .petBodyProfile:
            l.tr(
                zh: "身体资料", en: "Body profile", de: "Körperprofil",
                es: "Datos físicos", pt: "Perfil físico", fr: "Profil physique",
                ja: "身体情報", ko: "신체 정보", it: "Profilo fisico"
            )
        case .petPersonalityAppearance:
            l.tr(
                zh: "形象与性格", en: "Look & personality", de: "Aussehen & Charakter",
                es: "Aspecto y personalidad", pt: "Visual e personalidade", fr: "Apparence et caractère",
                ja: "見た目と性格", ko: "외형과 성격", it: "Aspetto e personalità"
            )
        case .petDailyCare:
            l.tr(
                zh: "日常照护", en: "Daily care", de: "Tägliche Pflege",
                es: "Cuidados diarios", pt: "Cuidados diários", fr: "Soins quotidiens",
                ja: "日常ケア", ko: "일상 돌봄", it: "Cura quotidiana"
            )
        case .plantIdentityAppearance:
            l.tr(
                zh: "物种与形象", en: "Species & appearance", de: "Art & Erscheinungsbild",
                es: "Especie e imagen", pt: "Espécie e aparência", fr: "Espèce et apparence",
                ja: "種類と見た目", ko: "종과 외형", it: "Specie e aspetto"
            )
        case .plantAcquisition:
            l.tr(
                zh: "获得信息", en: "Acquisition", de: "Herkunft",
                es: "Adquisición", pt: "Aquisição", fr: "Acquisition",
                ja: "お迎え情報", ko: "입수 정보", it: "Acquisizione"
            )
        case .plantPlacementEnvironment:
            l.tr(
                zh: "位置与环境", en: "Place & environment", de: "Standort & Umgebung",
                es: "Lugar y entorno", pt: "Local e ambiente", fr: "Lieu et environnement",
                ja: "場所と環境", ko: "위치와 환경", it: "Posizione e ambiente"
            )
        case .plantPottingGrowthStory:
            l.tr(
                zh: "盆土、尺寸或故事", en: "Potting, size, or story", de: "Topf, Größe oder Geschichte",
                es: "Maceta, tamaño o historia", pt: "Vaso, tamanho ou história", fr: "Pot, taille ou histoire",
                ja: "鉢・サイズ・ストーリー", ko: "화분, 크기 또는 이야기", it: "Vaso, dimensioni o storia"
            )
        }
    }
}

nonisolated struct MemberProfileCompletionSnapshot: Equatable, Sendable {
    let kind: MemberProfileCompletionKind
    let actualCategories: Set<MemberProfileCompletionCategory>
    let explicitlyResolvedCategories: Set<MemberProfileCompletionCategory>
    let requiredActualCategories: Set<MemberProfileCompletionCategory>

    var allCategories: [MemberProfileCompletionCategory] {
        MemberProfileCompletenessPolicy.categories(for: kind)
    }

    var completedCategories: Set<MemberProfileCompletionCategory> {
        actualCategories.union(explicitlyResolvedCategories)
    }
    var completedCategoryCount: Int { completedCategories.count }
    var totalCategoryCount: Int { allCategories.count }
    var completionPercent: Int {
        guard totalCategoryCount > 0 else { return 0 }
        return Int((Double(completedCategoryCount) / Double(totalCategoryCount) * 100).rounded())
    }
    var missingRequiredCategories: [MemberProfileCompletionCategory] {
        allCategories.filter {
            requiredActualCategories.contains($0) && !actualCategories.contains($0)
        }
    }
    var reachesProfileThreshold: Bool {
        completionPercent >= MemberProfileCompletenessPolicy.starterRewardThresholdPercent
            && missingRequiredCategories.isEmpty
    }
    var missingCategories: [MemberProfileCompletionCategory] {
        allCategories.filter { !completedCategories.contains($0) }
    }
}

nonisolated struct HumanProfileCompletionDraft: Equatable, Sendable {
    let hasMeaningfulAppearance: Bool
    let birthday: Date?
    let genderIdentityRaw: String
    let bloodType: String
    let heightCm: Double
    let mbti: String
    let nationality: String
    let city: String
    let notes: String
}

nonisolated enum MemberProfileCompletenessPolicy {
    static let starterRewardThresholdPercent = 75
    static let humanRequiredActualCategories: Set<MemberProfileCompletionCategory> = [
        .humanLifeStage,
        .humanBodyProfile
    ]

    static func categories(for kind: MemberProfileCompletionKind) -> [MemberProfileCompletionCategory] {
        MemberProfileCompletionCategory.allCases.filter { $0.kind == kind }
    }

    static func evaluate(
        kind: MemberProfileCompletionKind,
        actualCategories: Set<MemberProfileCompletionCategory>,
        explicitlyResolvedCategories: Set<MemberProfileCompletionCategory> = [],
        requiredActualCategories: Set<MemberProfileCompletionCategory> = []
    ) -> MemberProfileCompletionSnapshot {
        let allowed = Set(categories(for: kind))
        let actual = actualCategories.intersection(allowed)
        let required = requiredActualCategories.intersection(allowed)
        let resolved = explicitlyResolvedCategories
            .intersection(allowed)
            .subtracting(required)
        return MemberProfileCompletionSnapshot(
            kind: kind,
            actualCategories: actual,
            explicitlyResolvedCategories: resolved.subtracting(actual),
            requiredActualCategories: required
        )
    }

    static func humanActualCategories(_ human: Human) -> Set<MemberProfileCompletionCategory> {
        humanActualCategories(
            HumanProfileCompletionDraft(
                hasMeaningfulAppearance: hasMeaningfulHumanAppearance(human),
                birthday: human.birthday,
                genderIdentityRaw: human.genderIdentityRaw ?? "",
                bloodType: human.bloodType,
                heightCm: human.heightCm,
                mbti: human.mbti,
                nationality: human.nationality,
                city: human.city,
                notes: HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            )
        )
    }

    static func humanActualCategories(
        _ draft: HumanProfileCompletionDraft
    ) -> Set<MemberProfileCompletionCategory> {
        var completed: Set<MemberProfileCompletionCategory> = []
        if draft.hasMeaningfulAppearance { completed.insert(.humanAppearance) }
        if draft.birthday != nil { completed.insert(.humanLifeStage) }
        if hasMeaningfulHumanGender(draft.genderIdentityRaw) {
            completed.insert(.humanBodyProfile)
        }
        if hasMeaningfulHumanOptionalDetails(draft) {
            completed.insert(.humanPersonalityContext)
        }
        return completed
    }

    static func petActualCategories(_ pet: Pet) -> Set<MemberProfileCompletionCategory> {
        var completed: Set<MemberProfileCompletionCategory> = []
        if pet.birthday != nil || pet.homeDate != nil { completed.insert(.petLifeStage) }
        if hasMeaningfulPetBodyProfile(pet) { completed.insert(.petBodyProfile) }
        if hasMeaningfulPetPersonalityAppearance(pet) { completed.insert(.petPersonalityAppearance) }
        if hasMeaningfulPetDailyCare(pet) { completed.insert(.petDailyCare) }
        return completed
    }

    static func plantActualCategories(_ plant: Plant) -> Set<MemberProfileCompletionCategory> {
        var completed: Set<MemberProfileCompletionCategory> = []
        if hasMeaningfulPlantIdentityAppearance(plant) { completed.insert(.plantIdentityAppearance) }
        if plant.acquiredDate != nil || !normalized(plant.acquisitionSourceRaw).isEmpty {
            completed.insert(.plantAcquisition)
        }
        if hasMeaningfulPlantPlacementEnvironment(plant) {
            completed.insert(.plantPlacementEnvironment)
        }
        if hasMeaningfulPlantPottingGrowthStory(plant) {
            completed.insert(.plantPottingGrowthStory)
        }
        return completed
    }

    static func human(
        _ human: Human,
        explicitlyResolvedCategories: Set<MemberProfileCompletionCategory> = []
    ) -> MemberProfileCompletionSnapshot {
        Self.human(
            HumanProfileCompletionDraft(
                hasMeaningfulAppearance: hasMeaningfulHumanAppearance(human),
                birthday: human.birthday,
                genderIdentityRaw: human.genderIdentityRaw ?? "",
                bloodType: human.bloodType,
                heightCm: human.heightCm,
                mbti: human.mbti,
                nationality: human.nationality,
                city: human.city,
                notes: HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            ),
            explicitlyResolvedCategories: explicitlyResolvedCategories
        )
    }

    static func human(
        _ draft: HumanProfileCompletionDraft,
        explicitlyResolvedCategories: Set<MemberProfileCompletionCategory> = []
    ) -> MemberProfileCompletionSnapshot {
        evaluate(
            kind: .human,
            actualCategories: humanActualCategories(draft),
            explicitlyResolvedCategories: explicitlyResolvedCategories,
            requiredActualCategories: humanRequiredActualCategories
        )
    }

    static func pet(
        _ pet: Pet,
        explicitlyResolvedCategories: Set<MemberProfileCompletionCategory> = []
    ) -> MemberProfileCompletionSnapshot {
        evaluate(
            kind: .pet,
            actualCategories: petActualCategories(pet),
            explicitlyResolvedCategories: explicitlyResolvedCategories
        )
    }

    static func plant(_ plant: Plant) -> MemberProfileCompletionSnapshot {
        evaluate(kind: .plant, actualCategories: plantActualCategories(plant))
    }

    private static func hasMeaningfulHumanAppearance(_ human: Human) -> Bool {
        if human.avatarAttachmentState == .present || !human.avatarImageSignature.isEmpty { return true }
        let emoji = normalized(human.avatarEmoji)
        return !emoji.isEmpty && emoji != "👤"
    }

    private static func hasMeaningfulHumanGender(_ raw: String) -> Bool {
        HumanProfileOptions.storedGenderIdentity(raw) != nil
    }

    private static func hasMeaningfulHumanOptionalDetails(
        _ draft: HumanProfileCompletionDraft
    ) -> Bool {
        !normalized(draft.bloodType).isEmpty
            || (draft.heightCm.isFinite && draft.heightCm > 0)
            || !normalized(draft.mbti).isEmpty
            || !normalized(draft.nationality).isEmpty
            || !normalized(draft.city).isEmpty
            || !normalized(draft.notes).isEmpty
    }

    private static func hasMeaningfulPetBodyProfile(_ pet: Pet) -> Bool {
        let gender = normalized(pet.gender).lowercased()
        return (!gender.isEmpty && gender != "unknown" && gender != "未知")
            || !normalized(pet.coatColor).isEmpty
            || !normalized(pet.birthCountry).isEmpty
            || !normalized(pet.birthCity).isEmpty
    }

    private static func hasMeaningfulPetPersonalityAppearance(_ pet: Pet) -> Bool {
        let emoji = normalized(pet.avatarEmoji)
        return !normalized(pet.personalityTagsRaw).isEmpty
            || pet.avatarAttachmentState == .present
            || !pet.avatarImageSignature.isEmpty
            || pet.cardPopoutAttachmentState == .present
            || !pet.cardPopoutImageSignature.isEmpty
            || (!emoji.isEmpty && emoji != "🐾")
    }

    private static func hasMeaningfulPetDailyCare(_ pet: Pet) -> Bool {
        !normalized(pet.foodBrand).isEmpty
            || pet.dailyPortionGrams > 0
            || pet.restockDate != nil
            || pet.restockWeight > 0
            || pet.foodPrice > 0
            || pet.casualOpenDate != nil
            || pet.casualDurationDays > 0
            || pet.foodReminderEnabled
    }

    private static func hasMeaningfulPlantIdentityAppearance(_ plant: Plant) -> Bool {
        let emoji = normalized(plant.avatarEmoji)
        return !normalized(plant.species).isEmpty
            || !normalized(plant.catalogSpeciesId).isEmpty
            || plant.avatarAttachmentState == .present
            || !plant.avatarImageSignature.isEmpty
            || (!emoji.isEmpty && emoji != "🌱")
    }

    private static func hasMeaningfulPlantPlacementEnvironment(_ plant: Plant) -> Bool {
        !normalized(plant.location).isEmpty
            || !normalized(plant.roomNameRaw).isEmpty
            || plant.windowDirection != .unknown
            || plant.lastLightMeasurementLux > 0
            || plant.lightLevel != .medium
            || plant.humidityPreference != .standard
            || plant.temperaturePreference != .standard
            || !plant.isIndoor
            || plant.isNearClimateSource
    }

    private static func hasMeaningfulPlantPottingGrowthStory(_ plant: Plant) -> Bool {
        plant.potDiameterCm > 0
            || !normalized(plant.potMaterialRaw).isEmpty
            || !normalized(plant.soilTypeRaw).isEmpty
            || plant.currentHeightCm > 0
            || plant.currentSpreadCm > 0
            || !normalized(plant.notes).isEmpty
            || plant.isHydroponic
            || plant.isSucculent
            || !plant.potHasDrainage
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
