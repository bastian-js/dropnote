import SwiftUI
import AppKit
import LocalAuthentication

struct ContentView: View {
    @StateObject private var searchManager = SearchManager.shared
    @ObservedObject private var todoService = TodoFileService.shared
    @State private var notes: [Note] = []
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

    @State private var showEditorToolbar: Bool
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

    // Transcription tab state
    @State private var showTranscriptionTab: Bool
    @State private var showingTranscriptionTab: Bool = false

    @State private var popoverSize: CGSize
    @State private var popoverSizeLocked: Bool

    // Self-destruct custom date sheet
    @State private var expiryNoteID: UUID?

    @Environment(\.undoManager) private var undoManager

    private let notesService = NotesFileService.shared
    private let settingsService = SettingsService.shared

    init() {
        let settings = SettingsService.shared.settings
        _showWordCounter = State(initialValue: settings.showWordCounter)
        _themeMode = State(initialValue: settings.themeMode)
        _showSearchRecentNotes = State(initialValue: settings.showSearchRecentNotes)
        _showTodoTab = State(initialValue: settings.showTodoTab)
        _showTranscriptionTab = State(initialValue: settings.showTranscriptionTab)
        _notes = State(initialValue: [])
        _isLoadingNotes = State(initialValue: true)
        _popoverSize = State(initialValue: CGSize(width: settings.popoverWidth, height: settings.popoverHeight))
        _popoverSizeLocked = State(initialValue: settings.popoverSizeLocked)
        _showEditorToolbar = State(initialValue: settings.showEditorToolbar)
    }

