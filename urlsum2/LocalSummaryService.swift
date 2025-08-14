import Foundation
import SwiftUI

// Import Apple's Foundation Models Framework for iOS 26 Tahoe
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - LocalSummaryService for Apple Intelligence
class LocalSummaryService {
    
    // Check if Apple Intelligence is available on this device
    static func isAvailable() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // Check if Foundation Models framework is available and model is supported
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return true
            case .unavailable(_):
                return false
            }
        } else {
            return false
        }
        #else
        return false
        #endif
    }
    
    // Summarize text using on-device Apple Intelligence with provided prompt
    static func summarizeText(_ prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            Task {
                do {
                    print("📱 LocalSummaryService: Using prompt (first 300 chars): \(prompt.prefix(300))...")
                    print("📱 LocalSummaryService: Prompt total length: \(prompt.count) characters")
                    print("📱 LocalSummaryService: Prompt contains 'Be concise': \(prompt.contains("Be concise"))")
                    print("📱 LocalSummaryService: Prompt contains 'key points': \(prompt.contains("key points"))")
                    
                    // Create Language Model session
                    let session = LanguageModelSession()
                    let response = try await session.respond(to: prompt)
                    
                    DispatchQueue.main.async {
                        completion(.success(response.content))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            completion(.failure(NSError(domain: "LocalSummaryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "iOS 26+ required"])))
        }
        #else
        completion(.failure(NSError(domain: "LocalSummaryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "FoundationModels not available"])))
        #endif
    }
    
    // Ask question about text using on-device Apple Intelligence
    static func askQuestion(about text: String, question: String, previousQuestion: String? = nil, previousAnswer: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            Task {
                do {
                    var prompt = """
                    Based on the following text, please answer this question. Format your response using markdown: use **bold** for emphasis, bullet points for lists, ## headers for sections if needed, and `code` formatting for technical terms.
                    
                    Question: \(question)
                    """
                    
                    // Include previous Q&A context if available
                    if let prevQ = previousQuestion, let prevA = previousAnswer {
                        prompt += """
                        
                        Previous Question: \(prevQ)
                        Previous Answer: \(prevA)
                        """
                    }
                    
                    prompt += """
                    
                    Text:
                    \(text)
                    
                    If the answer cannot be determined from the text, please state that the information is not available. Remember to format your response using markdown.
                    """
                    
                    // Create Language Model session for Q&A
                    let session = LanguageModelSession()
                    let response = try await session.respond(to: prompt)
                    
                    DispatchQueue.main.async {
                        completion(.success(response.content))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            completion(.failure(NSError(domain: "LocalSummaryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "iOS 26+ required"])))
        }
        #else
        completion(.failure(NSError(domain: "LocalSummaryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "FoundationModels not available"])))
        #endif
    }
}

// MARK: - Fallback implementation for pre-iOS 26
class LocalSummaryServiceFallback {
    
    // Check if Apple Intelligence is available on this device
    static func isAvailable() -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            return LocalSummaryService.isAvailable()
        }
        return false
    }
    
    // Summarize text using available Apple Intelligence
    static func summarizeText(_ prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        if #available(iOS 26.0, macOS 26.0, *) {
            LocalSummaryService.summarizeText(prompt, completion: completion)
        } else {
            completion(.failure(NSError(domain: "LocalSummaryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence requires iOS 26+ with Foundation Models"])))
        }
    }
    
    // Ask question about text using available Apple Intelligence
    static func askQuestion(about text: String, question: String, previousQuestion: String? = nil, previousAnswer: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        if #available(iOS 26.0, macOS 26.0, *) {
            LocalSummaryService.askQuestion(about: text, question: question, previousQuestion: previousQuestion, previousAnswer: previousAnswer, completion: completion)
        } else {
            completion(.failure(NSError(domain: "LocalSummaryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence requires iOS 26+ with Foundation Models"])))
        }
    }
}

// MARK: - Error Detection Extension
extension Error {
    var isContextLimitError: Bool {
        let errorMessage = self.localizedDescription.lowercased()
        
        // Common context/length related errors from Apple Intelligence
        let contextKeywords = [
            "context", "token", "length", "limit", "exceeded",
            "too long", "too large", "maximum", "size",
            "input too large", "content too long", "text too long",
            "request too large", "payload too large", "truncated",
            "buffer", "capacity", "overflow", "quota"
        ]
        
        for keyword in contextKeywords {
            if errorMessage.contains(keyword) {
                return true
            }
        }
        
        // Check error codes that typically indicate context limits
        if let nsError = self as? NSError {
            let contextErrorCodes = [413, 422, 400, 431]
            if contextErrorCodes.contains(nsError.code) {
                return true
            }
        }
        
        return false
    }
}