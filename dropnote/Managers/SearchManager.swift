import Foundation

final class SearchManager: ObservableObject {
    static let shared = SearchManager()
    
    @Published var noteIDToOpen: UUID? = nil
    
    private init() {}
    
    func openNote(_ noteID: UUID) {
        self.noteIDToOpen = noteID
    }
}
