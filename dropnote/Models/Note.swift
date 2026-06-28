import Foundation

/// A point-in-time snapshot of a note's content, used for local version history.
struct NoteVersion: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var attributedTextRTF: Data?
    var timestamp: Date
}

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var text: String
    var isPinned: Bool = false
    var isLocked: Bool = false
    var attributedTextRTF: Data?
    var lastModified: Date?
    /// Optional self-destruct date. When passed, the note is removed automatically.
    var expiryDate: Date?
    /// Local version history, most recent last. Capped at `maxVersions`.
    var versions: [NoteVersion] = []

    static let maxVersions = 10

    mutating func updateModifiedDate() {
        lastModified = Date()
    }

    /// Stores the current content as a version, throttled so we don't snapshot on
    /// every keystroke. Keeps at most `maxVersions` entries.
    mutating func captureVersionIfNeeded(minInterval: TimeInterval = 60) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let last = versions.last {
            if last.text == text { return }
            if Date().timeIntervalSince(last.timestamp) < minInterval { return }
        }

        versions.append(NoteVersion(text: text, attributedTextRTF: attributedTextRTF, timestamp: Date()))
        if versions.count > Note.maxVersions {
            versions.removeFirst(versions.count - Note.maxVersions)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, text, isPinned, isLocked, attributedTextRTF, lastModified, expiryDate, versions
    }

    init(id: UUID = UUID(),
         title: String,
         text: String,
         isPinned: Bool = false,
         isLocked: Bool = false,
         attributedTextRTF: Data? = nil,
         lastModified: Date? = nil,
         expiryDate: Date? = nil,
         versions: [NoteVersion] = []) {
        self.id = id
        self.title = title
        self.text = text
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.attributedTextRTF = attributedTextRTF
        self.lastModified = lastModified
        self.expiryDate = expiryDate
        self.versions = versions
    }

    // Backward-compatible decoding: new fields default when missing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decodeIfPresent(UUID.self,           forKey: .id) ?? UUID()
        title             = try c.decodeIfPresent(String.self,         forKey: .title) ?? ""
        text              = try c.decodeIfPresent(String.self,         forKey: .text) ?? ""
        isPinned          = try c.decodeIfPresent(Bool.self,           forKey: .isPinned) ?? false
        isLocked          = try c.decodeIfPresent(Bool.self,           forKey: .isLocked) ?? false
        attributedTextRTF = try c.decodeIfPresent(Data.self,           forKey: .attributedTextRTF)
        lastModified      = try c.decodeIfPresent(Date.self,           forKey: .lastModified)
        expiryDate        = try c.decodeIfPresent(Date.self,           forKey: .expiryDate)
        versions          = try c.decodeIfPresent([NoteVersion].self,  forKey: .versions) ?? []
    }
}
