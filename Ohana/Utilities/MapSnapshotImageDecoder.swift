//
//  MapSnapshotImageDecoder.swift
//  Ohana
//
//  Small async decoder for persisted walk map snapshots.
//

import Foundation
import UIKit

enum MapSnapshotImageDecoder {
    static func decode(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
    }
}
