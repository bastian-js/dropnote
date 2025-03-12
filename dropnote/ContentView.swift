import SwiftUI
import AppKit

struct ContentView: View {
    @State private var notes: [String] = []
    @State private var selectedTab: Int = 0
    @State private var showSettingsWindow = false
    @State private var showMenu = false
    
    let savePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    
    init() {
        if let loadedNotes = loadNotes() {
            self._notes = State(initialValue: loadedNotes)
        } else {
            self._notes = State(initialValue: [""])
        }
        
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
                TabView(selection: $selectedTab) {
                    ForEach(0..<notes.count, id: \..self) { index in
                        VStack {
                            TextEditor(text: $notes[index])
                                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 2))
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .lineSpacing(6)
                                .font(.system(size: 16))
                                .onChange(of: notes[index]) { _ in
                                    saveNotes()
                                }
                        }
                        .padding(12)
                        .tabItem {
                            Text(getTabTitle(from: notes[index]))
                        }
                        .tag(index)
                    }
                }
                .frame(minHeight: 300)
                .padding(.top, 10)
            }
            
            HStack {
                Button(action: addNote) {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.count >= 5)
                
                Button(action: removeNote) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.isEmpty)
            }
            .padding(.bottom, 5)
            
            HStack {
                Spacer()
                Button(action: { showMenu.toggle() }) {
                    Image(systemName: "gear")
                        .padding(5)
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showMenu, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Settings", action: openSettingsWindow)
                        Button("Exit", action: { NSApplication.shared.terminate(nil) })
                        Divider()
                        Text("2025 © bastian-js")
                            .foregroundColor(.gray)
                            .disabled(true)
                    }
                    .padding()
                    .frame(width: 150)
                }
            }
        }
        .frame(width: 320, height: 420)
        .onDisappear {
            saveNotes()
        }
    }
    
    func openSettingsWindow() {
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
    
    func addNote() {
        if notes.count < 5 {
            notes.append("")
            selectedTab = notes.count - 1
            saveNotes()
        }
    }
    
    func removeNote() {
        if !notes.isEmpty {
            notes.remove(at: selectedTab)
            selectedTab = max(0, selectedTab - 1)
            saveNotes()
        }
    }
    
    func saveNotes() {
        do {
            let folderURL = savePath.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            let data = try JSONEncoder().encode(notes)
            try data.write(to: savePath, options: .atomic)
            
            Swift.print("Notizen gespeichert: \(notes)")
        } catch {
            Swift.print("Fehler beim Speichern: \(error.localizedDescription)")
        }
    }
    
    func loadNotes() -> [String]? {
        do {
            if FileManager.default.fileExists(atPath: savePath.path) {
                let data = try Data(contentsOf: savePath)
                let loadedNotes = try JSONDecoder().decode([String].self, from: data)
                
                Swift.print("Notizen erfolgreich geladen: \(loadedNotes)")
                return loadedNotes
            } else {
                Swift.print("Datei existiert nicht, neue wird erstellt.")
                saveNotes()
                return nil
            }
        } catch {
            Swift.print("Fehler beim Laden: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getTabTitle(from text: String) -> String {
        let words = text.split(separator: " ")
        let title = words.first.map(String.init) ?? "New Note"
        return title.count > 7 ? "New Note" : title
    }
}
