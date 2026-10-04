import SwiftUI
import AppKit
import LocalAuthentication

// MARK: - Selection model

enum FullWindowSelection: Equatable {
    case todos
    case transcription
    case note(UUID)
}

// MARK: - FullWindowView

struct FullWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var todoService = TodoFileService.shared
    /// Same store the popover uses — that's what keeps the two windows in sync.
    @ObservedObject private var store = NotesStore.shared
    @State private var selection: FullWindowSelection = .todos
    @State private var sidebarExpanded: Bool
    @State private var unlockedNoteIDs: Set<UUID> = []
    @State private var themeMode: String
    @State private var showWordCounter: Bool
    @State private var showDeleteAlert = false
    @State private var pendingDeleteId: UUID? = nil
    @State private var expiryNoteID: UUID?

    init() {
        let s = SettingsService.shared.settings
        _sidebarExpanded = State(initialValue: s.sidebarExpanded)
        _themeMode       = State(initialValue: s.themeMode)
        _showWordCounter = State(initialValue: s.showWordCounter)
    }

    private var notes: [Note] { store.notes }

    /// The selected note, or nil once it has been deleted elsewhere.
    private var selectedNoteID: UUID? {
        guard case .note(let id) = selection, store.contains(id) else { return nil }
        return id
    }

    private var pendingTodosCount: Int {
        todoService.todos.filter { !$0.isCompleted }.count
    }

    private var effectiveColorScheme: ColorScheme {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return colorScheme
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: effectiveColorScheme == .dark
                    ? [Color.black.opacity(0.18), Color.gray.opacity(0.08)]
                    : [Color.white, Color.gray.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

        HStack(spacing: 0) {
            // Sidebar
            if sidebarExpanded {
                FullWindowSidebar(
                    notes: notes,
                    selection: $selection,
                    pendingTodosCount: pendingTodosCount,
                    onAddNote: addNote,
                    onDeleteNote: { id in pendingDeleteId = id; showDeleteAlert = true },
                    onTogglePin: { id in store.togglePin(id: id) },
                    onOpenSettings: { SettingsWindowController.shared.show() },
                    onCollapse: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            sidebarExpanded = false
                        }
                        persistSidebar(false)
                    },
                    onMoveNote: { from, to in store.move(id: from, toPositionOf: to) },
                    onFloatNote: { id in
                        if let note = store.note(id) {
                            FloatingNoteWindowController.shared.show(note: note)
                        }
                    },
                    onSetExpiry: { id, date in store.setExpiry(date, id: id) },
                    onRequestCustomExpiry: { id in expiryNoteID = id }
                )
                .frame(width: 240)
                .transition(.move(edge: .leading).combined(with: .opacity))
                .shadow(
                    color: Color.black.opacity(effectiveColorScheme == .dark ? 0.25 : 0.08),
                    radius: 12, x: 4, y: 0
                )
                .zIndex(1)
            }

            // Main panel
            VStack(spacing: 0) {
                mainHeader
                Divider()
                mainContent
            }
        }
        } // ZStack
        .frame(minWidth: 760, minHeight: 520)
        .appAccent()
        .preferredColorScheme(resolvedColorScheme())
        .alert("Delete note?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteId { deleteNote(noteId: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be permanently deleted.")
        }
        .onAppear { loadData() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsChanged"))) { _ in
            let s = SettingsService.shared.settings
            themeMode       = s.themeMode
            showWordCounter = s.showWordCounter
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewNoteRequested"))) { _ in
            addNote()
        }
        // The selected note can disappear from under us (expiry, or a delete in
        // the popover). Fall back instead of showing a stale selection.
        .onChange(of: store.notes.map(\.id)) { _, _ in
            if case .note(let id) = selection, !store.contains(id) {
                selection = store.notes.first.map { .note($0.id) } ?? .todos
            }
        }
        .sheet(isPresented: Binding(
            get: { expiryNoteID != nil },
            set: { if !$0 { expiryNoteID = nil } }
        )) {
            if let id = expiryNoteID, let note = store.note(id) {
                ExpiryPickerView(
                    noteTitle: note.title,
                    initialDate: note.expiryDate,
                    onSet: { date in
                        store.setExpiry(date, id: id)
                        expiryNoteID = nil
                    },
                    onCancel: { expiryNoteID = nil }
                )
            }
        }
    }

    // MARK: - Main Header

    @ViewBuilder
    private var mainHeader: some View {
        HStack(spacing: 12) {
            if !sidebarExpanded {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        sidebarExpanded = true
                    }
                    persistSidebar(true)
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show Sidebar")
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            switch selection {
            case .todos:
                Text("Todos")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .padding(.bottom, 2)
                Spacer()

            case .transcription:
                Text("Transcription")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .padding(.bottom, 2)
                Spacer()

            case .note(let id):
                if let note = store.note(id) {
                    // Title binding resolves the note by id on every read/write,
                    // so renaming can't land on the wrong note.
                    TextField("Note title", text: store.titleBinding(for: id))
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                    Spacer()
                    if let lastModified = note.lastModified {
                        Text(DateFormattingHelper.formatDate(lastModified))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.55))
                    }
                } else {
                    Spacer()
                }
            }
        }
        .padding(.leading, sidebarExpanded ? 20 : 80)
        .padding(.trailing, 20)
        .padding(.vertical, 18)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selection {
        case .todos:
            todosArea

        case .transcription:
            transcriptionArea

        case .note:
            if let id = selectedNoteID {
                FullWindowEditor(
                    noteID: id,
                    unlockedNoteIDs: $unlockedNoteIDs,
                    showWordCounter: showWordCounter,
                    onAddNote: addNote,
                    onDelete: { pendingDeleteId = id; showDeleteAlert = true },
                    onTogglePin: { store.togglePin(id: id) },
                    onToggleLock: { toggleLock(noteId: id) },
                    onUnlock: { unlockNote(noteId: id) }
                )
            } else {
                emptyNoteState
            }
        }
    }

    // MARK: - Transcription Area

    @ViewBuilder
    private var transcriptionArea: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 40)
            TranscriptionView(onSaveAsNote: { text in
                let note = store.addNote(text: text)
                selection = .note(note.id)
            })
            .padding(.vertical, 20)
            .frame(maxWidth: 700, maxHeight: .infinity)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Todos Area

    @ViewBuilder
    private var todosArea: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 40)
            TodoListView(todos: $todoService.todos, compact: false, showBorder: false, onSave: todoService.save)
                .frame(maxWidth: 700)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyNoteState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.22))
            Text("No note selected")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.secondary.opacity(0.65))
            Text("Select a note from the sidebar, or create a new one.")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 64)
            Button("New Note") { addNote() }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func loadData() {
        store.loadIfNeeded()
        // Select something sensible once the notes are there.
        if case .note(let id) = selection, store.contains(id) { return }
        if let first = store.notes.first { selection = .note(first.id) }
    }

    // MARK: - Note Actions

    private func addNote() {
        let note = store.addNote()
        withAnimation {
            selection = .note(note.id)
        }
    }

    private func deleteNote(noteId: UUID) {
        let index = store.index(of: noteId)
        store.delete(id: noteId)
        unlockedNoteIDs.remove(noteId)

        if case .note(let id) = selection, id == noteId {
            if let index, !store.notes.isEmpty {
                selection = .note(store.notes[min(index, store.notes.count - 1)].id)
            } else {
                selection = store.notes.first.map { .note($0.id) } ?? .todos
            }
        }
    }

    private func toggleLock(noteId: UUID) {
        guard let note = store.note(noteId) else { return }
        if note.isLocked {
            Task { @MainActor in
                let ok = await AuthenticationService.shared.authenticate(reason: "Remove lock from \"\(note.title)\"")
                if ok {
                    store.setLocked(false, id: noteId)
                    unlockedNoteIDs.remove(noteId)
                }
            }
        } else {
            Task { @MainActor in
                let ok = await AuthenticationService.shared.ensurePasswordOrBiometricsConfigured()
                if ok {
                    store.setLocked(true, id: noteId)
                    unlockedNoteIDs.remove(noteId)
                }
            }
        }
    }

    private func unlockNote(noteId: UUID) {
        guard let note = store.note(noteId) else { return }
        Task { @MainActor in
            let ok = await AuthenticationService.shared.authenticate(reason: "Unlock \"\(note.title)\"")
            if ok { unlockedNoteIDs.insert(noteId) }
        }
    }

    private func persistSidebar(_ expanded: Bool) {
        var s = SettingsService.shared.settings
        s.sidebarExpanded = expanded
        SettingsService.shared.updateSetting(s)
    }

    private func resolvedColorScheme() -> ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

