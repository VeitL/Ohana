import Foundation
import XCTest

final class MediaBlobBoundaryTests: XCTestCase {
    func testExternalStorageModelFieldsAreExplicitlyAccountedFor() throws {
        let rootURL = repositoryRootURL()
        let modelPaths = [
            "Ohana/Models/Human.swift",
            "Ohana/Models/Pet.swift",
            "Ohana/Models/PetDocument.swift",
            "Ohana/Models/PetMilestone.swift",
            "Ohana/Models/PetPhotoLog.swift",
            "Ohana/Models/PetWalkLog.swift",
            "Ohana/Models/Plant.swift",
            "Ohana/Models/PlantCareLog.swift"
        ]
        let expectedFields: Set<String> = [
            "Human.avatarImageData",
            "Pet.avatarImageData",
            "Pet.cardPopoutImageData",
            "PetDocument.data",
            "PetDocument.attachmentData",
            "PetMilestone.photoData",
            "PetPhotoLog.imageData",
            "PetWalkLog.mapSnapshotData",
            "PetWalkLog.routeLocationsData",
            "Plant.avatarImageData",
            "PlantCareLog.photoData"
        ]

        var discoveredFields: [String] = []
        for path in modelPaths {
            let source = try source(path, rootURL: rootURL)
            let modelName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            for line in source.components(separatedBy: .newlines) where line.contains("@Attribute(.externalStorage)") {
                guard let fieldName = line.externalStorageFieldName else {
                    XCTFail("Could not parse externalStorage field in \(path): \(line)")
                    continue
                }
                discoveredFields.append("\(modelName).\(fieldName)")
            }
        }

        XCTAssertEqual(Set(discoveredFields), expectedFields)
        XCTAssertEqual(discoveredFields.count, expectedFields.count)
    }

    func testShareLinksUsePreparedPayloadsOrPreparedUrls() throws {
        let rootURL = repositoryRootURL()
        let familySource = try source(
            "Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift",
            rootURL: rootURL
        )
        let petBasicInfoSource = try source(
            "Ohana/Features/Members/Views/PetBasicInfoDetailView.swift",
            rootURL: rootURL
        )
        let petHealthSummarySource = try source(
            "Ohana/Features/Members/Views/PetBasicInfoDetailView+HealthSummary.swift",
            rootURL: rootURL
        )
        let plantGrowthSource = try source(
            "Ohana/Features/Plants/Views/PlantDetailView+HealthGrowthSections.swift",
            rootURL: rootURL
        )
        let settingsBackupSource = try source(
            "Ohana/Features/Settings/Views/SettingsView+Backup.swift",
            rootURL: rootURL
        )
        let pdfShareSource = try source(
            "Ohana/Features/Documents/Views/PetVetSummaryPDFView.swift",
            rootURL: rootURL
        )
        let allShareSources = [
            familySource,
            petBasicInfoSource,
            petHealthSummarySource,
            plantGrowthSource,
            settingsBackupSource,
            pdfShareSource
        ].joined(separator: "\n")

        XCTAssertFalse(allShareSources.contains("legacy eager export text"))
        XCTAssertTrue(familySource.contains("@State private var preparedShareText: String?"))
        XCTAssertTrue(familySource.contains(".task(id: sharePreparationSignature)"))
        XCTAssertTrue(familySource.contains("preparedShareText = shareText"))
        XCTAssertTrue(familySource.contains("ShareLink(item: preparedShareText)"))
        XCTAssertFalse(familySource.contains("ShareLink(item: shareText)"))

        XCTAssertTrue(petBasicInfoSource.contains("@State var preparedVetVisitSummaryText: String?"))
        XCTAssertTrue(petBasicInfoSource.contains(".task(id: vetVisitSummaryPreparationSignature)"))
        XCTAssertTrue(petHealthSummarySource.contains("preparedVetVisitSummaryText = vetVisitSummaryText"))
        XCTAssertTrue(petHealthSummarySource.contains("ShareLink(item: preparedVetVisitSummaryText)"))
        XCTAssertFalse(petHealthSummarySource.contains("ShareLink(item: vetVisitSummaryText)"))

        XCTAssertTrue(plantGrowthSource.contains("ShareLink(item: growthDiaryMarkdown)"))
        XCTAssertTrue(plantGrowthSource.contains("cached render-data export string"))
        XCTAssertTrue(settingsBackupSource.contains("else if let url = exportedJSONURL"))
        XCTAssertTrue(settingsBackupSource.contains("showingBackupSavePicker = true"))
        XCTAssertTrue(settingsBackupSource.contains("BackupPackageFileExporter"))
        XCTAssertTrue(settingsBackupSource.contains("UIDocumentPickerViewController(forExporting: [url], asCopy: true)"))
        XCTAssertTrue(settingsBackupSource.contains("ShareLink(item: url"))
        XCTAssertTrue(pdfShareSource.contains("let pdfURL: URL"))
        XCTAssertTrue(pdfShareSource.contains("ShareLink(item: pdfURL"))
    }

