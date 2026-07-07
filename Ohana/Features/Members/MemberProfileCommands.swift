//
//  MemberProfileCommands.swift
//  Ohana
//
//  Domain write boundaries for member profile updates.
//

import Foundation
import SwiftData

struct PetProfileCommandInput: Equatable {
    let name: String
    let avatarImageData: Data?
    let avatarEmoji: String?
    let species: String
    let breed: String
    let gender: String
    let isNeutered: Bool
    let birthday: Date?
    let homeDate: Date?
    let themeHex: String
    let notes: String
    let coatColor: String?
    let eyeColor: String?
    let microchipID: String?
    let vetContact: String?
    let vetClinicName: String?
    let vetDoctorName: String?
    let vetAddress: String?
    let allergies: String?
    let passportNumber: String?
    let hasPassportExpiry: Bool?
    let passportExpiryDate: Date?
    let formerName: String?
    let birthCountry: String?
    let birthCity: String?
    let lineageInfo: String?
    let foodBrand: String?
    let dailyPortionGrams: Double?

    init(
        name: String,
        avatarImageData: Data?,
        avatarEmoji: String? = nil,
        species: String,
        breed: String,
        gender: String,
        isNeutered: Bool,
        birthday: Date?,
        homeDate: Date?,
        themeHex: String,
        notes: String,
        coatColor: String? = nil,
        eyeColor: String? = nil,
        microchipID: String? = nil,
        vetContact: String? = nil,
        vetClinicName: String? = nil,
        vetDoctorName: String? = nil,
        vetAddress: String? = nil,
        allergies: String? = nil,
        passportNumber: String? = nil,
        hasPassportExpiry: Bool? = nil,
        passportExpiryDate: Date? = nil,
        formerName: String? = nil,
        birthCountry: String? = nil,
        birthCity: String? = nil,
        lineageInfo: String? = nil,
        foodBrand: String? = nil,
        dailyPortionGrams: Double? = nil
    ) {
        self.name = name
        self.avatarImageData = avatarImageData
        self.avatarEmoji = avatarEmoji
        self.species = species
        self.breed = breed
        self.gender = gender
        self.isNeutered = isNeutered
        self.birthday = birthday
        self.homeDate = homeDate
        self.themeHex = themeHex
        self.notes = notes
        self.coatColor = coatColor
        self.eyeColor = eyeColor
        self.microchipID = microchipID
        self.vetContact = vetContact
        self.vetClinicName = vetClinicName
        self.vetDoctorName = vetDoctorName
        self.vetAddress = vetAddress
        self.allergies = allergies
        self.passportNumber = passportNumber
        self.hasPassportExpiry = hasPassportExpiry
        self.passportExpiryDate = passportExpiryDate
        self.formerName = formerName
        self.birthCountry = birthCountry
        self.birthCity = birthCity
        self.lineageInfo = lineageInfo
        self.foodBrand = foodBrand
        self.dailyPortionGrams = dailyPortionGrams
    }
}

struct HumanProfileCommandInput: Equatable {
    let name: String
    let avatarImageData: Data?
    let avatarEmoji: String
    let role: String
    let gender: String
    let birthday: Date?
    let bloodType: String
    let heightText: String
    let mbti: String
    let nationality: String
    let city: String
    let themeHex: String
    let notes: String
    let preservedNoteParts: [String]
    let shouldShowOnHome: Bool?
    let privateFieldsRaw: Set<String>?

    init(
        name: String,
        avatarImageData: Data?,
        avatarEmoji: String,
        role: String,
        gender: String,
        birthday: Date?,
        bloodType: String,
        heightText: String,
        mbti: String,
        nationality: String,
        city: String,
        themeHex: String,
        notes: String,
        preservedNoteParts: [String],
        shouldShowOnHome: Bool? = nil,
        privateFieldsRaw: Set<String>? = nil
    ) {
        self.name = name
        self.avatarImageData = avatarImageData
        self.avatarEmoji = avatarEmoji
        self.role = role
        self.gender = gender
        self.birthday = birthday
        self.bloodType = bloodType
        self.heightText = heightText
        self.mbti = mbti
        self.nationality = nationality
        self.city = city
        self.themeHex = themeHex
        self.notes = notes
        self.preservedNoteParts = preservedNoteParts
        self.shouldShowOnHome = shouldShowOnHome
        self.privateFieldsRaw = privateFieldsRaw
    }
}

