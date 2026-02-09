import Foundation

class SearchManager: ObservableObject {
    static let shared = SearchManager()
    
    @Published var noteIDToOpen: UUID? = nil
    
    private init() {}
    
    func openNote(_ noteID: UUID) {
        print("SearchManager: Requesting to open note with ID: \(noteID)")
        self.noteIDToOpen = noteID
    }
}
