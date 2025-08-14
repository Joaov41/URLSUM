import Foundation

class TTSChunkManager {
    private let maxChunkSize = 2000
    private let initialChunkSize = 200
    
    func splitTextIntoChunks(_ text: String) -> (firstChunk: String, remainingChunks: [String]) {
        // Get first chunk with sentence preservation
        let firstChunk = extractFirstChunk(from: text)
        
        // Remove first chunk from text
        let remainingText = String(text.dropFirst(firstChunk.count))
        
        // Split remaining text into larger chunks
        let remainingChunks = splitRemainingText(remainingText)
        
        return (firstChunk, remainingChunks)
    }
    
    private func extractFirstChunk(from text: String) -> String {
        guard text.count > initialChunkSize else {
            return text
        }
        
        // Look for sentence end within initialChunkSize
        let searchRange = text.index(text.startIndex, offsetBy: min(initialChunkSize, text.count))
        let searchText = String(text[..<searchRange])
        
        // Find last sentence end
        let sentenceEnds = searchText.indices.filter { idx in
            let char = text[idx]
            return [".", "!", "?"].contains(char) &&
                   (idx < text.index(before: text.endIndex) && text[text.index(after: idx)].isWhitespace)
        }
        
        if let lastSentenceEnd = sentenceEnds.last {
            return String(text[...lastSentenceEnd])
        }
        
        // If no sentence end found, look for last space
        if let lastSpace = searchText.lastIndex(where: { $0.isWhitespace }) {
            return String(text[...lastSpace])
        }
        
        // If no space found, just take initialChunkSize
        return String(text.prefix(initialChunkSize))
    }
    
    private func splitRemainingText(_ text: String) -> [String] {
        var chunks: [String] = []
        var remainingText = text
        
        while !remainingText.isEmpty {
            let chunk = extractNextChunk(from: remainingText)
            chunks.append(chunk)
            remainingText = String(remainingText.dropFirst(chunk.count))
        }
        
        return chunks
    }
    
    private func extractNextChunk(from text: String) -> String {
        guard text.count > maxChunkSize else {
            return text
        }
        
        // Look for sentence end within maxChunkSize
        let searchRange = text.index(text.startIndex, offsetBy: min(maxChunkSize, text.count))
        let searchText = String(text[..<searchRange])
        
        // Find last sentence end
        let sentenceEnds = searchText.indices.filter { idx in
            let char = text[idx]
            return [".", "!", "?"].contains(char) &&
                   (idx < text.index(before: text.endIndex) && text[text.index(after: idx)].isWhitespace)
        }
        
        if let lastSentenceEnd = sentenceEnds.last {
            return String(text[...lastSentenceEnd])
        }
        
        // If no sentence end found, look for last space
        if let lastSpace = searchText.lastIndex(where: { $0.isWhitespace }) {
            return String(text[...lastSpace])
        }
        
        // If no space found, just take maxChunkSize
        return String(text.prefix(maxChunkSize))
    }
} 