    func testUIBlobFieldTouchpointsStayIntentionallyClassified() throws {
        let rootURL = repositoryRootURL()
        let allowedTouchpointFiles: [String: String] = [
            "Ohana/Features/Achievements/Views/AchievementWallContentView+PopupAndAvatars.swift": "post-frame avatar cache preparation",
            "Ohana/Features/Calendar/Views/AddEventView.swift": "lazy avatar chip data providers",
            "Ohana/Features/CrewRoster/Views/CrewRosterOverlayEditors.swift": "edit/read avatar preparation",
            "Ohana/Features/DailyStreak/Views/DailyStreakDetailView.swift": "post-frame avatar cache preparation",
            "Ohana/Features/Documents/Views/DocumentDetailSheet.swift": "attachment preview data providers",
            "Ohana/Features/Documents/Views/PetVetSummaryPDFView.swift": "one-shot PDF snapshot export",
            "Ohana/Features/Economy/Views/EquipPopoutCardSheet.swift": "edit preview thumbnail preparation",
            "Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView+Map.swift": "post-frame map avatar cache preparation",
            "Ohana/Features/FunctionMenu/Views/FeatureAggregateView.swift": "post-frame avatar cache preparation",
            "Ohana/Features/Insurance/Views/ProtectionDashboardComponents.swift": "document preview data providers",
            "Ohana/Features/Members/Views/EditHumanSheet.swift": "edit-state seed",
            "Ohana/Features/Members/Views/EditPetSheet.swift": "edit-state seed",
            "Ohana/Features/Members/Views/HumanAllFeaturesSheet.swift": "post-frame avatar cache preparation",
            "Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift": "detail/edit avatar surface",
            "Ohana/Features/Members/Views/HumanDetailView+Hero.swift": "post-frame hero avatar cache preparation",
            "Ohana/Features/Members/Views/MemberCardCreationContentView+MediaAndSave.swift": "creation draft and save handoff",
            "Ohana/Features/Members/Views/MemberCardCreationView.swift": "creation draft media decode",
            "Ohana/Features/Members/Views/PetBasicInfoDetailView+Commands.swift": "edit-state seed",
            "Ohana/Features/Milestones/Views/PetMilestoneListView.swift": "route-scoped photo data providers",
            "Ohana/Features/Plants/Views/PlantDetailEditSheet.swift": "edit-state seed",
            "Ohana/Features/Settings/Views/SettingsHumanIdentityAvatar.swift": "settings avatar cache preparation",
            "Ohana/Features/Walks/Views/GlobalWalkBanner.swift": "prepared walk map snapshot",
            "Ohana/Features/Walks/Views/WalkDetailView.swift": "walk detail map snapshot and route decode",
            "Ohana/Features/Walks/Views/WalkSummarySheet.swift": "walk summary snapshot decode",
            "Ohana/Shared/Components/FeatureHubComponents.swift": "lazy thumbnail component",
            "Ohana/Shared/Components/PetAvatarPortraitView.swift": "lazy thumbnail component"
        ]

        let discoveredFiles = try uiBlobTouchpointFiles(rootURL: rootURL)
        let unexpectedFiles = discoveredFiles.subtracting(allowedTouchpointFiles.keys)

        XCTAssertTrue(
            unexpectedFiles.isEmpty,
            """
            New direct UI blob field touchpoints need explicit review and classification:
            \(unexpectedFiles.sorted().joined(separator: "\n"))
            """
        )
        XCTAssertFalse(allowedTouchpointFiles.values.contains(where: \.isEmpty))
    }

