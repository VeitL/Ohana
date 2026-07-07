//
//  MemberCardCreationContentView+Labels.swift
//  Ohana
//

import AVFoundation
import Combine
import ImageIO
import os
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

extension MemberCardCreationContentView {
    func speciesLabel(_ species: String) -> String {
        Pet.localizedSpeciesName(species, l: l)
    }

    func personalityLabel(_ id: String) -> String {
        guard let tag = PetPersonalityTag.lookup(id) else { return id }
        return l.tr(zh: tag.titleZh, en: tag.titleEn, de: tag.titleEn)
    }

    func petGenderLabel(_ gender: String) -> String {
        switch gender {
        case "boy", "male", "男": l.tr(zh: "男孩", en: "Boy", de: "Junge")
        case "girl", "female", "女": l.tr(zh: "女孩", en: "Girl", de: "Mädchen")
        default: l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")
        }
    }

    func humanGenderLabel(_ gender: String) -> String {
        switch HumanProfileOptions.normalizedGender(gender) {
        case "男": l.tr(zh: "男", en: "Male", de: "Männlich")
        case "女": l.tr(zh: "女", en: "Female", de: "Weiblich")
        case "非二元": l.tr(zh: "非二元", en: "Nonbinary", de: "Nichtbinär")
        default: l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt")
        }
    }

    func humanRoleLabel(_ role: String) -> String {
        switch HumanProfileOptions.normalizedRole(role) {
        case "owner": l.tr(zh: "主人", en: "Owner", de: "Besitzer")
        default: l.tr(zh: "家人", en: "Family", de: "Familie")
        }
    }

    func bloodTypeLabel(_ value: String) -> String {
        value.isEmpty ? l.tr(zh: "不设置", en: "Skip", de: "Überspringen") : value
    }
}
