//
//  DataBackupMediaPackage.swift
//  Ohana
//
//  Out-of-line media storage for backup packages.
//

import Foundation

nonisolated protocol DataBackupMediaWriting {
    func write(_ data: Data?, purpose: DataBackupMediaPurpose, id: String) throws -> BackupMediaReference?
}

nonisolated protocol DataBackupMediaResolving {
    func data(for reference: BackupMediaReference?) throws -> Data?
}

nonisolated enum DataBackupMediaPurpose: String {
    case petAvatar = "pet-avatar"
    case petCardPopout = "pet-card-popout"
    case humanAvatar = "human-avatar"
    case plantAvatar = "plant-avatar"
    case plantCarePhoto = "plant-care-photo"
    case petDocumentAttachment = "pet-document-attachment"
    case petDocumentAttachmentFile = "pet-document-attachment-file"
    case petMilestonePhoto = "pet-milestone-photo"
    case petPhoto = "pet-photo"
    case petWalkMapSnapshot = "pet-walk-map-snapshot"
    case petWalkRouteLocations = "pet-walk-route-locations"
    case symptomPhoto = "symptom-photo"
}

nonisolated struct DataBackupPackageBuildResult: Sendable {
    let manifestData: Data
    let mediaCount: Int
    let mediaBytes: Int
}

final nonisolated class DataBackupMediaPackageWriter: DataBackupMediaWriting, @unchecked Sendable {
    private let packageURL: URL
    private let mediaDirectoryURL: URL
    private let encryptMedia: Bool
    private let password: String?
    private var sequence = 0

    private(set) var mediaCount = 0
    private(set) var mediaBytes = 0

    init(packageURL: URL, encryptMedia: Bool, password: String?) {
        self.packageURL = packageURL
        self.mediaDirectoryURL = packageURL.appendingPathComponent(DataBackupManager.mediaDirectoryName, isDirectory: true)
        self.encryptMedia = encryptMedia
        self.password = password
    }

    func preparePackageDirectory() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)
    }

    func write(_ data: Data?, purpose: DataBackupMediaPurpose, id: String) throws -> BackupMediaReference? {
        guard let data, !data.isEmpty else { return nil }
        sequence += 1
        let fileName = "\(purpose.rawValue)-\(Self.safeFileComponent(id))-\(sequence).bin"
        let relativePath = "\(DataBackupManager.mediaDirectoryName)/\(fileName)"
        let url = mediaDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let payload = if encryptMedia, let password {
            try DataBackupEncryption.encrypt(data, password: password)
        } else {
            data
        }
        try payload.write(to: url, options: [.atomic, .completeFileProtection])
        mediaCount += 1
        mediaBytes += data.count
        return BackupMediaReference(path: relativePath, byteCount: data.count)
    }

    private nonisolated static func safeFileComponent(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = raw.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return value.isEmpty ? UUID().uuidString : value
    }
}

final nonisolated class DataBackupMediaPackageReader: DataBackupMediaResolving {
    private let packageURL: URL
    private let password: String?

    init(packageURL: URL, password: String?) {
        self.packageURL = packageURL
        self.password = password
    }

    func data(for reference: BackupMediaReference?) throws -> Data? {
        guard let reference else { return nil }
        let components = reference.path.split(separator: "/").map(String.init)
        guard components.count == 2,
              components[0] == DataBackupManager.mediaDirectoryName,
              !components[1].isEmpty,
              !components[1].contains("..") else {
            throw BackupError.invalidBackupPackage
        }
        let url = packageURL
            .appendingPathComponent(components[0], isDirectory: true)
            .appendingPathComponent(components[1], isDirectory: false)
        let fileData = try Data(contentsOf: url)
        return try DataBackupEncryption.decryptIfNeeded(fileData, password: password)
    }
}
