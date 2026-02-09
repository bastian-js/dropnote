import SwiftUI
import AppKit
import LocalAuthentication

struct Note: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var isPinned: Bool = false
    var isLocked: Bool = false
    var attributedTextRTF: Data?
    var lastModified: Date?
    
    mutating func updateModifiedDate() {
        lastModified = Date()
    }
}

class ContentViewController: NSObject {
    @objc func openSettings(_ sender: Any?) {
        DispatchQueue.main.async {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            settingsWindow.center()
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.title = "Settings"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quitApp(_ sender: Any?) {
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct ContentView: View {
    @StateObject private var searchManager = SearchManager.shared
    
    @State private var notes: [Note] = []
    @State private var selectedTab: Int = 0
    @State private var isLoadingNotes: Bool = true

    @State private var isEditingTabTitle: Bool = false
    @State private var editedTabTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool

    @State private var showDeleteAlert: Bool = false
    @State private var deleteIndex: Int? = nil

    @State private var showWordCounter: Bool

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    @State private var showEditorToolbar: Bool = true
    
    @State private var noteIDToOpen: UUID? = nil

    private let editorHeight: CGFloat = 200
    private let toolbarHeight: CGFloat = 38

    @State private var isSaving: Bool = false
    @State private var lastSavedAt: Date? = nil
    @State private var pendingSaveWorkItem: DispatchWorkItem? = nil
    @State private var savingStatusTimer: Timer? = nil

    @State private var unlockedNoteIDs: Set<UUID> = []

    @Environment(\.undoManager) private var undoManager

    private func closeDropdownsAndEditing() {
        if isSearching {
            withAnimation { isSearching = false }
            isSearchFieldFocused = false
        }
        if isEditingTabTitle {
            isTextFieldFocused = false
            isEditingTabTitle = false
        }
    }

    private let savePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/notes.json")

    private let controller = ContentViewController()

    private var filteredIndices: [Int] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [Int]
        if trimmed.isEmpty {
            base = Array(notes.indices)
        } else {
            let q = trimmed.lowercased()
            base = notes.indices.filter { i in
                notes[i].title.lowercased().contains(q) ||
                notes[i].text.lowercased().contains(q)
            }
        }

        return base.sorted { a, b in
            let na = notes[a]
            let nb = notes[b]
            if na.isPinned != nb.isPinned { return na.isPinned && !nb.isPinned }
            return na.title.localizedCaseInsensitiveCompare(nb.title) == .orderedAscending
        }
    }

    private var activeIndex: Int? {
        print("DEBUG activeIndex: selectedTab=\(selectedTab), filteredIndices=\(filteredIndices), contains=\(filteredIndices.contains(selectedTab))")
        if filteredIndices.contains(selectedTab) { 
            print("DEBUG activeIndex returning selectedTab: \(selectedTab)")
            return selectedTab 
        }
        let firstIndex = filteredIndices.first
        print("DEBUG activeIndex returning first: \(String(describing: firstIndex))")
        return firstIndex
    }

    init() {
        let s = SettingsManager.shared.settings
        _showWordCounter = State(initialValue: s.showWordCounter)
        // Start with a dummy note so UI renders immediately, will be replaced when notes load
        _notes = State(initialValue: [Note(title: "Loading...", text: "")])
        _isLoadingNotes = State(initialValue: true)

        let showInDock = s.showInDock
        NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    var body: some View {
        mainContent
        .onAppear {
            // Load notes asynchronously if not already loaded
            if isLoadingNotes {
                DispatchQueue.global(qos: .userInitiated).async {
                    if let loaded = ContentView.loadNotesStatic(savePath: FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Application Support/DropNote/notes.json")) {
                        DispatchQueue.main.async {
                            self.notes = loaded
                            self.isLoadingNotes = false
                            
                            // If there's a pending note to open from search, open it now
                            if let noteIDToOpen = self.searchManager.noteIDToOpen,
                               let index = self.notes.firstIndex(where: { $0.id == noteIDToOpen }) {
                                print("Opening note from SearchManager at index \(index): \(self.notes[index].title)")
                                self.searchText = ""
                                self.isSearching = false
                                self.selectedTab = index
                                self.searchManager.noteIDToOpen = nil
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isLoadingNotes = false
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Close popover when app becomes inactive
            if let appDelegate = AppDelegate.shared, appDelegate.popover?.isShown == true {
                appDelegate.popover?.performClose(nil)
            }
        }
        .onReceive(searchManager.$noteIDToOpen) { noteID in
            // When SearchManager notifies of a note to open
            if let noteID = noteID, !isLoadingNotes {
                print("ContentView: SearchManager changed noteIDToOpen to \(noteID)")
                
                if let index = notes.firstIndex(where: { $0.id == noteID }) {
                    print("Found note at index: \(index), title: \(notes[index].title)")
                    
                    // Clear search state FIRST
                    searchText = ""
                    isSearching = false
                    
                    // Then select the tab
                    withAnimation {
                        selectedTab = index
                    }
                    
                    // Clear the request
                    searchManager.noteIDToOpen = nil
                }
            }
        }
        .onDisappear { saveNotes() }
        .alert("Delete note?", isPresented: $showDeleteAlert, presenting: deleteIndex) { index in
            Button("Delete", role: .destructive) {
                notes.remove(at: index)
                selectedTab = max(0, min(selectedTab, notes.count - 1))
                saveNotes()
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This note will be deleted permanently")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsChanged"))) { _ in
            showWordCounter = SettingsManager.shared.settings.showWordCounter
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 6) {
            searchBar
            tabsBar

            noteArea
                .frame(maxHeight: .infinity)

            bottomBar
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
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
                    controller.openSettings(nil)
                }
                Divider()
                Button("Quit DropNote") {
                    controller.quitApp(nil)
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
                            withAnimation { isSearching = false }
                        }
                    }
                    .onAppear {
                            DispatchQueue.main.async { self.isSearchFieldFocused = true }
                        }
            } else {
                Spacer()
                Button {
                    withAnimation { isSearching = true }
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
    private var tabsBar: some View {
        TabsBarView(
            notes: $notes,
            filteredIndices: filteredIndices,
            selectedTab: $selectedTab,
            isEditingTabTitle: $isEditingTabTitle,
            editedTabTitle: $editedTabTitle,
            isTextFieldFocused: $isTextFieldFocused,
            requestDelete: { index in
                deleteIndex = index
                showDeleteAlert = true
            },
            persist: saveNotes,
            requestTogglePin: { index in
                notes[index].isPinned.toggle()
                scheduleSave()
            },
            requestToggleLock: { index in
                toggleLock(noteIndex: index)
            }
        )
    }

    @ViewBuilder
    private var noteArea: some View {
        Group {
            if filteredIndices.isEmpty {
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
            } else if let current = activeIndex {
                noteAreaContent(current: current)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    .id(notes[current].id)
            }
        }
    }

    @ViewBuilder
    private func noteAreaContent(current: Int) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )

                Group {
                    if notes[current].isLocked && !unlockedNoteIDs.contains(notes[current].id) {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                            Text("Locked")
                                .font(.headline)
                            Text("Unlock to view and edit this note.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Unlock") {
                                unlockNoteFlow(noteIndex: current)
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                    } else {
                        VStack(spacing: 0) {
                            FormattingToolbar(
                                onBoldTap: {
                                    if let window = NSApplication.shared.keyWindow,
                                       let textView = RichTextEditor.getTextViewFromWindow(window) {
                                        RichTextEditor.applyBold(to: textView)
                                        notes[current].text = textView.string
                                        if let rtfData = try? textView.attributedString().data(from: NSRange(location: 0, length: textView.attributedString().length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                                            notes[current].attributedTextRTF = rtfData
                                        }
                                        scheduleSave()
                                    }
                                },
                                onItalicTap: {
                                    if let window = NSApplication.shared.keyWindow,
                                       let textView = RichTextEditor.getTextViewFromWindow(window) {
                                        RichTextEditor.applyItalic(to: textView)
                                        notes[current].text = textView.string
                                        if let rtfData = try? textView.attributedString().data(from: NSRange(location: 0, length: textView.attributedString().length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                                            notes[current].attributedTextRTF = rtfData
                                        }
                                        scheduleSave()
                                    }
                                },
                                onUnderlineTap: {
                                    if let window = NSApplication.shared.keyWindow,
                                       let textView = RichTextEditor.getTextViewFromWindow(window) {
                                        RichTextEditor.applyUnderline(to: textView)
                                        notes[current].text = textView.string
                                        if let rtfData = try? textView.attributedString().data(from: NSRange(location: 0, length: textView.attributedString().length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                                            notes[current].attributedTextRTF = rtfData
                                        }
                                        scheduleSave()
                                    }
                                },
                                onUpdateFormats: { _, _, _ in }
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            
                            RichTextEditor(
                                text: $notes[current].text,
                                attributedTextRTF: notes[current].attributedTextRTF,
                                onTextChange: scheduleSave,
                                onAttributedChange: { rtfData in
                                    notes[current].attributedTextRTF = rtfData
                                    scheduleSave()
                                }
                            )
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 6))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if showWordCounter && !notes[current].isLocked {
                    VStack {
                        Spacer()
                        HStack {
                            Text("Words: \(notes[current].text.split { $0.isWhitespace || $0.isNewline }.count)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 12)
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 0)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let current = activeIndex, showEditorToolbar {
            editorToolbar(current: current)
        }
    }

    private func editorToolbar(current: Int) -> some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            
            Button(action: addNote) { 
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("New Note")

            Button {
                deleteIndex = current
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Delete")

            Button {
                notes[current].isPinned.toggle()
                scheduleSave()
            } label: {
                Image(systemName: notes[current].isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(notes[current].isPinned ? "Unpin" : "Pin")

            Button {
                toggleLock(noteIndex: current)
            } label: {
                Image(systemName: notes[current].isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(notes[current].isLocked ? "Unlock / remove lock" : "Lock")

            Menu {
                Button("Copy as Plain Text") { copyPlainText(noteIndex: current) }
                Divider()
                Button("Export as TXT…") { exportAsTXT(noteIndex: current) }
                Button("Export as PDF…") { exportAsPDF(noteIndex: current) }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .menuIndicator(.hidden)
            .help("Share / Export")
            
            Spacer(minLength: 0)
            
            if isSaving {
                Text("Saving...")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            } else {
                Text("Saved")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
                .frame(maxWidth: 8)
        }
        .frame(maxWidth: .infinity, minHeight: toolbarHeight, maxHeight: toolbarHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private var settingsButton: some View {
        Menu {
            Button("Settings") {
                controller.openSettings(nil)
            }
            Divider()
            Button("Quit DropNote") {
                controller.quitApp(nil)
            }
        } label: {
            ZStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 44, height: toolbarHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
    }



    private func scheduleSave() {
        if let current = activeIndex {
            notes[current].updateModifiedDate()
        }
        
        pendingSaveWorkItem?.cancel()
        isSaving = true

        let work = DispatchWorkItem { [savePath] in
            DispatchQueue.main.async {
                saveNotes()
                lastSavedAt = Date()
                
                SearchIndexManager.shared.indexNotes()
                
                savingStatusTimer?.invalidate()
                savingStatusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    isSaving = false
                }
            }
        }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func unlockNoteFlow(noteIndex: Int) {
        let note = notes[noteIndex]
        guard note.isLocked else { return }

        Task { @MainActor in
            let ok = await NotesAuth.shared.authenticate(reason: "Unlock “\(note.title)”")
            if ok {
                unlockedNoteIDs.insert(note.id)
            }
        }
    }

    private func toggleLock(noteIndex: Int) {
        let note = notes[noteIndex]
        if note.isLocked {
            Task { @MainActor in
                let ok = await NotesAuth.shared.authenticate(reason: "Remove lock from “\(note.title)”")
                if ok {
                    notes[noteIndex].isLocked = false
                    unlockedNoteIDs.remove(note.id)
                    scheduleSave()
                }
            }
        } else {
            Task { @MainActor in
                let ok = await NotesAuth.shared.ensurePasswordOrBiometricsConfigured()
                if ok {
                    notes[noteIndex].isLocked = true
                    unlockedNoteIDs.remove(note.id)
                    scheduleSave()
                }
            }
        }
    }

    private func copyPlainText(noteIndex: Int) {
        guard !notes[noteIndex].isLocked || unlockedNoteIDs.contains(notes[noteIndex].id) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(notes[noteIndex].text, forType: .string)
    }

    private func exportAsTXT(noteIndex: Int) {
        guard !notes[noteIndex].isLocked || unlockedNoteIDs.contains(notes[noteIndex].id) else { return }
        let note = notes[noteIndex]

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(note.title).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try note.text.data(using: .utf8)?.write(to: url, options: .atomic)
            } catch {
                print("Export TXT failed:", error.localizedDescription)
            }
        }
    }

    private func exportAsPDF(noteIndex: Int) {
        guard !notes[noteIndex].isLocked || unlockedNoteIDs.contains(notes[noteIndex].id) else { return }
        let note = notes[noteIndex]

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(note.title).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let pdf = makeSimplePDFData(title: note.title, body: note.text, attributedTextRTF: note.attributedTextRTF)
                try pdf.write(to: url, options: .atomic)
            } catch {
                print("Export PDF failed:", error.localizedDescription)
            }
        }
    }

    private func makeSimplePDFData(title: String, body: String, attributedTextRTF: Data?) -> Data {
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        view.isEditable = false
        view.textContainerInset = NSSize(width: 36, height: 36)
        
        // Create attributed string for title
        let titleAttr = NSAttributedString(string: "\(title)\n\n", attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)])
        let mutableAttr = NSMutableAttributedString(attributedString: titleAttr)
        
        // Try to use formatted body if RTF available
        if let rtfData = attributedTextRTF,
           let bodyAttr = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            mutableAttr.append(bodyAttr)
        } else {
            // Fallback to plain text
            let bodyAttr = NSAttributedString(string: body, attributes: [.font: NSFont.systemFont(ofSize: 12)])
            mutableAttr.append(bodyAttr)
        }
        
        view.textStorage?.setAttributedString(mutableAttr)
        return view.dataWithPDF(inside: view.bounds)
    }

    func addNote() {
        let nextNumber = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? (notes.count + 1)
        var newNote = Note(title: "Note \(nextNumber)", text: "")
        newNote.updateModifiedDate()
        withAnimation(.easeInOut(duration: 0.2)) {
            notes.append(newNote)
            selectedTab = notes.count - 1
        }
        saveNotes()
        SearchIndexManager.shared.indexNotes()
    }

    func saveNotes() {
        let folderURL = savePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        if let data = try? JSONEncoder().encode(notes) {
            try? data.write(to: savePath)
        }
    }

    static func loadNotesStatic(savePath: URL) -> [Note]? {
        guard FileManager.default.fileExists(atPath: savePath.path),
              let data = try? Data(contentsOf: savePath),
              var decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            return nil
        }
        
        // Ensure all notes have a lastModified date
        var needsSave = false
        for i in 0..<decoded.count {
            if decoded[i].lastModified == nil {
                decoded[i].lastModified = Date()
                needsSave = true
            }
        }
        
        // Save back if we added dates
        if needsSave {
            if let updatedData = try? JSONEncoder().encode(decoded) {
                try? updatedData.write(to: savePath)
            }
        }
        
        return decoded
    }

    func loadNotes() -> [Note]? {
        Self.loadNotesStatic(savePath: savePath)
    }
}

private struct TabsBarView: View {
    @Binding var notes: [Note]
    let filteredIndices: [Int]
    @Binding var selectedTab: Int

    @Binding var isEditingTabTitle: Bool
    @Binding var editedTabTitle: String
    @FocusState.Binding var isTextFieldFocused: Bool

    let requestDelete: (Int) -> Void
    let persist: () -> Void
    let requestTogglePin: (Int) -> Void
    let requestToggleLock: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(filteredIndices, id: \.self) { index in
                    tabItem(index: index)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func tabItem(index: Int) -> some View {
        if isEditingTabTitle && selectedTab == index {
            TextField("", text: $editedTabTitle, onCommit: {
                notes[index].title = editedTabTitle
                isEditingTabTitle = false
                persist()
            })
            .focused($isTextFieldFocused)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(6)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(6)
            .fixedSize(horizontal: true, vertical: false)
            .onChange(of: isTextFieldFocused) { _, focused in
                guard !focused, isEditingTabTitle, selectedTab == index else { return }
                let trimmed = editedTabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    notes[index].title = trimmed
                    persist()
                }
                isEditingTabTitle = false
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        } else {
            HStack(spacing: 6) {
                if notes[index].isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Text(notes[index].title)
                    .lineLimit(1)
            }
            .padding(6)
                .background(selectedTab == index ? Color.accentColor.opacity(0.3) : Color.clear)
                .cornerRadius(6)
                .fixedSize(horizontal: true, vertical: false)
                .contextMenu {
                    Button(notes[index].isPinned ? "Unpin" : "Pin") {
                        requestTogglePin(index)
                    }
                    Button("Edit Title") {
                        editedTabTitle = notes[index].title
                        isEditingTabTitle = true
                        selectedTab = index
                    }
                    Button(notes[index].isLocked ? "Remove Lock" : "Lock") {
                        requestToggleLock(index)
                    }
                    Button("Delete Note", role: .destructive) {
                        requestDelete(index)
                    }
                }
                .onTapGesture(count: 2) {
                    editedTabTitle = notes[index].title
                    isEditingTabTitle = true
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = index
                    }
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = index
                    }
                }
        }
    }
}
