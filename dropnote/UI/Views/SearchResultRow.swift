import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let index: Int
    let isSelected: Bool
    var onTap: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            resultIcon
            resultContent
            resultMetadata
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    @ViewBuilder
    private var resultIcon: some View {
        Image(systemName: "doc.text.fill")
            .font(.system(size: 20))
            .foregroundColor(.accentColor)
            .frame(width: 32)
    }
    
    @ViewBuilder
    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.note.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            if !result.preview.isEmpty {
                highlightedPreview
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var highlightedPreview: some View {
        highlightedText(result.preview, ranges: result.highlightRanges)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var resultMetadata: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(DateFormattingHelper.formatDate(result.note.lastModified))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            if result.matchedInTitle {
                Text("title match")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .frame(width: 100)
    }
    
    private func highlightedText(_ text: String, ranges: [Range<String.Index>]) -> Text {
        guard !ranges.isEmpty else {
            return Text(text)
        }
        
        var result = Text("")
        var currentIndex = text.startIndex
        
        for range in ranges {
            // Add text before highlight
            if currentIndex < range.lowerBound {
                result = result + Text(String(text[currentIndex..<range.lowerBound]))
            }
            
            // Add highlighted text
            result = result + Text(String(text[range]))
                .foregroundColor(.accentColor)
                .fontWeight(.semibold)
            
            currentIndex = range.upperBound
        }
        
        // Add remaining text
        if currentIndex < text.endIndex {
            result = result + Text(String(text[currentIndex..<text.endIndex]))
        }
        
        return result
    }
}
