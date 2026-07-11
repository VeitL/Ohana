//
//  HumanNoteAttachmentStore.swift
//  Ohana
//
//  Lightweight file-backed attachments for Human.notes entries.
//

import Foundation
import UIKit

nonisolated struct HumanNoteAttachmentReference: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var fileName: String
    var relativePath: String
    var isImage: Bool
}

nonisolated struct HumanNoteAttachmentStorage: Equatable, Sendable {
    let applicationSupportDirectory: URL?

    static let live = HumanNoteAttachmentStorage(applicationSupportDirectory: nil)

    init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
    }

    private init(applicationSupportDirectory: URL?) {
        self.applicationSupportDirectory = applicationSupportDirectory
    }
}

nonisolated enum HumanNoteAttachmentCleanupResult: Equatable, Sendable {
    case notRequired
    case completed(removedFileCount: Int)
    case pending(String)

    var didComplete: Bool {
        switch self {
        case .notRequired, .completed:
            true
        case .pending:
            false
        }
    }
}

nonisolated enum HumanNoteAttachmentStore {
    private static let markerPrefix = "@@ohana-note-attachments:"
    private static let rootFolderComponents = ["Ohana", "HumanNotes"]

    static func saveImage(
        _ image: UIImage,
        humanId: UUID,
        index: Int,
        storage: HumanNoteAttachmentStorage = .live
    ) -> HumanNoteAttachmentReference? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        return saveFile(
            data: data,
            originalFileName: "photo_\(index).jpg",
            isImage: true,
            humanId: humanId,
            storage: storage
        )
    }

    static func saveFile(
        data: Data,
        originalFileName: String,
        isImage: Bool,
        humanId: UUID,
        storage: HumanNoteAttachmentStorage = .live
    ) -> HumanNoteAttachmentReference? {
        let cleanName = sanitizedFileName(originalFileName, fallback: isImage ? "image.jpg" : "attachment")
        let storedName = "\(UUID().uuidString)_\(cleanName)"
        let relativePath = (rootFolderComponents + [humanId.uuidString, storedName])
            .joined(separator: "/")

        guard let url = url(forRelativePath: relativePath, storage: storage) else { return nil }
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try LocalBackupExclusionPolicy.excludeFromDeviceBackup(directory)
            try data.write(to: url, options: [.atomic])
            try LocalBackupExclusionPolicy.excludeFromDeviceBackup(url)
            return HumanNoteAttachmentReference(
                id: UUID(),
                fileName: cleanName,
                relativePath: relativePath,
                isImage: isImage
            )
        } catch {
            try? FileManager.default.removeItem(at: url)
            OhanaLog.error(
                "Human note attachment save or backup exclusion failed.",
                category: "Privacy",
                privacy: .publicText
            )
            return nil
        }
    }

    static func marker(for references: [HumanNoteAttachmentReference]) -> String {
        guard !references.isEmpty,
              let data = try? JSONEncoder().encode(references) else {
            return ""
        }
        return "\n\(markerPrefix)\(data.base64EncodedString())"
    }

    static func visibleTextAndAttachments(from raw: String) -> (text: String, attachments: [HumanNoteAttachmentReference]) {
        guard let range = raw.range(of: markerPrefix) else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), [])
        }

        let visible = raw[..<range.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedTail = raw[range.upperBound...]
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        guard let data = Data(base64Encoded: encodedTail),
              let refs = try? JSONDecoder().decode([HumanNoteAttachmentReference].self, from: data) else {
            return (visible, [])
        }
        return (visible, refs)
    }

    static func references(in notes: String) -> [HumanNoteAttachmentReference] {
        notes
            .components(separatedBy: "\n\n")
            .flatMap { visibleTextAndAttachments(from: $0).attachments }
    }

    static func referencedRelativePaths(in notes: [String]) -> Set<String> {
        Set(
            notes
                .flatMap(references(in:))
                .compactMap { managedRelativePath($0.relativePath) }
        )
    }

    static func url(
        for reference: HumanNoteAttachmentReference,
        storage: HumanNoteAttachmentStorage = .live
    ) -> URL? {
        url(forRelativePath: reference.relativePath, storage: storage)
    }

    @discardableResult
    static func deletePendingAttachments(_ references: [HumanNoteAttachmentReference]) -> HumanNoteAttachmentCleanupResult {
        deletePendingAttachments(references, storage: .live)
    }

    @discardableResult
    static func deletePendingAttachments(
        _ references: [HumanNoteAttachmentReference],
        storage: HumanNoteAttachmentStorage
    ) -> HumanNoteAttachmentCleanupResult {
        deleteReferences(
            references,
            preservingRelativePaths: [],
            storage: storage
        )
    }

    static func deleteUnreferencedAttachments(
        _ references: [HumanNoteAttachmentReference],
        preservingRelativePaths: Set<String>,
        storage: HumanNoteAttachmentStorage = .live
    ) -> HumanNoteAttachmentCleanupResult {
        deleteReferences(
            references,
            preservingRelativePaths: preservingRelativePaths,
            storage: storage
        )
    }

    static func deleteHumanDirectory(
        humanID: UUID,
        preservingRelativePaths: Set<String>,
        storage: HumanNoteAttachmentStorage = .live
    ) -> HumanNoteAttachmentCleanupResult {
        guard let directory = humanDirectoryURL(humanID: humanID, storage: storage) else {
            return pendingCleanup("The Human Notes storage directory could not be resolved.")
        }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            return .completed(removedFileCount: 0)
        }

        let protectedPaths = Set(
            preservingRelativePaths.compactMap {
                url(forRelativePath: $0, storage: storage)?.standardizedFileURL.path
            }
        )
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return pendingCleanup("The Human Notes member directory could not be inspected.")
        }

        var files: [URL] = []
        var directories: [URL] = []
        for case let itemURL as URL in enumerator {
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                directories.append(itemURL)
            } else {
                files.append(itemURL)
            }
        }

        var removedFileCount = 0
        var firstError: Error?
        for fileURL in files where !protectedPaths.contains(fileURL.standardizedFileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
                removedFileCount += 1
            } catch {
                firstError = firstError ?? error
            }
        }

        for candidate in (directories + [directory]).sorted(by: { $0.path.count > $1.path.count }) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: candidate.path)
                if contents.isEmpty {
                    try fileManager.removeItem(at: candidate)
                }
            } catch {
                if fileManager.fileExists(atPath: candidate.path) {
                    firstError = firstError ?? error
                }
            }
        }

        if let firstError {
            return pendingCleanup("Some local Human Note attachments could not be removed: \(firstError.localizedDescription)")
        }
        return .completed(removedFileCount: removedFileCount)
    }

    static func deleteAll(
        storage: HumanNoteAttachmentStorage = .live
    ) -> HumanNoteAttachmentCleanupResult {
        guard let root = rootURL(storage: storage) else {
            return pendingCleanup("The Human Notes storage root could not be resolved.")
        }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else {
            return .completed(removedFileCount: 0)
        }

        let fileCount = fileManager.enumerator(atPath: root.path)?
            .compactMap { $0 as? String }
            .count(where: { path in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(
                    atPath: root.appendingPathComponent(path).path,
                    isDirectory: &isDirectory
                ) && !isDirectory.boolValue
            })
             ?? 0
        do {
            try fileManager.removeItem(at: root)
            return .completed(removedFileCount: fileCount)
        } catch {
            return pendingCleanup("Local Human Note attachments could not be removed: \(error.localizedDescription)")
        }
    }

    private static func deleteReferences(
        _ references: [HumanNoteAttachmentReference],
        preservingRelativePaths: Set<String>,
        storage: HumanNoteAttachmentStorage
    ) -> HumanNoteAttachmentCleanupResult {
        let protectedPaths = Set(preservingRelativePaths.compactMap(managedRelativePath))
        let candidates = Dictionary(
            references.compactMap { reference -> (String, HumanNoteAttachmentReference)? in
                guard let path = managedRelativePath(reference.relativePath),
                      !protectedPaths.contains(path) else {
                    return nil
                }
                return (path, reference)
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard !candidates.isEmpty else {
            return .completed(removedFileCount: 0)
        }

        let fileManager = FileManager.default
        var removedFileCount = 0
        var firstError: Error?
        var affectedDirectories: Set<URL> = []
        for reference in candidates.values {
            guard let fileURL = url(for: reference, storage: storage) else {
                firstError = firstError ?? HumanNoteAttachmentStoreError.invalidManagedPath
                continue
            }
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            do {
                try fileManager.removeItem(at: fileURL)
                removedFileCount += 1
                affectedDirectories.insert(fileURL.deletingLastPathComponent())
            } catch {
                firstError = firstError ?? error
            }
        }

        if let root = rootURL(storage: storage) {
            for directory in affectedDirectories {
                removeEmptyManagedAncestors(
                    startingAt: directory,
                    root: root,
                    fileManager: fileManager
                )
            }
        }

        if let firstError {
            return pendingCleanup("Some local Human Note attachments could not be removed: \(firstError.localizedDescription)")
        }
        return .completed(removedFileCount: removedFileCount)
    }

    private static func removeEmptyManagedAncestors(
        startingAt directory: URL,
        root: URL,
        fileManager: FileManager
    ) {
        var current = directory.standardizedFileURL
        let managedRoot = root.standardizedFileURL
        while current.path != managedRoot.path,
              current.path.hasPrefix(managedRoot.path + "/") {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: current.path),
                  contents.isEmpty else {
                return
            }
            try? fileManager.removeItem(at: current)
            current = current.deletingLastPathComponent().standardizedFileURL
        }
    }

    private static func rootURL(storage: HumanNoteAttachmentStorage) -> URL? {
        guard let applicationSupportDirectory = applicationSupportDirectory(storage: storage) else {
            return nil
        }
        return rootFolderComponents.reduce(applicationSupportDirectory) { partial, component in
            partial.appendingPathComponent(component, isDirectory: true)
        }
        .standardizedFileURL
    }

    private static func humanDirectoryURL(
        humanID: UUID,
        storage: HumanNoteAttachmentStorage
    ) -> URL? {
        rootURL(storage: storage)?
            .appendingPathComponent(humanID.uuidString, isDirectory: true)
            .standardizedFileURL
    }

    private static func url(
        forRelativePath relativePath: String,
        storage: HumanNoteAttachmentStorage
    ) -> URL? {
        guard let managedPath = managedRelativePath(relativePath),
              let applicationSupportDirectory = applicationSupportDirectory(storage: storage),
              let root = rootURL(storage: storage) else {
            return nil
        }
        let candidate = applicationSupportDirectory
            .appendingPathComponent(managedPath, isDirectory: false)
            .standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPrefix) else { return nil }
        return candidate
    }

    private static func applicationSupportDirectory(
        storage: HumanNoteAttachmentStorage
    ) -> URL? {
        if let override = storage.applicationSupportDirectory {
            return override.standardizedFileURL
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .standardizedFileURL
    }

    private static func managedRelativePath(_ raw: String) -> String? {
        guard !raw.hasPrefix("/") else { return nil }
        let components = NSString(string: raw).pathComponents
        guard components.count >= rootFolderComponents.count + 2,
              Array(components.prefix(rootFolderComponents.count)) == rootFolderComponents,
              !components.contains(".."),
              !components.contains("."),
              components.allSatisfy({ !$0.isEmpty && $0 != "/" }) else {
            return nil
        }
        return components.joined(separator: "/")
    }

    private static func pendingCleanup(_ message: String) -> HumanNoteAttachmentCleanupResult {
        OhanaLog.error(
            "Human note attachment cleanup remains pending.",
            category: "Privacy",
            privacy: .publicText
        )
        return .pending(message)
    }

    private static func sanitizedFileName(_ raw: String, fallback: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = raw
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }
}

private nonisolated enum HumanNoteAttachmentStoreError: LocalizedError {
    case invalidManagedPath

    var errorDescription: String? {
        "The attachment path is outside the managed Human Notes directory."
    }
}
