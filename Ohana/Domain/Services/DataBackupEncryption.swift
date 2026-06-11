//
//  DataBackupEncryption.swift
//  Ohana
//
//  Password-based encryption envelope for user-triggered backup exports.
//

import CommonCrypto
import CryptoKit
import Foundation
import Security

nonisolated enum DataBackupEncryption {
    static let envelopeFormat = "com.guanchen.li.ohana.backup.encrypted.v1"
    static let minimumPasswordLength = 8

    private static let legacyHKDFDerivation = "HKDF.SHA256.salted.v1"
    private static let pbkdf2Iterations = 210_000
    private static let pbkdf2Derivation = "PBKDF2.SHA256.210000.v2"

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        let password = sanitizedPassword(password)
        guard !password.isEmpty else { throw BackupError.missingPassword }
        guard password.count >= minimumPasswordLength else {
            throw BackupError.weakPassword(minimum: minimumPasswordLength)
        }

        let salt = try randomBytes(count: 32)
        let key = try symmetricKey(password: password, salt: salt, keyDerivation: pbkdf2Derivation)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        let envelope = EncryptedBackupEnvelope(
            format: envelopeFormat,
            cipher: "AES.GCM",
            keyDerivation: pbkdf2Derivation,
            saltBase64: salt.base64EncodedString(),
            nonceBase64: Data(sealed.nonce).base64EncodedString(),
            ciphertextBase64: sealed.ciphertext.base64EncodedString(),
            tagBase64: sealed.tag.base64EncodedString()
        )
        return try JSONEncoder().encode(envelope)
    }

    static func decryptIfNeeded(_ data: Data, password: String?) throws -> Data {
        guard let envelope = try? JSONDecoder().decode(EncryptedBackupEnvelope.self, from: data),
              envelope.format == envelopeFormat else {
            return data
        }

        guard let password = password.map(sanitizedPassword), !password.isEmpty else {
            throw BackupError.missingPassword
        }

        do {
            guard let salt = Data(base64Encoded: envelope.saltBase64),
                  let nonceData = Data(base64Encoded: envelope.nonceBase64),
                  let ciphertext = Data(base64Encoded: envelope.ciphertextBase64),
                  let tag = Data(base64Encoded: envelope.tagBase64) else {
                throw BackupError.invalidEncryptedBackup
            }
            let key = try symmetricKey(password: password, salt: salt, keyDerivation: envelope.keyDerivation)
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(box, using: key)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidBackupPassword
        }
    }

    static func isEncryptedBackup(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(EncryptedBackupEnvelope.self, from: data))?.format == envelopeFormat
    }

    private static func symmetricKey(password: String, salt: Data, keyDerivation: String) throws -> SymmetricKey {
        switch keyDerivation {
        case pbkdf2Derivation:
            return try pbkdf2SymmetricKey(password: password, salt: salt)
        case legacyHKDFDerivation:
            return hkdfSymmetricKey(password: password, salt: salt)
        default:
            throw BackupError.invalidEncryptedBackup
        }
    }

    private static func hkdfSymmetricKey(password: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(password.utf8)),
            salt: salt,
            info: Data("OhanaBackupEncryption.v1".utf8),
            outputByteCount: 32
        )
    }

    private static func pbkdf2SymmetricKey(password: String, salt: Data) throws -> SymmetricKey {
        var derivedKey = [UInt8](repeating: 0, count: 32)
        let passwordData = Data(password.utf8)
        let status = passwordData.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.bindMemory(to: CChar.self).baseAddress,
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(pbkdf2Iterations),
                    &derivedKey,
                    derivedKey.count
                )
            }
        }
        guard status == kCCSuccess else { throw BackupError.encryptionUnavailable }
        return SymmetricKey(data: Data(derivedKey))
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw BackupError.encryptionUnavailable }
        return Data(bytes)
    }

    private static func sanitizedPassword(_ password: String) -> String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct EncryptedBackupEnvelope: Codable {
    var format: String
    var cipher: String
    var keyDerivation: String
    var saltBase64: String
    var nonceBase64: String
    var ciphertextBase64: String
    var tagBase64: String
}
