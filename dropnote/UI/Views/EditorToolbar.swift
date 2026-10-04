import SwiftUI
import AppKit
import PDFKit

struct EditorToolbar: View {
    let noteID: UUID
    @ObservedObject var store: NotesStore = .shared
    var onRequestDelete: (UUID) -> Void
    var onRequestAddNote: () -> Void
    var onRequestTogglePin: (UUID) -> Void
    var onRequestToggleLock: (UUID) -> Void

    @State private var showHistory: Bool = false

    private var note: Note? { store.note(noteID) }

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            addNoteButton

            if let note {
                deleteNoteButton
                pinNoteButton(note: note)
                lockNoteButton(note: note)
                historyButton
                exportMenu(note: note)
            }

            Spacer(minLength: 0)
        }
        .tint(.secondary)
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
                onRequestDelete(noteID)
            }
        )
    }

    @ViewBuilder
    private func pinNoteButton(note: Note) -> some View {
        toolbarButton(
            icon: note.isPinned ? "pin.fill" : "pin",
            tooltip: note.isPinned ? "Unpin" : "Pin",
            action: {
                onRequestTogglePin(noteID)
            }
        )
    }

    @ViewBuilder
    private func lockNoteButton(note: Note) -> some View {
        toolbarButton(
            icon: note.isLocked ? "lock.fill" : "lock.open",
            tooltip: note.isLocked ? "Unlock / remove lock" : "Lock",
            action: {
                onRequestToggleLock(noteID)
            }
        )
    }

    @ViewBuilder
    private func exportMenu(note: Note) -> some View {
        Menu {
            Button("Copy as Plain Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }

            Divider()

            Button("Export as TXT…") {
                exportAsTXT(note: note)
            }

            Button("Export as PDF…") {
                exportAsPDF(note: note)
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
    private var historyButton: some View {
        Button {
            showHistory.toggle()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(BorderlessButtonStyle())
        .help("Version history")
        .popover(isPresented: $showHistory, arrowEdge: .top) {
            NoteHistoryView(
                note: store.binding(for: noteID),
                onRestore: { store.scheduleSave(debounce: 0) }
            )
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

    private func exportAsTXT(note: Note) {
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

    private func exportAsPDF(note: Note) {
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
