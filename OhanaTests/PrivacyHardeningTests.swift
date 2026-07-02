import CryptoKit
import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Ohana

struct PrivacyHardeningTests {
    @Test func imageAttachmentSanitizerStripsGPSMetadataAndPreservesPDFBytes() throws {
        let jpegWithGPS = try makeJPEGWithGPSMetadata()
        #expect(hasGPSMetadata(jpegWithGPS))

        let sanitized = AttachmentPrivacySanitizer.sanitizedData(
            jpegWithGPS,
            filename: "clinic-receipt.jpg",
            isImage: true
        )
        #expect(!hasGPSMetadata(sanitized))

        let pdf = Data("%PDF-1.7\n%%EOF".utf8)
        #expect(AttachmentPrivacySanitizer.sanitizedData(pdf, filename: "form.pdf", isImage: false) == pdf)
    }

    @Test func imageAttachmentSanitizerPreservesUndecodableImageBytes() {
        let malformedImage = Data("not actually an image".utf8)

        #expect(AttachmentPrivacySanitizer.sanitizedData(
            malformedImage,
            filename: "receipt.jpg",
            isImage: true
        ) == malformedImage)
    }

    @Test func receiptDocumentBuilderSanitizesImageAttachmentsBeforePersistence() throws {
        let jpegWithGPS = try makeJPEGWithGPSMetadata()
        let pdf = Data("%PDF-1.7\n%%EOF".utf8)

        let draft = ExpenseReceiptDocumentBuilder.makeDraft(
            title: "Vet receipt",
            category: .medical,
            cost: 88,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            visibleNote: "复诊",
            linkedExpenseLogId: "expense-1",
            attachments: [
                ExpenseReceiptAttachmentDraft(data: jpegWithGPS, filename: "receipt.jpg", isImage: true),
                ExpenseReceiptAttachmentDraft(data: pdf, filename: "invoice.pdf", isImage: false)
            ]
        )

        let imageAttachment = try #require(draft.attachments.first)
        let pdfAttachment = try #require(draft.attachments.dropFirst().first)
        let legacyAttachmentData = try #require(draft.attachmentData)
        #expect(!hasGPSMetadata(legacyAttachmentData))
        #expect(!hasGPSMetadata(imageAttachment.data))
        #expect(pdfAttachment.data == pdf)
    }

    @MainActor
    @Test func documentCommandServiceSanitizesImageAttachmentsBeforeSave() throws {
        let container = try makePrivacyHardeningContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let jpegWithGPS = try makeJPEGWithGPSMetadata()
        context.insert(pet)
        try context.save()

        PetDocumentCommandService.createDocument(
            input: PetDocumentCreateCommandInput(
                title: "Vaccine proof",
                category: .vaccine,
                issuingAuthority: "",
                notes: "",
                issueDate: nil,
                expiryDate: nil,
                cost: 0,
                payerId: nil,
                documentNumber: "",
                attachments: [
                    PetDocumentAttachmentCommandInput(
                        data: jpegWithGPS,
                        filename: "vaccine.jpg",
                        isImage: true
                    )
                ]
            ),
            pet: pet,
            context: context
        )

        let document = try #require(try context.fetch(FetchDescriptor<PetDocument>()).first)
        let attachment = try #require(document.attachments.first)
        let legacyAttachmentData = try #require(document.attachmentData)
        #expect(!hasGPSMetadata(legacyAttachmentData))
        #expect(!hasGPSMetadata(attachment.data))
    }

    @MainActor
    @Test func petPhotoAlbumSanitizesImageBytesBeforeSave() throws {
        let container = try makePrivacyHardeningContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let jpegWithGPS = try makeJPEGWithGPSMetadata()
        context.insert(pet)
        try context.save()

        PetPhotoAlbumCommandService.createPhotos(
            data: [jpegWithGPS],
            pet: pet,
            context: context,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let photo = try #require(try context.fetch(FetchDescriptor<PetPhotoLog>()).first)
        #expect(!hasGPSMetadata(photo.imageData))
    }

    @MainActor
    @Test func quickMomentSanitizesPhotoBytesBeforeSave() throws {
        let container = try makePrivacyHardeningContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let jpegWithGPS = try makeJPEGWithGPSMetadata()
        context.insert(pet)
        try context.save()

        MomentCommandService.recordMoment(
            pet: pet,
            note: "sunny window",
            photoData: [jpegWithGPS],
            locationLatitude: 52.52,
            locationLongitude: 13.405,
            locationPlacename: "Home",
            context: context,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let photo = try #require(try context.fetch(FetchDescriptor<PetPhotoLog>()).first)
        #expect(!hasGPSMetadata(photo.imageData))
        #expect(photo.locationPlacename == "Home")
    }

    @Test func encryptedBackupRejectsWeakPasswordsAndUsesPBKDF2ForNewExports() throws {
        do {
            _ = try DataBackupEncryption.encrypt(Data("private".utf8), password: "1234567")
            Issue.record("Expected short backup password to be rejected")
        } catch let BackupError.weakPassword(minimum) {
            #expect(minimum == DataBackupEncryption.minimumPasswordLength)
        } catch {
            Issue.record("Expected weakPassword, got \(error)")
        }

        let encrypted = try DataBackupEncryption.encrypt(Data("private".utf8), password: "correct horse battery")
        let envelope = try JSONDecoder().decode(EncryptedBackupEnvelope.self, from: encrypted)
        #expect(envelope.keyDerivation == "PBKDF2.SHA256.210000.v2")
        #expect(try DataBackupEncryption.decryptIfNeeded(encrypted, password: "correct horse battery") == Data("private".utf8))
    }

    @Test func encryptedBackupCanStillDecryptLegacyHKDFEnvelope() throws {
        let plaintext = Data("legacy private backup".utf8)
        let password = "old pass"
        let legacyEnvelope = try makeLegacyHKDFEnvelope(plaintext: plaintext, password: password)

        #expect(DataBackupEncryption.isEncryptedBackup(legacyEnvelope))
        #expect(try DataBackupEncryption.decryptIfNeeded(legacyEnvelope, password: password) == plaintext)
    }

    @MainActor
    private func makePrivacyHardeningContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeJPEGWithGPSMetadata() throws -> Data {
        var pixel: [UInt8] = [255, 0, 0, 255]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 52.52,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 13.405,
                kCGImagePropertyGPSLongitudeRef: "E"
            ]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func hasGPSMetadata(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return false
        }
        return properties[kCGImagePropertyGPSDictionary] != nil
    }

    private func makeLegacyHKDFEnvelope(plaintext: Data, password: String) throws -> Data {
        let salt = Data((0 ..< 32).map(UInt8.init))
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(password.utf8)),
            salt: salt,
            info: Data("OhanaBackupEncryption.v1".utf8),
            outputByteCount: 32
        )
        let sealed = try AES.GCM.seal(plaintext, using: key)
        let envelope = EncryptedBackupEnvelope(
            format: DataBackupEncryption.envelopeFormat,
            cipher: "AES.GCM",
            keyDerivation: "HKDF.SHA256.salted.v1",
            saltBase64: salt.base64EncodedString(),
            nonceBase64: Data(sealed.nonce).base64EncodedString(),
            ciphertextBase64: sealed.ciphertext.base64EncodedString(),
            tagBase64: sealed.tag.base64EncodedString()
        )
        return try JSONEncoder().encode(envelope)
    }
}