struct PlantProfileCommandInput: Equatable {
    let name: String
    let avatarImageData: Data?
    let avatarEmoji: String
    let species: String
    let location: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let roomNameRaw: String
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
    let lastLightMeasurementLux: Int
    let lastLightMeasurementDate: Date?
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let isNearClimateSource: Bool
    let potHasDrainage: Bool
    let acquiredDate: Date?
    let acquisitionSourceRaw: String
    let currentHeightCm: Double
    let currentSpreadCm: Double
    let isHydroponic: Bool
    let isSucculent: Bool
    let healthStatus: PlantHealthStatus
    let catalogSpeciesId: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
    let remindersEnabled: Bool
    let themeHex: String
    let notes: String

    init(
        name: String,
        avatarImageData: Data?,
        avatarEmoji: String,
        species: String,
        location: String,
        wateringIntervalDays: Int,
        fertilizingIntervalDays: Int,
        roomNameRaw: String = "",
        potDiameterCm: Double = 0,
        potMaterialRaw: String = "",
        soilTypeRaw: String = "",
        isIndoor: Bool = true,
        windowDirection: PlantWindowDirection = .unknown,
        lightLevel: PlantLightLevel = .medium,
        lastLightMeasurementLux: Int = 0,
        lastLightMeasurementDate: Date? = nil,
        humidityPreference: PlantHumidityPreference = .standard,
        temperaturePreference: PlantTemperaturePreference = .standard,
        isNearClimateSource: Bool = false,
        potHasDrainage: Bool = true,
        acquiredDate: Date? = nil,
        acquisitionSourceRaw: String = "",
        currentHeightCm: Double = 0,
        currentSpreadCm: Double = 0,
        isHydroponic: Bool = false,
        isSucculent: Bool = false,
        healthStatus: PlantHealthStatus = .stable,
        catalogSpeciesId: String = "",
        isToxicToCats: Bool = false,
        isToxicToDogs: Bool = false,
        isToxicToChildren: Bool = false,
        isIndoorSuitable: Bool = true,
        remindersEnabled: Bool = true,
        themeHex: String,
        notes: String
    ) {
        self.name = name
        self.avatarImageData = avatarImageData
        self.avatarEmoji = avatarEmoji
        self.species = species
        self.location = location
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.roomNameRaw = roomNameRaw
        self.potDiameterCm = potDiameterCm
        self.potMaterialRaw = potMaterialRaw
        self.soilTypeRaw = soilTypeRaw
        self.isIndoor = isIndoor
        self.windowDirection = windowDirection
        self.lightLevel = lightLevel
        self.lastLightMeasurementLux = lastLightMeasurementLux
        self.lastLightMeasurementDate = lastLightMeasurementDate
        self.humidityPreference = humidityPreference
        self.temperaturePreference = temperaturePreference
        self.isNearClimateSource = isNearClimateSource
        self.potHasDrainage = potHasDrainage
        self.acquiredDate = acquiredDate
        self.acquisitionSourceRaw = acquisitionSourceRaw
        self.currentHeightCm = currentHeightCm
        self.currentSpreadCm = currentSpreadCm
        self.isHydroponic = isHydroponic
        self.isSucculent = isSucculent
        self.healthStatus = healthStatus
        self.catalogSpeciesId = catalogSpeciesId
        self.isToxicToCats = isToxicToCats
        self.isToxicToDogs = isToxicToDogs
        self.isToxicToChildren = isToxicToChildren
        self.isIndoorSuitable = isIndoorSuitable
        self.remindersEnabled = remindersEnabled
        self.themeHex = themeHex
        self.notes = notes
    }
}

struct MemberProfileCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let changedFields: Set<String>

    var didWrite: Bool { !changedFields.isEmpty }
}

struct MemberLifecycleCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let action: String
    let didPersist: Bool = true
    let persistenceError: String? = nil

    var didWrite: Bool { didPersist && action != "no-op" }
}

struct MemberHomeVisibilityCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let visible: Bool
    let didWrite: Bool
}

struct PetWalkGoalCommandResult: Equatable {
    let petID: UUID
    let goalKm: Double
    let didWrite: Bool
}

struct PetWalkSummaryCommandResult: Equatable {
    let petID: UUID
    let walkID: UUID
    let moodRating: Int
    let hasNotes: Bool
    let didWrite: Bool
}

