import SwiftUI
import AppKit
import PDFKit

struct EditorToolbar: View {
    let noteIndex: Int
    @Binding var notes: [Note]
    var onRequestDelete: (Int) -> Void
    var onRequestAddNote: () -> Void
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
                .stroke(ColorSchemeHelper.borderColor(), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var addNoteButton: some View {
        toolbarButton(
            icon: "plus",
            tooltip: "New Note",
            action: {
                onRequestAddNote()
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
        
        NSApp.activate(ignoringOtherApps: true)
        
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
        
        NSApp.activate(ignoringOtherApps: true)
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            
            let pdfDocument = PDFDocument()
            let pageSize = CGSize(width: 612, height: 792)
            let page = PDFPage()
            page.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
            
            pdfDocument.insert(page, at: 0)
            
            // Render text to PDF
            let textColor: NSColor = NSAppearance.current.name == .darkAqua ? .white : .black
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: textColor
            ]
            
            let titleText = "\(note.title)\n\n"
            let titleColor: NSColor = NSAppearance.current.name == .darkAqua ? .white : .black
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: titleColor
            ]
            
            var y: CGFloat = 36
            let x: CGFloat = 36
            let pageWidth = pageSize.width - 72
            
            // Draw title
            let titleString = NSAttributedString(string: titleText, attributes: titleAttributes)
            let titleSize = titleString.size()
            let titleRect = CGRect(x: x, y: pageSize.height - y - titleSize.height, width: pageWidth, height: titleSize.height)
            titleString.draw(in: titleRect)
            y += titleSize.height + 12
            
            // Draw body text
            let textString = NSAttributedString(string: note.text, attributes: attributes)
            let textSize = textString.size()
            let textRect = CGRect(x: x, y: pageSize.height - y - textSize.height, width: pageWidth, height: textSize.height)
            textString.draw(in: textRect)
            
            if let pdfData = pdfDocument.dataRepresentation() {
                try? pdfData.write(to: url, options: .atomic)
            }
        }
    }
}
