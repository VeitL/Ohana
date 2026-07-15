import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanNoteAttachmentLifecycleTests {
    @Test func noteDeletionPreservesSharedReferenceThenRemovesItWhenLastReferenceIsDeleted() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let owner = Human(name: "Owner")
        let collaborator = Human(name: "Collaborator")
        let reference = try #require(saveAttachment(humanID: owner.id, storage: fixture.storage))
        let ownerEntry = noteEntry("owner copy", references: [reference])
        let sharedEntry = noteEntry("shared copy", references: [reference])
        owner.notes = ownerEntry
        collaborator.notes = sharedEntry
        context.insert(owner)
        context.insert(collaborator)
        try context.save()
        let fileURL = try #require(HumanNoteAttachmentStore.url(for: reference, storage: fixture.storage))

        let firstDelete = HumanNoteCommandService.deleteNote(
            human: owner,
            rawString: ownerEntry,
            context: context,
            attachmentStorage: fixture.storage
        )

        #expect(firstDelete.didPersist)
        #expect(firstDelete.attachmentCleanup == .completed(removedFileCount: 0))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let repeatedDelete = HumanNoteCommandService.deleteNote(
            human: owner,
            rawString: ownerEntry,
            context: context,
            attachmentStorage: fixture.storage
        )

        #expect(!repeatedDelete.didDelete)
        #expect(repeatedDelete.attachmentCleanup == .notRequired)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let finalDelete = HumanNoteCommandService.deleteNote(
            human: collaborator,
            rawString: sharedEntry,
            context: context,
            attachmentStorage: fixture.storage
        )

        #expect(finalDelete.didPersist)
        #expect(finalDelete.attachmentCleanup == .completed(removedFileCount: 1))
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func noteDeletionSaveFailurePreservesDatabaseReferenceAndFile() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let human = Human(name: "Owner")
        let reference = try #require(saveAttachment(humanID: human.id, storage: fixture.storage))
        let entry = noteEntry("keep after rollback", references: [reference])
        human.notes = entry
        context.insert(human)
        try context.save()
        let fileURL = try #require(HumanNoteAttachmentStore.url(for: reference, storage: fixture.storage))

        let result = HumanNoteCommandService.deleteNote(
            human: human,
            rawString: entry,
            context: context,
            attachmentStorage: fixture.storage,
            saveChanges: injectedSaveFailure
        )

        #expect(!result.didPersist)
        #expect(result.attachmentCleanup == .notRequired)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let persistedHuman = try #require(try context.fetch(FetchDescriptor<Human>()).first)
        #expect(persistedHuman.notes == entry)
    }

    @Test func noteCreationSaveFailureRemovesUncommittedAttachment() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let human = Human(name: "Owner")
        context.insert(human)
        try context.save()

        let result = try #require(HumanNoteCommandService.recordNote(
            human: human,
            note: "will roll back",
            date: Date(timeIntervalSinceReferenceDate: 100),
            imageAttachments: [],
            fileAttachments: [
                HumanNoteFileAttachmentPayload(
                    fileName: "private.pdf",
                    data: Data([1, 2, 3]),
                    isImage: false
                )
            ],
            reminderDate: nil,
            appLanguage: "en",
            context: context,
            scheduleNotification: false,
            attachmentStorage: fixture.storage,
            saveChanges: injectedSaveFailure
        ))

        #expect(!result.didPersist)
        #expect(fileCount(in: fixture.applicationSupportDirectory) == 0)
        let persistedHuman = try #require(try context.fetch(FetchDescriptor<Human>()).first)
        #expect(persistedHuman.notes.isEmpty)
    }

    @Test func humanDeletionClearsOwnedAndOrphanFilesButPreservesSharedReference() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let owner = Human(name: "Owner")
        let survivor = Human(name: "Survivor")
        let owned = try #require(saveAttachment(fileName: "owned.pdf", humanID: owner.id, storage: fixture.storage))
        let shared = try #require(saveAttachment(fileName: "shared.pdf", humanID: owner.id, storage: fixture.storage))
        let orphan = try #require(saveAttachment(fileName: "orphan.pdf", humanID: owner.id, storage: fixture.storage))
        owner.notes = noteEntry("owner", references: [owned, shared])
        let survivorEntry = noteEntry("shared", references: [shared])
        survivor.notes = survivorEntry
        context.insert(owner)
        context.insert(survivor)
        try context.save()
        let ownedURL = try #require(HumanNoteAttachmentStore.url(for: owned, storage: fixture.storage))
        let sharedURL = try #require(HumanNoteAttachmentStore.url(for: shared, storage: fixture.storage))
        let orphanURL = try #require(HumanNoteAttachmentStore.url(for: orphan, storage: fixture.storage))
        let deletedHumanDirectory = sharedURL.deletingLastPathComponent()

        let result = MemberDeletionCommandService.deleteHuman(
            owner,
            activeHumanID: owner.id.uuidString,
            context: context,
            attachmentStorage: fixture.storage
        )

        #expect(result.didPersist)
        #expect(result.attachmentCleanup == .completed(removedFileCount: 2))
        #expect(!FileManager.default.fileExists(atPath: ownedURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(FileManager.default.fileExists(atPath: sharedURL.path))

        _ = HumanNoteCommandService.deleteNote(
            human: survivor,
            rawString: survivorEntry,
            context: context,
            attachmentStorage: fixture.storage
        )

        #expect(!FileManager.default.fileExists(atPath: sharedURL.path))
        #expect(!FileManager.default.fileExists(atPath: deletedHumanDirectory.path))
    }

    @Test func humanDeletionSaveFailurePreservesDirectoryAndReference() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let human = Human(name: "Owner")
        let reference = try #require(saveAttachment(humanID: human.id, storage: fixture.storage))
        human.notes = noteEntry("keep", references: [reference])
        context.insert(human)
        try context.save()
        let fileURL = try #require(HumanNoteAttachmentStore.url(for: reference, storage: fixture.storage))

        let result = MemberDeletionCommandService.deleteHuman(
            human,
            activeHumanID: human.id.uuidString,
            context: context,
            attachmentStorage: fixture.storage,
            saveChanges: injectedSaveFailure
        )

        #expect(!result.didPersist)
        #expect(result.attachmentCleanup == .notRequired)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(try context.fetch(FetchDescriptor<Human>()).count == 1)
    }

    @Test func appResetDeletesEntireHumanNotesRootAfterDatabaseCommit() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let human = Human(name: "Owner")
        let reference = try #require(saveAttachment(humanID: human.id, storage: fixture.storage))
        human.notes = noteEntry("reset", references: [reference])
        context.insert(human)
        try context.save()
        let fileURL = try #require(HumanNoteAttachmentStore.url(for: reference, storage: fixture.storage))
        let rootURL = fileURL.deletingLastPathComponent().deletingLastPathComponent()

        let cleanup = try AppResetService.reset(
            context: context,
            defaults: fixture.defaults,
            options: resetOptions,
            attachmentStorage: fixture.storage,
            deletePersistentData: { _ in
                context.delete(human)
                try context.save()
            }
        )

        #expect(cleanup == .completed(removedFileCount: 1))
        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: rootURL.path))
    }

    @Test func appResetStoreDeletionFailureLeavesDatabaseAndAttachmentRootUntouched() throws {
        let fixture = try makeFixture()
        defer { fixture.removeFiles() }
        let context = fixture.container.mainContext
        let human = Human(name: "Owner")
        let reference = try #require(saveAttachment(humanID: human.id, storage: fixture.storage))
        human.notes = noteEntry("keep", references: [reference])
        context.insert(human)
        try context.save()
        let fileURL = try #require(HumanNoteAttachmentStore.url(for: reference, storage: fixture.storage))
        var didThrow = false

        do {
            _ = try AppResetService.reset(
                context: context,
                defaults: fixture.defaults,
                options: resetOptions,
                attachmentStorage: fixture.storage,
                deletePersistentData: injectedStoreDeletionFailure
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        #expect(try context.fetch(FetchDescriptor<Human>()).count == 1)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private var resetOptions: AppResetService.Options {
        AppResetService.Options(
            cancelPendingNotifications: false,
            deleteCustomBackground: false,
            deleteHumanNoteAttachments: true,
            resetSharedRuntimeState: false,
            cleanUpAutomaticBackups: false
        )
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HumanNoteAttachmentLifecycleTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suiteName = "HumanNoteAttachmentLifecycleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let schema = Schema(ArkSchemaV85.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return Fixture(
            container: container,
            applicationSupportDirectory: root,
            storage: HumanNoteAttachmentStorage(applicationSupportDirectory: root),
            defaults: defaults,
            defaultsSuiteName: suiteName
        )
    }

    private func saveAttachment(
        fileName: String = "note.pdf",
        humanID: UUID,
        storage: HumanNoteAttachmentStorage
    ) -> HumanNoteAttachmentReference? {
        HumanNoteAttachmentStore.saveFile(
            data: Data([4, 5, 6]),
            originalFileName: fileName,
            isImage: false,
            humanId: humanID,
            storage: storage
        )
    }

    private func noteEntry(
        _ text: String,
        references: [HumanNoteAttachmentReference]
    ) -> String {
        "[2026-07-10] \(text)\(HumanNoteAttachmentStore.marker(for: references))"
    }

    private func fileCount(in directory: URL) -> Int {
        FileManager.default.enumerator(atPath: directory.path)?
            .compactMap { $0 as? String }
            .count(where: { path in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent(path).path,
                    isDirectory: &isDirectory
                ) && !isDirectory.boolValue
            })
             ?? 0
    }

    private func injectedSaveFailure(_: ModelContext) -> ModelContextSaveResult {
        .failed(InjectedSaveError())
    }

    private func injectedStoreDeletionFailure(_: ModelContainer) throws {
        throw InjectedStoreDeletionError()
    }
}

private struct Fixture {
    let container: ModelContainer
    let applicationSupportDirectory: URL
    let storage: HumanNoteAttachmentStorage
    let defaults: UserDefaults
    let defaultsSuiteName: String

    func removeFiles() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: applicationSupportDirectory)
    }
}

private struct InjectedSaveError: LocalizedError {
    var errorDescription: String? { "Injected save failure" }
}

private struct InjectedStoreDeletionError: LocalizedError {
    var errorDescription: String? { "Injected store deletion failure" }
}
