import Foundation

final class NotesFileService {
    static let shared = NotesFileService()
    
    private let notesPath: URL
    
    private init() {
        self.notesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    }
    
    // MARK: - Public Methods
    
    func loadNotes() -> [Note]? {
        guard FileManager.default.fileExists(atPath: notesPath.path),
              let data = try? Data(contentsOf: notesPath),
              var decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            return nil
        }
        
        ensureAllNotesHaveModifiedDate(&decoded)
        return decoded
    }
    
    func saveNotes(_ notes: [Note]) {
        let folderURL = notesPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        if let data = try? JSONEncoder().encode(notes) {
            try? data.write(to: notesPath)
        }
    }
    
    // MARK: - Private Methods
    
    private func ensureAllNotesHaveModifiedDate(_ notes: inout [Note]) {
        var needsSave = false
        for i in 0..<notes.count {
            if notes[i].lastModified == nil {
                notes[i].lastModified = Date()
                needsSave = true
            }
        }
        
        if needsSave {
            if let updatedData = try? JSONEncoder().encode(notes) {
                try? updatedData.write(to: notesPath)
            }
        }
    }
}
