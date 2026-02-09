import SwiftUI
import AppKit

struct FormattingToolbar: View {
    @State private var activeBold = false
    @State private var activeItalic = false
    @State private var activeUnderline = false
    @State private var updateTimer: Timer?
    
    var onBoldTap: () -> Void
    var onItalicTap: () -> Void
    var onUnderlineTap: () -> Void
    var onUpdateFormats: ((Bool, Bool, Bool) -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            formatButton(
                action: {
                    onBoldTap()
                    updateFormatStates()
                },
                icon: "bold",
                isActive: activeBold,
                tooltip: "Bold"
            )
            
            formatButton(
                action: {
                    onItalicTap()
                    updateFormatStates()
                },
                icon: "italic",
                isActive: activeItalic,
                tooltip: "Italic"
            )
            
            formatButton(
                action: {
                    onUnderlineTap()
                    updateFormatStates()
                },
                icon: "underline",
                isActive: activeUnderline,
                tooltip: "Underline"
            )
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
    
    @ViewBuilder
    private func formatButton(
        action: @escaping () -> Void,
        icon: String,
        isActive: Bool,
        tooltip: String
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundColor(.primary)
                .background(isActive ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
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
           let textView = NSTextView.findInWindow(window) {
            let formats = TextFormattingHelper.getActiveFormats(from: textView)
            activeBold = formats.bold
            activeItalic = formats.italic
            activeUnderline = formats.underline
            onUpdateFormats?(formats.bold, formats.italic, formats.underline)
        }
    }
}