    func testHighTrafficBlobTouchpointsUseDeferredOrLazyBoundaries() throws {
        let rootURL = repositoryRootURL()
        let photoAlbumSource = try source(
            "Ohana/Features/PhotoAlbum/Views/PetPhotoAlbumView.swift",
            rootURL: rootURL
        )
        let mediaLoaderSource = try source(
            "Ohana/Shared/Media/SwiftDataMediaBlobLoader.swift",
            rootURL: rootURL
        )
        let petAvatarSource = try source(
            "Ohana/Shared/Components/PetAvatarPortraitView.swift",
            rootURL: rootURL
        )
        let featureHubSource = try source(
            "Ohana/Shared/Components/FeatureHubComponents.swift",
            rootURL: rootURL
        )
        let coHealthFullSource = try source(
            "Ohana/Features/Health/Views/CoHealthDashboardFullView.swift",
            rootURL: rootURL
        )
        let coHealthSnapshotSource = try source(
            "Ohana/Features/Health/CoHealthDashboardSnapshot.swift",
            rootURL: rootURL
        )

        XCTAssertTrue(photoAlbumSource.contains("AsyncDecodedImageView"))
        XCTAssertTrue(photoAlbumSource.contains("@State private var mediaBlobLoader: SwiftDataMediaBlobLoader?"))
        XCTAssertTrue(photoAlbumSource.contains("private func routeMediaBlobLoader() -> SwiftDataMediaBlobLoader"))
        XCTAssertTrue(photoAlbumSource.contains("let loader = routeMediaBlobLoader()"))
        XCTAssertTrue(mediaLoaderSource.contains("func petPhotoLogImageData"))
        XCTAssertTrue(mediaLoaderSource.contains("func petMilestonePhotoData"))
        XCTAssertTrue(mediaLoaderSource.contains("let data = log.imageData"))
        XCTAssertTrue(mediaLoaderSource.contains("persistRepairIfNeeded(log.repairImageAttachmentIndexIfNeeded())"))
        XCTAssertTrue(mediaLoaderSource.contains("return data"))
        XCTAssertFalse(photoAlbumSource.contains("return log.imageData"))

        XCTAssertTrue(petAvatarSource.contains("imageDataProvider: @escaping @MainActor () -> Data?"))
        XCTAssertTrue(petAvatarSource.contains("MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: imageDataProvider)"))
        XCTAssertTrue(featureHubSource.contains(".task(id: lazyThumbnailKey)"))
        XCTAssertTrue(featureHubSource.contains("MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: imageDataProvider)"))
        XCTAssertTrue(coHealthFullSource.contains("petModelID: pet.petModelID"))
        XCTAssertFalse(coHealthFullSource.contains("imageDataProvider: { pet.avatarImageData }"))
        XCTAssertFalse(coHealthSnapshotSource.contains("let avatarImageData: Data?"))
        XCTAssertFalse(coHealthSnapshotSource.contains("pet.avatarImageData"))

        let deferredAvatarSources = [
            "Ohana/Features/Achievements/Views/AchievementWallContentView+PopupAndAvatars.swift",
            "Ohana/Features/DailyStreak/Views/DailyStreakDetailView.swift",
            "Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView+Map.swift",
            "Ohana/Features/FunctionMenu/Views/FeatureAggregateView.swift"
        ]
        for path in deferredAvatarSources {
            let source = try source(path, rootURL: rootURL)
            XCTAssertTrue(source.contains("OhanaFrameScheduler.waitAfterNextFrame"), path)
            XCTAssertTrue(source.contains("FocusWalletAvatarCache.Payload"), path)
        }

        let documentSources = [
            "Ohana/Features/Documents/Views/DocumentDetailSheet.swift",
            "Ohana/Features/Insurance/Views/ProtectionDashboardComponents.swift"
        ]
        for path in documentSources {
            let source = try source(path, rootURL: rootURL)
            XCTAssertTrue(source.contains("dataProvider:"), path)
            XCTAssertTrue(source.contains("canAttemptLegacyAttachmentLoad ? doc.attachmentData : nil"), path)
        }

        let walkBannerSource = try source(
            "Ohana/Features/Walks/Views/GlobalWalkBanner.swift",
            rootURL: rootURL
        )
        XCTAssertTrue(walkBannerSource.contains("prepareSummaryMapSnapshot"))
        XCTAssertTrue(walkBannerSource.contains("OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 64)"))
    }

