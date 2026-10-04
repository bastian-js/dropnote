import SwiftUI
import AppKit
import LocalAuthentication

struct ContentView: View {
    @StateObject private var searchManager = SearchManager.shared
    @ObservedObject private var todoService = TodoFileService.shared
    @ObservedObject private var store = NotesStore.shared

    /// The note shown in the editor. `nil` falls back to the first visible note —
    /// resolved through `NotesStore`, so it can never point at a deleted note.
    @State private var selectedNoteID: UUID?

    @State private var isEditingTabTitle: Bool = false
    @State private var editedTabTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool

    @State private var showDeleteAlert: Bool = false
    @State private var deleteNoteID: UUID?
    @State private var showWordCounter: Bool

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    @State private var showEditorToolbar: Bool
    @State private var showSettingsMenu: Bool = false

    @State private var unlockedNoteIDs: Set<UUID> = []
    @State private var relockWorkItems: [UUID: DispatchWorkItem] = [:]
    @State private var themeMode: String = "system"
    @State private var showSearchRecentNotes: Bool = true

    // Todo tab state
    @State private var showTodoTab: Bool
    @State private var showTodoTabTitle: Bool
    @State private var showingTodoTab: Bool = false

    // Transcription tab state
    @State private var showTranscriptionTab: Bool
    @State private var showTranscriptionTabTitle: Bool
    @State private var showingTranscriptionTab: Bool = false

    @State private var popoverSize: CGSize
    @State private var popoverSizeLocked: Bool

    // Self-destruct custom date sheet
    @State private var expiryNoteID: UUID?

    @Environment(\.undoManager) private var undoManager

    private let settingsService = SettingsService.shared

    init() {
        let settings = SettingsService.shared.settings
        _showWordCounter = State(initialValue: settings.showWordCounter)
        _themeMode = State(initialValue: settings.themeMode)
        _showSearchRecentNotes = State(initialValue: settings.showSearchRecentNotes)
        _showTodoTab = State(initialValue: settings.showTodoTab)
        _showTodoTabTitle = State(initialValue: settings.showTodoTabTitle)
        _showTranscriptionTab = State(initialValue: settings.showTranscriptionTab)
        _showTranscriptionTabTitle = State(initialValue: settings.showTranscriptionTabTitle)
        _popoverSize = State(initialValue: CGSize(width: settings.popoverWidth, height: settings.popoverHeight))
        _popoverSizeLocked = State(initialValue: settings.popoverSizeLocked)
        _showEditorToolbar = State(initialValue: settings.showEditorToolbar)
    }

    var body: some View {
        mainContent
            .appAccent()
            .preferredColorScheme(getColorScheme())
            .onAppear {
                store.loadIfNeeded()
                handlePendingNoteSelection()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                guard let appDelegate = AppDelegate.shared else { return }
                // Keep the popover open while a Touch ID / password prompt has focus.
                if appDelegate.isHoldingPopoverForAuth { return }
                if appDelegate.popover?.isShown == true {
                    appDelegate.popover?.performClose(nil)
                }
            }
            .onReceive(searchManager.$noteIDToOpen) { noteID in
                handleSearchResultSelection(noteID)
            }
            .onDisappear {
                store.saveNow()
            }
            .alert("Delete note?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let id = deleteNoteID { deleteNote(id: id) }
                    deleteNoteID = nil
                }
                Button("Cancel", role: .cancel) { deleteNoteID = nil }
            } message: {
                Text("This note will be deleted permanently")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsChanged"))) { _ in
                let s = SettingsService.shared.settings
                showWordCounter = s.showWordCounter
                themeMode = s.themeMode
                showSearchRecentNotes = s.showSearchRecentNotes
                let newShowTodoTab = s.showTodoTab
                showTodoTab = newShowTodoTab
                showTodoTabTitle = s.showTodoTabTitle
                if !newShowTodoTab && showingTodoTab { showingTodoTab = false }
                let newShowTranscriptionTab = s.showTranscriptionTab
                showTranscriptionTab = newShowTranscriptionTab
                showTranscriptionTabTitle = s.showTranscriptionTabTitle
                if !newShowTranscriptionTab && showingTranscriptionTab { showingTranscriptionTab = false }
                popoverSizeLocked = s.popoverSizeLocked
                showEditorToolbar = s.showEditorToolbar
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PopoverSizeReset"))) { note in
                if let size = note.object as? CGSize { popoverSize = size }
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
            // Selecting a note tab deselects the todo tab
            .onChange(of: selectedNoteID) { _, _ in
                relockOnSwitchIfNeeded()
                if showingTodoTab { showingTodoTab = false }
                if showingTranscriptionTab { showingTranscriptionTab = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSPopover.didCloseNotification)) { _ in
                if settingsService.settings.noteRelockMode == "onPopoverClose" {
                    clearAllUnlocks()
                }
            }
    }

