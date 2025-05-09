import SwiftUI
import AppKit

struct Note: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
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

    let savePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/notes.json")

    let controller = ContentViewController()

    init() {
        if let loadedNotes = loadNotes() {
            self._notes = State(initialValue: loadedNotes)
        } else {
            self._notes = State(initialValue: [])
        }

        let showInDock = SettingsManager.shared.settings.showInDock
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)

        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                if let screen = NSScreen.main {
                    let screenFrame = screen.frame
                    let windowSize = window.frame.size
                    let xPos = (screenFrame.width - windowSize.width) / 2
                    let yPos = (screenFrame.height - windowSize.height) / 2
                    window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if notes.isEmpty {
                Text("No notes available")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        ForEach(0..<notes.count, id: \..self) { index in
                            if isEditingTabTitle && selectedTab == index {
                                TextField("", text: $editedTabTitle, onCommit: {
                                    notes[selectedTab].title = editedTabTitle
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
                                Text(notes[index].title)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(6)
                                    .background(selectedTab == index ? Color.accentColor.opacity(0.3) : Color.clear)
                                    .cornerRadius(6)
                                    .contextMenu {
                                        Button("Titel bearbeiten") {
                                            editedTabTitle = notes[index].title
                                            isEditingTabTitle = true
                                            selectedTab = index
                                        }
                                        Button("Notiz löschen", role: .destructive) {
                                            deleteIndex = index
                                            showDeleteAlert = true
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        editedTabTitle = notes[index].title
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

                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            TextEditor(text: $notes[selectedTab].text)
                                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 2))
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .lineSpacing(6)
                                .font(.system(size: 16))
                                .onChange(of: notes[selectedTab].text) { _ in
                                    saveNotes()
                                }

                            HStack {
                                Text("Words: \(notes[selectedTab].text.split { $0.isWhitespace || $0.isNewline }.count)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .padding(.bottom, 4)
                                Spacer()
                            }
                        }
                        .padding(.top, 6)
                        .padding(.trailing, 10)
                    }
                }
            }

            HStack {
                Button(action: addNote) {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.count >= 5)

                Button(action: {
                    deleteIndex = selectedTab
                    showDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.isEmpty)
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
        .alert("Notiz löschen?", isPresented: $showDeleteAlert, presenting: deleteIndex) { index in
            Button("Löschen", role: .destructive) {
                notes.remove(at: index)
                selectedTab = max(0, selectedTab - 1)
                saveNotes()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Diese Notiz wird dauerhaft entfernt.")
        }
    }

    func showNativeMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(controller.openSettings(_:)), keyEquivalent: "")
        settingsItem.target = controller
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit DropNote", action: #selector(controller.quitApp(_:)), keyEquivalent: "q")
        quitItem.target = controller
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    func addNote() {
        guard notes.count < 5 else { return }
        let nextNumber = (1...).first { n in !notes.contains { $0.title == "Note \(n)" } } ?? notes.count + 1
        notes.append(Note(title: "Note \(nextNumber)", text: ""))
        selectedTab = notes.count - 1
        saveNotes()
    }

    func saveNotes() {
        let folderURL = savePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
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
}