    func testAvatarPreviewCacheHitWorkStaysOffMainAndCancellable() throws {
        let rootURL = repositoryRootURL()
        let cacheSource = try source(
            "Ohana/Shared/Media/FocusWalletAvatarCache.swift",
            rootURL: rootURL
        )
        let pipelineSource = try source(
            "Ohana/Shared/Media/AvatarPipeline.swift",
            rootURL: rootURL
        )
        let homeUtilitiesSource = try source(
            "Ohana/Features/Home/Views/VerticalSolidHomeView+Utilities.swift",
            rootURL: rootURL
        )

        XCTAssertTrue(cacheSource.contains("static func seedPreviewEntries(payloads: [Payload]) async -> Bool"))
        XCTAssertTrue(cacheSource.contains("let priority: TaskPriority = budget.allowsExpensiveWork ? .utility : .background"))
        XCTAssertTrue(cacheSource.contains("Task.detached(priority: priority)"))
        XCTAssertTrue(cacheSource.contains("previewEntry(for: id, signature: signature)"))
        XCTAssertTrue(cacheSource.contains("guard !Task.isCancelled, generation == evictionGeneration else { return didChange }"))

        XCTAssertTrue(pipelineSource.contains("func seedPreviewEntries("))
        XCTAssertTrue(pipelineSource.contains("await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)"))
        XCTAssertTrue(pipelineSource.contains("await FocusWalletAvatarCache.seedPreviewEntries(payloads: payloads)"))
        XCTAssertTrue(pipelineSource.contains("private func previewTaskKey(for key: String) -> String"))
        XCTAssertTrue(pipelineSource.contains("decodeTasks[taskKey]?.cancel()"))

        XCTAssertTrue(homeUtilitiesSource.contains("if await FocusWalletAvatarCache.seedPreviewEntries(payloads: legacyPayloads)"))
        XCTAssertFalse(homeUtilitiesSource.contains("if FocusWalletAvatarCache.seedPreviewEntries(payloads: legacyPayloads)"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }

    private func uiBlobTouchpointFiles(rootURL: URL) throws -> Set<String> {
        let blobFieldAccess = try NSRegularExpression(
            pattern: #"\.(avatarImageData|cardPopoutImageData|attachmentData|photoData|imageData|mapSnapshotData|routeLocationsData)\b"#
        )
        let paths = try swiftPaths(
            under: [
                "Ohana/Features",
                "Ohana/Shared/Components",
                "Ohana/App"
            ],
            rootURL: rootURL
        )

        return Set(
            try paths.compactMap { path in
                guard path.contains("/Views/")
                    || path.hasPrefix("Ohana/Shared/Components/")
                    || path.hasPrefix("Ohana/App/")
                else { return nil }

                let source = try source(path, rootURL: rootURL)
                let range = NSRange(source.startIndex ..< source.endIndex, in: source)
                return blobFieldAccess.firstMatch(in: source, range: range) == nil ? nil : path
            }
        )
    }

    private func swiftPaths(under roots: [String], rootURL: URL) throws -> [String] {
        var paths: [String] = []
        for relativeRoot in roots {
            let root = rootURL.appendingPathComponent(relativeRoot)
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }

                paths.append(relativePath(for: url, rootURL: rootURL))
            }
        }
        return paths
    }

    private func relativePath(for url: URL, rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count))
    }
}

private extension String {
    var externalStorageFieldName: String? {
        guard let varRange = range(of: " var ") else { return nil }
        let suffix = self[varRange.upperBound...]
        return suffix
            .split { character in
                character == ":" || character == " " || character == "\t"
            }
            .first
            .map(String.init)
    }
}
