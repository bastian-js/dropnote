import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var tags: [String] = []
    var createdAt: Date = Date()
}
