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
        default: l.tr(zh: "请选择", en: "Choose", de: "Auswählen")
        }
    }

    func humanGenderLabel(_ gender: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(gender, l: l)
        return title.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : title
    }

    func humanRoleLabel(_ role: String) -> String {
        HumanProfileOptions.localizedRoleTitle(role, l: l)
    }

    func bloodTypeLabel(_ value: String) -> String {
        value.isEmpty ? l.tr(zh: "不设置", en: "Skip", de: "Überspringen") : value
    }
}
