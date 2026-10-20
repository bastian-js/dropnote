import Foundation
import CryptoKit
import Security

/// Encrypts the body of locked notes before it is written to `notes.json`.
///
/// Locking used to be UI-only: the text sat in plaintext on disk. Now a locked
/// note's text, rich text and version history are sealed with AES-256-GCM under
/// a random key that lives in the Keychain, so the file alone reveals nothing.
/// Title and metadata (pin, expiry, dates) stay readable — the tab bar shows them
/// while the note is locked.
///
/// The ciphertext is bound to the note's id, so a sealed body can't be swapped
/// onto another note.
final class NoteCrypto {
    static let shared = NoteCrypto()

    enum CryptoError: Error {
        case keyUnavailable(OSStatus)
        case malformedKey
        case sealFailed
    }

    private let service = "xyz.bbastian.dropnote"
    private let account = "notes_encryption_key_v1"

    /// Saves run on a background queue, loads on another — the lock keeps two
    /// threads from creating two different keys.
    private let lock = NSLock()
    private var cachedKey: SymmetricKey?

    private init() {}

    /// What gets encrypted. Everything that could reveal the note's content.
    private struct Body: Codable {
        var text: String
        var attributedTextRTF: Data?
        var versions: [NoteVersion]
    }

    // MARK: - Public Methods

    /// A copy of `note` with its body replaced by ciphertext, ready for disk.
    /// A note that was never decrypted is returned unchanged.
    func sealed(_ note: Note) throws -> Note {
        guard !note.isSealed else { return note }

        let key = try key(createIfMissing: true)
        let body = Body(text: note.text, attributedTextRTF: note.attributedTextRTF, versions: note.versions)
        let plaintext = try JSONEncoder().encode(body)
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: Self.associatedData(for: note.id))
        guard let combined = box.combined else { throw CryptoError.sealFailed }

        var copy = note
        copy.text = ""
        copy.attributedTextRTF = nil
        copy.versions = []
        copy.sealedContent = combined
        return copy
    }

    /// A copy of `note` with its body decrypted back in.
    func opened(_ note: Note) throws -> Note {
        guard let sealed = note.sealedContent else { return note }

        // Never create a key here: a missing key can't open existing ciphertext.
        let key = try key(createIfMissing: false)
        let box = try AES.GCM.SealedBox(combined: sealed)
        let plaintext = try AES.GCM.open(box, using: key, authenticating: Self.associatedData(for: note.id))
        let body = try JSONDecoder().decode(Body.self, from: plaintext)

        var copy = note
        copy.text = body.text
        copy.attributedTextRTF = body.attributedTextRTF
        copy.versions = body.versions
        copy.sealedContent = nil
        return copy
    }

    // MARK: - Private Methods

    private static func associatedData(for id: UUID) -> Data {
        Data(id.uuidString.utf8)
    }

    private func key(createIfMissing: Bool) throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }

        if let cachedKey { return cachedKey }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, data.count == 32 else { throw CryptoError.malformedKey }
            let key = SymmetricKey(data: data)
            cachedKey = key
            return key

        // Only a key that provably doesn't exist may be replaced. Any other error
        // (keychain locked, access denied, …) must not mint a new key, or every
        // note sealed with the old one would become unreadable.
        case errSecItemNotFound where createIfMissing:
            let key = SymmetricKey(size: .bits256)
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecValueData as String: key.withUnsafeBytes { Data($0) }
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw CryptoError.keyUnavailable(addStatus) }
            cachedKey = key
            return key

        default:
            throw CryptoError.keyUnavailable(status)
        }
    }
}
