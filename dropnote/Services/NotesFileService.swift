import Foundation

final class NotesFileService {
    static let shared = NotesFileService()

    private let notesPath: URL

    private init() {
        self.notesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    }

    // MARK: - Public Methods

    /// Locked notes come back sealed (see `Note.sealedContent`); they are only
    /// decrypted after the user unlocks them.
    func loadNotes() -> [Note]? {
        guard FileManager.default.fileExists(atPath: notesPath.path),
              let data = try? Data(contentsOf: notesPath),
              var decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            return nil
        }

        let addedDates = ensureAllNotesHaveModifiedDate(&decoded)
        // Notes locked before encryption existed are still plaintext on disk.
        // Seal them right away instead of waiting for the next edit.
        let hasPlaintextLocked = decoded.contains { $0.isLocked && !$0.isSealed }
        if addedDates || hasPlaintextLocked {
            saveNotes(decoded)
        }
        return decoded
    }

    func saveNotes(_ notes: [Note]) {
        let onDisk: [Note]
        do {
            onDisk = try notes.map { note in
                note.isLocked || note.isSealed ? try NoteCrypto.shared.sealed(note) : note
            }
        } catch {
            // Never fall back to writing a locked note in plaintext. The previous
            // file stays as it is; the next save retries.
            print("DropNote: not saving notes, encrypting a locked note failed: \(error)")
            return
        }

        guard let data = try? JSONEncoder().encode(onDisk) else { return }
        write(data)
    }

    // MARK: - Private Methods

    /// Atomic, so a crash mid-write can't leave a truncated `notes.json`, and
    /// readable by the owner only.
    private func write(_ data: Data) {
        let fm = FileManager.default
        let folderURL = notesPath.deletingLastPathComponent()
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        // The folder also covers the temporary file `.atomic` writes first.
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folderURL.path)

        do {
            try data.write(to: notesPath, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: notesPath.path)
        } catch {
            print("DropNote: writing notes.json failed: \(error)")
        }
    }

    /// Returns whether any note was missing its date.
    private func ensureAllNotesHaveModifiedDate(_ notes: inout [Note]) -> Bool {
        var changed = false
        for i in 0..<notes.count {
            if notes[i].lastModified == nil {
                notes[i].lastModified = Date()
                changed = true
            }
        }
        return changed
    }
}
