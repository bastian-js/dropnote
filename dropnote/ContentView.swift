import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct Note: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var images: [String] = []
}

class ContentViewController: NSObject {
    @objc func openSettings(_ sender: Any?) {
        DispatchQueue.main.async {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
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
    @State private var notes: [Note] = []
    @State private var selectedTab: Int = 0
    @State private var isEditingTabTitle: Bool = false
    @State private var editedTabTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showDeleteAlert: Bool = false
    @State private var deleteIndex: Int? = nil
    @State private var showWordCounter: Bool = SettingsManager.shared.settings.showWordCounter
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showPreview: Bool = false

    private let notesDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/Notes")

    private let savePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    private let controller = ContentViewController()

    private var filteredIndices: [Int] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(notes.indices)
        }
        let q = searchText.lowercased()
        return notes.indices.filter { i in
            notes[i].title.lowercased().contains(q) ||
            notes[i].text.lowercased().contains(q)
        }
    }

    private var activeIndex: Int? {
        if filteredIndices.contains(selectedTab) {
            return selectedTab
        }
        return filteredIndices.first
    }

    init() {
        if let loaded = loadNotes() {
            _notes = State(initialValue: loaded)
        }
        try? FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        let showInDock = SettingsManager.shared.settings.showInDock
        NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                if isSearching {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .transition(.opacity)
                        .focused($isSearchFieldFocused)
                        .onChange(of: isSearchFieldFocused) { focused in
                            if !focused && searchText.isEmpty {
                                withAnimation { isSearching = false }
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.async {
                                self.isSearchFieldFocused = true
                            }
                        }
                } else {
                    Button(action: {
                        withAnimation { isSearching = true }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .padding(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            Button(action: {
                withAnimation { isSearching = true }
                DispatchQueue.main.async {
                    self.isSearchFieldFocused = true
                }
            }) {
                EmptyView()
            }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)

            if filteredIndices.isEmpty {
                Text("No notes available")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        ForEach(filteredIndices, id: \.self) { index in
                            let note = notes[index]
                            if isEditingTabTitle && selectedTab == index {
                                TextField("", text: $editedTabTitle, onCommit: {
                                    notes[index].title = editedTabTitle
                                    isEditingTabTitle = false
                                    saveNotes()
                                })
                                .focused($isTextFieldFocused)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isTextFieldFocused = true
                                    }
                                }
                            } else {
                                Text(note.title)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(6)
                                    .background(selectedTab == index ? Color.accentColor.opacity(0.3) : Color.clear)
                                    .cornerRadius(6)
                                    .contextMenu {
                                        Button("Edit Title") {
                                            editedTabTitle = note.title
                                            isEditingTabTitle = true
                                            selectedTab = index
                                        }
                                        Button("Delete Note", role: .destructive) {
                                            deleteIndex = index
                                            showDeleteAlert = true
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        editedTabTitle = note.title
                                        isEditingTabTitle = true
                                        selectedTab = index
                                    }
                                    .onTapGesture {
                                        selectedTab = index
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    if let current = activeIndex {
                        VStack(alignment: .leading, spacing: 4) {
                            if showPreview {
                                ScrollView {
                                    markdownText(notes[current].text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(notes[current].images, id: \.self) { img in
                                        let url = notesDirectory.appendingPathComponent(notes[current].id.uuidString).appendingPathComponent(img)
                                        if let nsimg = NSImage(contentsOf: url) {
                                            Image(nsImage: nsimg)
                                                .resizable()
                                                .scaledToFit()
                                        }
                                    }
                                }
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                TextEditor(text: $notes[current].text)
                                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 2))
                                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .lineSpacing(6)
                                    .font(.system(size: 16))
                                    .onChange(of: notes[current].text) { _ in
                                        saveNotes()
                                    }
                                    .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                                        handleDrop(providers: providers, index: current)
                                    }
                            }

                            if showWordCounter {
                                HStack {
                                    Text("Words: \(notes[current].text.split { $0.isWhitespace || $0.isNewline }.count)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                        .padding(.bottom, 4)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 6)
                        .padding(.trailing, 10)
                    } else {
                        Text("No results")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: addNote) {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: insertImage) {
                    Label("Add Image", systemImage: "photo")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(activeIndex == nil)

                Button(action: {
                    deleteIndex = activeIndex ?? selectedTab
                    showDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.isEmpty)

                Button(action: {
                    editedTabTitle = notes[selectedTab].title
                    isEditingTabTitle = true
                }) {
                    Label("Edit Title", systemImage: "pencil")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.isEmpty)
                Spacer()
                Toggle("Preview", isOn: $showPreview)
                    .toggleStyle(SwitchToggleStyle())
                    .frame(width: 100)
            }
            .padding(.bottom, 5)

            HStack {
                Spacer()
                Button(action: showNativeMenu) {
                    Image(systemName: "gear")
                        .padding(5)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.top, 8)
        .frame(width: 320, height: 420)
        .onDisappear {
            saveNotes()
        }
        .alert("Delete note?", isPresented: $showDeleteAlert, presenting: deleteIndex) { index in
            Button("Delete", role: .destructive) {
                notes.remove(at: index)
                selectedTab = max(0, selectedTab - 1)
                saveNotes()
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This note will be deleted permanently")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsChanged")), perform: { _ in
            showWordCounter = SettingsManager.shared.settings.showWordCounter
        })
    }

    func tabButton(for note: Note, index: Int) -> some View {
        Group {
            if isEditingTabTitle && selectedTab == index {
                TextField("", text: $editedTabTitle, onCommit: {
                    notes[index].title = editedTabTitle
                    isEditingTabTitle = false
                    saveNotes()
                })
                .focused($isTextFieldFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
            } else {
                Text(note.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(6)
                    .background(selectedTab == index ? Color.accentColor.opacity(0.3) : Color.clear)
                    .cornerRadius(6)
                    .contextMenu {
                        Button("Edit Title") {
                            editedTabTitle = note.title
                            isEditingTabTitle = true
                            selectedTab = index
                        }
                        Button("Delete Note", role: .destructive) {
                            deleteIndex = index
                            showDeleteAlert = true
                        }
                    }
                    .onTapGesture(count: 2) {
                        editedTabTitle = note.title
                        isEditingTabTitle = true
                        selectedTab = index
                    }
                    .onTapGesture {
                        selectedTab = index
                    }
            }
        }
    }

    func showNativeMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(controller.openSettings(_:)), keyEquivalent: "")
        settingsItem.target = controller
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit DropNote", action: #selector(controller.quitApp(_:)), keyEquivalent: "q")
        quitItem.target = controller
        menu.addItem(quitItem)
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    func addNote() {
        let nextNumber = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? notes.count + 1
        let newNote = Note(title: "Note \(nextNumber)", text: "")
        notes.append(newNote)
        let folder = notesDirectory.appendingPathComponent(newNote.id.uuidString)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        selectedTab = notes.count - 1
        saveNotes()
    }

    func saveNotes() {
        let folderURL = savePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        for note in notes {
            let folder = notesDirectory.appendingPathComponent(note.id.uuidString)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        if let data = try? JSONEncoder().encode(notes) {
            try? data.write(to: savePath)
        }
    }

    func loadNotes() -> [Note]? {
        guard FileManager.default.fileExists(atPath: savePath.path),
              let data = try? Data(contentsOf: savePath),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            return nil
        }
        return decoded
    }

    /// Very small Markdown renderer for preview mode
    func markdownText(_ text: String) -> Text {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var result = Text("")
        for (i, line) in lines.enumerated() {
            var t: Text
            if line.hasPrefix("## ") {
                t = Text(String(line.dropFirst(3))).font(.title2).bold()
            } else if line.hasPrefix("# ") {
                t = Text(String(line.dropFirst(2))).font(.title).bold()
            } else {
                t = Text(String(line))
            }
            result = result + t
            if i < lines.count - 1 { result = result + Text("\n") }
        }
        return result
    }

    func insertImage() {
        guard let current = activeIndex else { return }
        let panel = NSOpenPanel()
        panel.allowedFileTypes = NSImage.imageTypes
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let folder = notesDirectory.appendingPathComponent(notes[current].id.uuidString)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let dest = folder.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                notes[current].images.append(url.lastPathComponent)
                saveNotes()
            } catch {
                print("Failed to copy image:", error.localizedDescription)
            }
        }
    }

    func handleDrop(providers: [NSItemProvider], index: Int) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        let folder = notesDirectory.appendingPathComponent(notes[index].id.uuidString)
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let dest = folder.appendingPathComponent(url.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: dest.path) {
                                try FileManager.default.removeItem(at: dest)
                            }
                            try FileManager.default.copyItem(at: url, to: dest)
                            notes[index].images.append(url.lastPathComponent)
                            saveNotes()
                        } catch {
                            print("Drop copy failed", error.localizedDescription)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