// MARK: - FullWindowSidebar

struct FullWindowSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    let notes: [Note]
    @Binding var selection: FullWindowSelection
    let pendingTodosCount: Int

    let onAddNote: () -> Void
    let onDeleteNote: (UUID) -> Void
    let onTogglePin: (UUID) -> Void
    let onOpenSettings: () -> Void
    let onCollapse: () -> Void
    /// Reorder by identity: move the first note into the second note's slot.
    var onMoveNote: ((UUID, UUID) -> Void)? = nil
    var onFloatNote: ((UUID) -> Void)? = nil
    var onSetExpiry: ((UUID, Date?) -> Void)? = nil
    var onRequestCustomExpiry: ((UUID) -> Void)? = nil

    @State private var draggingNoteID: UUID?

    private var isTodosSelected: Bool { selection == .todos }
    private var isTranscriptionSelected: Bool { selection == .transcription }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    todosItem
                    transcriptionItem
                    notesSectionDivider
                    notesSectionHeader
                    LazyVStack(spacing: 2) {
                        ForEach(notes) { note in
                            sidebarNoteRow(note: note)
                                .opacity(draggingNoteID == note.id ? 0.45 : 1.0)
                                .onDrag {
                                    draggingNoteID = note.id
                                    return NSItemProvider(object: note.id.uuidString as NSString)
                                }
                                .onDrop(of: ["public.text"], delegate: SidebarDropDelegate(
                                    targetNoteID: note.id,
                                    draggingNoteID: $draggingNoteID,
                                    onMove: onMoveNote
                                ))
                        }
                    }
                    .padding(.horizontal, 6)
                    if notes.isEmpty { emptyNotesState }
                }
                .padding(.bottom, 8)
            }
            Divider()
            sidebarFooter
        }
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.28)
                : Color(NSColor.controlBackgroundColor).opacity(0.85)
        )
    }

    // MARK: Sidebar Header

    @ViewBuilder
    private var sidebarHeader: some View {
        HStack(spacing: 0) {
            Text("DropNote")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .padding(.bottom, 2)
            Spacer()
            Button(action: onCollapse) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Hide Sidebar")
        }
        .padding(.leading, 80)
        .padding(.trailing, 14)
        .padding(.vertical, 18)
    }

    // MARK: Todos Item

    @ViewBuilder
    private var todosItem: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { selection = .todos }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isTodosSelected ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isTodosSelected ? .accentColor : .secondary)
                    .frame(width: 18)

                Text("Todos")
                    .font(.system(size: 13, weight: isTodosSelected ? .semibold : .medium))
                    .foregroundColor(isTodosSelected ? .accentColor : .primary)

                Spacer()

                if pendingTodosCount > 0 {
                    Text("\(pendingTodosCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(isTodosSelected ? .accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isTodosSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.07))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isTodosSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    // MARK: Transcription Item

    @ViewBuilder
    private var transcriptionItem: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { selection = .transcription }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isTranscriptionSelected ? "mic.fill" : "mic")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isTranscriptionSelected ? .accentColor : .secondary)
                    .frame(width: 18)
                Text("Transcribe")
                    .font(.system(size: 13, weight: isTranscriptionSelected ? .semibold : .medium))
                    .foregroundColor(isTranscriptionSelected ? .accentColor : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isTranscriptionSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
    }

    // MARK: Notes Section

    @ViewBuilder
    private var notesSectionDivider: some View {
        Divider()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private var notesSectionHeader: some View {
        HStack(spacing: 7) {
            Text("NOTES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.9)
            Spacer()
            Button { onAddNote() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("New Note")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 5)
    }

    @ViewBuilder
    private func sidebarNoteRow(note: Note) -> some View {
        let isSelected: Bool = {
            if case .note(let id) = selection { return id == note.id }
            return false
        }()

        HStack(spacing: 8) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.45))
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(note.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .lineLimit(1)
                if !note.text.isEmpty {
                    Text(note.text)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer()

            if note.expiryDate != nil {
                Image(systemName: "timer")
                    .font(.system(size: 9))
                    .foregroundColor(.orange.opacity(0.9))
            }

            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.45))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) { selection = .note(note.id) }
        }
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin") { onTogglePin(note.id) }
            Button("Float Note") { onFloatNote?(note.id) }
            Menu("Self-Destruct") {
                ExpiryMenuItems(
                    hasExpiry: note.expiryDate != nil,
                    onPreset: { onSetExpiry?(note.id, Date().addingTimeInterval($0)) },
                    onCustom: { onRequestCustomExpiry?(note.id) },
                    onRemove: { onSetExpiry?(note.id, nil) }
                )
            }
            Divider()
            Button("Delete", role: .destructive) { onDeleteNote(note.id) }
        }
    }

    @ViewBuilder
    private var emptyNotesState: some View {
        VStack(spacing: 8) {
            Text("No notes yet")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.55))
            Button("Create a note") { onAddNote() }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    // MARK: Footer

    @ViewBuilder
    private var sidebarFooter: some View {
        HStack {
            Button(action: onOpenSettings) {
                HStack(spacing: 7) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Spacer()

            Text("© 2026 DropNote")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.35))
                .padding(.trailing, 14)
        }
    }
}

