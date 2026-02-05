import SwiftUI
import AppKit

struct FormattingToolbar: View {
    @State private var activeBold = false
    @State private var activeItalic = false
    @State private var activeUnderline = false
    @State private var updateTimer: Timer? = nil
    
    var onBoldTap: () -> Void
    var onItalicTap: () -> Void
    var onUnderlineTap: () -> Void
    var onUpdateFormats: ((Bool, Bool, Bool) -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                onBoldTap()
                updateFormatStates()
            }) {
                Image(systemName: "bold")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primary)
                    .background(activeBold ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Bold")
            
            Button(action: {
                onItalicTap()
                updateFormatStates()
            }) {
                Image(systemName: "italic")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primary)
                    .background(activeItalic ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Italic")
            
            Button(action: {
                onUnderlineTap()
                updateFormatStates()
            }) {
                Image(systemName: "underline")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primary)
                    .background(activeUnderline ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Underline")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
        .onAppear {
            startUpdateTimer()
        }
        .onDisappear {
            stopUpdateTimer()
        }
    }
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            updateFormatStates()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateFormatStates() {
        if let window = NSApplication.shared.keyWindow,
           let textView = RichTextEditor.getTextViewFromWindow(window) {
            let formats = RichTextEditor.getActiveFormats(from: textView)
            activeBold = formats.bold
            activeItalic = formats.italic
            activeUnderline = formats.underline
            onUpdateFormats?(formats.bold, formats.italic, formats.underline)
        }
    }
}

