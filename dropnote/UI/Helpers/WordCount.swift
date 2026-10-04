import Foundation
import AppKit

/// Counts the words of a note.
///
/// Deliberately paranoid, because this number is the one visible proof that the
/// editor and the stored note agree:
///
/// * it scans scalars instead of building an array of substrings, so it stays
///   cheap even when it runs on every keystroke of a long note;
/// * it treats every Unicode whitespace and control character as a word break,
///   not just ASCII space and newline;
/// * invisible marks (zero-width joiners, BOM, …) neither start nor end a word;
/// * and if a note's plain `text` is empty while it *does* carry rich text, the
///   count falls back to what the RTF actually contains instead of claiming 0.
enum WordCount {

    // MARK: - Counting

    /// Word count for a note, with the rich-text fallback.
    static func count(in note: Note) -> Int {
        let direct = count(in: note.text)
        if direct > 0 { return direct }

        // Plain text and rich text disagree: the note looks empty but isn't. Can
        // happen with notes written by older versions, where only the RTF was kept.
        guard let rtf = note.attributedTextRTF, !rtf.isEmpty else { return direct }

        let key = rtf as NSData
        if let cached = rtfCountCache.object(forKey: key) { return cached.intValue }

        guard let plain = plainText(fromRTF: rtf) else { return direct }
        let fallback = count(in: plain)
        rtfCountCache.setObject(NSNumber(value: fallback), forKey: key)
        return fallback
    }

    /// Word count for a plain string. Allocation-free.
    static func count(in text: String) -> Int {
        var words = 0
        var insideWord = false

        for scalar in text.unicodeScalars {
            if isInvisible(scalar) {
                // Doesn't open a word and doesn't close one either.
                continue
            }
            if isWordBreak(scalar) {
                insideWord = false
            } else if !insideWord {
                insideWord = true
                words += 1
            }
        }

        return words
    }

    // MARK: - Rich text

    /// The plain string behind an RTF blob, or nil if it can't be decoded.
    static func plainText(fromRTF data: Data) -> String? {
        guard !data.isEmpty,
              let attributed = try? NSAttributedString(
                  data: data,
                  options: [.documentType: NSAttributedString.DocumentType.rtf],
                  documentAttributes: nil
              ) else { return nil }
        return attributed.string
    }

    // MARK: - Private

    /// Only consulted when the plain-text count is 0, so this stays cold in normal
    /// use. Keyed by the RTF bytes, which change whenever the note changes.
    private static let rtfCountCache: NSCache<NSData, NSNumber> = {
        let cache = NSCache<NSData, NSNumber>()
        cache.countLimit = 40
        return cache
    }()

    private static func isWordBreak(_ scalar: Unicode.Scalar) -> Bool {
        // Fast path for the characters that make up almost every separator.
        switch scalar {
        case " ", "\n", "\r", "\t": return true
        default: break
        }
        if scalar.properties.isWhitespace { return true }
        // Stray control characters (e.g. a NUL from a damaged import) must not be
        // mistaken for the start of a word.
        return scalar.properties.generalCategory == .control
    }

    private static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}": return true
        default: return scalar.properties.isDefaultIgnorableCodePoint
        }
    }
}