    // MARK: - Main View Components

    @ViewBuilder
    private var mainContent: some View {
        let visible = visibleNotes
        let activeID = activeNoteID(in: visible)

        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 6) {
                searchBar
                TabsBar(
                    notes: visible,
                    selectedNoteID: Binding(
                        get: { activeID },
                        set: { selectedNoteID = $0 }
                    ),
                    isEditingTabTitle: $isEditingTabTitle,
                    editedTabTitle: $editedTabTitle,
                    isTextFieldFocused: $isTextFieldFocused,
                    onRequestDelete: { id in
                        deleteNoteID = id
                        showDeleteAlert = true
                    },
                    onRename: { id, title in store.setTitle(title, id: id) },
                    onRequestTogglePin: { id in store.togglePin(id: id) },
                    onRequestToggleLock: { id in toggleLock(noteID: id) },
                    showTodoTab: showTodoTab,
                    showTodoTabTitle: showTodoTabTitle,
                    isTodoTabSelected: showingTodoTab,
                    onSelectTodoTab: {
                        relockOnSwitchIfNeeded()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingTodoTab = true
                            showingTranscriptionTab = false
                        }
                    },
                    onSelectNoteTab: { _ in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingTodoTab = false
                            showingTranscriptionTab = false
                        }
                    },
                    showTranscriptionTab: showTranscriptionTab,
                    showTranscriptionTabTitle: showTranscriptionTabTitle,
                    isTranscriptionTabSelected: showingTranscriptionTab,
                    onSelectTranscriptionTab: {
                        relockOnSwitchIfNeeded()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingTranscriptionTab = true
                            showingTodoTab = false
                        }
                    },
                    onRequestFloat: { id in
                        if let note = store.note(id) {
                            FloatingNoteWindowController.shared.show(note: note)
                        }
                    },
                    onSetExpiry: { id, date in store.setExpiry(date, id: id) },
                    onRequestCustomExpiry: { id in expiryNoteID = id },
                    onMove: { from, to in store.move(id: from, toPositionOf: to) }
                )

                noteArea(visible: visible, activeID: activeID)
                    .frame(maxHeight: .infinity)

                if let activeID, showEditorToolbar, !showingTodoTab, !showingTranscriptionTab {
                    EditorToolbar(
                        noteID: activeID,
                        onRequestDelete: { id in
                            deleteNoteID = id
                            showDeleteAlert = true
                        },
                        onRequestAddNote: { addNote() },
                        onRequestTogglePin: { id in store.togglePin(id: id) },
                        onRequestToggleLock: { id in toggleLock(noteID: id) }
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
    private func noteArea(visible: [Note], activeID: UUID?) -> some View {
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
                if let activeID {
                    NoteEditor(
                        noteID: activeID,
                        unlockedNoteIDs: $unlockedNoteIDs,
                        showWordCounter: showWordCounter,
                        onUnlock: unlockNoteFlow,
                        onToggleLock: toggleLock
                    )
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                } else {
                    emptyState(isFiltered: !visible.isEmpty || !searchText.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(isFiltered: Bool) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            if !store.isLoaded {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.bottom, 4)
                Text("Loading notes...")
                    .font(.title3.weight(.semibold))
                Text("Please wait while your notes are being loaded.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if isFiltered {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                Text("No matching notes")
                    .font(.title3.weight(.semibold))
                Text("No note matches “\(searchText)”.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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

    // MARK: - Selection

    /// The notes the tab bar shows, after the search filter.
    private var visibleNotes: [Note] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.notes }

        let query = trimmed.lowercased()
        return store.notes.filter { note in
            if note.title.lowercased().contains(query) { return true }
            // Never match on the hidden body of a locked note — that would leak its
            // contents through search. Only search text once it's been unlocked.
            let isReadable = !note.isLocked || unlockedNoteIDs.contains(note.id)
            return isReadable && note.text.lowercased().contains(query)
        }
    }

    /// The selected note if it's still visible, otherwise the first visible one.
    private func activeNoteID(in visible: [Note]) -> UUID? {
        if let selectedNoteID, visible.contains(where: { $0.id == selectedNoteID }) {
            return selectedNoteID
        }
        return visible.first?.id
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

    private func handlePendingNoteSelection() {
        guard let pending = searchManager.noteIDToOpen, store.contains(pending) else { return }
        searchText = ""
        isSearching = false
        selectedNoteID = pending
        searchManager.noteIDToOpen = nil
    }

    private func handleSearchResultSelection(_ noteID: UUID?) {
        guard let noteID, store.contains(noteID) else { return }
        searchText = ""
        isSearching = false
        showingTodoTab = false
        showingTranscriptionTab = false
        withAnimation { selectedNoteID = noteID }
        searchManager.noteIDToOpen = nil
    }

    private func addNote() {
        addNote(withText: "")
    }

    private func addNote(withText text: String) {
        let note = store.addNote(text: text)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedNoteID = note.id
            showingTodoTab = false
            showingTranscriptionTab = false
        }
    }

    private func deleteNote(id: UUID) {
        // Pick the neighbour to select *before* removing, so the editor never has
        // to fall back to "nothing selected" for a frame.
        let index = store.index(of: id)
        store.delete(id: id)
        if selectedNoteID == id || selectedNoteID == nil {
            if let index {
                let next = min(index, store.notes.count - 1)
                selectedNoteID = next >= 0 ? store.notes[next].id : nil
            } else {
                selectedNoteID = store.notes.first?.id
            }
        }
        unlockedNoteIDs.remove(id)
        relockWorkItems[id]?.cancel()
        relockWorkItems[id] = nil
    }

    private func unlockNoteFlow(noteID: UUID) {
        guard let note = store.note(noteID), note.isLocked else { return }
        Task { @MainActor in
            let authenticated = await AuthenticationService.shared.authenticate(reason: "Unlock \"\(note.title)\"")
            if authenticated {
                unlockedNoteIDs.insert(noteID)
                if settingsService.settings.noteRelockMode == "timer" {
                    scheduleTimerRelock(for: noteID)
                }
            }
        }
    }

    // MARK: - Auto Re-Lock

    /// Called when the visible note changes. In the default "onSwitch" mode this
    /// re-locks any note that was unlocked this session.
    private func relockOnSwitchIfNeeded() {
        if settingsService.settings.noteRelockMode == "onSwitch" {
            clearAllUnlocks()
        }
    }

    private func clearAllUnlocks() {
        relockWorkItems.values.forEach { $0.cancel() }
        relockWorkItems.removeAll()
        if !unlockedNoteIDs.isEmpty { unlockedNoteIDs.removeAll() }
    }

    private func scheduleTimerRelock(for id: UUID) {
        relockWorkItems[id]?.cancel()
        let minutes = max(1, settingsService.settings.noteRelockMinutes)
        let work = DispatchWorkItem {
            unlockedNoteIDs.remove(id)
            relockWorkItems[id] = nil
        }
        relockWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes) * 60, execute: work)
    }

    private func toggleLock(noteID: UUID) {
        guard let note = store.note(noteID) else { return }
        if note.isLocked {
            Task { @MainActor in
                let authenticated = await AuthenticationService.shared.authenticate(reason: "Remove lock from \"\(note.title)\"")
                if authenticated {
                    store.setLocked(false, id: noteID)
                    unlockedNoteIDs.remove(noteID)
                }
            }
        } else {
            Task { @MainActor in
                let configured = await AuthenticationService.shared.ensurePasswordOrBiometricsConfigured()
                if configured {
                    store.setLocked(true, id: noteID)
                    unlockedNoteIDs.remove(noteID)
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
