import Foundation

final class TodoFileService: ObservableObject {
    static let shared = TodoFileService()

    @Published var todos: [TodoItem] = []

    private let todosPath: URL

    private init() {
        self.todosPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/todos.json")
        todos = loadFromDisk()
    }

    func save() {
        let snapshot = todos
        DispatchQueue.global(qos: .utility).async {
            let folderURL = self.todosPath.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: self.todosPath, options: .atomic)
            }
        }
    }

    private func loadFromDisk() -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: todosPath.path),
              let data = try? Data(contentsOf: todosPath),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }
}
