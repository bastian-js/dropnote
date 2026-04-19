import SwiftUI
import AppKit
import LocalAuthentication

struct ContentView: View {
    @StateObject private var searchManager = SearchManager.shared
    @State private var notes: [Note] = []
    @State private var todos: [TodoItem] = []
    @State private var selectedTab: Int = 0
    @State private var isLoadingNotes: Bool = true

    @State private var isEditingTabTitle: Bool = false
    @State private var editedTabTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool

    @State private var showDeleteAlert: Bool = false
    @State private var deleteIndex: Int?
    @State private var showWordCounter: Bool

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    @State private var showEditorToolbar: Bool = true
    @State private var noteIDToOpen: UUID?
    @State private var showSettingsMenu: Bool = false

    @State private var isSaving: Bool = false
    @State private var lastSavedAt: Date?
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    @State private var savingStatusTimer: Timer?

    @State private var unlockedNoteIDs: Set<UUID> = []
    @State private var themeMode: String = "system"
    @State private var showSearchRecentNotes: Bool = true
    @State private var cachedFilteredIndices: [Int] = []

    // Todo tab state
    @State private var showTodoTab: Bool
    @State private var showingTodoTab: Bool = false

    @Environment(\.undoManager) private var undoManager

    private let editorHeight: CGFloat = 200
    private let toolbarHeight: CGFloat = 38
    private let notesService = NotesFileService.shared
    private let todoService = TodoFileService.shared
    private let settingsService = SettingsService.shared

    init() {
        let settings = SettingsService.shared.settings
        _showWordCounter = State(initialValue: settings.showWordCounter)
        _themeMode = State(initialValue: settings.themeMode)
        _showSearchRecentNotes = State(initialValue: settings.showSearchRecentNotes)
        _showTodoTab = State(initialValue: settings.showTodoTab)
        _notes = State(initialValue: [])
        _isLoadingNotes = State(initialValue: true)
    }