enum MemberProfileCommandService {
    @discardableResult
    @MainActor
    static func updatePet(
        _ pet: Pet,
        input: PetProfileCommandInput,
        context: ModelContext
    ) -> MemberProfileCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .profileEdit).writesContent else {
            return MemberProfileCommandResult(entityID: pet.id, kind: EntityKind.pet.rawValue, changedFields: [])
        }
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.name = trimmedName.isEmpty ? pet.name : trimmedName
        pet.updateAvatarImageData(input.avatarImageData)
        if let avatarEmoji = input.avatarEmoji {
            let trimmedEmoji = avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
            pet.avatarEmoji = trimmedEmoji.isEmpty ? "🐾" : trimmedEmoji
        }
        pet.species = input.species
        pet.breed = input.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.gender = input.gender
        pet.isNeutered = input.isNeutered
        pet.birthday = input.birthday
        pet.homeDate = input.homeDate
        pet.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            input.themeHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        pet.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let coatColor = input.coatColor {
            pet.coatColor = coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let eyeColor = input.eyeColor {
            pet.eyeColor = eyeColor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let microchipID = input.microchipID {
            pet.microchipID = microchipID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetContact = input.vetContact {
            pet.vetContact = vetContact.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetClinicName = input.vetClinicName {
            pet.vetClinicName = vetClinicName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetDoctorName = input.vetDoctorName {
            pet.vetDoctorName = vetDoctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetAddress = input.vetAddress {
            pet.vetAddress = vetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let allergies = input.allergies {
            pet.allergies = allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let passportNumber = input.passportNumber {
            pet.passportNumber = passportNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let hasPassportExpiry = input.hasPassportExpiry {
            pet.passportExpiryDate = hasPassportExpiry ? input.passportExpiryDate : nil
        }
        if let formerName = input.formerName {
            pet.formerName = formerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let birthCountry = input.birthCountry {
            pet.birthCountry = birthCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let birthCity = input.birthCity {
            pet.birthCity = birthCity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let lineageInfo = input.lineageInfo {
            pet.lineageInfo = lineageInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let foodBrand = input.foodBrand {
            pet.foodBrand = foodBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dailyPortionGrams = input.dailyPortionGrams {
            pet.dailyPortionGrams = max(0, dailyPortionGrams)
        }
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context)
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()

        var changedFields: Set<String> = [
            "name", "avatarImageData", "species", "breed", "gender",
            "isNeutered", "birthday", "homeDate", "themeColorHex", "notes"
        ]
        if input.avatarEmoji != nil { changedFields.insert("avatarEmoji") }
        if input.coatColor != nil { changedFields.insert("coatColor") }
        if input.eyeColor != nil { changedFields.insert("eyeColor") }
        if input.microchipID != nil { changedFields.insert("microchipID") }
        if input.vetContact != nil { changedFields.insert("vetContact") }
        if input.vetClinicName != nil { changedFields.insert("vetClinicName") }
        if input.vetDoctorName != nil { changedFields.insert("vetDoctorName") }
        if input.vetAddress != nil { changedFields.insert("vetAddress") }
        if input.allergies != nil { changedFields.insert("allergies") }
        if input.passportNumber != nil { changedFields.insert("passportNumber") }
        if input.hasPassportExpiry != nil { changedFields.insert("passportExpiryDate") }
        if input.formerName != nil { changedFields.insert("formerName") }
        if input.birthCountry != nil { changedFields.insert("birthCountry") }
        if input.birthCity != nil { changedFields.insert("birthCity") }
        if input.lineageInfo != nil { changedFields.insert("lineageInfo") }
        if input.foodBrand != nil { changedFields.insert("foodBrand") }
        if input.dailyPortionGrams != nil { changedFields.insert("dailyPortionGrams") }

        return MemberProfileCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            changedFields: changedFields
        )
    }

    @discardableResult
    @MainActor
    static func updateHuman(
        _ human: Human,
        input: HumanProfileCommandInput,
        context: ModelContext
    ) -> MemberProfileCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .profileEdit).writesContent else {
            return MemberProfileCommandResult(entityID: human.id, kind: EntityKind.human.rawValue, changedFields: [])
        }
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        human.name = trimmedName.isEmpty ? human.name : trimmedName
        human.updateAvatarImageData(input.avatarImageData)
        human.avatarEmoji = input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "👤"
            : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        human.role = HumanProfileOptions.normalizedRole(input.role)
        human.birthday = input.birthday
        human.bloodType = input.bloodType == "未填写" ? "" : input.bloodType
        human.heightCm = Double(input.heightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        human.mbti = input.mbti == "未填写" ? "" : input.mbti.uppercased()
        human.nationality = input.nationality.trimmingCharacters(in: .whitespacesAndNewlines)
        human.city = input.city.trimmingCharacters(in: .whitespacesAndNewlines)
        human.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            input.themeHex,
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )
        human.genderIdentityRaw = HumanProfileOptions.storedGenderIdentity(input.gender)

        var noteParts: [String] = []
        noteParts.append(contentsOf: input.preservedNoteParts)
        let trimmedNotes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            noteParts.append(trimmedNotes)
        }
        human.notes = noteParts.joined(separator: "｜")
        if let shouldShowOnHome = input.shouldShowOnHome {
            human.shouldShowOnHome = shouldShowOnHome
        }
        if let privateFieldsRaw = input.privateFieldsRaw {
            for field in HumanPrivateField.allCases {
                human.setPrivate(field, privateFieldsRaw.contains(field.rawValue))
            }
        }
        CloudSyncMutationRecorder.markModified(human, context: context)
        context.safeSave()

        var changedFields: Set<String> = [
            "name", "avatarImageData", "avatarEmoji", "role", "birthday",
            "bloodType", "heightCm", "mbti", "nationality", "city",
            "themeColorHex", "genderIdentityRaw", "notes"
        ]
        if input.shouldShowOnHome != nil { changedFields.insert("shouldShowOnHome") }
        if input.privateFieldsRaw != nil { changedFields.insert("privateFields") }

        return MemberProfileCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            changedFields: changedFields
        )
    }

    @discardableResult
    @MainActor
    static func updatePlant(
        _ plant: Plant,
        input: PlantProfileCommandInput,
        context: ModelContext
    ) -> MemberProfileCommandResult {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.name = trimmedName.isEmpty ? plant.name : trimmedName
        plant.updateAvatarImageData(input.avatarImageData)
        plant.avatarEmoji = input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "🌱"
            : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.species = input.species.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.location = input.location.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.wateringIntervalDays = input.wateringIntervalDays
        plant.fertilizingIntervalDays = input.fertilizingIntervalDays
        plant.roomNameRaw = input.roomNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.potDiameterCm = input.potDiameterCm
        plant.potMaterialRaw = input.potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.soilTypeRaw = input.soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.isIndoor = input.isIndoor
        plant.windowDirection = input.windowDirection
        plant.lightLevel = input.lightLevel
        plant.lastLightMeasurementLux = max(0, input.lastLightMeasurementLux)
        plant.lastLightMeasurementDate = input.lastLightMeasurementDate
        plant.humidityPreference = input.humidityPreference
        plant.temperaturePreference = input.temperaturePreference
        plant.isNearClimateSource = input.isNearClimateSource
        plant.potHasDrainage = input.potHasDrainage
        plant.acquiredDate = input.acquiredDate
        plant.acquisitionSourceRaw = input.acquisitionSourceRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.currentHeightCm = input.currentHeightCm
        plant.currentSpreadCm = input.currentSpreadCm
        plant.isHydroponic = input.isHydroponic
        plant.isSucculent = input.isSucculent
        plant.healthStatus = input.healthStatus
        plant.catalogSpeciesId = input.catalogSpeciesId
        plant.isToxicToCats = input.isToxicToCats
        plant.isToxicToDogs = input.isToxicToDogs
        plant.isToxicToChildren = input.isToxicToChildren
        plant.isIndoorSuitable = input.isIndoorSuitable
        plant.remindersEnabled = input.remindersEnabled
        plant.themeColorHex = input.themeHex
        plant.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        CloudSyncMutationRecorder.markModified(plant, context: context)
        context.safeSave()
        PlantCarePlanScheduleService.sync(plant: plant, context: context)

        return MemberProfileCommandResult(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            changedFields: [
                "name", "avatarImageData", "avatarEmoji", "species", "location",
                "wateringIntervalDays", "fertilizingIntervalDays", "roomNameRaw",
                "potDiameterCm", "potMaterialRaw", "soilTypeRaw", "isIndoor",
                "windowDirectionRaw", "lightLevelRaw", "lastLightMeasurementLux",
                "lastLightMeasurementDate", "humidityPreferenceRaw", "temperaturePreferenceRaw",
                "isNearClimateSource", "potHasDrainage", "acquiredDate", "acquisitionSourceRaw",
                "currentHeightCm", "currentSpreadCm", "isHydroponic", "isSucculent",
                "healthStatusRaw", "catalogSpeciesId", "toxicity", "isIndoorSuitable",
                "remindersEnabled", "themeColorHex", "notes"
            ]
        )
    }
}
