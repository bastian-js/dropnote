import Foundation

struct Note: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var isPinned: Bool = false
    var isLocked: Bool = false
    var attributedTextRTF: Data?
    var lastModified: Date?
    
    mutating func updateModifiedDate() {
        lastModified = Date()
    }
}
