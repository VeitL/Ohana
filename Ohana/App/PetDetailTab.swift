//
//  PetDetailTab.swift
//  Ohana
//
//  Compatibility route marker for legacy pet-detail entry points.
//

import Foundation

enum PetDetailTab: String, CaseIterable {
    case overview = "概览"
    case health = "健康"
    case records = "记录"

    var icon: String {
        switch self {
        case .overview: "pawprint.fill"
        case .health: "heart.text.clipboard"
        case .records: "list.clipboard"
        }
    }
}
