import Foundation

struct IndexedNote {
    let id: UUID
    let title: String
    let text: String
    let lastModified: Date
    let titleLowercased: String
    let textLowercased: String
}
