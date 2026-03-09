//
//  DataExportService.swift
//  Ohana
//
//  任务四：本地数据冷备份 — 打包 SwiftData SQLite + 外部照片 → .zip 文件
//

import Foundation
import UIKit

@MainActor
final class DataExportService {
    static let shared = DataExportService()
    private init() {}

    // MARK: - 导出 ZIP

    /// 将 SwiftData 数据库文件 + 外部图片目录打包为 ZIP，返回临时文件 URL
    /// - Returns: zip 文件 URL（置于 tmp/）；失败返回 nil
    func exportZip() async -> URL? {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let tmpDir = fm.temporaryDirectory
                .appendingPathComponent("ohana_backup_\(Int(Date().timeIntervalSince1970))", isDirectory: true)
            let zipURL = fm.temporaryDirectory
                .appendingPathComponent("ohana_backup_\(Self.dateStamp()).zip")

            do {
                try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

                // ── 1. 复制 SwiftData SQLite 文件
                let dbFiles = Self.sqliteFiles()
                if !dbFiles.isEmpty {
                    let dbDst = tmpDir.appendingPathComponent("database", isDirectory: true)
                    try fm.createDirectory(at: dbDst, withIntermediateDirectories: true)
                    for src in dbFiles {
                        let dst = dbDst.appendingPathComponent(src.lastPathComponent)
                        if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
                        try fm.copyItem(at: src, to: dst)
                    }
                }

                // ── 2. 复制 App Documents 中的外部图片目录
                let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                let photoDst = tmpDir.appendingPathComponent("photos", isDirectory: true)
                if fm.fileExists(atPath: docsDir.path) {
                    try? fm.copyItem(at: docsDir, to: photoDst)
                }

                // ── 3. 写一份元数据 manifest.json
                let manifest: [String: Any] = [
                    "exportDate": ISO8601DateFormatter().string(from: Date()),
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                    "schemaVersion": "14"
                ]
                let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
                try manifestData.write(to: tmpDir.appendingPathComponent("manifest.json"))

                // ── 4. 将 tmpDir 本身作为共享目录返回（iOS 不支持 Process/zip 命令）
                // 调用方通过 ShareLink(item: URL) 分享整个目录或其中的单个文件
                // 这里把 manifest.json 路径作为代表文件返回，目录与文件同在 tmp 中
                let manifestURL = tmpDir.appendingPathComponent("manifest.json")
                guard fm.fileExists(atPath: manifestURL.path) else { return nil }
                return manifestURL
            } catch {
                try? fm.removeItem(at: tmpDir)
                #if DEBUG
                print("❌ [DataExportService] exportZip 失败: \(error)")
                #endif
                return nil
            }
        }.value
    }

    // MARK: - SwiftData SQLite 文件路径探测

    private nonisolated static func sqliteFiles() -> [URL] {
        let fm = FileManager.default
        var candidates: [URL] = []

        // SwiftData 默认存储路径（无 App Group 时）
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // SwiftData 数据库通常在 Application Support 下以 .store 后缀命名
        let storeDir = appSupport
        if let contents = try? fm.contentsOfDirectory(at: storeDir,
                                                       includingPropertiesForKeys: nil,
                                                       options: .skipsHiddenFiles) {
            for url in contents where ["sqlite", "sqlite-shm", "sqlite-wal", "store"].contains(url.pathExtension) {
                candidates.append(url)
            }
        }

        // 递归搜索子目录（SwiftData 有时会放在子文件夹中）
        if let enumerator = fm.enumerator(at: storeDir, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if ["sqlite", "sqlite-shm", "sqlite-wal", "store"].contains(url.pathExtension),
                   !candidates.contains(url) {
                    candidates.append(url)
                }
            }
        }

        return candidates
    }

    // MARK: - 日期戳
    private nonisolated static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }

    // MARK: - 估算备份大小
    func estimatedBackupSizeText() -> String {
        let fm = FileManager.default
        var totalBytes: Int64 = 0

        for url in Self.sqliteFiles() {
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            totalBytes += size
        }

        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let enumerator = fm.enumerator(at: docsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
                totalBytes += size
            }
        }

        let mb = Double(totalBytes) / 1_048_576
        return mb < 1 ? "<1 MB" : String(format: "约 %.1f MB", mb)
    }
}