    var body: some View {
        mainContent
            .preferredColorScheme(getColorScheme())
            .onAppear {
                loadNotesIfNeeded()
                loadTodos()
                recomputeFilteredIndices()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                if let appDelegate = AppDelegate.shared, appDelegate.popover?.isShown == true {
                    appDelegate.popover?.performClose(nil)
                }
            }
            .onReceive(searchManager.$noteIDToOpen) { noteID in
                handleSearchResultSelection(noteID)
            }
            .onDisappear {
                saveNotes()
            }
            .alert("Delete note?", isPresented: $showDeleteAlert, presenting: deleteIndex) { index in
                Button("Delete", role: .destructive) { deleteNote(at: index) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This note will be deleted permanently")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsChanged"))) { _ in
                let s = SettingsService.shared.settings
                showWordCounter = s.showWordCounter
                themeMode = s.themeMode
                showSearchRecentNotes = s.showSearchRecentNotes
                let newShowTodoTab = s.showTodoTab
                showTodoTab = newShowTodoTab
                if !newShowTodoTab && showingTodoTab {
                    showingTodoTab = false
                }
            }
            .onChange(of: notes) { _, _ in recomputeFilteredIndices() }
            .onChange(of: searchText) { _, _ in recomputeFilteredIndices() }
            // Selecting a note tab deselects the todo tab
            .onChange(of: selectedTab) { _, _ in
                if showingTodoTab { showingTodoTab = false }
            }
    }

    // MARK: - Main View Components

    @ViewBuilder
    private var mainContent: some View {
        let currentFilteredIndices = cachedFilteredIndices
        let currentActiveIndex = activeIndex(from: currentFilteredIndices)

        VStack(spacing: 6) {
            searchBar
            TabsBar(
                notes: $notes,
                filteredIndices: currentFilteredIndices,
                selectedTab: $selectedTab,
                isEditingTabTitle: $isEditingTabTitle,
                editedTabTitle: $editedTabTitle,
                isTextFieldFocused: $isTextFieldFocused,
                onRequestDelete: { index in
                    deleteIndex = index
                    showDeleteAlert = true
                },
                onPersist: saveNotes,
                onRequestTogglePin: { index in
                    notes[index].isPinned.toggle()
                    scheduleSave()
                },
                onRequestToggleLock: { index in toggleLock(noteIndex: index) },
                showTodoTab: showTodoTab,
                isTodoTabSelected: showingTodoTab,
                onSelectTodoTab: {
                    withAnimation(.easeInOut(duration: 0.15)) { showingTodoTab = true }
                }
            )

            noteArea(filteredIndices: currentFilteredIndices, activeIndex: currentActiveIndex)
                .frame(maxHeight: .infinity)

            if let current = currentActiveIndex, showEditorToolbar, !showingTodoTab {
                EditorToolbar(
                    noteIndex: current,
                    notes: $notes,
                    onRequestDelete: { index in
                        deleteIndex = index
                        showDeleteAlert = true
                    },
                    onRequestAddNote: { addNote() },
                    onRequestTogglePin: { index in
                        notes[index].isPinned.toggle()
                        scheduleSave()
                    },
                    onRequestToggleLock: toggleLock,
                    onSave: scheduleSave
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 8)
        .frame(width: 320, height: 480)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { closeDropdownsAndEditing() }
        )
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Button {
                showSettingsMenu.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showSettingsMenu, arrowEdge: .top) {
                settingsMenu
            }

            if isSearching {
                HStack(spacing: 6) {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ColorSchemeHelper.searchFieldBackground())
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorSchemeHelper.searchFieldBorder(), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                        .focused($isSearchFieldFocused)
                        .onChange(of: isSearchFieldFocused) { _, focused in
                            if !focused {
                                withAnimation {
                                    isSearching = false
                                    searchText = ""
                                }
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.async { self.isSearchFieldFocused = true }
                        }

                    Button {
                        withAnimation {
                            isSearching = false
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Spacer()
                Button {
                    withAnimation { isSearching = true }
                } label: {
                    Image(systemName: "magnifyingglass").padding(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func noteArea(filteredIndices: [Int], activeIndex: Int?) -> some View {
        if showingTodoTab {
            TodoListView(todos: $todos, onSave: saveTodos)
                .padding(.horizontal, 12)
                .transition(.opacity)
        } else {
            Group {
                if filteredIndices.isEmpty {
                    emptyState
                } else if let current = activeIndex {
                    NoteEditor(
                        noteIndex: current,
                        notes: $notes,
                        unlockedNoteIDs: $unlockedNoteIDs,
                        showWordCounter: $showWordCounter,
                        onSave: scheduleSave,
                        onUnlock: unlockNoteFlow,
                        onToggleLock: toggleLock
                    )
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            if isLoadingNotes {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.bottom, 4)
                Text("Loading notes...")
                    .font(.title3.weight(.semibold))
                Text("Please wait while your notes are being loaded.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                Text("No notes yet")
                    .font(.title3.weight(.semibold))
                Text("Create your first note to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button {
                    addNote()
                } label: {
                    Label("Create Note", systemImage: "plus")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .transition(.opacity)
    }

    // MARK: - Computed Properties

    private func computeFilteredIndices() -> [Int] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseIndices: [Int]

        if trimmed.isEmpty {
            baseIndices = Array(notes.indices)
        } else {
            let lowercasedQuery = trimmed.lowercased()
            baseIndices = notes.indices.filter { index in
                notes[index].title.lowercased().contains(lowercasedQuery) ||
                notes[index].text.lowercased().contains(lowercasedQuery)
            }
        }

        return baseIndices.sorted { a, b in
            let noteA = notes[a]
            let noteB = notes[b]
            if noteA.isPinned != noteB.isPinned { return noteA.isPinned && !noteB.isPinned }
            return noteA.title.localizedCaseInsensitiveCompare(noteB.title) == .orderedAscending
        }
    }

    private func recomputeFilteredIndices() {
        cachedFilteredIndices = computeFilteredIndices()
    }

    private func activeIndex(from indices: [Int]) -> Int? {
        if indices.contains(selectedTab) { return selectedTab }
        return indices.first
    }

    // MARK: - Private Methods

    private func closeDropdownsAndEditing() {
        showSettingsMenu = false
        if isSearching {
            withAnimation {
                isSearching = false
                searchText = ""
            }
            isSearchFieldFocused = false
        }
        if isEditingTabTitle {
            isTextFieldFocused = false
            isEditingTabTitle = false
        }
    }

    @ViewBuilder
    private var settingsMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            settingsMenuButton(title: "Settings", icon: "gearshape") {
                showSettingsMenu = false
                openSettings(nil)
            }
            settingsMenuButton(title: "Notes Window", icon: "macwindow") {
                showSettingsMenu = false
                openFullWindow()
            }
            Divider()
            settingsMenuButton(title: "Quit DropNote", icon: "power") {
                showSettingsMenu = false
                quitApp(nil)
            }
        }
        .padding(12)
        .frame(width: 200)
    }

    @ViewBuilder
    private func settingsMenuButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadNotesIfNeeded() {
        guard isLoadingNotes else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            if let loaded = notesService.loadNotes() {
                DispatchQueue.main.async {
                    self.notes = loaded
                    self.isLoadingNotes = false
                    self.handlePendingNoteSelection()
                }
            } else {
                DispatchQueue.main.async { self.isLoadingNotes = false }
            }
        }
    }

    private func loadTodos() {
        let loaded = todoService.loadTodos()
        self.todos = loaded
    }

    private func handlePendingNoteSelection() {
        guard let noteIDToOpen = searchManager.noteIDToOpen,
              let index = notes.firstIndex(where: { $0.id == noteIDToOpen }) else { return }
        searchText = ""
        isSearching = false
        selectedTab = index
        searchManager.noteIDToOpen = nil
    }

    private func handleSearchResultSelection(_ noteID: UUID?) {
        guard let noteID = noteID, !isLoadingNotes else { return }
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        searchText = ""
        isSearching = false
        showingTodoTab = false
        withAnimation { selectedTab = index }
        searchManager.noteIDToOpen = nil
    }

    private func scheduleSave() {
        let currentFilteredIndices = cachedFilteredIndices
        if let current = activeIndex(from: currentFilteredIndices) {
            notes[current].updateModifiedDate()
        }

        let notesSnapshot = notes
        pendingSaveWorkItem?.cancel()
        isSaving = true

        let work = DispatchWorkItem {
            DispatchQueue.global(qos: .utility).async {
                self.notesService.saveNotes(notesSnapshot)
                DispatchQueue.main.async {
                    NoteSearchService.shared.indexNotes(with: notesSnapshot)
                }
                DispatchQueue.main.async {
                    self.lastSavedAt = Date()
                    self.savingStatusTimer?.invalidate()
                    self.savingStatusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        self.isSaving = false
                    }
                }
            }
        }

        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func saveNotes() {
        let snapshot = notes
        DispatchQueue.global(qos: .utility).async {
            self.notesService.saveNotes(snapshot)
        }
    }

    private func saveTodos() {
        let snapshot = todos
        DispatchQueue.global(qos: .utility).async {
            self.todoService.saveTodos(snapshot)
        }
    }

    private func addNote() {
        let nextNumber = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? (notes.count + 1)
        var newNote = Note(title: "Note \(nextNumber)", text: "")
        newNote.updateModifiedDate()

        withAnimation(.easeInOut(duration: 0.2)) {
            notes.append(newNote)
            selectedTab = notes.count - 1
            showingTodoTab = false
        }
        saveNotes()
        NoteSearchService.shared.indexNotes(with: notes)
    }

    private func deleteNote(at index: Int) {
        notes.remove(at: index)
        selectedTab = max(0, min(selectedTab, notes.count - 1))
        saveNotes()
        NoteSearchService.shared.indexNotes(with: notes)
    }

    private func unlockNoteFlow(noteIndex: Int) {
        let note = notes[noteIndex]
        guard note.isLocked else { return }
        Task { @MainActor in
            let authenticated = await AuthenticationService.shared.authenticate(reason: "Unlock \"\(note.title)\"")
            if authenticated { unlockedNoteIDs.insert(note.id) }
        }
    }

    private func toggleLock(noteIndex: Int) {
        let note = notes[noteIndex]
        if note.isLocked {
            Task { @MainActor in
                let authenticated = await AuthenticationService.shared.authenticate(reason: "Remove lock from \"\(note.title)\"")
                if authenticated {
                    notes[noteIndex].isLocked = false
                    unlockedNoteIDs.remove(note.id)
                    scheduleSave()
                }
            }
        } else {
            Task { @MainActor in
                let configured = await AuthenticationService.shared.ensurePasswordOrBiometricsConfigured()
                if configured {
                    notes[noteIndex].isLocked = true
                    unlockedNoteIDs.remove(note.id)
                    scheduleSave()
                }
            }
        }
    }

    private func openSettings(_ sender: Any?) {
        DispatchQueue.main.async {
            if let appDelegate = AppDelegate.shared,
               let popover = appDelegate.popover,
               popover.isShown {
                popover.performClose(nil)
                popover.close()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                SettingsWindowController.shared.show()
            }
        }
    }

    private func openFullWindow() {
        DispatchQueue.main.async {
            if let appDelegate = AppDelegate.shared,
               let popover = appDelegate.popover,
               popover.isShown {
                popover.performClose(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                FullWindowController.shared.show()
            }
        }
    }

    private func quitApp(_ sender: Any?) {
        DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
    }

    private func getColorScheme() -> ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
