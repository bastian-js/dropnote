import AppKit

struct TextFormattingHelper {
    // MARK: - Font Traits Operation
    
    static func toggleFontTrait(_ trait: NSFontDescriptor.SymbolicTraits, in textView: NSTextView) {
        guard let selectedRange = textView.selectedRanges.first as? NSRange, selectedRange.length > 0 else {
            return
        }
        
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedString())
        
        attributedString.enumerateAttributes(in: selectedRange, options: []) { attrs, attrRange, _ in
            var newAttrs = attrs
            let currentFont = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: 15)
            let traits = currentFont.fontDescriptor.symbolicTraits
            
            if traits.contains(trait) {
                newAttrs[.font] = NSFont(
                    descriptor: currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(trait)),
                    size: currentFont.pointSize
                )
            } else {
                newAttrs[.font] = NSFont(
                    descriptor: currentFont.fontDescriptor.withSymbolicTraits(traits.union(trait)),
                    size: currentFont.pointSize
                )
            }
            attributedString.setAttributes(newAttrs, range: attrRange)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
        preserveSelection(textView, originalRange: selectedRange)
    }
    
    static func toggleUnderline(in textView: NSTextView) {
        guard let selectedRange = textView.selectedRanges.first as? NSRange, selectedRange.length > 0 else {
            return
        }
        
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedString())
        
        attributedString.enumerateAttributes(in: selectedRange, options: []) { attrs, attrRange, _ in
            var newAttrs = attrs
            let underlineStyle = (attrs[.underlineStyle] as? NSNumber)?.intValue ?? 0
            
            if underlineStyle == NSUnderlineStyle.single.rawValue {
                newAttrs.removeValue(forKey: .underlineStyle)
            } else {
                newAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            attributedString.setAttributes(newAttrs, range: attrRange)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
        preserveSelection(textView, originalRange: selectedRange)
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
                if traits.contains(.bold) {
                    hasBold = true
                }
                if traits.contains(.italic) {
                    hasItalic = true
                }
            }
            if let underlineStyle = attrs[.underlineStyle] as? NSNumber {
                if underlineStyle.intValue == NSUnderlineStyle.single.rawValue {
                    hasUnderline = true
                }
            }
        }
        
        return (hasBold, hasItalic, hasUnderline)
    }
    
    // MARK: - Private Methods
    
    private static func preserveSelection(_ textView: NSTextView, originalRange: NSRange) {
        DispatchQueue.main.async {
            textView.selectedRanges = [NSValue(range: originalRange)]
        }
    }
}
