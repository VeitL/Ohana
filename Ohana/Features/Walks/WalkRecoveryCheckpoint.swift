import Foundation

@MainActor
enum WalkRecoveryCheckpoint {
    private static let metadataPrefix = "ohana.walk.checkpoint.metadata.v1:"

    static func makeSharedSessionID(id: UUID = UUID()) -> String {
        PetWalkLog.recoveryCheckpointSessionPrefix + id.uuidString
    }

    static func isCheckpoint(_ walk: PetWalkLog) -> Bool {
        walk.isRecoveryCheckpoint
    }

    static func isRecoverable(_ walk: PetWalkLog) -> Bool {
        isCheckpoint(walk) && walk.endDate == nil
    }

    static func sessionID(from walk: PetWalkLog) -> UUID? {
        guard isCheckpoint(walk) else { return nil }
        let rawID = walk.sharedSessionId.dropFirst(PetWalkLog.recoveryCheckpointSessionPrefix.count)
        return UUID(uuidString: String(rawID))
    }

    static func metadata(elapsedTime: TimeInterval, poopMarkers: [WalkPoopMarker]) -> WalkRecoveryCheckpointMetadata {
        WalkRecoveryCheckpointMetadata(
            elapsedSeconds: max(0, elapsedTime),
            poopMarkers: poopMarkers.map(WalkRecoveryCheckpointPoopMarker.init(marker:))
        )
    }

    static func encodeMetadata(_ metadata: WalkRecoveryCheckpointMetadata) -> String? {
        guard let data = try? JSONEncoder().encode(metadata) else { return nil }
        return metadataPrefix + data.base64EncodedString()
    }

    static func decodeMetadata(from walk: PetWalkLog) -> WalkRecoveryCheckpointMetadata? {
        guard let notes = walk.behaviorNotes,
              notes.hasPrefix(metadataPrefix)
        else { return nil }
        let encoded = String(notes.dropFirst(metadataPrefix.count))
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(WalkRecoveryCheckpointMetadata.self, from: data)
    }
}

nonisolated struct WalkRecoveryCheckpointMetadata: Codable, Equatable {
    var elapsedSeconds: TimeInterval
    var poopMarkers: [WalkRecoveryCheckpointPoopMarker]
}

nonisolated struct WalkRecoveryCheckpointPoopMarker: Codable, Equatable {
    var id: UUID
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var accuracyMeters: Double?
    var typeRawValue: String

    init(marker: WalkPoopMarker) {
        id = marker.id
        date = marker.date
        latitude = marker.latitude
        longitude = marker.longitude
        accuracyMeters = marker.accuracyMeters
        typeRawValue = marker.type.rawValue
    }
}

extension WalkPoopMarker {
    init(checkpoint marker: WalkRecoveryCheckpointPoopMarker) {
        self.init(
            id: marker.id,
            date: marker.date,
            latitude: marker.latitude,
            longitude: marker.longitude,
            accuracyMeters: marker.accuracyMeters,
            type: PottyType(rawValue: marker.typeRawValue) ?? .perfectPoop
        )
    }
}
