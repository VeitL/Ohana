//
//  DataBackupEncryption.swift
//  Ohana
//
//  Password-based encryption envelope for user-triggered backup exports.
//

import CryptoKit
import Foundation
import Security

nonisolated enum DataBackupEncryption {
    static let envelopeFormat = "com.guanchen.li.ohana.backup.encrypted.v1"

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        let password = sanitizedPassword(password)
        guard !password.isEmpty else { throw BackupError.missingPassword }

        let salt = try randomBytes(count: 32)
        let key = symmetricKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        let envelope = EncryptedBackupEnvelope(
            format: envelopeFormat,
            cipher: "AES.GCM",
            keyDerivation: "HKDF.SHA256.salted.v1",
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
            let key = symmetricKey(password: password, salt: salt)
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

    private static func symmetricKey(password: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(password.utf8)),
            salt: salt,
            info: Data("OhanaBackupEncryption.v1".utf8),
            outputByteCount: 32
        )
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
