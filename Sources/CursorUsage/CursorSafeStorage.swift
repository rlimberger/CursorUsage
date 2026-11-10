import Foundation
import Security
import CommonCrypto

/// Decrypts Cursor 3.27+ `cursor-safe-storage:v1:` auth tokens.
/// Uses the existing Keychain item written by Cursor.app (Electron safeStorage / Chromium OSCrypt v10).
enum CursorSafeStorage {
    private static let envelopePrefix = "cursor-safe-storage:v1:"
    private static let v10Magic = Data("v10".utf8)
    private static let keychainService = "Cursor Safe Storage"

    /// In-process cache of the derived AES key so background refreshes don't re-hit Keychain.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedAESKey: Data?

    static func resolveAccessToken(_ raw: String) throws -> String {
        guard raw.hasPrefix(envelopePrefix) else {
            return raw
        }
        return try decrypt(raw)
    }

    private static func decrypt(_ raw: String) throws -> String {
        let b64 = String(raw.dropFirst(envelopePrefix.count))
        guard let envelope = Data(base64Encoded: b64),
              envelope.count > v10Magic.count,
              envelope.prefix(v10Magic.count) == v10Magic
        else {
            throw UsageError.tokenDecryptFailed
        }

        let ciphertext = envelope.dropFirst(v10Magic.count)
        let key = try aesKey()
        if let plain = aes128CBCDecrypt(ciphertext: Data(ciphertext), key: key) {
            return plain
        }
        // Stale cached key (e.g. Keychain item rotated) — clear and retry once.
        let retryKey = try aesKey(forceReload: true)
        guard let retryPlain = aes128CBCDecrypt(ciphertext: Data(ciphertext), key: retryKey) else {
            throw UsageError.tokenDecryptFailed
        }
        return retryPlain
    }

    private static func aesKey(forceReload: Bool = false) throws -> Data {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if !forceReload, let cachedAESKey {
            return cachedAESKey
        }
        let password = try loadKeychainPassword()
        let derived = try pbkdf2SHA1(
            password: password,
            salt: Data("saltysalt".utf8),
            iterations: 1003,
            keyLength: 16
        )
        cachedAESKey = derived
        return derived
    }

    /// Query by service only — account is `Cursor Key` on most installs, sometimes `Cursor`.
    private static func loadKeychainPassword() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, !data.isEmpty else {
            if status == errSecUserCanceled || status == errSecAuthFailed {
                throw UsageError.keychainAccessDenied
            }
            throw UsageError.keychainItemMissing
        }
        return data
    }

    private static func pbkdf2SHA1(
        password: Data,
        salt: Data,
        iterations: UInt32,
        keyLength: Int
    ) throws -> Data {
        var derived = Data(count: keyLength)
        let result = derived.withUnsafeMutableBytes { derivedBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        iterations,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        guard result == kCCSuccess else {
            throw UsageError.tokenDecryptFailed
        }
        return derived
    }

    private static func aes128CBCDecrypt(ciphertext: Data, key: Data) -> String? {
        // Chromium OSCrypt macOS: IV is 16 ASCII spaces.
        let iv = Data(repeating: UInt8(ascii: " "), count: kCCBlockSizeAES128)
        var outLength = 0
        var out = Data(count: ciphertext.count + kCCBlockSizeAES128)

        let status = out.withUnsafeMutableBytes { outBytes in
            ciphertext.withUnsafeBytes { cipherBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            cipherBytes.baseAddress,
                            ciphertext.count,
                            outBytes.baseAddress,
                            outBytes.count,
                            &outLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        out.removeSubrange(outLength..<out.count)
        guard let text = String(data: out, encoding: .utf8), text.split(separator: ".").count == 3 else {
            return nil
        }
        return text
    }
}
