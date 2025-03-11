import SwiftUI
import AppKit

struct ContentView: View {
    @State private var notes: [String] = []
    @State private var selectedTab: Int = 0
    @State private var showSettings = false
    @State private var showMenu = false
    
    let savePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    
    init() {
        if let loadedNotes = loadNotes() {
            self._notes = State(initialValue: loadedNotes)
        } else {
            self._notes = State(initialValue: [""])
        }
        
        // Fenster in die Mitte des Bildschirms setzen
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
        VStack(spacing: 5) { // 🔥 Weniger Abstand zwischen Textfeld, Buttons und Zahnrad
            if notes.isEmpty {
                Text("Keine Notizen vorhanden")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                TabView(selection: $selectedTab) {
                    ForEach(0..<notes.count, id: \..self) { index in
                        VStack {
                            TextEditor(text: $notes[index])
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                .onChange(of: notes[index]) { _ in
                                    saveNotes()
                                }
                        }
                        .padding()
                        .tabItem {
                            Text(getTabTitle(from: notes[index]))
                        }
                        .tag(index)
                    }
                }
                .frame(minHeight: 300)
                .padding(.top, 5) // 🔥 Weniger Abstand oben
            }
            
            HStack {
                Button(action: addNote) {
                    Label("Neue Notiz", systemImage: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: removeNote) {
                    Label("Löschen", systemImage: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(notes.isEmpty)
            }
            .padding(.bottom, 5)
            
            HStack {
                Spacer()
                Menu {
                    Button("Einstellungen", action: { showSettings.toggle() })
                    Button("Beenden", action: { NSApplication.shared.terminate(nil) })
                } label: {
                    Image(systemName: "gear")
                        .padding(5)
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
        }
        .frame(width: 300, height: 400)
        .onDisappear {
            saveNotes()
        }
    }
    
    func addNote() {
        notes.append("")
        selectedTab = notes.count - 1
        saveNotes()
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
            
            Swift.print("✅ Notizen gespeichert: \(notes)")
        } catch {
            Swift.print("❌ Fehler beim Speichern: \(error.localizedDescription)")
        }
    }
    
    func loadNotes() -> [String]? {
        do {
            if FileManager.default.fileExists(atPath: savePath.path) {
                let data = try Data(contentsOf: savePath)
                let loadedNotes = try JSONDecoder().decode([String].self, from: data)
                
                Swift.print("✅ Notizen erfolgreich geladen: \(loadedNotes)")
                return loadedNotes
            } else {
                Swift.print("⚠ Datei existiert nicht, neue wird erstellt.")
                saveNotes()
                return nil
            }
        } catch {
            Swift.print("❌ Fehler beim Laden: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getTabTitle(from text: String) -> String {
        let words = text.split(separator: " ")
        return words.first.map(String.init) ?? "Neue Notiz"
    }
}
