import AppKit

struct FileExportHelper {
    // MARK: - PDF Export
    
    static func createPDFData(title: String, body: String, attributedTextRTF: Data?) -> Data {
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        view.isEditable = false
        view.textContainerInset = NSSize(width: 36, height: 36)
        
        // Create title with formatting
        let titleAttr = NSAttributedString(
            string: "\(title)\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]
        )
        let mutableAttr = NSMutableAttributedString(attributedString: titleAttr)
        
        // Try to use formatted body if RTF available
        if let rtfData = attributedTextRTF,
           let bodyAttr = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            mutableAttr.append(bodyAttr)
        } else {
            // Fallback to plain text
            let bodyAttr = NSAttributedString(
                string: body,
                attributes: [.font: NSFont.systemFont(ofSize: 12)]
            )
            mutableAttr.append(bodyAttr)
        }
        
        view.textStorage?.setAttributedString(mutableAttr)
        return view.dataWithPDF(inside: view.bounds)
    }
    
    // MARK: - Text File Export
    
    static func createTextData(from text: String) -> Data? {
        text.data(using: .utf8)
    }
}
