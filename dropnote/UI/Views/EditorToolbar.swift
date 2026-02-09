import SwiftUI
import AppKit

struct EditorToolbar: View {
    let noteIndex: Int
    @Binding var notes: [Note]
    var onRequestDelete: (Int) -> Void
    var onRequestTogglePin: (Int) -> Void
    var onRequestToggleLock: (Int) -> Void
    var onSave: () -> Void
    
    @State private var isSaving: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            
            addNoteButton
            deleteNoteButton
            pinNoteButton
            lockNoteButton
            exportMenu
            
            Spacer(minLength: 0)
            
            savingStatus
            
            Spacer(minLength: 0)
                .frame(maxWidth: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var addNoteButton: some View {
        toolbarButton(
            icon: "plus",
            tooltip: "New Note",
            action: {
                onRequestTogglePin(noteIndex)
            }
        )
    }
    
    @ViewBuilder
    private var deleteNoteButton: some View {
        toolbarButton(
            icon: "trash",
            tooltip: "Delete",
            action: {
                onRequestDelete(noteIndex)
            }
        )
    }
    
    @ViewBuilder
    private var pinNoteButton: some View {
        toolbarButton(
            icon: notes[noteIndex].isPinned ? "pin.fill" : "pin",
            tooltip: notes[noteIndex].isPinned ? "Unpin" : "Pin",
            action: {
                onRequestTogglePin(noteIndex)
            }
        )
    }
    
    @ViewBuilder
    private var lockNoteButton: some View {
        toolbarButton(
            icon: notes[noteIndex].isLocked ? "lock.fill" : "lock.open",
            tooltip: notes[noteIndex].isLocked ? "Unlock / remove lock" : "Lock",
            action: {
                onRequestToggleLock(noteIndex)
            }
        )
    }
    
    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Button("Copy as Plain Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(notes[noteIndex].text, forType: .string)
            }
            
            Divider()
            
            Button("Export as TXT…") {
                exportAsTXT(noteIndex: noteIndex)
            }
            
            Button("Export as PDF…") {
                exportAsPDF(noteIndex: noteIndex)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(BorderlessButtonStyle())
        .menuIndicator(.hidden)
        .help("Share / Export")
    }
    
    @ViewBuilder
    private var savingStatus: some View {
        if isSaving {
            Text("Saving...")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        } else {
            Text("Saved")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func toolbarButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(BorderlessButtonStyle())
        .help(tooltip)
    }
    
    // MARK: - Private Methods
    
    private func exportAsTXT(noteIndex: Int) {
        let note = notes[noteIndex]
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(note.title).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            
            if let textData = FileExportHelper.createTextData(from: note.text) {
                try? textData.write(to: url, options: .atomic)
            }
        }
    }
    
    private func exportAsPDF(noteIndex: Int) {
        let note = notes[noteIndex]
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(note.title).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            
            let pdfData = FileExportHelper.createPDFData(
                title: note.title,
                body: note.text,
                attributedTextRTF: note.attributedTextRTF
            )
            try? pdfData.write(to: url, options: .atomic)
        }
    }
}
