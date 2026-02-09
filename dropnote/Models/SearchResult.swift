import Foundation

struct SearchResult: Identifiable {
    let id: UUID
    let note: IndexedNote
    let score: Double
    let matchedInTitle: Bool
    let preview: String
    let highlightRanges: [Range<String.Index>]
}