    var body: some View {
        mainContent
            .appAccent()
            .preferredColorScheme(getColorScheme())
            .onAppear {
                loadNotesIfNeeded()
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
                if !newShowTodoTab && showingTodoTab { showingTodoTab = false }
                let newShowTranscriptionTab = s.showTranscriptionTab
                showTranscriptionTab = newShowTranscriptionTab
                if !newShowTranscriptionTab && showingTranscriptionTab { showingTranscriptionTab = false }
                popoverSizeLocked = s.popoverSizeLocked
                showEditorToolbar = s.showEditorToolbar
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PopoverSizeReset"))) { note in
                if let size = note.object as? CGSize { popoverSize = size }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NotesWiped"))) { _ in
                cachedFilteredIndices = []
                notes = []
                selectedTab = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: ExpiryManager.notesReloadRequested)) { _ in
                reloadNotesFromDisk()
            }
            .sheet(isPresented: Binding(
                get: { expiryNoteID != nil },
                set: { if !$0 { expiryNoteID = nil } }
            )) {
                if let id = expiryNoteID, let idx = notes.firstIndex(where: { $0.id == id }) {
                    ExpiryPickerView(
                        noteTitle: notes[idx].title,
                        initialDate: notes[idx].expiryDate,
                        onSet: { date in
                            setExpiry(noteIndex: idx, date: date)
                            expiryNoteID = nil
                        },
                        onCancel: { expiryNoteID = nil }
                    )
                }
            }
            .onChange(of: notes) { _, _ in recomputeFilteredIndices() }
            .onChange(of: searchText) { _, _ in recomputeFilteredIndices() }
            // Selecting a note tab deselects the todo tab
            .onChange(of: selectedTab) { _, _ in
                if showingTodoTab { showingTodoTab = false }
                if showingTranscriptionTab { showingTranscriptionTab = false }
            }
    }

    // MARK: - Main View Components

    @ViewBuilder
    private var mainContent: some View {
        let currentFilteredIndices = cachedFilteredIndices
        let currentActiveIndex = activeIndex(from: currentFilteredIndices)

        ZStack(alignment: .bottomTrailing) {
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
                    onRequestTogglePin: { index in togglePin(noteIndex: index) },
                    onRequestToggleLock: { index in toggleLock(noteIndex: index) },
                    showTodoTab: showTodoTab,
                    isTodoTabSelected: showingTodoTab,
                    onSelectTodoTab: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingTodoTab = true
                            showingTranscriptionTab = false
                        }
                    },
                    onSelectNoteTab: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingTodoTab = false
                            showingTranscriptionTab = false
                        }
                    },
                    showTranscriptionTab: showTranscriptionTab,
                    isTranscriptionTabSelected: showingTranscriptionTab,
                    onSelectTranscriptionTab: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingTranscriptionTab = true
                            showingTodoTab = false
                        }
                    },
                    onRequestFloat: { index in
                        guard index < notes.count else { return }
                        FloatingNoteWindowController.shared.show(note: notes[index])
                    },
                    onSetExpiry: { index, date in setExpiry(noteIndex: index, date: date) },
                    onRequestCustomExpiry: { index in
                        guard index < notes.count else { return }
                        expiryNoteID = notes[index].id
                    },
                    onMove: moveNote
                )

                noteArea(filteredIndices: currentFilteredIndices, activeIndex: currentActiveIndex)
                    .frame(maxHeight: .infinity)

                if let current = currentActiveIndex, showEditorToolbar, !showingTodoTab, !showingTranscriptionTab {
                    EditorToolbar(
                        noteIndex: current,
                        notes: $notes,
                        onRequestDelete: { index in
                            deleteIndex = index
                            showDeleteAlert = true
                        },
                        onRequestAddNote: { addNote() },
                        onRequestTogglePin: { index in togglePin(noteIndex: index) },
                        onRequestToggleLock: toggleLock,
                        onSave: scheduleSave
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
            .padding(.top, 8)
            .frame(width: popoverSize.width, height: popoverSize.height)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeDropdownsAndEditing() }
            )

            if !popoverSizeLocked {
                ResizeHandle(
                    currentSize: popoverSize,
                    onResize: { newSize in
                        popoverSize = newSize
                        AppDelegate.shared?.popover?.contentSize = newSize
                    },
                    onResizeEnd: { newSize in
                        var s = settingsService.settings
                        s.popoverWidth = newSize.width
                        s.popoverHeight = newSize.height
                        settingsService.updateSetting(s)
                    }
                )
                .padding(2)
            }
        }
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
                    addNote()
                } label: {
                    Image(systemName: "square.and.pencil").padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                .help("New Note")
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
            TodoListView(todos: $todoService.todos, hideCompleted: true, onSave: todoService.save)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity)
        } else if showingTranscriptionTab {
            TranscriptionView(onSaveAsNote: { text in
                addNote(withText: text)
            })
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .transition(.opacity)
        } else {
            Group {
                if filteredIndices.isEmpty {
                    emptyState
                } else if let current = activeIndex, current < notes.count {
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
        if trimmed.isEmpty {
            return Array(notes.indices)
        }
        let lowercasedQuery = trimmed.lowercased()
        return notes.indices.filter { index in
            notes[index].title.lowercased().contains(lowercasedQuery) ||
            notes[index].text.lowercased().contains(lowercasedQuery)
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
            notes[current].captureVersionIfNeeded()
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

    private func addNote() {
        addNote(withText: "")
    }

    private func addNote(withText text: String) {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil

        let nextNumber = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? (notes.count + 1)
        var newNote = Note(title: "Note \(nextNumber)", text: text)
        newNote.updateModifiedDate()

        withAnimation(.easeInOut(duration: 0.2)) {
            notes.append(newNote)
            selectedTab = notes.count - 1
            showingTodoTab = false
            showingTranscriptionTab = false
        }
        saveNotes()
        NoteSearchService.shared.indexNotes(with: notes)
    }

    private func setExpiry(noteIndex: Int, date: Date?) {
        guard noteIndex < notes.count else { return }
        notes[noteIndex].expiryDate = date
        scheduleSave()
    }

    private func reloadNotesFromDisk() {
        guard let loaded = notesService.loadNotes() else { return }
        let selectedID = activeIndex(from: cachedFilteredIndices).flatMap { idx -> UUID? in
            idx < notes.count ? notes[idx].id : nil
        }
        notes = loaded
        if let selectedID, let newIndex = loaded.firstIndex(where: { $0.id == selectedID }) {
            selectedTab = newIndex
        } else {
            selectedTab = max(0, min(selectedTab, loaded.count - 1))
        }
        recomputeFilteredIndices()
    }

    private func togglePin(noteIndex: Int) {
        let wasPinned = notes[noteIndex].isPinned
        notes[noteIndex].isPinned.toggle()
        if !wasPinned {
            notes.move(fromOffsets: IndexSet(integer: noteIndex), toOffset: 0)
            if selectedTab == noteIndex { selectedTab = 0 }
            else if selectedTab < noteIndex { selectedTab += 1 }
        }
        scheduleSave()
    }

    private func moveNote(from: Int, to: Int) {
        notes.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        if selectedTab == from {
            selectedTab = to
        } else if from < to, selectedTab > from, selectedTab <= to {
            selectedTab -= 1
        } else if from > to, selectedTab >= to, selectedTab < from {
            selectedTab += 1
        }
        scheduleSave()
    }

    private func deleteNote(at index: Int) {
        // Cancel any pending debounced save so it can't overwrite with a stale snapshot.
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil

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
