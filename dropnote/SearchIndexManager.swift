import Foundation

struct IndexedNote {
    let id: UUID
    let title: String
    let text: String
    let lastModified: Date
    let titleLowercased: String
    let textLowercased: String
}

struct SearchResult: Identifiable {
    let id: UUID
    let note: IndexedNote
    let score: Double
    let matchedInTitle: Bool
    let preview: String
    let highlightRanges: [Range<String.Index>]
}

class SearchIndexManager: ObservableObject {
    static let shared = SearchIndexManager()
    
    @Published var indexedNotes: [IndexedNote] = []
    private var notesPath: URL
    
    private init() {
        self.notesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    }
    
    func indexNotes() {
        print("SearchIndexManager: Indexing notes from \(notesPath.path)")
        
        guard FileManager.default.fileExists(atPath: notesPath.path) else {
            print("SearchIndexManager: Notes file does not exist")
            indexedNotes = []
            return
        }
        
        guard let data = try? Data(contentsOf: notesPath),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            print("SearchIndexManager: Failed to load or decode notes")
            indexedNotes = []
            return
        }
        
        print("SearchIndexManager: Loaded \(notes.count) notes")
        
        indexedNotes = notes.map { note in
            IndexedNote(
                id: note.id,
                title: note.title,
                text: note.text,
                lastModified: note.lastModified ?? Date(),
                titleLowercased: note.title.lowercased(),
                textLowercased: note.text.lowercased()
            )
        }
        
        print("SearchIndexManager: Indexed \(indexedNotes.count) notes")
    }
    
    func search(query: String, limit: Int = 10) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty query: return recent notes
        if trimmedQuery.isEmpty {
            return indexedNotes
                .sorted { $0.lastModified > $1.lastModified }
                .prefix(limit)
                .map { note in
                    SearchResult(
                        id: note.id,
                        note: note,
                        score: 0,
                        matchedInTitle: false,
                        preview: getPreview(from: note.text, query: "", maxLength: 80),
                        highlightRanges: []
                    )
                }
        }
        
        let queryLowercased = trimmedQuery.lowercased()
        
        var scoredResults: [(note: IndexedNote, score: Double, matchedInTitle: Bool)] = []
        
        for note in indexedNotes {
            var score: Double = 0
            var matchedInTitle = false
            
            // First check if phrase exists in title
            if note.titleLowercased.contains(queryLowercased) {
                matchedInTitle = true
                // Exact phrase in title: highest score
                if note.titleLowercased == queryLowercased {
                    score += 1000
                } else if note.titleLowercased.hasPrefix(queryLowercased) {
                    score += 500
                } else if note.titleLowercased.contains(" " + queryLowercased) {
                    score += 400
                } else {
                    score += 300
                }
            }
            
            // Check phrase in text
            if note.textLowercased.contains(queryLowercased) {
                // Check if match is at the beginning
                if note.textLowercased.hasPrefix(queryLowercased) {
                    score += 200
                } else {
                    // Count occurrences
                    let occurrences = note.textLowercased.components(separatedBy: queryLowercased).count - 1
                    score += Double(occurrences) * 50
                }
            }
            
            // Only include if phrase was found
            if score > 0 {
                // Boost by recency (normalize to 0-100 range)
                let daysSinceModified = Date().timeIntervalSince(note.lastModified) / 86400
                let recencyScore = max(0, 100 - daysSinceModified)
                score += recencyScore * 0.5
                
                scoredResults.append((note, score, matchedInTitle))
            }
        }
        
        // Sort by score
        scoredResults.sort { $0.score > $1.score }
        
        // Create search results with previews
        return scoredResults.prefix(limit).map { result in
            let preview = getPreview(from: result.note.text, query: queryLowercased, maxLength: 100)
            let highlightRanges = findHighlightRanges(in: preview, query: queryLowercased)
            
            return SearchResult(
                id: result.note.id,
                note: result.note,
                score: result.score,
                matchedInTitle: result.matchedInTitle,
                preview: preview,
                highlightRanges: highlightRanges
            )
        }
    }
    
    private func getPreview(from text: String, query: String, maxLength: Int) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.isEmpty {
            return ""
        }
        
        // If query is not empty, try to find it and show context
        if !query.isEmpty, let range = cleanText.lowercased().range(of: query) {
            let start = cleanText.distance(from: cleanText.startIndex, to: range.lowerBound)
            let contextStart = max(0, start - 20)
            let contextEnd = min(cleanText.count, start + query.count + maxLength - 20)
            
            let startIndex = cleanText.index(cleanText.startIndex, offsetBy: contextStart)
            let endIndex = cleanText.index(cleanText.startIndex, offsetBy: min(contextEnd, cleanText.count))
            
            var preview = String(cleanText[startIndex..<endIndex])
            if contextStart > 0 {
                preview = "..." + preview
            }
            if contextEnd < cleanText.count {
                preview = preview + "..."
            }
            return preview
        }
        
        // Otherwise, just return the beginning
        if cleanText.count > maxLength {
            let endIndex = cleanText.index(cleanText.startIndex, offsetBy: maxLength)
            return String(cleanText[..<endIndex]) + "..."
        }
        
        return cleanText
    }
    
    private func findHighlightRanges(in text: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }
        
        var ranges: [Range<String.Index>] = []
        let lowercasedText = text.lowercased()
        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
        
        while let range = lowercasedText.range(of: query, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<lowercasedText.endIndex
        }
        
        return ranges
    }
}
