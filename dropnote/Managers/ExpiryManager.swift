import Foundation
import UserNotifications

/// Watches notes for their self-destruct (`expiryDate`) and removes them once
/// they pass, firing a local notification. Everything stays on disk — no cloud.
final class ExpiryManager {
    static let shared = ExpiryManager()

    static let notesReloadRequested = Notification.Name("NotesReloadRequested")

    private var timer: Timer?
    private let notesService = NotesFileService.shared

    private init() {}

    func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        checkNow()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.checkNow()
        }
    }

    /// Removes any notes whose expiry has passed and notifies the user.
    func checkNow() {
        guard let notes = notesService.loadNotes() else { return }
        let now = Date()
        let expired = notes.filter { note in
            guard let expiry = note.expiryDate else { return false }
            return expiry <= now
        }
        guard !expired.isEmpty else { return }

        expired.forEach(notify)

        let remaining = notes.filter { note in
            guard let expiry = note.expiryDate else { return true }
            return expiry > now
        }
        notesService.saveNotes(remaining)

        DispatchQueue.main.async {
            NoteSearchService.shared.indexNotes(with: remaining)
            NotificationCenter.default.post(name: Self.notesReloadRequested, object: nil)
        }
    }

    private func notify(_ note: Note) {
        let content = UNMutableNotificationContent()
        content.title = "Note expired"
        let name = note.title.isEmpty ? "Your note" : note.title
        content.body = "“\(name)” reached its expiry and was removed."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "expiry-\(note.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
