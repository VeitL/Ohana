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
        await Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }.value
    }
}
