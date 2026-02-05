import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    var attributedTextRTF: Data?
    var onTextChange: () -> Void = {}
    var onAttributedChange: (Data?) -> Void = { _ in }
    
    // Static cache for decoded RTF strings
    private static let rtfCache = NSCache<NSData, NSAttributedString>()
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var lastLoadedRTF: Data? = nil
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
                
                // Save attributed text as RTF
                if let rtfData = try? textView.attributedString().data(from: NSRange(location: 0, length: textView.attributedString().length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
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
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor.clear
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = false
        
        // Proper configuration for top alignment
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        
        // Rich text support
        textView.isRichText = true
        textView.allowsUndo = true
        
        scrollView.documentView = textView
        
        // Load RTF data synchronously on initialization from cache
        if let rtfData = attributedTextRTF {
            if let cachedString = RichTextEditor.rtfCache.object(forKey: rtfData as NSData) {
                textView.textStorage?.setAttributedString(cachedString)
            } else if let attributedString = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributedString)
                RichTextEditor.rtfCache.setObject(attributedString, forKey: rtfData as NSData)
            }
            context.coordinator.lastLoadedRTF = rtfData
        }
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            // Check if RTF data actually changed
            let rtfChanged = context.coordinator.lastLoadedRTF != attributedTextRTF
            
            if rtfChanged {
                context.coordinator.lastLoadedRTF = attributedTextRTF
                
                let currentText = text
                // Always update asynchronously to avoid blocking UI
                DispatchQueue.global(qos: .userInitiated).async {
                    if let rtfData = attributedTextRTF {
                        // Check cache first
                        if let cachedString = RichTextEditor.rtfCache.object(forKey: rtfData as NSData) {
                            DispatchQueue.main.async {
                                if context.coordinator.lastLoadedRTF == rtfData {
                                    textView.textStorage?.setAttributedString(cachedString)
                                }
                            }
                        } else if let attributedString = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                            // Cache it
                            RichTextEditor.rtfCache.setObject(attributedString, forKey: rtfData as NSData)
                            DispatchQueue.main.async {
                                if context.coordinator.lastLoadedRTF == rtfData {
                                    textView.textStorage?.setAttributedString(attributedString)
                                }
                            }
                        }
                    } else {
                        // Fallback to plain text
                        DispatchQueue.main.async {
                            if textView.string != currentText {
                                textView.string = currentText
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func applyBold(to textView: NSTextView) {
        guard let selectedRange = textView.selectedRanges.first as? NSRange, selectedRange.length > 0 else { return }
        
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedString())
        let range = selectedRange
        
        attributedString.enumerateAttributes(in: range, options: []) { attrs, attrRange, _ in
            var newAttrs = attrs
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) {
                    newAttrs[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits.subtracting(.bold)), size: font.pointSize)
                } else {
                    newAttrs[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits.union(.bold)), size: font.pointSize)
                }
            } else {
                let font = NSFont.systemFont(ofSize: 15)
                newAttrs[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.bold)), size: 15)
            }
            attributedString.setAttributes(newAttrs, range: attrRange)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
        // Preserve selection by setting it after update
        DispatchQueue.main.async {
            textView.selectedRanges = [NSValue(range: selectedRange)]
        }
    }
    
    static func applyItalic(to textView: NSTextView) {
        guard let selectedRange = textView.selectedRanges.first as? NSRange, selectedRange.length > 0 else { return }
        
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedString())
        let range = selectedRange
        
        attributedString.enumerateAttributes(in: range, options: []) { attrs, attrRange, _ in
            var newAttrs = attrs
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.italic) {
                    newAttrs[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits.subtracting(.italic)), size: font.pointSize)
                } else {
                    newAttrs[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits.union(.italic)), size: font.pointSize)
                }
            } else {
                let font = NSFont.systemFont(ofSize: 15)
                newAttrs[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.italic)), size: 15)
            }
            attributedString.setAttributes(newAttrs, range: attrRange)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
        // Preserve selection by setting it after update
        DispatchQueue.main.async {
            textView.selectedRanges = [NSValue(range: selectedRange)]
        }
    }
    
    static func applyUnderline(to textView: NSTextView) {
        guard let selectedRange = textView.selectedRanges.first as? NSRange, selectedRange.length > 0 else { return }
        
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedString())
        let range = selectedRange
        
        attributedString.enumerateAttributes(in: range, options: []) { attrs, attrRange, _ in
            var newAttrs = attrs
            let underline = (attrs[.underlineStyle] as? NSNumber)?.intValue ?? 0
            if underline == NSUnderlineStyle.single.rawValue {
                newAttrs.removeValue(forKey: .underlineStyle)
            } else {
                newAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            attributedString.setAttributes(newAttrs, range: attrRange)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
        // Preserve selection by setting it after update
        DispatchQueue.main.async {
            textView.selectedRanges = [NSValue(range: selectedRange)]
        }
    }
    
    static func getActiveFormats(from textView: NSTextView) -> (bold: Bool, italic: Bool, underline: Bool) {
        guard let selectedRange = textView.selectedRanges.first as? NSRange, selectedRange.length > 0 else {
            return (false, false, false)
        }
        
        var hasBold = false
        var hasItalic = false
        var hasUnderline = false
        
        textView.attributedString().enumerateAttributes(in: selectedRange, options: []) { attrs, _, _ in
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) { hasBold = true }
                if traits.contains(.italic) { hasItalic = true }
            }
            if let underlineStyle = attrs[.underlineStyle] as? NSNumber {
                if underlineStyle.intValue == NSUnderlineStyle.single.rawValue {
                    hasUnderline = true
                }
            }
        }
        
        return (hasBold, hasItalic, hasUnderline)
    }
    
    static func getTextViewFromWindow(_ window: NSWindow) -> NSTextView? {
        func findTextView(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView {
                return textView
            }
            for subview in view.subviews {
                if let found = findTextView(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        if let contentView = window.contentView {
            return findTextView(in: contentView)
        }
        return nil
    }
}