// MARK: - FullWindowEditor

struct FullWindowEditor: View {
    let noteID: UUID
    @Binding var unlockedNoteIDs: Set<UUID>
    let showWordCounter: Bool
    let onAddNote: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleLock: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NoteEditor(
                noteID: noteID,
                unlockedNoteIDs: $unlockedNoteIDs,
                showWordCounter: showWordCounter,
                onUnlock: { _ in onUnlock() },
                onToggleLock: { _ in onToggleLock() }
            )
            .padding(.horizontal, 48)
            .padding(.top, 16)
            .padding(.bottom, 16)

            EditorToolbar(
                noteID: noteID,
                onRequestDelete: { _ in onDelete() },
                onRequestAddNote: onAddNote,
                onRequestTogglePin: { _ in onTogglePin() },
                onRequestToggleLock: { _ in onToggleLock() }
            )
            .padding(.horizontal, 48)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SidebarDropDelegate

private struct SidebarDropDelegate: DropDelegate {
    let targetNoteID: UUID
    @Binding var draggingNoteID: UUID?
    let onMove: ((UUID, UUID) -> Void)?

    func dropEntered(info: DropInfo) {
        guard let dragID = draggingNoteID, dragID != targetNoteID else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            onMove?(dragID, targetNoteID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingNoteID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
