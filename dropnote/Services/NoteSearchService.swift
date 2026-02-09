import Foundation

final class NoteSearchService: ObservableObject {
    static let shared = NoteSearchService()
    
    @Published private(set) var indexedNotes: [IndexedNote] = []
    private let notesPath: URL
    
    private init() {
        self.notesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    }
    
    // MARK: - Public Methods
    
    func indexNotes() {
        guard FileManager.default.fileExists(atPath: notesPath.path),
              let data = try? Data(contentsOf: notesPath),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            indexedNotes = []
            return
        }
        
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
    }
    
    func search(query: String, limit: Int = 10) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            return getRecentNotes(limit: limit)
        }
        
        return performSearch(query: trimmedQuery, limit: limit)
    }
    
    // MARK: - Private Methods
    
    private func getRecentNotes(limit: Int) -> [SearchResult] {
        indexedNotes
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
    
    private func performSearch(query: String, limit: Int) -> [SearchResult] {
        let queryLowercased = query.lowercased()
        var scoredResults: [(note: IndexedNote, score: Double, matchedInTitle: Bool)] = []
        
        for note in indexedNotes {
            let score = calculateSearchScore(note: note, query: queryLowercased)
            if score > 0 {
                let matchedInTitle = note.titleLowercased.contains(queryLowercased)
                scoredResults.append((note, score, matchedInTitle))
            }
        }
        
        scoredResults.sort { $0.score > $1.score }
        
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
    
    private func calculateSearchScore(note: IndexedNote, query: String) -> Double {
        var score: Double = 0
        
        // Score title matches
        if note.titleLowercased.contains(query) {
            if note.titleLowercased == query {
                score += 1000
            } else if note.titleLowercased.hasPrefix(query) {
                score += 500
            } else if note.titleLowercased.contains(" " + query) {
                score += 400
            } else {
                score += 300
            }
        }
        
        // Score text matches
        if note.textLowercased.contains(query) {
            if note.textLowercased.hasPrefix(query) {
                score += 200
            } else {
                let occurrences = note.textLowercased.components(separatedBy: query).count - 1
                score += Double(occurrences) * 50
            }
        }
        
        guard score > 0 else {
            return 0
        }
        
        // Boost by recency
        let daysSinceModified = Date().timeIntervalSince(note.lastModified) / 86400
        let recencyScore = max(0, 100 - daysSinceModified)
        score += recencyScore * 0.5
        
        return score
    }
    
    private func getPreview(from text: String, query: String, maxLength: Int) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else {
            return ""
        }
        
        // If query is provided, try to find context around it
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
        
        // Otherwise return the beginning
        if cleanText.count > maxLength {
            let endIndex = cleanText.index(cleanText.startIndex, offsetBy: maxLength)
            return String(cleanText[..<endIndex]) + "..."
        }
        
        return cleanText
    }
    
    private func findHighlightRanges(in text: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else {
            return []
        }
        
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
