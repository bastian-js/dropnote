import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    var attributedTextRTF: Data?
    var onTextChange: () -> Void = {}
    var onAttributedChange: (Data?) -> Void = { _ in }
    
    private static let rtfCache: NSCache<NSData, NSAttributedString> = {
        let cache = NSCache<NSData, NSAttributedString>()
        cache.countLimit = 20
        cache.totalCostLimit = 6 * 1024 * 1024  // 6 MB total
        return cache
    }()
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var lastLoadedRTF: Data?
        var isProgrammaticUpdate = false
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if isProgrammaticUpdate {
                return
            }

            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
                
                // Save attributed text as RTF
                if let rtfData = try? textView.attributedString().data(
                    from: NSRange(location: 0, length: textView.attributedString().length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                ) {
                    parent.onAttributedChange(rtfData)
                }
                
                parent.onTextChange()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = createScrollView()
        let textView = createTextView()
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        loadAttributedText(textView, context: context)
        return scrollView
    }

    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else {
            return
        }
        
        let rtfChanged = context.coordinator.lastLoadedRTF != attributedTextRTF
        guard rtfChanged else {
            return
        }
        
        context.coordinator.lastLoadedRTF = attributedTextRTF
        updateTextViewContent(textView, context: context)
    }
    
    // MARK: - Private Methods
    
    private func createScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.focusRingType = .none

        return scrollView
    }

    
    private func createTextView() -> NSTextView {
        let textView = DropNoteTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = false
        
        // Proper configuration for top alignment
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        
        // Rich text support
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticLinkDetectionEnabled = true

        // Only lay out text that's visible; saves significant memory for long notes.
        textView.layoutManager?.allowsNonContiguousLayout = true

        return textView
    }
    
    private func loadAttributedText(_ textView: NSTextView, context: Context) {
        guard let rtfData = attributedTextRTF else {
            return
        }

        let selectedRanges = textView.selectedRanges

        if let cachedString = Self.rtfCache.object(forKey: rtfData as NSData) {
            context.coordinator.isProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(cachedString)
            detectAndStyleURLs(in: textView)
            context.coordinator.isProgrammaticUpdate = false
        } else if let attributedString = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            context.coordinator.isProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(attributedString)
            detectAndStyleURLs(in: textView)
            context.coordinator.isProgrammaticUpdate = false
            Self.rtfCache.setObject(attributedString, forKey: rtfData as NSData, cost: rtfData.count)
        }
        textView.selectedRanges = selectedRanges
        context.coordinator.lastLoadedRTF = rtfData
    }

    private func updateTextViewContent(_ textView: NSTextView, context: Context) {
        let currentText = text

        // Update visible text immediately so note switching feels instant.
        if textView.string != currentText {
            context.coordinator.isProgrammaticUpdate = true
            textView.string = currentText
            context.coordinator.isProgrammaticUpdate = false
        }

        guard let rtfData = attributedTextRTF else {
            return
        }

        let selectedRanges = textView.selectedRanges

        if let cachedString = Self.rtfCache.object(forKey: rtfData as NSData) {
            context.coordinator.isProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(cachedString)
            detectAndStyleURLs(in: textView)
            context.coordinator.isProgrammaticUpdate = false
            textView.selectedRanges = selectedRanges
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let attributedString = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) else {
                return
            }

            Self.rtfCache.setObject(attributedString, forKey: rtfData as NSData, cost: rtfData.count)

            DispatchQueue.main.async {
                if context.coordinator.lastLoadedRTF == rtfData {
                    context.coordinator.isProgrammaticUpdate = true
                    textView.textStorage?.setAttributedString(attributedString)
                    self.detectAndStyleURLs(in: textView)
                    context.coordinator.isProgrammaticUpdate = false
                    textView.selectedRanges = selectedRanges
                }
            }
        }
    }

    private func detectAndStyleURLs(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let string = textStorage.string
        guard !string.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }

        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        let matches = detector.matches(in: string, range: fullRange)
        guard !matches.isEmpty else { return }

        textStorage.beginEditing()
        for match in matches {
            guard let url = match.url else { continue }
            textStorage.addAttribute(.link, value: url, range: match.range)
        }
        textStorage.endEditing()
    }
}

// MARK: - DropNoteTextView

private final class DropNoteTextView: NSTextView {

    // Handle edit shortcuts directly so they work in every window context
    // without relying on the menu system or the SwiftUI/AppKit responder chain.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let ch = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        switch ch {
        case "c": copy(nil);      return true
        case "v": paste(nil);     return true
        case "x": cut(nil);       return true
        case "a": selectAll(nil); return true
        case "z":
            if event.modifierFlags.contains(.shift) { undoManager?.redo() }
            else { undoManager?.undo() }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func paste(_ sender: Any?) {
        guard let plain = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }
        let range = selectedRange
        let insertion = NSAttributedString(string: plain, attributes: typingAttributes)
        textStorage?.replaceCharacters(in: range, with: insertion)
        setSelectedRange(NSRange(location: range.location + (plain as NSString).length, length: 0))
        didChangeText()
    }
}
