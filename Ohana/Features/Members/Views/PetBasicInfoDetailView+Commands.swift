//
//  PetBasicInfoDetailView+Commands.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

extension PetBasicInfoDetailView {
    func loadEditState() {
        eName = pet.name
        eSpecies = pet.species
        eBreed = pet.breed
        eGender = pet.gender
        eIsNeutered = pet.isNeutered
        eHasBirthday = pet.birthday != nil
        eBirthday = pet.birthday ?? Date()
        eHasHomeDate = pet.homeDate != nil
        eHomeDate = pet.homeDate ?? Date()
        eCoatColor = pet.coatColor
        eEyeColor = pet.eyeColor
        eMicrochipID = pet.microchipID
        eVetContact = pet.vetContact
        eVetClinicName = pet.vetClinicName
        eVetDoctorName = pet.vetDoctorName
        eVetAddress = pet.vetAddress
        eAllergies = pet.allergies
        ePassportNumber = pet.passportNumber
        eHasPassportExpiry = pet.passportExpiryDate != nil
        ePassportExpiry = pet.passportExpiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        eFormerName = pet.formerName
        eBirthCountry = pet.birthCountry
        eBirthCity = pet.birthCity
        eLineageInfo = pet.lineageInfo
        eNotes = pet.notes
        eThemeColorHex = pet.safeThemeColorHex
        eAvatarImageData = pet.avatarImageData
    }

    func saveChanges() {
        let input = PetProfileCommandInput(
            name: eName,
            avatarImageData: eAvatarImageData,
            avatarEmoji: pet.avatarEmoji,
            species: eSpecies,
            breed: eBreed,
            gender: eGender,
            isNeutered: eIsNeutered,
            birthday: eHasBirthday ? eBirthday : nil,
            homeDate: eHasHomeDate ? eHomeDate : nil,
            themeHex: eThemeColorHex,
            notes: eNotes,
            coatColor: eCoatColor,
            eyeColor: eEyeColor,
            microchipID: eMicrochipID,
            vetContact: eVetContact,
            vetClinicName: eVetClinicName,
            vetDoctorName: eVetDoctorName,
            vetAddress: eVetAddress,
            allergies: eAllergies,
            passportNumber: ePassportNumber,
            hasPassportExpiry: eHasPassportExpiry,
            passportExpiryDate: ePassportExpiry,
            formerName: eFormerName,
            birthCountry: eBirthCountry,
            birthCity: eBirthCity,
            lineageInfo: eLineageInfo,
            foodBrand: pet.foodBrand,
            dailyPortionGrams: pet.dailyPortionGrams
        )
        commandQueue.enqueue(.memberProfile(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updatePetProfile(
                pet,
                input: input,
                note: "petBasicInfo.profile"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { isEditing = false }
        }
    }
}
