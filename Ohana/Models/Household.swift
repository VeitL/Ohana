//
//  Household.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation

@Model
final class Household {
    var id: UUID
    var name: String
    var createdAt: Date
    var ckShareRecordName: String
    // Phase 20: 岛屿繁荣度 EXP（只增不减）
    var totalProsperity: Int

    init(name: String = "我的家庭") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.ckShareRecordName = ""
        self.totalProsperity = 0
    }
}
