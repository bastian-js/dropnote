import Foundation
import Combine
import UserNotifications

/// Watches notes for their self-destruct (`expiryDate`) and removes them once
/// they pass, firing a local notification. Everything stays on disk — no cloud.
final class ExpiryManager {
    static let shared = ExpiryManager()

    static let notesReloadRequested = Notification.Name("NotesReloadRequested")

    private var timer: Timer?
    private var loadObserver: AnyCancellable?

    private init() {}

    func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // The first sweep has to wait for the store's initial load; after that the
        // timer runs on the main run loop, so every sweep touches the store on the
        // main thread like every other mutation.
        loadObserver = NotesStore.shared.$isLoaded
            .filter { $0 }
            .first()
            .sink { [weak self] _ in self?.checkNow() }
        NotesStore.shared.loadIfNeeded()

        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.checkNow()
        }
    }

    /// Removes any notes whose expiry has passed and notifies the user.
    ///
    /// Works on the shared store rather than on `notes.json` directly — writing the
    /// file behind the UI's back used to drop whatever was being typed at the time.
    func checkNow() {
        let store = NotesStore.shared
        guard store.isLoaded else { return }

        let now = Date()
        let expired = store.notes.filter { note in
            guard let expiry = note.expiryDate else { return false }
            return expiry <= now
        }
        guard !expired.isEmpty else { return }

        expired.forEach(notify)

        let expiredIDs = Set(expired.map(\.id))
        store.replaceAll(with: store.notes.filter { !expiredIDs.contains($0.id) })

        NotificationCenter.default.post(name: Self.notesReloadRequested, object: nil)
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
