import SwiftUI
import AppKit

/// An `NSTextView` wrapper for a single document.
///
/// It deliberately takes **values plus a callback** instead of a `Binding`. The
/// coordinator outlives any single SwiftUI update, and a `Binding` created from
/// `$notes[index]` keeps pointing at that index forever — so an AppKit callback
/// arriving after a note was added or deleted used to write through a stale index
/// and trap with "Index out of range". A callback carries no index at all; the
/// owner resolves the note by id when the change arrives.
///
/// `contentID` identifies the document being edited. When it changes, the whole
/// text view is reloaded — that is what keeps the editor showing the note the
/// tab bar says is selected.
struct RichTextEditor: NSViewRepresentable {
    let contentID: UUID
    let text: String
    let attributedTextRTF: Data?
    /// Called on every edit with the new plain text and its RTF representation.
    var onChange: (String, Data?) -> Void = { _, _ in }

    private static let rtfCache: NSCache<NSData, NSAttributedString> = {
        let cache = NSCache<NSData, NSAttributedString>()
        cache.countLimit = 20
        cache.totalCostLimit = 6 * 1024 * 1024  // 6 MB total
        return cache
    }()

    static let defaultFont = NSFont.systemFont(ofSize: 15)

    static var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: defaultFont, .foregroundColor: NSColor.labelColor]
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        /// Refreshed on every `updateNSView`, so callbacks always target the note
        /// that is currently on screen rather than the one that was there when the
        /// coordinator was created.
        var parent: RichTextEditor
        var loadedContentID: UUID?
        var lastLoadedRTF: Data?
        var isProgrammaticUpdate = false

        // Inline link previews
        weak var textView: NSTextView?
        weak var previewContainer: NSView?
        var previewItems: [String: LinkPreviewItem] = [:]
        var previewHosts: [String: NSHostingView<LinkPreviewSlot>] = [:]
        private static let cardHeight: CGFloat = 40
        private static let cardWidth: CGFloat = 210
        // Vertical gap reserved after a link's paragraph so the card doesn't sit on
        // top of the text the user types next.
        private static let reservedSpacing: CGFloat = 48

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }

            // Inline markdown: turn **text** into real formatting as you type.
            isProgrammaticUpdate = true
            applyInlineMarkdown(textView)
            isProgrammaticUpdate = false

            let plain = textView.string
            let attributed = textView.attributedString()
            let rtfData = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )

            // The text view already *is* this content, so when it comes back around
            // through the store don't reload (and reset the caret) over it.
            lastLoadedRTF = rtfData

            parent.onChange(plain, rtfData)
            updateLinkPreviews()
        }

        // MARK: - Inline Link Previews

        @objc func layoutChanged() {
            updateLinkPreviews()
        }

        /// Reserves space under each link's paragraph and places a flush-left preview
        /// card in that gap.
        func updateLinkPreviews() {
            guard let textView,
                  let container = previewContainer,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let storage = textView.textStorage else { return }

            let nsString = storage.string as NSString
            let matches = Self.detectLinkRanges(in: storage.string)
            let activeKeys = Set(matches.map { $0.url.absoluteString })

            // Drop cards whose link no longer exists.
            for (key, host) in previewHosts where !activeKeys.contains(key) {
                host.removeFromSuperview()
                previewHosts[key] = nil
                previewItems[key] = nil
            }

            // Reserve a gap below each paragraph that contains a link.
            let linkParagraphs = matches.map { nsString.paragraphRange(for: $0.range) }
            adjustParagraphSpacing(storage: storage, fullLength: nsString.length, linkParagraphs: linkParagraphs)

            layoutManager.ensureLayout(for: textContainer)
            let origin = textView.textContainerOrigin
            // The text's true left edge: where every line fragment starts drawing.
            let leftMargin = origin.x + textContainer.lineFragmentPadding

            for match in matches {
                let key = match.url.absoluteString
                let glyphRange = layoutManager.glyphRange(forCharacterRange: match.range, actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let lineBottom = rect.maxY + origin.y

                let item = previewItems[key] ?? {
                    let new = LinkPreviewItem(url: match.url)
                    previewItems[key] = new
                    return new
                }()

                let host: NSHostingView<LinkPreviewSlot>
                if let existing = previewHosts[key] {
                    host = existing
                } else {
                    host = NSHostingView(rootView: LinkPreviewSlot(item: item))
                    host.translatesAutoresizingMaskIntoConstraints = true
                    if #available(macOS 13.3, *) { host.safeAreaRegions = [] }
                    container.addSubview(host)
                    previewHosts[key] = host
                }

                let maxWidth = max(120, container.bounds.width - leftMargin - 8)
                let width = min(Self.cardWidth, maxWidth)
                host.frame = NSRect(x: leftMargin, y: lineBottom + 4, width: width, height: Self.cardHeight)
            }
        }

        /// Removes every preview card. Used when the document is swapped out.
        func clearLinkPreviews() {
            previewHosts.values.forEach { $0.removeFromSuperview() }
            previewHosts.removeAll()
            previewItems.removeAll()
        }

        /// Adds `reservedSpacing` after link paragraphs and clears it elsewhere.
        /// Only mutates when a value actually differs, so it can't loop via layout.
        private func adjustParagraphSpacing(storage: NSTextStorage, fullLength: Int, linkParagraphs: [NSRange]) {
            guard fullLength > 0 else { return }
            var changes: [(NSRange, CGFloat)] = []

            storage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: fullLength), options: []) { value, range, _ in
                let isLink = linkParagraphs.contains { NSIntersectionRange($0, range).length > 0 }
                let current = (value as? NSParagraphStyle)?.paragraphSpacing ?? 0
                if isLink && current != Self.reservedSpacing {
                    changes.append((range, Self.reservedSpacing))
                } else if !isLink && current == Self.reservedSpacing {
                    changes.append((range, 0))
                }
            }
            // Paragraphs with no paragraphStyle attribute at all still need the gap.
            for para in linkParagraphs where para.length >= 0 {
                let existing = para.location < fullLength
                    ? storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle
                    : nil
                if (existing?.paragraphSpacing ?? 0) != Self.reservedSpacing {
                    changes.append((para, Self.reservedSpacing))
                }
            }

            guard !changes.isEmpty else { return }
            storage.beginEditing()
            for (range, spacing) in changes {
                guard range.location < fullLength else { continue }
                let clamped = NSRange(
                    location: range.location,
                    length: min(range.length, fullLength - range.location)
                )
                let base = (storage.attribute(.paragraphStyle, at: clamped.location, effectiveRange: nil) as? NSParagraphStyle) ?? .default
                let mutable = (base.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                mutable.paragraphSpacing = spacing
                storage.addAttribute(.paragraphStyle, value: mutable, range: clamped)
            }
            storage.endEditing()
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

            let baseFont = (textView.typingAttributes[.font] as? NSFont) ?? RichTextEditor.defaultFont
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

        context.coordinator.loadedContentID = contentID
        context.coordinator.lastLoadedRTF = attributedTextRTF
        loadDocument(into: textView, coordinator: context.coordinator, resetCaret: true)
        DispatchQueue.main.async { context.coordinator.updateLinkPreviews() }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Keep the coordinator's view of the world current — without this, every
        // AppKit callback would write into whatever note was showing when the
        // coordinator was first created.
        context.coordinator.parent = self

        guard let textView = nsView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator

        // A different note is being shown: replace the whole document.
        if coordinator.loadedContentID != contentID {
            coordinator.loadedContentID = contentID
            coordinator.lastLoadedRTF = attributedTextRTF
            coordinator.clearLinkPreviews()
            loadDocument(into: textView, coordinator: coordinator, resetCaret: true)
            DispatchQueue.main.async { coordinator.updateLinkPreviews() }
            return
        }

        // Same note, but its content changed somewhere else (a floating window, a
        // restored version, an import). Plain text is compared too, so a note
        // without RTF still refreshes.
        let rtfChanged = coordinator.lastLoadedRTF != attributedTextRTF
        let plainChanged = textView.string != text
        guard rtfChanged || plainChanged else { return }

        coordinator.lastLoadedRTF = attributedTextRTF
        loadDocument(into: textView, coordinator: coordinator, resetCaret: false)
        DispatchQueue.main.async { coordinator.updateLinkPreviews() }
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
        textView.font = Self.defaultFont
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

    /// Replaces the text view's content with this note's content.
    ///
    /// `resetCaret` is true when a *different* note is loaded (start at the top);
    /// false for an external update to the same note, where the caret is kept and
    /// clamped to the new length.
    private func loadDocument(into textView: NSTextView, coordinator: Coordinator, resetCaret: Bool) {
        let previousRanges = textView.selectedRanges

        coordinator.isProgrammaticUpdate = true
        defer { coordinator.isProgrammaticUpdate = false }

        if let rtfData = attributedTextRTF, let attributed = Self.attributedString(from: rtfData) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            // No rich text: render plain text with the editor's default styling, so
            // formatting from a previously shown note can't bleed in.
            textView.textStorage?.setAttributedString(
                NSAttributedString(string: text, attributes: Self.defaultAttributes)
            )
        }

        textView.typingAttributes = Self.defaultAttributes
        detectAndStyleURLs(in: textView)

        let length = (textView.string as NSString).length
        if resetCaret {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scroll(.zero)
            // A different document is loaded: an undo from here must not paste the
            // previous note's text into this one.
            textView.undoManager?.removeAllActions()
        } else {
            // Keep the caret, but never outside the new text.
            let clamped = previousRanges.compactMap { value -> NSValue? in
                let range = value.rangeValue
                let location = min(range.location, length)
                return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
            }
            textView.selectedRanges = clamped.isEmpty
                ? [NSValue(range: NSRange(location: length, length: 0))]
                : clamped
        }
    }

    private static func attributedString(from rtfData: Data) -> NSAttributedString? {
        if let cached = rtfCache.object(forKey: rtfData as NSData) { return cached }
        guard let decoded = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { return nil }
        rtfCache.setObject(decoded, forKey: rtfData as NSData, cost: rtfData.count)
        return decoded
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
        guard shouldChangeText(in: range, replacementString: plain) else { return }
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
