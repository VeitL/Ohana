//
//  HumanNoteAttachmentStore.swift
//  Ohana
//
//  Lightweight file-backed attachments for Human.notes entries.
//

import Foundation
import UIKit

struct HumanNoteAttachmentReference: Codable, Hashable, Identifiable {
    var id: UUID
    var fileName: String
    var relativePath: String
    var isImage: Bool
}

enum HumanNoteAttachmentStore {
    private static let markerPrefix = "@@ohana-note-attachments:"
    private static let rootFolder = "Ohana/HumanNotes"

    static func saveImage(_ image: UIImage, humanId: UUID, index: Int) -> HumanNoteAttachmentReference? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        return saveFile(
            data: data,
            originalFileName: "photo_\(index).jpg",
            isImage: true,
            humanId: humanId
        )
    }

    static func saveFile(
        data: Data,
        originalFileName: String,
        isImage: Bool,
        humanId: UUID
    ) -> HumanNoteAttachmentReference? {
        let cleanName = sanitizedFileName(originalFileName, fallback: isImage ? "image.jpg" : "attachment")
        let storedName = "\(UUID().uuidString)_\(cleanName)"
        let relativePath = "\(rootFolder)/\(humanId.uuidString)/\(storedName)"

        guard let url = url(forRelativePath: relativePath) else { return nil }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
            return HumanNoteAttachmentReference(
                id: UUID(),
                fileName: cleanName,
                relativePath: relativePath,
                isImage: isImage
            )
        } catch {
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

    static func url(for reference: HumanNoteAttachmentReference) -> URL? {
        url(forRelativePath: reference.relativePath)
    }

    static func deletePendingAttachments(_ references: [HumanNoteAttachmentReference]) {
        for reference in references {
            guard let url = url(for: reference) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func url(forRelativePath relativePath: String) -> URL? {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root.appendingPathComponent(relativePath, isDirectory: false)
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
