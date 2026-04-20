import SwiftUI
import AppKit
import LocalAuthentication

// MARK: - Selection model

enum FullWindowSelection: Equatable {
    case todos
    case note(UUID)
}

// MARK: - FullWindowView

struct FullWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var notes: [Note] = []
    @State private var todos: [TodoItem] = []
    @State private var selection: FullWindowSelection = .todos
    @State private var sidebarExpanded: Bool
    @State private var unlockedNoteIDs: Set<UUID> = []
    @State private var themeMode: String
    @State private var showWordCounter: Bool
    @State private var showDeleteAlert = false
    @State private var pendingDeleteId: UUID? = nil
    @State private var pendingSaveWorkItem: DispatchWorkItem?

    private let notesService = NotesFileService.shared
    private let todoService  = TodoFileService.shared

    init() {
        let s = SettingsService.shared.settings
        _sidebarExpanded = State(initialValue: s.sidebarExpanded)
        _themeMode       = State(initialValue: s.themeMode)
        _showWordCounter = State(initialValue: s.showWordCounter)
    }

    private var selectedNoteIndex: Int? {
        guard case .note(let id) = selection else { return nil }
        return notes.firstIndex { $0.id == id }
    }

    private var pendingTodosCount: Int {
        todos.filter { !$0.isCompleted }.count
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
                    notes: $notes,
                    selection: $selection,
                    pendingTodosCount: pendingTodosCount,
                    onAddNote: addNote,
                    onDeleteNote: { id in pendingDeleteId = id; showDeleteAlert = true },
                    onTogglePin: { id in
                        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
                        notes[i].isPinned.toggle()
                        scheduleSave()
                    },
                    onOpenSettings: { SettingsWindowController.shared.show() },
                    onCollapse: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            sidebarExpanded = false
                        }
                        persistSidebar(false)
                    }
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

            case .note(let id):
                if let idx = notes.firstIndex(where: { $0.id == id }) {
                    TextField("Note title", text: $notes[idx].title)
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .onSubmit { scheduleSave() }
                        .onChange(of: notes[idx].title) { _, _ in scheduleSave() }
                    Spacer()
                    if let lastModified = notes[idx].lastModified {
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

        case .note:
            if let idx = selectedNoteIndex {
                FullWindowEditor(
                    notes: $notes,
                    noteIndex: idx,
                    unlockedNoteIDs: $unlockedNoteIDs,
                    showWordCounter: showWordCounter,
                    onSave: scheduleSave,
                    onAddNote: addNote,
                    onDelete: { pendingDeleteId = notes[idx].id; showDeleteAlert = true },
                    onTogglePin: { togglePin(noteId: notes[idx].id) },
                    onToggleLock: { toggleLock(noteId: notes[idx].id) },
                    onUnlock: { unlockNote(noteId: notes[idx].id) }
                )
            } else {
                emptyNoteState
            }
        }
    }

    // MARK: - Todos Area

    @ViewBuilder
    private var todosArea: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 40)
            TodoListView(todos: $todos, compact: false, showBorder: false, onSave: saveTodos)
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
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedNotes = notesService.loadNotes() ?? []
            let loadedTodos = todoService.loadTodos()
            DispatchQueue.main.async {
                self.notes = loadedNotes
                self.todos = loadedTodos
                if let first = loadedNotes.first {
                    self.selection = .note(first.id)
                }
            }
        }
    }

    // MARK: - Note Actions

    private func addNote() {
        let next = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? (notes.count + 1)
        var note = Note(title: "Note \(next)", text: "")
        note.updateModifiedDate()
        withAnimation {
            notes.append(note)
            selection = .note(note.id)
        }
        scheduleSave()
    }

    private func deleteNote(noteId: UUID) {
        notes.removeAll { $0.id == noteId }
        if case .note(let id) = selection, id == noteId {
            selection = notes.first.map { .note($0.id) } ?? .todos
        }
        scheduleSave()
        NoteSearchService.shared.indexNotes(with: notes)
    }

    private func togglePin(noteId: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[i].isPinned.toggle()
        scheduleSave()
    }

    private func toggleLock(noteId: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == noteId }) else { return }
        let note = notes[i]
        if note.isLocked {
            Task { @MainActor in
                let ok = await AuthenticationService.shared.authenticate(reason: "Remove lock from \"\(note.title)\"")
                if ok { notes[i].isLocked = false; unlockedNoteIDs.remove(note.id); scheduleSave() }
            }
        } else {
            Task { @MainActor in
                let ok = await AuthenticationService.shared.ensurePasswordOrBiometricsConfigured()
                if ok { notes[i].isLocked = true; unlockedNoteIDs.remove(note.id); scheduleSave() }
            }
        }
    }

    private func unlockNote(noteId: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == noteId }) else { return }
        let note = notes[i]
        Task { @MainActor in
            let ok = await AuthenticationService.shared.authenticate(reason: "Unlock \"\(note.title)\"")
            if ok { unlockedNoteIDs.insert(note.id) }
        }
    }

    private func scheduleSave() {
        let snapshot = notes
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem {
            DispatchQueue.global(qos: .utility).async {
                self.notesService.saveNotes(snapshot)
                DispatchQueue.main.async { NoteSearchService.shared.indexNotes(with: snapshot) }
            }
        }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func saveTodos() {
        let snapshot = todos
        DispatchQueue.global(qos: .utility).async { self.todoService.saveTodos(snapshot) }
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
    @Binding var notes: [Note]
    @Binding var selection: FullWindowSelection
    let pendingTodosCount: Int

    let onAddNote: () -> Void
    let onDeleteNote: (UUID) -> Void
    let onTogglePin: (UUID) -> Void
    let onOpenSettings: () -> Void
    let onCollapse: () -> Void

    private var isTodosSelected: Bool { selection == .todos }

    private var sortedNotes: [Note] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    todosItem
                    notesSectionDivider
                    notesSectionHeader
                    LazyVStack(spacing: 2) {
                        ForEach(sortedNotes) { note in
                            sidebarNoteRow(note: note)
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

        Button {
            withAnimation(.easeInOut(duration: 0.1)) { selection = .note(note.id) }
        } label: {
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
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin") { onTogglePin(note.id) }
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
    @Binding var notes: [Note]
    let noteIndex: Int
    @Binding var unlockedNoteIDs: Set<UUID>
    let showWordCounter: Bool
    let onSave: () -> Void
    let onAddNote: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleLock: () -> Void
    let onUnlock: () -> Void

    @State private var localShowWordCounter: Bool

    init(
        notes: Binding<[Note]>,
        noteIndex: Int,
        unlockedNoteIDs: Binding<Set<UUID>>,
        showWordCounter: Bool,
        onSave: @escaping () -> Void,
        onAddNote: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onToggleLock: @escaping () -> Void,
        onUnlock: @escaping () -> Void
    ) {
        self._notes = notes
        self.noteIndex = noteIndex
        self._unlockedNoteIDs = unlockedNoteIDs
        self.showWordCounter = showWordCounter
        self.onSave = onSave
        self.onAddNote = onAddNote
        self.onDelete = onDelete
        self.onTogglePin = onTogglePin
        self.onToggleLock = onToggleLock
        self.onUnlock = onUnlock
        self._localShowWordCounter = State(initialValue: showWordCounter)
    }

    var body: some View {
        VStack(spacing: 0) {
            NoteEditor(
                noteIndex: noteIndex,
                notes: $notes,
                unlockedNoteIDs: $unlockedNoteIDs,
                showWordCounter: $localShowWordCounter,
                onSave: onSave,
                onUnlock: { _ in onUnlock() },
                onToggleLock: { _ in onToggleLock() }
            )
            .padding(.horizontal, 48)
            .padding(.top, 16)
            .padding(.bottom, 16)

            EditorToolbar(
                noteIndex: noteIndex,
                notes: $notes,
                onRequestDelete: { _ in onDelete() },
                onRequestAddNote: onAddNote,
                onRequestTogglePin: { _ in onTogglePin() },
                onRequestToggleLock: { _ in onToggleLock() },
                onSave: onSave
            )
            .padding(.horizontal, 48)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showWordCounter) { _, newVal in localShowWordCounter = newVal }
    }
}
