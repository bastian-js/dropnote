import SwiftUI
import AppKit
import LocalAuthentication

struct ContentView: View {
    @StateObject private var searchManager = SearchManager.shared
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
    
    @State private var showEditorToolbar: Bool = true
    @State private var noteIDToOpen: UUID?
    
    @State private var isSaving: Bool = false
    @State private var lastSavedAt: Date?
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    @State private var savingStatusTimer: Timer?
    
    @State private var unlockedNoteIDs: Set<UUID> = []
    
    @Environment(\.undoManager) private var undoManager
    
    private let editorHeight: CGFloat = 200
    private let toolbarHeight: CGFloat = 38
    private let notesService = NotesFileService.shared
    private let settingsService = SettingsService.shared
    
    init() {
        let settings = SettingsService.shared.settings
        _showWordCounter = State(initialValue: settings.showWordCounter)
        _notes = State(initialValue: [Note(title: "Loading...", text: "")])
        _isLoadingNotes = State(initialValue: true)
    }
    
    var body: some View {
        mainContent
            .onAppear {
                loadNotesIfNeeded()
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
                Button("Delete", role: .destructive) {
                    deleteNote(at: index)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This note will be deleted permanently")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsChanged"))) { _ in
                showWordCounter = SettingsService.shared.settings.showWordCounter
            }
    }
    
    // MARK: - Main View Components
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 6) {
            searchBar
            TabsBar(
                notes: $notes,
                filteredIndices: filteredIndices,
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
                onRequestToggleLock: { index in
                    toggleLock(noteIndex: index)
                }
            )
            
            noteArea
                .frame(maxHeight: .infinity)
            
            if let current = activeIndex, showEditorToolbar {
                EditorToolbar(
                    noteIndex: current,
                    notes: $notes,
                    onRequestDelete: { index in
                        deleteIndex = index
                        showDeleteAlert = true
                    },
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
                .onTapGesture {
                    closeDropdownsAndEditing()
                }
        )
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button("Settings") {
                    openSettings(nil)
                }
                Divider()
                Button("Quit DropNote") {
                    quitApp(nil)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)
            
            if isSearching {
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                    .focused($isSearchFieldFocused)
                    .onChange(of: isSearchFieldFocused) { _, focused in
                        if !focused {
                            withAnimation {
                                isSearching = false
                            }
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            self.isSearchFieldFocused = true
                        }
                    }
            } else {
                Spacer()
                Button {
                    withAnimation {
                        isSearching = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var noteArea: some View {
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .id(notes[current].id)
            }
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            
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
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .transition(.opacity)
    }
    
    // MARK: - Computed Properties
    
    private var filteredIndices: [Int] {
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
            if noteA.isPinned != noteB.isPinned {
                return noteA.isPinned && !noteB.isPinned
            }
            return noteA.title.localizedCaseInsensitiveCompare(noteB.title) == .orderedAscending
        }
    }
    
    private var activeIndex: Int? {
        if filteredIndices.contains(selectedTab) {
            return selectedTab
        }
        return filteredIndices.first
    }
    
    // MARK: - Private Methods
    
    private func closeDropdownsAndEditing() {
        if isSearching {
            withAnimation {
                isSearching = false
            }
            isSearchFieldFocused = false
        }
        if isEditingTabTitle {
            isTextFieldFocused = false
            isEditingTabTitle = false
        }
    }
    
    private func loadNotesIfNeeded() {
        guard isLoadingNotes else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let loaded = notesService.loadNotes() {
                DispatchQueue.main.async {
                    self.notes = loaded
                    self.isLoadingNotes = false
                    handlePendingNoteSelection()
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingNotes = false
                }
            }
        }
    }
    
    private func handlePendingNoteSelection() {
        guard let noteIDToOpen = searchManager.noteIDToOpen,
              let index = notes.firstIndex(where: { $0.id == noteIDToOpen }) else {
            return
        }
        
        searchText = ""
        isSearching = false
        selectedTab = index
        searchManager.noteIDToOpen = nil
    }
    
    private func handleSearchResultSelection(_ noteID: UUID?) {
        guard let noteID = noteID, !isLoadingNotes else {
            return
        }
        
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else {
            return
        }
        
        searchText = ""
        isSearching = false
        withAnimation {
            selectedTab = index
        }
        searchManager.noteIDToOpen = nil
    }
    
    private func scheduleSave() {
        if let current = activeIndex {
            notes[current].updateModifiedDate()
        }
        
        pendingSaveWorkItem?.cancel()
        isSaving = true
        
        let work = DispatchWorkItem {
            DispatchQueue.main.async {
                self.saveNotes()
                self.lastSavedAt = Date()
                NoteSearchService.shared.indexNotes()
                
                self.savingStatusTimer?.invalidate()
                self.savingStatusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    self.isSaving = false
                }
            }
        }
        
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    private func saveNotes() {
        notesService.saveNotes(notes)
    }
    
    private func addNote() {
        let nextNumber = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? (notes.count + 1)
        var newNote = Note(title: "Note \(nextNumber)", text: "")
        newNote.updateModifiedDate()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            notes.append(newNote)
            selectedTab = notes.count - 1
        }
        saveNotes()
        NoteSearchService.shared.indexNotes()
    }
    
    private func deleteNote(at index: Int) {
        notes.remove(at: index)
        selectedTab = max(0, min(selectedTab, notes.count - 1))
        saveNotes()
    }
    
    private func unlockNoteFlow(noteIndex: Int) {
        let note = notes[noteIndex]
        guard note.isLocked else {
            return
        }
        
        Task { @MainActor in
            let authenticated = await AuthenticationService.shared.authenticate(
                reason: "Unlock \"\(note.title)\""
            )
            if authenticated {
                unlockedNoteIDs.insert(note.id)
            }
        }
    }
    
    private func toggleLock(noteIndex: Int) {
        let note = notes[noteIndex]
        if note.isLocked {
            Task { @MainActor in
                let authenticated = await AuthenticationService.shared.authenticate(
                    reason: "Remove lock from \"\(note.title)\""
                )
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
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.center()
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.title = "Settings"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func quitApp(_ sender: Any?) {
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
