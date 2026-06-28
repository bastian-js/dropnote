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

        // Inline link previews
        weak var textView: NSTextView?
        weak var previewContainer: NSView?
        var previewItems: [String: LinkPreviewItem] = [:]
        var previewHosts: [String: NSHostingView<LinkPreviewCard>] = [:]
        private static let cardHeight: CGFloat = 40
        private static let cardWidth: CGFloat = 210

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            if isProgrammaticUpdate {
                return
            }

            if let textView = notification.object as? NSTextView {
                // Inline markdown: turn **text** into real formatting as you type.
                isProgrammaticUpdate = true
                applyInlineMarkdown(textView)
                isProgrammaticUpdate = false

                parent.text = textView.string

                // Save attributed text as RTF
                if let rtfData = try? textView.attributedString().data(
                    from: NSRange(location: 0, length: textView.attributedString().length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                ) {
                    parent.onAttributedChange(rtfData)
                }

                parent.onTextChange()
                updateLinkPreviews()
            }
        }

        // MARK: - Inline Link Previews

        @objc func layoutChanged() {
            updateLinkPreviews()
        }

        /// Places a compact preview card directly below each link in the text.
        func updateLinkPreviews() {
            guard let textView,
                  let container = previewContainer,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let text = textView.string
            let matches = Self.detectLinkRanges(in: text)
            let activeKeys = Set(matches.map { $0.url.absoluteString })

            // Drop cards whose link no longer exists.
            for (key, host) in previewHosts where !activeKeys.contains(key) {
                host.removeFromSuperview()
                previewHosts[key] = nil
                previewItems[key] = nil
            }

            layoutManager.ensureLayout(for: textContainer)
            let origin = textView.textContainerOrigin

            for match in matches {
                let key = match.url.absoluteString
                let glyphRange = layoutManager.glyphRange(forCharacterRange: match.range, actualCharacterRange: nil)
                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect.origin.x += origin.x
                rect.origin.y += origin.y

                let item = previewItems[key] ?? {
                    let new = LinkPreviewItem(url: match.url)
                    previewItems[key] = new
                    return new
                }()

                let host: NSHostingView<LinkPreviewCard>
                if let existing = previewHosts[key] {
                    host = existing
                } else {
                    host = NSHostingView(rootView: LinkPreviewCard(item: item))
                    host.translatesAutoresizingMaskIntoConstraints = true
                    container.addSubview(host)
                    previewHosts[key] = host
                }

                let maxWidth = max(120, container.bounds.width - rect.minX - 8)
                let width = min(Self.cardWidth, maxWidth)
                host.frame = NSRect(x: rect.minX, y: rect.maxY + 2, width: width, height: Self.cardHeight)
            }
        }

        static func detectLinkRanges(in text: String) -> [(url: URL, range: NSRange)] {
            guard !text.isEmpty,
                  let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
            let ns = text as NSString
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length))
            var seen = Set<String>()
            var result: [(URL, NSRange)] = []
            for match in matches {
                guard let url = match.url, url.scheme?.hasPrefix("http") == true,
                      !seen.contains(url.absoluteString) else { continue }
                seen.insert(url.absoluteString)
                result.append((url, match.range))
            }
            return result
        }

        /// Detects a just-completed `**bold**` marker ending at the caret and replaces
        /// it with bold text, stripping the asterisks. Notion-style, no mode switching.
        /// Restricted to `**` so stray single asterisks (e.g. "2 * 3") are left alone.
        private func applyInlineMarkdown(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let caret = textView.selectedRange().location
            guard caret > 1 else { return }
            let ns = storage.string as NSString
            guard caret <= ns.length else { return }
            // Only act right after an asterisk was typed.
            guard ns.substring(with: NSRange(location: caret - 1, length: 1)) == "*" else { return }

            let prefix = ns.substring(to: caret)

            guard let regex = try? NSRegularExpression(pattern: "\\*\\*([^*\\n]+)\\*\\*$") else { return }
            let range = NSRange(location: 0, length: (prefix as NSString).length)
            guard let match = regex.firstMatch(in: prefix, options: [], range: range) else { return }

            let fullRange = match.range
            let inner = (prefix as NSString).substring(with: match.range(at: 1))

            let baseFont = (textView.typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 15)
            let traited = baseFont.fontDescriptor.symbolicTraits.union(.bold)
            let newFont = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(traited), size: baseFont.pointSize) ?? baseFont

            var attrs = textView.typingAttributes
            attrs[.font] = newFont
            let replacement = NSAttributedString(string: inner, attributes: attrs)

            guard textView.shouldChangeText(in: fullRange, replacementString: inner) else { return }
            storage.replaceCharacters(in: fullRange, with: replacement)

            let newCaret = fullRange.location + (inner as NSString).length
            textView.setSelectedRange(NSRange(location: newCaret, length: 0))

            // Reset typing attributes so text typed after the marker isn't bold.
            var reset = textView.typingAttributes
            reset[.font] = baseFont
            textView.typingAttributes = reset

            textView.didChangeText()
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

        // Overlay that hosts inline link-preview cards. It lives inside the text view
        // so it scrolls with the text; hit-testing passes through except on the cards.
        let container = LinkPreviewOverlayView()
        container.frame = textView.bounds
        container.autoresizingMask = [.width, .height]
        textView.addSubview(container)
        context.coordinator.textView = textView
        context.coordinator.previewContainer = container

        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.layoutChanged),
            name: NSView.frameDidChangeNotification,
            object: textView
        )

        loadAttributedText(textView, context: context)
        DispatchQueue.main.async { context.coordinator.updateLinkPreviews() }
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
        DispatchQueue.main.async { context.coordinator.updateLinkPreviews() }
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

// MARK: - LinkPreviewOverlayView

/// Flipped overlay (so it shares the text view's top-left coordinate system) that
/// hosts inline preview cards. Clicks pass straight through to the text view unless
/// they land on a card.
private final class LinkPreviewOverlayView: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}
