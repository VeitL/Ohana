//
//  IdentifiableCropImage.swift
//  Ohana
//

import Foundation
import UIKit

struct IdentifiableCropImage: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: IdentifiableCropImage, rhs: IdentifiableCropImage) -> Bool {
        lhs.id == rhs.id
    }
}
