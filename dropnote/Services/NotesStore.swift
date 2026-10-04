import SwiftUI
import Combine

/// The single source of truth for notes.
///
/// Every surface that shows or edits a note — the popover, the full window, a
/// floating note, the expiry manager, the search index — reads and writes *this*
/// object, so they all stay in sync without reloading from disk.
///
/// **Everything is addressed by `Note.id`, never by array index.** A view that
/// holds an index goes stale the moment a note is added, deleted, pinned or
/// reordered; with SwiftUI that stale index ends up inside a `Binding` and traps
/// with "Index out of range" on the next read. ID lookups simply return `nil`
/// instead, so a stale reference is a no-op rather than a crash.
///
/// All mutations must happen on the main thread (disk I/O is moved off it
/// internally).
final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    @Published private(set) var notes: [Note] = []
    /// False until the first disk load finished — drives the loading placeholder.
    @Published private(set) var isLoaded = false

    private let service = NotesFileService.shared
    private var saveWork: DispatchWorkItem?
    private var isLoading = false
    /// A save that was requested before the first load finished. Writing then would
    /// truncate `notes.json` to whatever little was in memory.
    private var needsSaveAfterLoad = false

    private init() {}

    // MARK: - Loading

    /// Loads notes from disk once. Safe to call from every view's `onAppear`.
    func loadIfNeeded() {
        guard !isLoaded, !isLoading else { return }
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = self?.service.loadNotes() ?? []
            let (repaired, didRepair) = Self.repairMissingPlainText(loaded)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                // Keep anything created while the load was in flight instead of
                // letting the disk copy overwrite it.
                let created = Set(self.notes.map(\.id))
                self.notes = repaired.filter { !created.contains($0.id) } + self.notes
                self.isLoaded = true
                NoteSearchService.shared.indexNotes(with: self.notes)
                if self.needsSaveAfterLoad || didRepair {
                    self.needsSaveAfterLoad = false
                    self.saveNow()
                }
            }
        }
    }

    /// Fills in `text` for notes that only carry rich text.
    ///
    /// A note like that reads as empty everywhere plain text is used — the word
    /// counter, search, the sidebar preview, TXT/PDF export — even though the
    /// editor shows content. Repairing once on load keeps the two representations
    /// in step for good. Runs off the main thread; decoding RTF isn't free.
    private static func repairMissingPlainText(_ notes: [Note]) -> (notes: [Note], didRepair: Bool) {
        var result = notes
        var didRepair = false

        for i in result.indices {
            guard result[i].text.isEmpty,
                  let rtf = result[i].attributedTextRTF,
                  let plain = WordCount.plainText(fromRTF: rtf),
                  !plain.isEmpty else { continue }
            result[i].text = plain
            didRepair = true
        }

        return (result, didRepair)
    }

    /// Re-reads `notes.json`. Only needed when something outside this process
    /// could have changed the file; in-app edits never need it.
    func reloadFromDisk() {
        guard let loaded = service.loadNotes() else { return }
        notes = loaded
        isLoaded = true
        NoteSearchService.shared.indexNotes(with: loaded)
    }

    // MARK: - Lookup

    func index(of id: UUID) -> Int? {
        notes.firstIndex { $0.id == id }
    }

    func note(_ id: UUID?) -> Note? {
        guard let id else { return nil }
        return notes.first { $0.id == id }
    }

    func contains(_ id: UUID?) -> Bool {
        note(id) != nil
    }

    /// The id that should be selected when `preferred` is gone (or was never set).
    func resolveSelection(preferred: UUID?) -> UUID? {
        if let preferred, contains(preferred) { return preferred }
        return notes.first?.id
    }

    // MARK: - Mutation

    /// Mutates one note in place. Does nothing if the note no longer exists.
    func update(id: UUID, save: Bool = true, _ mutate: (inout Note) -> Void) {
        guard let i = index(of: id) else { return }
        mutate(&notes[i])
        if save { scheduleSave() }
    }

    /// Writes edited editor content back to a note. Called on every keystroke, so
    /// it bails out when nothing actually changed.
    func updateContent(id: UUID, text: String, rtf: Data?) {
        guard let i = index(of: id) else { return }
        guard notes[i].text != text || notes[i].attributedTextRTF != rtf else { return }
        notes[i].text = text
        notes[i].attributedTextRTF = rtf
        notes[i].updateModifiedDate()
        notes[i].captureVersionIfNeeded()
        scheduleSave()
    }

    func setTitle(_ title: String, id: UUID) {
        update(id: id) { note in
            guard note.title != title else { return }
            note.title = title
            note.updateModifiedDate()
        }
    }

    func setExpiry(_ date: Date?, id: UUID) {
        update(id: id) { $0.expiryDate = date }
    }

    func setLocked(_ locked: Bool, id: UUID) {
        update(id: id) { $0.isLocked = locked }
    }

    /// Appends a new note and returns it. The caller selects it by `id`.
    @discardableResult
    func addNote(text: String = "", title: String? = nil) -> Note {
        let resolvedTitle = title ?? defaultTitle()
        var note = Note(title: resolvedTitle, text: text)
        note.updateModifiedDate()
        notes.append(note)
        saveNow()
        return note
    }

    func delete(id: UUID) {
        guard let i = index(of: id) else { return }
        notes.remove(at: i)
        saveNow()
    }

    func deleteAll() {
        notes.removeAll()
        saveNow()
    }

    /// Replaces the whole list (expiry sweep, restore-from-disk, …).
    func replaceAll(with newNotes: [Note]) {
        notes = newNotes
        isLoaded = true
        saveNow()
    }

    func togglePin(id: UUID) {
        guard let i = index(of: id) else { return }
        let wasPinned = notes[i].isPinned
        notes[i].isPinned.toggle()
        if !wasPinned {
            let note = notes.remove(at: i)
            notes.insert(note, at: 0)
        }
        saveNow()
    }

    /// Reorders by identity: moves `id` into the slot currently held by `targetID`.
    func move(id: UUID, toPositionOf targetID: UUID) {
        guard id != targetID,
              let from = index(of: id),
              let to = index(of: targetID) else { return }
        let note = notes.remove(at: from)
        notes.insert(note, at: min(to, notes.count))
        scheduleSave()
    }

    // MARK: - Bindings

    /// A crash-proof binding to a single note. If the note is deleted while a view
    /// still holds this binding, reads return a blank placeholder and writes are
    /// dropped — instead of trapping on an out-of-range array index.
    func binding(for id: UUID) -> Binding<Note> {
        Binding(
            get: { [weak self] in self?.note(id) ?? Note.placeholder },
            set: { [weak self] newValue in
                guard let self, let i = self.index(of: id) else { return }
                self.notes[i] = newValue
            }
        )
    }

    func titleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.note(id)?.title ?? "" },
            set: { [weak self] in self?.setTitle($0, id: id) }
        )
    }

    // MARK: - Persistence

    /// Debounced write. Coalesces bursts of keystrokes into a single disk write.
    func scheduleSave(debounce: TimeInterval = 0.5) {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    /// Writes immediately and cancels any pending debounced write, so a delete can
    /// never be undone by a stale in-flight snapshot.
    func saveNow() {
        saveWork?.cancel()
        saveWork = nil

        // Never write before the stored notes have been read back in.
        guard isLoaded else {
            needsSaveAfterLoad = true
            return
        }

        let snapshot = notes
        DispatchQueue.global(qos: .utility).async { [service] in
            service.saveNotes(snapshot)
        }
        NoteSearchService.shared.indexNotes(with: snapshot)
    }

    // MARK: - Helpers

    private func defaultTitle() -> String {
        let existing = Set(notes.map(\.title))
        var n = 1
        while existing.contains("Note \(n)") { n += 1 }
        return "Note \(n)"
    }
}

extension Note {
    /// Stand-in returned by `NotesStore.binding(for:)` when the note is gone.
    /// Never persisted — it only keeps a dangling view readable for one frame.
    static let placeholder = Note(title: "", text: "")
}
