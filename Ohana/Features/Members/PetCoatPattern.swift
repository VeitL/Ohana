//
//  PetCoatPattern.swift
//  Ohana
//

import SwiftUI

nonisolated enum PetCoatPattern: String, CaseIterable {
    case calico = "三花"
    case silverChinchilla = "银渐层"
    case tortoiseshell = "玳瑁"
    case cowPattern = "奶牛色"
    case bicolor = "蓝白双色"

    var displayName: String { rawValue }

    var gradient: AnyShapeStyle {
        switch self {
        case .calico:
            AnyShapeStyle(
                AngularGradient(
                    gradient: Gradient(colors: [.white, .black, Color(hex: "E87722"), .white]),
                    center: .center
                )
            )
        case .silverChinchilla:
            AnyShapeStyle(
                RadialGradient(
                    colors: [.white, Color(hex: "C8C8C8"), Color(hex: "909090")],
                    center: .center,
                    startRadius: 2,
                    endRadius: 20
                )
            )
        case .tortoiseshell:
            AnyShapeStyle(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "2C1A0E"),
                        Color(hex: "C05A00"),
                        Color(hex: "1A1A1A"),
                        Color(hex: "D4820A"),
                        Color(hex: "2C1A0E")
                    ]),
                    center: .center
                )
            )
        case .cowPattern:
            AnyShapeStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.4),
                        .init(color: .black, location: 0.4),
                        .init(color: .black, location: 0.65),
                        .init(color: .white, location: 0.65),
                        .init(color: .white, location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .bicolor:
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "95ADBE"), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

extension PetCoatPattern {
    static func patterns(forBreed breed: BreedInfo?) -> [PetCoatPattern] {
        guard let breed else { return [] }
        let names = breed.coatColors.map(\.name)
        let matched = PetCoatPattern.allCases.filter { $0.matchesCoatColorNames(names) }
        guard Self.breedAllowsCatTypicalPatterns(breed) else {
            return matched.filter { $0 == .cowPattern }
        }
        return matched
    }

    private static func breedAllowsCatTypicalPatterns(_ breed: BreedInfo) -> Bool {
        let name = breed.name
        if name.hasSuffix("猫") { return true }
        if name.contains("田园猫") { return true }
        if name == "银渐层" || name == "金渐层" { return true }
        return false
    }

    private func matchesCoatColorNames(_ names: [String]) -> Bool {
        if names.contains(displayName) { return true }
        switch self {
        case .calico:
            return names.contains { $0.contains("三花") }
        case .silverChinchilla:
            return names.contains { $0.contains("银渐层") || $0.contains("银底") || $0.contains("浅银") }
        case .tortoiseshell:
            return names.contains { $0.contains("玳瑁") }
        case .cowPattern:
            return names.contains { $0.contains("奶牛") || $0.contains("白底黑斑") || $0.contains("白底肝斑") }
        case .bicolor:
            return names.contains { name in
                name == "蓝白" || name.contains("蓝白双色") || (name.contains("蓝白") && !name.contains("重点"))
            }
        }
    }
}
