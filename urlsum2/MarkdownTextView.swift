import SwiftUI

struct FullMarkdownTextView: View {
    let markdown: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    
    init(_ markdown: String, fontSize: CGFloat = 16, lineSpacing: CGFloat = 6) {
        self.markdown = markdown
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            // Parse markdown into AttributedString
            if let attributedString = try? AttributedString(markdown: markdown) {
                Text(attributedString)
                    .foregroundStyle(.primary)
                    .lineSpacing(lineSpacing)
                    .textSelection(.enabled)
            } else {
                // Fallback to plain text
                Text(markdown)
                    .font(.system(size: fontSize, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineSpacing(lineSpacing)
                    .textSelection(.enabled)
            }
        } else {
            Text(markdown)
                .font(.system(size: fontSize, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(lineSpacing)
                .textSelection(.enabled)
        }
    }
}

struct MarkdownTextView: View {
    let markdown: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    
    init(_ markdown: String, fontSize: CGFloat = 16, lineSpacing: CGFloat = 4) {
        self.markdown = markdown
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        FullMarkdownTextView(markdown, fontSize: fontSize, lineSpacing: lineSpacing)
    }
}