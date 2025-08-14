import SwiftUI
import Combine
import Foundation
import WebKit
import SwiftSoup
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import AVFoundation
import CryptoKit

// MARK: - iOS 26 Liquid Glass Styles
@available(iOS 26.0, macOS 26.0, *)
struct LiquidGlassTextFieldStyle: TextFieldStyle {
    let isCompact: Bool
    
    init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 8 : 12)
            .background(Color.clear)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: isCompact ? 8 : 12))
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct LiquidGlassButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    let isCompact: Bool
    
    init(cornerRadius: CGFloat = 8, isCompact: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isCompact = isCompact
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 8 : 12)
            .background(Color.clear)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Fallback styles for older iOS versions
struct AdaptiveLiquidGlassTextFieldStyle: TextFieldStyle {
    let isCompact: Bool
    
    init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 8 : 12)
            .background {
                if #available(iOS 26.0, macOS 26.0, *) {
                    // Use Liquid Glass on iOS 26+
                    Color.clear
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: isCompact ? 8 : 12))
                } else {
                    // Fallback for older versions
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
    }
}

struct AdaptiveLiquidGlassButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    let isCompact: Bool
    
    init(cornerRadius: CGFloat = 8, isCompact: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isCompact = isCompact
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 8 : 12)
            .background {
                if #available(iOS 26.0, macOS 26.0, *) {
                    // Use Liquid Glass on iOS 26+
                    Color.clear
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
                } else {
                    // Fallback for older versions
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color Extension
extension Color {
    static var systemBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    static var secondaryBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
}

// MARK: - Environment Key for Base Font Size
private struct BaseFontSizeKey: EnvironmentKey {
    static let defaultValue: Double = 14.0
}

extension EnvironmentValues {
    var baseFontSize: Double {
        get { self[BaseFontSizeKey.self] }
        set { self[BaseFontSizeKey.self] = newValue }
    }
}

// MARK: - GeminiError
enum GeminiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL provided"
        case .invalidResponse: return "Invalid response from server"
        case .parsingError: return "Failed to parse server response"
        case .rateLimited: return "Too many requests. Please try again in a few minutes."
        }
    }
}

// MARK: - GeminiService
actor GeminiService {
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    // Modified to accept the full prompt text
    func summarizeContent(prompt: String) async throws -> String {
        print("🔮 GeminiService: Received prompt (first 300 chars): \(prompt.prefix(300))...")
        print("🔮 GeminiService: Prompt total length: \(prompt.count) characters")
        print("🔮 GeminiService: Prompt contains 'Be concise': \(prompt.contains("Be concise"))")
        print("🔮 GeminiService: Prompt contains 'key points': \(prompt.contains("key points"))")
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent"
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        let parameters = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt) // Use the passed prompt
                ])
            ],
            generationConfig: GenerationConfig(thinkingConfig: ThinkingConfig(thinkingBudget: 0))
        )
        // Log the content and length
        print("📄 Sending content for summarization:")
        // print("📄 Full content: \(prompt)") // Log the prompt if needed, might be long
        
        // Add log to confirm thinking is off
        print("⚙️ Configuring Gemini request with thinkingBudget: 0")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(parameters)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GeminiError.invalidResponse
        }
        let responseForLogging = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        // Log the decoded response
        print("✅ API Response: \(responseForLogging)")
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let summary = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.parsingError
        }
        
        return summary
    }
    
    func qnaContent(_ text: String, question: String, previousQuestion: String? = nil, previousAnswer: String? = nil) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent"
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        var prompt = """
        Context:
        \(text)
        """
        
        // Include previous Q&A if available
        if let prevQ = previousQuestion, let prevA = previousAnswer {
            prompt += """
            
            Previous Question:
            \(prevQ)
            
            Previous Answer:
            \(prevA)
            """
        }
        
        prompt += """
        
        Question:
        \(question)
        
        Please provide a clear and concise answer based on the context above. Format your response using markdown: use **bold** for emphasis, bullet points for lists, ## headers for sections if needed, and `code` formatting for technical terms.
        """
        
        let parameters = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt)
                ])
            ],
            generationConfig: GenerationConfig(thinkingConfig: ThinkingConfig(thinkingBudget: 0))
        )
        
        print("🔍 Q&A Request:")
        print("URL: \(url)")
        print("Prompt length: \(prompt.count) characters")
        print("❓ Question: \(question)")
        if let pq = previousQuestion { print("⏪ Previous Question: \(pq)") }
        if let pa = previousAnswer { print("⏪ Previous Answer: \(pa)") }
        
        // Add log to confirm thinking is off
        print("⚙️ Configuring Gemini request with thinkingBudget: 0")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(parameters)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        print("📡 Q&A Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 Raw Response: \(responseString)")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw GeminiError.rateLimited
            }
            throw GeminiError.invalidResponse
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        print("✅ Decoded Response: \(geminiResponse)")
        
        guard let answer = geminiResponse.candidates.first?.content.parts.first?.text else {
            print("❌ Failed to extract answer from response")
            throw GeminiError.parsingError
        }
        
        print("✅ Extracted Answer: \(answer)")
        return answer
    }
}

// MARK: - Gemini Models
struct ThinkingConfig: Codable {
    let thinkingBudget: Int
}

struct GenerationConfig: Codable {
    let thinkingConfig: ThinkingConfig
}

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

// MARK: - ContentExtractor Protocol
protocol ContentExtractor {
    func extractContent(from url: URL) async throws -> (content: String, commentCount: Int?)
}

struct RedditContentExtractor: ContentExtractor {
    private let api = RedditAPI()
    
    func extractContent(from url: URL) async throws -> (content: String, commentCount: Int?) {
        print("📍 RedditContentExtractor - Starting extraction for URL: \(url)")
        return try await api.getContent(from: url)
    }
}

// MARK: - WebContentExtractor
struct WebContentExtractor: ContentExtractor {
    func extractContent(from url: URL) async throws -> (content: String, commentCount: Int?) {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        let doc = try SwiftSoup.parse(htmlString)
        try doc.select("script, style, nav, footer, header, aside").remove()
        
        if let articleContent = try doc.select("article").first()?.text() {
            return (cleanText(articleContent), nil)
        }
        
        if let mainContent = try doc.select("main").first()?.text() {
            return (cleanText(mainContent), nil)
        }
        
        return (cleanText(try doc.body()?.text() ?? ""), nil)
    }
    
    private func cleanText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - ContentExtractionFactory
struct ContentExtractionFactory {
    static func createExtractor(for url: URL) -> ContentExtractor {
        if url.host?.contains("reddit.com") == true {
            return RedditContentExtractor()
        }
        return WebContentExtractor()
    }
}

// MARK: - DragState
enum DragState {
    case inactive
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
}

// MARK: - Summary Length
enum SummaryLength {
    case short
    case long
}

// MARK: - AI Provider Selection
enum AIProvider: String, CaseIterable {
    case gemini = "Gemini"
    case appleLocal = "Apple Local"
    case appleCloud = "Apple Cloud"
    
    var displayName: String {
        switch self {
        case .gemini: return "Gemini API"
        case .appleLocal: return "Apple Intelligence (Local)"
        case .appleCloud: return "Apple Intelligence (Cloud)"
        }
    }
    
    var icon: String {
        switch self {
        case .gemini: return "sparkle"
        case .appleLocal: return "cpu"
        case .appleCloud: return "cloud"
        }
    }
    
    var description: String {
        switch self {
        case .gemini: return "Google's Gemini API"
        case .appleLocal: return "On-device processing"
        case .appleCloud: return "Apple's cloud AI via Shortcuts"
        }
    }
}

// MARK: - Apple Intelligence Request Type
enum AppleIntelligenceRequestType {
    case summary
    case qa
}

// MARK: - Progress Tracking Types
struct ProgressStep {
    let id: String
    let title: String
    let isComplete: Bool
    let isActive: Bool
    let estimatedDuration: TimeInterval
}

enum SummarizationPhase {
    case extracting
    case analyzing
    case generating
    case complete
    
    var title: String {
        switch self {
        case .extracting: return "Extracting content"
        case .analyzing: return "Analyzing content"
        case .generating: return "Generating summary"
        case .complete: return "Complete"
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .extracting: return 2.0
        case .analyzing: return 1.0
        case .generating: return 5.0
        case .complete: return 0.0
        }
    }
}

// MARK: - SummarizerViewModel
@MainActor
final class SummarizerViewModel: ObservableObject {
    @Published private(set) var state = ViewState.idle
    @Published var urlString = ""
    @Published var currentURL: URL?
    @Published var extractedText = ""
    @Published var summary = ""
    @Published var answer = ""
    @Published var isAsking = false
    @Published var errorMessage = ""
    @Published var redditAPIError: RedditAPIError? = nil
    @Published var qaHistory: [(question: String, answer: String)] = []
    @Published var commentCount: Int? = nil // Added comment count
    @Published var pageTitle = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    private var previousQuestion: String = ""
    private var previousAnswer: String = ""
    
    // Progress tracking properties
    @Published var progressPhase: SummarizationPhase = .extracting
    @Published var progressPercentage: Double = 0.0
    @Published var timeElapsed: TimeInterval = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0.0
    @Published var progressSteps: [ProgressStep] = []
    @Published var progressDetailMessage: String = ""
    @Published var shouldShowSummary: Bool = false
    private var progressStartTime: Date?
    private var progressTimer: Timer?
    
    private var geminiService: GeminiService
    @Published var selectedAIProvider: AIProvider = .gemini
    
    // Apple Intelligence properties
    @Published var isWaitingForAppleIntelligence = false
    @Published var appleIntelligenceWaitProgress = ""
    @Published var isWaitingForQA = false
    @Published var qaWaitProgress = ""
    private var clipboardTimer: Timer?
    private var clipboardCheckCount = 0
    private let maxClipboardChecks = 24 // 2 minutes max
    private var currentRequestType: AppleIntelligenceRequestType = .summary
    private var currentRequestCompletion: ((String) -> Void)?
    
    enum ViewState: Equatable { // Add Equatable conformance
        case idle
        case loading
        case summarizing
        case asking
        case error(String)
    }
    
    init(geminiService: GeminiService) {
        self.geminiService = geminiService
        initializeProgressSteps()
    }
    
    func updateGeminiAPIKey(_ apiKey: String) {
        self.geminiService = GeminiService(apiKey: apiKey)
    }
    
    func updateAIProvider(_ provider: AIProvider) {
        print("🔄 SummarizerViewModel: updateAIProvider called with: \(provider.displayName)")
        self.selectedAIProvider = provider
        print("🔄 SummarizerViewModel: selectedAIProvider is now: \(self.selectedAIProvider.displayName)")
    }
    
    // MARK: - Apple Intelligence Integration
    
    private func performLocalSummarization(prompt: String, completion: @escaping (String) -> Void) {
        if #available(iOS 18.2, macOS 15.2, *), LocalSummaryServiceFallback.isAvailable() {
            print("📱 Using local Apple Intelligence for summarization with length-specific prompt")
            LocalSummaryServiceFallback.summarizeText(prompt) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    print("✅ Local model succeeded")
                    completion(response)
                case .failure(let error):
                    print("⚠️ Local model failed: \(error.localizedDescription)")
                    
                    // Check if it's a context error and fallback to Gemini
                    if error.isContextLimitError {
                        print("🔄 Context error detected, falling back to Gemini")
                        self.performGeminiFallback(prompt: prompt, taskName: "summarization", completion: completion)
                    } else {
                        print("❌ Non-context error, still falling back to Gemini")
                        self.performGeminiFallback(prompt: prompt, taskName: "summarization", completion: completion)
                    }
                }
            }
        } else {
            print("⚠️ Local model not available, using Gemini")
            performGeminiFallback(prompt: prompt, taskName: "summarization", completion: completion)
        }
    }
    
    private func performLocalQA(text: String, question: String, previousQuestion: String?, previousAnswer: String?, completion: @escaping (String) -> Void) {
        if #available(iOS 18.2, macOS 15.2, *), LocalSummaryServiceFallback.isAvailable() {
            print("📱 Using local Apple Intelligence for Q&A")
            LocalSummaryServiceFallback.askQuestion(about: text, question: question, previousQuestion: previousQuestion, previousAnswer: previousAnswer) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    print("✅ Local model Q&A succeeded")
                    completion(response)
                case .failure(let error):
                    print("⚠️ Local model Q&A failed: \(error.localizedDescription)")
                    
                    // Fallback to Gemini
                    Task {
                        do {
                            let answer = try await self.geminiService.qnaContent(text, question: question, previousQuestion: previousQuestion, previousAnswer: previousAnswer)
                            completion(answer)
                        } catch {
                            print("❌ Gemini fallback also failed: \(error)")
                            completion("Error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else {
            print("⚠️ Local model not available for Q&A, using Gemini")
            Task {
                do {
                    let answer = try await self.geminiService.qnaContent(text, question: question, previousQuestion: previousQuestion, previousAnswer: previousAnswer)
                    completion(answer)
                } catch {
                    print("❌ Gemini Q&A failed: \(error)")
                    completion("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performGeminiFallback(prompt: String, taskName: String, completion: @escaping (String) -> Void) {
        Task {
            do {
                let response = try await self.geminiService.summarizeContent(prompt: prompt)
                completion(response)
            } catch {
                print("❌ Gemini fallback failed for \(taskName): \(error)")
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Apple Cloud Integration
    
    func launchCloudRequest(for text: String, type: AppleIntelligenceRequestType, completion: ((String) -> Void)?) {
        print("☁️ launchCloudRequest called with type: \(type), text length: \(text.count)")
        print("☁️ launchCloudRequest actual text being sent (first 300 chars): \(text.prefix(300))...")
        
        // Store the request type and completion handler
        self.currentRequestType = type
        self.currentRequestCompletion = completion
        
        #if os(macOS)
        // Prefer Shortcuts CLI on macOS to avoid opening the Shortcuts app
        runShortcutViaCLI(name: "RSS Reader Cloud Summary", input: text) { result in
            switch result {
            case .success(let output):
                DispatchQueue.main.async {
                    self.clearWaitingState(for: type)
                    self.currentRequestCompletion?(output)
                }
            case .failure(let error):
                print("⚠️ Shortcuts CLI failed: \(error.localizedDescription). Falling back to x-callback-url + clipboard.")
                // Fallback to x-callback-url and clipboard monitoring
                self.startClipboardMonitoring(for: type)
                self.launchShortcutViaXCallback(text: text)
            }
        }
        #else
        // iOS: must open Shortcuts app (x-callback-url)
        self.startClipboardMonitoring(for: type)
        self.launchShortcutViaXCallback(text: text)
        #endif
    }

    #if os(macOS)
    private func runShortcutViaCLI(name: String, input: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Prepare temp input/output files to avoid opening Shortcuts app UI
        let tempDir = FileManager.default.temporaryDirectory
        let inputFile = tempDir.appendingPathComponent("shortcut_input_\(UUID().uuidString).txt")
        let outputFile = tempDir.appendingPathComponent("shortcut_output_\(UUID().uuidString).txt")

        do {
            try input.write(to: inputFile, atomically: true, encoding: .utf8)
        } catch {
            completion(.failure(error))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = [
            "run",
            name,
            "--input-path", inputFile.path,
            "--output-path", outputFile.path,
            "--output-type", "public.plain-text"
        ]

        let errPipe = Pipe()
        process.standardError = errPipe

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()

                let status = process.terminationStatus
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if status == 0 {
                    let output = (try? String(contentsOf: outputFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    DispatchQueue.main.async {
                        completion(.success(output))
                    }
                } else {
                    let error = NSError(domain: "ShortcutsCLI", code: Int(status), userInfo: [NSLocalizedDescriptionKey: stderr.isEmpty ? "Shortcuts CLI failed" : stderr])
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }

                // Cleanup temp files
                try? FileManager.default.removeItem(at: inputFile)
                try? FileManager.default.removeItem(at: outputFile)
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    #endif

    private func launchShortcutViaXCallback(text: String) {
        // Use x-callback-url scheme to run shortcut
        let callbackURL = "shortcuts://x-callback-url/run-shortcut"
        var components = URLComponents(string: callbackURL)!
        components.queryItems = [
            URLQueryItem(name: "name", value: "RSS Reader Cloud Summary"),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "x-source", value: "URLSum"),
            URLQueryItem(name: "x-success", value: "urlsum://success"),
            URLQueryItem(name: "x-error", value: "urlsum://error")
        ]
        guard let url = components.url else {
            print("⚠️ Could not create x-callback URL")
            return
        }
        #if os(iOS)
        UIApplication.shared.open(url, options: [:]) { success in
            if success { print("✅ Successfully launched shortcut via x-callback-url") }
            else { print("⚠️ x-callback-url failed") }
        }
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        print("✅ Launched shortcut via x-callback-url on macOS")
        #endif
    }
    
    private func startClipboardMonitoring(for type: AppleIntelligenceRequestType = .summary) {
        // Cancel any existing timer
        clipboardTimer?.invalidate()
        clipboardCheckCount = 0
        
        // Store the original clipboard content
        #if os(iOS)
        let originalClipboard = UIPasteboard.general.string ?? ""
        #elseif os(macOS)
        let originalClipboard = NSPasteboard.general.string(forType: .string) ?? ""
        #endif
        
        print("📋 Starting clipboard monitoring for Apple Intelligence response (\(type))...")
        
        // Set waiting state based on request type
        DispatchQueue.main.async {
            switch type {
            case .summary:
                self.isWaitingForAppleIntelligence = true
                self.appleIntelligenceWaitProgress = "Waiting for Apple Intelligence... (0/\(self.maxClipboardChecks * 5)s)"
            case .qa:
                self.isWaitingForQA = true
                self.qaWaitProgress = "Waiting for answer... (0/\(self.maxClipboardChecks * 5)s)"
            }
        }
        
        // Check clipboard every 5 seconds, up to 2 minutes
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.clipboardCheckCount += 1
            let elapsedTime = self.clipboardCheckCount * 5
            let totalTime = self.maxClipboardChecks * 5
            
            #if os(iOS)
            let currentClipboard = UIPasteboard.general.string ?? ""
            #elseif os(macOS)
            let currentClipboard = NSPasteboard.general.string(forType: .string) ?? ""
            #endif
            
            print("📋 Checking clipboard for \(type)... (attempt \(self.clipboardCheckCount)/\(self.maxClipboardChecks))")
            
            // Update progress based on request type
            DispatchQueue.main.async {
                switch type {
                case .summary:
                    self.appleIntelligenceWaitProgress = "Waiting for Apple Intelligence... (\(elapsedTime)/\(totalTime)s)"
                case .qa:
                    self.qaWaitProgress = "Waiting for answer... (\(elapsedTime)/\(totalTime)s)"
                }
            }
            
            // If clipboard changed and contains meaningful content
            if currentClipboard != originalClipboard && !currentClipboard.isEmpty && currentClipboard.count > 10 {
                print("✅ Found \(type) response in clipboard after \(elapsedTime) seconds!")
                
                // Handle the response based on request type
                DispatchQueue.main.async {
                    self.clearWaitingState(for: type)
                    self.currentRequestCompletion?(currentClipboard)
                }
                
                // Stop monitoring
                timer.invalidate()
                self.clipboardTimer = nil
                return
            }
            
            // Check if we've exceeded the maximum attempts
            if self.clipboardCheckCount >= self.maxClipboardChecks {
                print("⏱️ Clipboard monitoring timed out after \(totalTime) seconds for \(type)")
                
                DispatchQueue.main.async {
                    self.clearWaitingState(for: type)
                    
                    let timeoutMessage = "Apple Intelligence processing took longer than expected. Please check your clipboard manually or try again."
                    self.currentRequestCompletion?(timeoutMessage)
                }
                
                timer.invalidate()
                self.clipboardTimer = nil
            }
        }
    }
    
    private func clearWaitingState(for type: AppleIntelligenceRequestType) {
        switch type {
        case .summary:
            self.isWaitingForAppleIntelligence = false
            self.appleIntelligenceWaitProgress = ""
        case .qa:
            self.isWaitingForQA = false
            self.qaWaitProgress = ""
        }
    }
    
    // MARK: - Progress Management
    
    private func initializeProgressSteps() {
        progressSteps = [
            ProgressStep(id: "extract", title: "Extracting content", isComplete: false, isActive: false, estimatedDuration: 2.0),
            ProgressStep(id: "analyze", title: "Analyzing content", isComplete: false, isActive: false, estimatedDuration: 1.0),
            ProgressStep(id: "generate", title: "Generating summary", isComplete: false, isActive: false, estimatedDuration: 5.0)
        ]
    }
    
    private func startProgress() {
        shouldShowSummary = false // Hide summary when starting new progress
        progressStartTime = Date()
        progressPercentage = 0.0
        timeElapsed = 0.0
        progressPhase = .extracting
        updateProgressSteps()
        
        // Start timer to update elapsed time and estimates
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgressTimer()
        }
    }
    
    private func updateProgress(phase: SummarizationPhase, percentage: Double, detailMessage: String = "") {
        progressPhase = phase
        progressPercentage = percentage
        progressDetailMessage = detailMessage
        updateProgressSteps()
        calculateTimeEstimates()
    }
    
    private func updateProgressSteps() {
        let phases: [SummarizationPhase] = [.extracting, .analyzing, .generating]
        let currentPhaseIndex = phases.firstIndex(of: progressPhase) ?? 0
        
        progressSteps = progressSteps.enumerated().map { index, step in
            let isComplete = index < currentPhaseIndex
            let isActive = index == currentPhaseIndex
            return ProgressStep(
                id: step.id,
                title: step.title,
                isComplete: isComplete,
                isActive: isActive,
                estimatedDuration: step.estimatedDuration
            )
        }
    }
    
    private func updateProgressTimer() {
        guard let startTime = progressStartTime else { return }
        timeElapsed = Date().timeIntervalSince(startTime)
        calculateTimeEstimates()
    }
    
    private func calculateTimeEstimates() {
        let totalEstimatedTime = progressSteps.reduce(0) { $0 + $1.estimatedDuration }
        
        if progressPercentage > 0 {
            let estimatedTotalTime = timeElapsed / (progressPercentage / 100.0)
            estimatedTimeRemaining = max(0, estimatedTotalTime - timeElapsed)
        } else {
            estimatedTimeRemaining = totalEstimatedTime
        }
    }
    
    private func completeProgress() {
        progressPhase = .complete
        progressPercentage = 100.0
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Mark all steps as complete
        progressSteps = progressSteps.map { step in
            ProgressStep(
                id: step.id,
                title: step.title,
                isComplete: true,
                isActive: false,
                estimatedDuration: step.estimatedDuration
            )
        }
        
        calculateTimeEstimates()
    }
    
    func loadURL() async {
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if input looks like a URL or a search query
        if isLikelyURL(input) {
            // Process as URL
            var cleanURL = input
            if !cleanURL.contains("://") {
                cleanURL = "https://" + cleanURL
            }
            
            if let url = URL(string: cleanURL) {
                await updateURL(url)
            } else {
                state = .error("Invalid URL")
            }
        } else {
            // Process as search query using DuckDuckGo
            let searchQuery = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURLString = "https://duckduckgo.com/?q=\(searchQuery)"
            
            if let searchURL = URL(string: searchURLString) {
                await updateURL(searchURL)
            } else {
                state = .error("Invalid search query")
            }
        }
    }
    
    private func isLikelyURL(_ input: String) -> Bool {
        // Check if input looks like a URL
        let lowercased = input.lowercased()
        
        // Check for explicit protocol
        if lowercased.contains("://") {
            return true
        }
        
        // Check for common TLDs
        let commonTLDs = [".com", ".org", ".net", ".edu", ".gov", ".io", ".co", ".uk", ".de", ".jp", ".cn", ".fr", ".au", ".ca", ".in", ".ru", ".br", ".app", ".dev", ".ai", ".ml"]
        for tld in commonTLDs {
            if lowercased.contains(tld) {
                return true
            }
        }
        
        // Check for localhost or IP addresses
        if lowercased.starts(with: "localhost") || 
           lowercased.starts(with: "127.0.0.1") ||
           lowercased.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#, options: .regularExpression) != nil {
            return true
        }
        
        // Check for common URL patterns
        if lowercased.contains(".") && !lowercased.contains(" ") {
            // Has a dot and no spaces, likely a domain
            return true
        }
        
        return false
    }
    
    func updateURL(_ url: URL) async {
        if currentURL != url {
            extractedText = ""
            summary = ""
            answer = ""
            commentCount = nil // Reset comment count
            qaHistory = [] // Clear Q&A history on navigation
            redditAPIError = nil // Reset Reddit API error
        }
        
        currentURL = url
        urlString = url.absoluteString
    }
    
    weak var webView: WKWebView? {
        didSet {
            updateNavigationState()
        }
    }
    
    private var navigationObservers: [NSKeyValueObservation] = []
    
    func setWebView(_ webView: WKWebView) {
        // Remove old observers
        navigationObservers.forEach { $0.invalidate() }
        navigationObservers.removeAll()
        
        self.webView = webView
        
        // Add new observers for navigation state
        let backObserver = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateNavigationState()
            }
        }
        
        let forwardObserver = webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateNavigationState()
            }
        }
        
        navigationObservers = [backObserver, forwardObserver]
        updateNavigationState()
    }
    
    private func updateNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }
    
    func updatePageTitle(_ title: String) {
        self.pageTitle = title
    }
    
    func dismissRedditError() {
        redditAPIError = nil
    }
    
    func retryLastAction() {
        // Retry the last action that caused the Reddit API error
        redditAPIError = nil
        
        if case .summarizing = state {
            Task {
                await summarize()
            }
        } else if isAsking {
            // Retry the last question if we were asking
            if let lastQuestion = qaHistory.last?.question {
                Task {
                    await askQuestion(lastQuestion)
                }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        if let redditError = error as? RedditAPIError {
            // Handle Reddit API errors specifically
            redditAPIError = redditError
            state = .error(redditError.localizedDescription)
            print("❌ Reddit API Error: \(redditError.localizedDescription)")
        } else {
            // Handle other errors normally
            state = .error(error.localizedDescription)
            print("❌ General Error: \(error.localizedDescription)")
        }
    }
    
    func summarize(length: SummaryLength = .long) async {
        guard let webView = webView,
              let url = webView.url else {
            state = .error("No URL loaded")
            return
        }
        
        print("🔍 Summarizing content from URL: \(url) with length: \(length)")
        state = .summarizing // Update state immediately on MainActor
        extractedText = "" // Clear previous extracted text
        summary = "" // Clear previous summary
        commentCount = nil // Reset comment count
        redditAPIError = nil // Reset Reddit API error
        
        // Start progress tracking
        startProgress()
        
        // Run extraction and summarization in a background task
        Task.detached(priority: .userInitiated) {
            do {
                // --- Phase 1: Content Extraction ---
                await MainActor.run {
                    self.updateProgress(phase: .extracting, percentage: 10.0, detailMessage: "Connecting to source...")
                }
                
                let extractor = ContentExtractionFactory.createExtractor(for: url)
                
                await MainActor.run {
                    if extractor is RedditContentExtractor {
                        self.updateProgress(phase: .extracting, percentage: 15.0, detailMessage: "Fetching Reddit comments...")
                    } else {
                        self.updateProgress(phase: .extracting, percentage: 15.0, detailMessage: "Extracting web content...")
                    }
                }
                
                let (content, commentCount) = try await extractor.extractContent(from: url)
                let extracted = content // Keep a copy for potential display
                
                await MainActor.run {
                    if let count = commentCount {
                        self.updateProgress(phase: .extracting, percentage: 30.0, detailMessage: "Extracted \(count) comments")
                    } else {
                        self.updateProgress(phase: .extracting, percentage: 30.0, detailMessage: "Content extracted successfully")
                    }
                }
                
                // Check if still summarizing before calling LLM
                guard await self.state == .summarizing else { return }
                
                // --- Phase 2: Content Analysis ---
                await MainActor.run {
                    self.updateProgress(phase: .analyzing, percentage: 40.0, detailMessage: "Preparing content for analysis...")
                }
                
                // Select prompt based on content source and length
                let promptText: String
                if length == .short {
                    // Short summary prompts
                    if extractor is RedditContentExtractor {
                        print("ℹ️ Using SHORT Reddit-specific summarization prompt.")
                        promptText = "Provide a concise 2-paragraph summary of the following Reddit post and its comments. First paragraph should cover the main post topic and content. Second paragraph should highlight the key points from the discussion in the comments. Use markdown formatting with **bold** for emphasis:\n\n" + content
                    } else {
                        print("ℹ️ Using SHORT general summarization prompt.")
                        promptText = "Provide a concise summary (maximum 2 paragraphs) of the following text. Focus on the key points and main ideas. Be concise and clear:\n\n" + content
                    }
                    
                    // Debug: Log the exact prompt structure for verification
                    await MainActor.run {
                        print("🔧 DEBUG: Short summary prompt configured")
                        print("🔧 DEBUG: Prompt starts with: \(promptText.prefix(200))...")
                    }
                } else {
                    // Long summary prompts (original)
                    if extractor is RedditContentExtractor {
                        print("ℹ️ Using LONG Reddit-specific summarization prompt.")
                        promptText = "Summarize the following Reddit post and its comments using markdown formatting. Use ## headers for sections, **bold** for emphasis, and bullet points for lists. Follow these instructions: First summarize the main post topic and content, then identify and explain the primary topics and discussions in the comments, highlight key themes and viewpoints present in the conversation. Ensure the summary is clear and provide a final summary:\n\n" + content
                    } else {
                        print("ℹ️ Using LONG general summarization prompt.")
                        promptText = "Summarize the following text using markdown formatting. Use ## headers for sections, **bold** for emphasis, bullet points for lists, and `code` formatting for technical terms. Clearly highlight key themes and points:\n\n" + content
                    }
                }
                
                await MainActor.run {
                    let lengthDesc = length == .short ? "short" : "detailed"
                    self.updateProgress(phase: .analyzing, percentage: 50.0, detailMessage: "Configured \(lengthDesc) summary prompt")
                    
                    // Debug: Log the exact prompt structure for verification
                    print("🔧 DEBUG: Prompt construction for \(lengthDesc) summary:")
                    print("🔧 DEBUG: Prompt starts with: \(promptText.prefix(200))...")
                    print("🔧 DEBUG: Prompt contains 'Be concise': \(promptText.contains("Be concise"))")
                    print("🔧 DEBUG: Prompt contains 'key points': \(promptText.contains("key points"))")
                    print("🔧 DEBUG: Full prompt length: \(promptText.count) characters")
                }
                
                // --- Phase 3: Summary Generation ---
                await MainActor.run {
                    let providerName = self.selectedAIProvider.displayName
                    self.updateProgress(phase: .generating, percentage: 60.0, detailMessage: "Sending to \(providerName) for processing...")
                }
                
                let summaryResult: String
                
                // Use provider-specific summarization
                let selectedProvider = await self.selectedAIProvider
                print("📋 Selected AI Provider for summarization: \(selectedProvider.displayName)")
                
                switch selectedProvider {
                case .gemini:
                    print("🔮 Using Gemini API for summarization")
                    print("🔮 Gemini prompt (first 300 chars): \(promptText.prefix(300))...")
                    print("🔮 Gemini prompt total length: \(promptText.count) characters")
                    summaryResult = try await self.geminiService.summarizeContent(prompt: promptText)
                    
                case .appleLocal:
                    print("📱 Using Apple Local Intelligence for summarization")
                    print("📱 Apple Local prompt (first 300 chars): \(promptText.prefix(300))...")
                    print("📱 Apple Local prompt total length: \(promptText.count) characters")
                    summaryResult = await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            self.performLocalSummarization(prompt: promptText) { result in
                                continuation.resume(returning: result)
                            }
                        }
                    }
                    
                case .appleCloud:
                    print("☁️ Using Apple Cloud Intelligence for summarization")
                    print("☁️ Apple Cloud prompt (first 300 chars): \(promptText.prefix(300))...")
                    print("☁️ Apple Cloud prompt total length: \(promptText.count) characters")
                    print("☁️ Apple Cloud prompt contains 'Be concise': \(promptText.contains("Be concise"))")
                    print("☁️ Apple Cloud prompt contains 'key points': \(promptText.contains("key points"))")
                    summaryResult = await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            self.launchCloudRequest(for: promptText, type: .summary) { result in
                                continuation.resume(returning: result)
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.updateProgress(phase: .generating, percentage: 90.0, detailMessage: "Finalizing summary...")
                }
                
                // --- End Background Work ---
                
                // Switch back to MainActor to update UI
                await MainActor.run {
                    self.extractedText = extracted // Update extracted text
                    self.summary = summaryResult
                    self.commentCount = commentCount // Update comment count
                    self.completeProgress()
                    self.state = .idle
                    self.shouldShowSummary = true // Trigger summary view
                    print("✅ Summarization complete.")
                }
            } catch {
                // Switch back to MainActor to update UI with error
                await MainActor.run {
                    self.progressTimer?.invalidate()
                    self.progressTimer = nil
                    self.handleError(error)
                }
            }
        }
    }
    
    func askQuestion(_ question: String) async {
        guard let webView = webView,
              let url = webView.url else {
            state = .error("No URL loaded")
            errorMessage = "Please load a URL first"
            return
        }
        
        print("🔍 Getting Q&A content from URL: \(url)")
        state = .loading // Keep loading state until content is fetched
        isAsking = true
        errorMessage = ""
        answer = ""
        redditAPIError = nil // Reset Reddit API error
        
        await MainActor.run { self.commentCount = nil }
        
        do {
            let extractor = ContentExtractionFactory.createExtractor(for: url)
            let (content, currentCommentCount) = try await extractor.extractContent(from: url)
            
            if content.isEmpty {
                await MainActor.run {
                    state = .error("No content found")
                    errorMessage = "No content found to analyze"
                    isAsking = false
                }
                return
            }
            
            await MainActor.run {
                self.extractedText = content
                self.commentCount = currentCommentCount
            }
            print("📝 Extracted content length: \(content.count), Comments: \(currentCommentCount ?? 0)")
            
            state = .asking
            
            let newAnswer: String
            
            // Use provider-specific Q&A
            switch selectedAIProvider {
            case .gemini:
                newAnswer = try await geminiService.qnaContent(content, question: question, previousQuestion: previousQuestion.isEmpty ? nil : previousQuestion, previousAnswer: previousAnswer.isEmpty ? nil : previousAnswer)
                
            case .appleLocal:
                newAnswer = await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        performLocalQA(text: content, question: question, previousQuestion: previousQuestion.isEmpty ? nil : previousQuestion, previousAnswer: previousAnswer.isEmpty ? nil : previousAnswer) { result in
                            continuation.resume(returning: result)
                        }
                    }
                }
                
            case .appleCloud:
                let qaPrompt = """
                Based on the following text, please answer this question. Format your response using markdown: use **bold** for emphasis, bullet points for lists, ## headers for sections if needed, and `code` formatting for technical terms.
                
                Question: \(question)
                \(previousQuestion.isEmpty ? "" : "\nPrevious Question: \(previousQuestion)")
                \(previousAnswer.isEmpty ? "" : "\nPrevious Answer: \(previousAnswer)")
                
                Text:
                \(content)
                
                If the answer cannot be determined from the text, please state that the information is not available. Remember to format your response using markdown.
                """
                
                newAnswer = await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        launchCloudRequest(for: qaPrompt, type: .qa) { result in
                            continuation.resume(returning: result)
                        }
                    }
                }
            }
            
            previousQuestion = question
            previousAnswer = newAnswer
            print("✅ Received answer: \(newAnswer)")
            
            if newAnswer.isEmpty {
                await MainActor.run {
                    state = .error("Empty response")
                    errorMessage = "No answer received from AI"
                    isAsking = false
                }
                return
            }
            
            await MainActor.run {
                answer = newAnswer
                qaHistory.append((question: question, answer: newAnswer))
                state = .idle
                isAsking = false
            }
        } catch {
            await MainActor.run {
                self.handleError(error)
                self.isAsking = false
            }
        }
    }
    
    func clear() {
        urlString = ""
        currentURL = nil
        extractedText = ""
        summary = ""
        answer = ""
        errorMessage = ""
        redditAPIError = nil
        previousQuestion = ""
        previousAnswer = ""
        qaHistory = []
        commentCount = nil // Reset comment count
        state = .idle
        
        // Reset progress tracking
        progressTimer?.invalidate()
        progressTimer = nil
        progressPercentage = 0.0
        timeElapsed = 0.0
        estimatedTimeRemaining = 0.0
        progressPhase = .extracting
        progressDetailMessage = ""
        shouldShowSummary = false
        initializeProgressSteps()
    }
}

// MARK: - Summary Components
struct SummaryDragHandle: View {
    let action: (DragGesture.Value) -> Void
    @GestureState var dragState: DragState
    
    var body: some View {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .cornerRadius(2)
                            .padding(.vertical, 8)
                            .gesture(
                                DragGesture()
                                    .updating($dragState) { drag, state, _ in
                                        state = .dragging(translation: drag.translation)
                                    }
                    .onEnded(action)
                            )
    }
}
                        
struct SummaryHeader: View {
    @Binding var showSummary: Bool
    
    var body: some View {
                        HStack {
                            Button(action: { showSummary = false }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("[", modifiers: .command)
                            
                            Text("Summary")
                                .font(.headline)
                            Spacer()
            Button("Close") {
                showSummary = false
            }
            .keyboardShortcut(.escape, modifiers: [])
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
    }
}
                        
struct SummaryContent: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var ttsViewModel: TTSViewModel
    let baseFontSize: Double
    
    // Adaptive font size - larger for iPad
    private var adaptiveFontSize: Double {
        #if os(iOS)
        return baseFontSize * 1.6  // 60% larger for iOS/iPad
        #else
        return baseFontSize * 1.2  // 20% larger for Mac
        #endif
    }
    
    var body: some View {
                        ScrollView {
                            if viewModel.summary.isEmpty {
                                Text("Summary will appear here")
                                    .font(.system(size: baseFontSize))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                VStack(spacing: 12) {
                    // Top buttons
                    HStack {
                        Spacer()
                        
                        // OPENAI TTS BUTTON
                                    Button {
                            if ttsViewModel.isPlaying {
                                ttsViewModel.stop()
                            } else {
                                ttsViewModel.speakWithOpenAI(viewModel.summary)
                            }
                        } label: {
                            HStack {
                                Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                                Text("OpenAI")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .bold()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .background(Color.blue)
                        .cornerRadius(0)
                        
                        // LOCAL TTS BUTTON
                        Button {
                            if ttsViewModel.isPlaying {
                                ttsViewModel.stop()
                            } else {
                                ttsViewModel.speakWithLocalTTS(viewModel.summary)
                            }
                        } label: {
                            HStack {
                                Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                                Text("Local")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .bold()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .background(Color.green)
                        .cornerRadius(0)
                        
                        // COPY BUTTON
                        Button {
                            #if os(macOS)
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(viewModel.summary, forType: .string)
                            #else
                            UIPasteboard.general.string = viewModel.summary
                            #endif
                                    } label: {
                                        Image(systemName: "doc.on.clipboard")
                                .font(.title)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    // TTS Controls when playing
                    if ttsViewModel.isPlaying {
                        VStack(spacing: 8) {
                            TTSControlsView(viewModel: ttsViewModel)
                            
                            // Show status message
                            if !ttsViewModel.statusMessage.isEmpty {
                                Text(ttsViewModel.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            
                            if ttsViewModel.progress > 0 && ttsViewModel.progress < 1 {
                                ProgressView(value: ttsViewModel.progress)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Summary text
                    FullMarkdownTextView(viewModel.summary, fontSize: adaptiveFontSize, lineSpacing: 6)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Comment count
                    if let commentCount = viewModel.commentCount {
                        Text("Comment count: \(commentCount)")
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                                }
                            }
                        }
                        .background(Color.clear)
    }
}

// MARK: - Q&A Components
struct QAHeader: View {
    @Binding var showQnA: Bool
    
    var body: some View {
                    HStack {
                        Button(action: { showQnA = false }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("[", modifiers: .command)
                        
                        Text("Q&A")
                            .font(.headline)
                        Spacer()
                        Button("Close") {
                            showQnA = false
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                        .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 6, isCompact: true))
                    }
                    .padding()
    }
}
                    
struct QAInputField: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @Binding var question: String
    
    var body: some View {
                    HStack {
                                        TextField("Enter your question", text: $question)
                    .textFieldStyle(AdaptiveLiquidGlassTextFieldStyle())
                            .disabled(viewModel.isAsking)
                            .onSubmit {
                                if !question.isEmpty && !viewModel.isAsking {
                                    Task {
                                        await viewModel.askQuestion(question)
                                    }
                                }
                            }
                        
                        Button(action: {
                            Task {
                                await viewModel.askQuestion(question)
                            }
                        }) {
                            Text("Ask")
                        }
                        .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                        .disabled(question.isEmpty || viewModel.isAsking)
                    }
                    .padding(.horizontal)
    }
}

struct QAHistoryView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var ttsViewModel: TTSViewModel
    let baseFontSize: Double
    
    var body: some View {
                    ScrollView {
                        if !viewModel.qaHistory.isEmpty {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(viewModel.qaHistory.indices, id: \.self) { index in
                        QAHistoryItem(
                            question: viewModel.qaHistory[index].question,
                            answer: viewModel.qaHistory[index].answer,
                            ttsViewModel: ttsViewModel,
                            baseFontSize: baseFontSize
                        )
                    }
                }
                .padding()
            } else if !viewModel.isAsking {
                Text("Enter your question about the content")
                    .font(.system(size: baseFontSize))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color.clear)
    }
}

struct QAHistoryItem: View {
    let question: String
    let answer: String
    @ObservedObject var ttsViewModel: TTSViewModel
    let baseFontSize: Double
    
    // Adaptive font size - larger for iPad
    private var adaptiveFontSize: Double {
        #if os(iOS)
        return baseFontSize * 1.6  // 60% larger for iOS/iPad
        #else
        return baseFontSize * 1.2  // 20% larger for Mac
        #endif
    }
    
    var body: some View {
                                    VStack(alignment: .leading, spacing: 8) {
            Text("Q: \(question)")
                                            .fontWeight(.semibold)
                                            .font(.system(size: adaptiveFontSize, design: .rounded))
                                            .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top) { 
                    Text("A:")
                        .fontWeight(.semibold)
                        .font(.system(size: adaptiveFontSize, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FullMarkdownTextView(answer, fontSize: adaptiveFontSize, lineSpacing: 4)
                        
                        // TTS Controls for answers
                        HStack {
                            // OpenAI TTS Button
                                            Button {
                                if ttsViewModel.isPlaying {
                                    ttsViewModel.stop()
                                } else {
                                    ttsViewModel.speakWithOpenAI(answer)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                    Text("OpenAI")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .background(Color.blue)
                            .cornerRadius(8)
                            
                            // Local TTS Button
                            Button {
                                if ttsViewModel.isPlaying {
                                    ttsViewModel.stop()
                                } else {
                                    ttsViewModel.speakWithLocalTTS(answer)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                    Text("Local")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .background(Color.green)
                            .cornerRadius(8)
                            
                            if ttsViewModel.isPlaying {
                                Spacer()
                                TTSControlsView(viewModel: ttsViewModel)
                            }
                            
                            Spacer()
                            
                            Button {
                                #if os(macOS)
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(answer, forType: .string)
                                #else
                                UIPasteboard.general.string = answer
                                #endif
                                            } label: {
                                                Image(systemName: "doc.on.clipboard")
                                            }
                            .buttonStyle(.plain)
                        }
                        
                        if ttsViewModel.isPlaying && ttsViewModel.progress > 0 && ttsViewModel.progress < 1 {
                            ProgressView(value: ttsViewModel.progress)
                        }
                    }
                }
                                        }
                                    }
                                    .padding()
                                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }

// MARK: - Updated Main Views
struct SummaryView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var ttsViewModel: TTSViewModel
    @Binding var showSummary: Bool
    @Binding var summaryHeight: CGFloat
    @GestureState var dragState: DragState
    let geometry: GeometryProxy
    let baseFontSize: Double
    
    var body: some View {
        VStack(spacing: 0) {
            SummaryDragHandle(action: { value in
                let newHeight = summaryHeight - value.translation.height
                summaryHeight = min(max(newHeight, 200), geometry.size.height * 0.8)
            }, dragState: dragState)
            
            SummaryHeader(showSummary: $showSummary)
            SummaryContent(viewModel: viewModel, ttsViewModel: ttsViewModel, baseFontSize: baseFontSize)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .frame(height: summaryHeight + dragState.translation.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: showSummary)
    }
}

struct QAView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var ttsViewModel: TTSViewModel
    @Binding var showQnA: Bool
    @Binding var question: String
    let baseFontSize: Double
    
    var body: some View {
        VStack {
            QAHeader(showQnA: $showQnA)
            QAInputField(viewModel: viewModel, question: $question)
            
            if viewModel.isAsking {
                ProgressView("Processing question...")
                                .padding()
            } else if viewModel.isWaitingForQA {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(viewModel.qaWaitProgress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                        }
            
            if let count = viewModel.commentCount {
                Text("Context includes \(count) comments.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }
            
            QAHistoryView(viewModel: viewModel, ttsViewModel: ttsViewModel, baseFontSize: baseFontSize)
                }
                .frame(width: 400, height: 400)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)
                .padding()
                .onDisappear {
                    question = ""
                    viewModel.answer = ""
                    viewModel.qaHistory = []
            viewModel.commentCount = nil
        }
    }
}

// MARK: - Toolbar View
struct ToolbarView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var bookmarkManager: BookmarkManager
    @Binding var showSummary: Bool
    @Binding var showQnA: Bool
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var summaryReady: Bool
    @Binding var summaryWasDismissed: Bool
    @Binding var isGeneratingSummary: Bool
    @Binding var summaryWasShown: Bool
    @State private var showSummaryOptions = false
    
    var summaryMenu: some View {
        Menu {
            Button {
                isGeneratingSummary = true
                showSummary = true
                summaryReady = false
                summaryWasDismissed = false
                summaryWasShown = true
                Task {
                    await viewModel.summarize(length: .short)
                    isGeneratingSummary = false
                    summaryReady = true
                    if summaryWasDismissed {
                        showSummary = true
                        summaryWasDismissed = false
                    }
                }
            } label: {
                Label("Short Summary", systemImage: "text.badge.minus")
                Text("2 paragraphs max")
            }
            
            Button {
                isGeneratingSummary = true
                showSummary = true
                summaryReady = false
                summaryWasDismissed = false
                summaryWasShown = true
                Task {
                    await viewModel.summarize(length: .long)
                    isGeneratingSummary = false
                    summaryReady = true
                    if summaryWasDismissed {
                        showSummary = true
                        summaryWasDismissed = false
                    }
                }
            } label: {
                Label("Long Summary", systemImage: "text.badge.plus")
                Text("Detailed analysis")
            }
        } label: {
            Text("Summarize")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
        .disabled(viewModel.currentURL == nil)
    }
    
    var qnaButton: some View {
        Button("Q&A") {
            showQnA.toggle()
        }
        .font(.system(size: 14, weight: .medium))
        .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Navigation buttons
            HStack(spacing: 4) {
                Button {
                    viewModel.webView?.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .disabled(!viewModel.canGoBack)
                .keyboardShortcut("[", modifiers: .command)
                .help("Go Back (⌘[)")
                
                Button {
                    viewModel.webView?.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .disabled(!viewModel.canGoForward)
                .keyboardShortcut("]", modifiers: .command)
                .help("Go Forward (⌘])")
                
                Button {
                    viewModel.webView?.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .keyboardShortcut("r", modifiers: .command)
                .help("Reload (⌘R)")
            }
            
            Divider()
                .frame(height: 20)
            
            TextField("Enter URL", text: $viewModel.urlString)
                .textFieldStyle(AdaptiveLiquidGlassTextFieldStyle(isCompact: true))
                .onSubmit {
                    Task { await viewModel.loadURL() }
                }
            
            // Summary menu - hidden on iPhone
            Group {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom != .phone {
                    summaryMenu
                }
                #else
                summaryMenu
                #endif
            }
            
            // Q&A button - hidden on iPhone  
            Group {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom != .phone {
                    qnaButton
                }
                #else
                qnaButton
                #endif
            }
            
            Button {
                if let url = viewModel.currentURL {
                    if bookmarkManager.isBookmarked(url: url.absoluteString) {
                        if let bookmark = bookmarkManager.bookmarks.first(where: { $0.url == url.absoluteString }) {
                            bookmarkManager.removeBookmark(bookmark)
                        }
                    } else {
                        let title = viewModel.pageTitle.isEmpty ? url.host ?? "Untitled" : viewModel.pageTitle
                        bookmarkManager.addBookmark(url: url.absoluteString, title: title)
                    }
                }
            } label: {
                Image(systemName: bookmarkManager.isBookmarked(url: viewModel.currentURL?.absoluteString ?? "") ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
            .disabled(viewModel.currentURL == nil)
            
            Button {
                showBookmarks.toggle()
            } label: {
                Image(systemName: "list.star")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
            
            // Reddit API Error indicator
            if viewModel.redditAPIError != nil {
                Button {
                    // Click to show error details (already shown as overlay)
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Reddit API Error - Click anywhere to see details")
            }
            
            Spacer()
            
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
        }
        .padding(8)
        .background(Color.systemBackground)
    }
}

// MARK: - Progress Tracking Components
struct ProgressStepView: View {
    let step: ProgressStep
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .stroke(step.isComplete ? Color.green : (step.isActive ? Color.blue : Color.gray.opacity(0.3)), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if step.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                } else if step.isActive {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Step title
            Text(step.title)
                .font(.system(size: 14, weight: step.isActive ? .semibold : .regular))
                .foregroundColor(step.isActive ? .primary : .secondary)
            
            Spacer()
            
            // Duration indicator for active step
            if step.isActive {
                Text("\(Int(step.estimatedDuration))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct ProgressTrackingView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Title section
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Processing Content")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // Main progress bar
                VStack(spacing: 10) {
                    HStack {
                        Text("Overall Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.progressPercentage))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: viewModel.progressPercentage, total: 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 2.0)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // Current phase with detail message
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("Current Step:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.progressPhase.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // Detail message
                if !viewModel.progressDetailMessage.isEmpty {
                    HStack {
                        Text(viewModel.progressDetailMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.leading, 24) // Align with icon
                }
            }
            .padding(.horizontal, 4)
            
            // Progress steps
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Steps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.bottom, 4)
                
                VStack(spacing: 10) {
                    ForEach(viewModel.progressSteps, id: \.id) { step in
                        ProgressStepView(step: step)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Time information
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(formatTime(viewModel.timeElapsed))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("~\(formatTime(viewModel.estimatedTimeRemaining))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "hourglass")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.01))  // extremely minimal blur
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let seconds = Int(timeInterval)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }
}

// MARK: - Loading Overlay View
struct LoadingOverlayView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            // Main content
            VStack {
                Spacer()
                
                if viewModel.state == .summarizing {
                    ProgressTrackingView(viewModel: viewModel)
                        .frame(maxWidth: 480)
                        .frame(maxHeight: 360)
                } else if viewModel.isWaitingForAppleIntelligence {
                    // Apple Intelligence waiting indicator
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text("Apple Intelligence")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text(viewModel.appleIntelligenceWaitProgress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.systemBackground)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                } else {
                    // Fallback for other loading states
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Loading...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.systemBackground)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var showSettings: Bool
    @Binding var isDarkMode: Bool
    @Binding var baseFontSize: Double
    @Binding var geminiAPIKey: String
    @Binding var openAIAPIKey: String
    @Binding var selectedAIProvider: AIProvider
    let viewModel: SummarizerViewModel
    let ttsViewModel: TTSViewModel
    
    @State private var tempGeminiKey: String = ""
    @State private var tempOpenAIKey: String = ""
    @State private var showGeminiKey: Bool = false
    @State private var showOpenAIKey: Bool = false
    @State private var showRestartAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    darkModeSection
                    
                    Divider()
                    
                    fontSizeSection
                    
                    Divider()
                    
                    aiProviderSection
                    
                    Divider()
                    
                    apiKeysSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
        }
        .frame(width: 450, height: 500)
        .background(Color.clear)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .padding()
        .onAppear {
            tempGeminiKey = geminiAPIKey
            tempOpenAIKey = openAIAPIKey
        }
    }
    
    private var settingsHeader: some View {
        HStack {
            Text("Settings")
                .font(.title2)
                .bold()
            
            Spacer()
            
            Button {
                showSettings = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var darkModeSection: some View {
        HStack {
            Label("Dark Mode", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
            Spacer()
            Toggle("", isOn: $isDarkMode)
                .toggleStyle(.switch)
        }
        .padding(.horizontal)
    }
    
    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Font Size", systemImage: "textformat.size")
                Spacer()
                Text("\(Int(baseFontSize))pt")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("A")
                    .font(.system(size: 12))
                
                Slider(value: $baseFontSize, in: 10...24, step: 1)
                
                Text("A")
                    .font(.system(size: 20))
            }
            
            Text("Preview: The quick brown fox jumps over the lazy dog")
                .font(.system(size: baseFontSize))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondaryBackground)
                .cornerRadius(0)
        }
        .padding(.horizontal)
    }
    
    private var aiProviderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Provider")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Button {
                        selectedAIProvider = provider
                        viewModel.updateAIProvider(provider)
                    } label: {
                        HStack {
                            Image(systemName: provider.icon)
                                .foregroundColor(selectedAIProvider == provider ? .white : .primary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.body)
                                    .foregroundColor(selectedAIProvider == provider ? .white : .primary)
                                
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundColor(selectedAIProvider == provider ? .white.opacity(0.8) : .secondary)
                            }
                            
                            Spacer()
                            
                            if selectedAIProvider == provider {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background {
                            if selectedAIProvider == provider {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Provider-specific notes
            Group {
                switch selectedAIProvider {
                case .gemini:
                    Text("Requires API key. Supports all content types with high accuracy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                
                case .appleLocal:
                    Text("On-device processing. Requires iOS 18.2+. Falls back to Gemini if context limits exceeded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                
                case .appleCloud:
                    Text("Requires 'URLSum AI Assistant' shortcut setup. Uses clipboard for responses.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API Keys")
                .font(.headline)
                .padding(.horizontal)
            
            geminiKeySection
            
            openAIKeySection
            
            if showRestartAlert {
                Text("API keys updated successfully!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
    }
    
    private var geminiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Gemini API Key", systemImage: "key.fill")
                Spacer()
                Button(action: {
                    showGeminiKey.toggle()
                }) {
                    Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                Group {
                    if showGeminiKey {
                        TextField("Enter Gemini API Key", text: $tempGeminiKey)
                    } else {
                        SecureField("Enter Gemini API Key", text: $tempGeminiKey)
                    }
                }
                .textFieldStyle(AdaptiveLiquidGlassTextFieldStyle())
                
                Button("Save") {
                    geminiAPIKey = tempGeminiKey
                    viewModel.updateGeminiAPIKey(tempGeminiKey)
                    showRestartAlert = true
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 6, isCompact: true))
                .disabled(tempGeminiKey.isEmpty)
                
                if !tempGeminiKey.isEmpty {
                    Button("Clear") {
                        tempGeminiKey = ""
                        geminiAPIKey = ""
                        viewModel.updateGeminiAPIKey("")
                        showRestartAlert = true
                    }
                    .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 6, isCompact: true))
                    .foregroundColor(.red)
                }
            }
            
            Text("API key required for summarization")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var openAIKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("OpenAI API Key", systemImage: "key.fill")
                Spacer()
                Button(action: {
                    showOpenAIKey.toggle()
                }) {
                    Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                Group {
                    if showOpenAIKey {
                        TextField("Enter OpenAI API Key", text: $tempOpenAIKey)
                    } else {
                        SecureField("Enter OpenAI API Key", text: $tempOpenAIKey)
                    }
                }
                .textFieldStyle(AdaptiveLiquidGlassTextFieldStyle())
                
                Button("Save") {
                    openAIAPIKey = tempOpenAIKey
                    ttsViewModel.updateOpenAIAPIKey(tempOpenAIKey)
                    showRestartAlert = true
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 6, isCompact: true))
                .disabled(tempOpenAIKey.isEmpty)
                
                if !tempOpenAIKey.isEmpty {
                    Button("Clear") {
                        tempOpenAIKey = ""
                        openAIAPIKey = ""
                        ttsViewModel.updateOpenAIAPIKey("")
                        showRestartAlert = true
                    }
                    .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 6, isCompact: true))
                    .foregroundColor(.red)
                }
            }
            
            Text("API key required for summarization")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - TTS Models and Services
struct OpenAITTSRequest: Codable {
    let model: String
    let input: String
    let voice: String
    let response_format: String
}

enum TTSVoice: String, CaseIterable {
    case alloy = "alloy"
    case echo = "echo"
    case fable = "fable"
    case onyx = "onyx"
    case nova = "nova"
    case shimmer = "shimmer"
    
    var displayName: String {
        rawValue.capitalized
    }
}

// Add iOS System Voice enum
enum IOSSystemVoice: String, CaseIterable {
    case ava = "com.apple.voice.premium.en-US.Ava"
    case evan = "com.apple.voice.premium.en-US.Evan"
    case nicky = "com.apple.voice.premium.en-US.Nicky"
    case zoe = "com.apple.voice.premium.en-US.Zoe"
    case samantha = "com.apple.ttsbundle.Samantha-compact"
    case alex = "com.apple.ttsbundle.siri_Alex_en-US_compact"
    case allison = "com.apple.ttsbundle.Allison-compact"
    case tom = "com.apple.ttsbundle.Tom-compact"
    case susan = "com.apple.ttsbundle.Susan-compact"
    case daniel = "com.apple.voice.premium.en-GB.Daniel"
    case serena = "com.apple.voice.premium.en-GB.Serena"
    case systemDefault = "system.default"
    
    var displayName: String {
        switch self {
        case .ava: return "Ava (Premium US)"
        case .evan: return "Evan (Premium US)"
        case .nicky: return "Nicky (Premium US)"
        case .zoe: return "Zoe (Premium US)"
        case .samantha: return "Samantha"
        case .alex: return "Alex (Siri)"
        case .allison: return "Allison"
        case .tom: return "Tom"
        case .susan: return "Susan"
        case .daniel: return "Daniel (Premium UK)"
        case .serena: return "Serena (Premium UK)"
        case .systemDefault: return "System Default"
        }
    }
    
    var speechVoice: AVSpeechSynthesisVoice? {
        if self == .systemDefault {
            return AVSpeechSynthesisVoice(language: "en-US")
        }
        return AVSpeechSynthesisVoice(identifier: self.rawValue)
    }
}

// MARK: - Advanced TTS Components

// Audio Cache for memory and disk caching
class AudioCache {
    static let shared = AudioCache()
    
    private let memoryCache = NSCache<NSString, NSData>()
    private let diskCacheURL: URL
    
    private init() {
        // Setup memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Setup disk cache
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        diskCacheURL = documentsPath.appendingPathComponent("TTSAudioCache")
        
        // Create disk cache directory
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    private func cacheKey(for text: String, voice: String) -> String {
        let combined = "\(text)_\(voice)"
        return combined.data(using: .utf8)!.sha256
    }
    
    func cachedAudio(for text: String, voice: String) -> Data? {
        let key = cacheKey(for: text, voice: voice)
        
        // Check memory cache first
        if let data = memoryCache.object(forKey: NSString(string: key)) {
            return data as Data
        }
        
        // Check disk cache
        let fileURL = diskCacheURL.appendingPathComponent(key)
        if let data = try? Data(contentsOf: fileURL) {
            // Store in memory cache for future use
            memoryCache.setObject(NSData(data: data), forKey: NSString(string: key))
            return data
        }
        
        return nil
    }
    
    func cacheAudio(_ data: Data, for text: String, voice: String) {
        let key = cacheKey(for: text, voice: voice)
        
        // Store in memory cache
        memoryCache.setObject(NSData(data: data), forKey: NSString(string: key))
        
        // Store in disk cache
        let fileURL = diskCacheURL.appendingPathComponent(key)
        try? data.write(to: fileURL)
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}

// Extension for SHA256 hashing
extension Data {
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}



// TTS Chunk Manager for intelligent text chunking
class TTSChunkManager {
    private let maxChunkSize = 3500 // Safe size for OpenAI API (4096 limit with buffer)
    private let initialChunkSize = 80 // ULTRA small for instant startup (1-2 sentences max)
    
    struct TextChunk {
        let text: String
        let isFirstChunk: Bool
        let chunkIndex: Int
    }
    
    func chunkText(_ text: String) -> [TextChunk] {
        guard !text.isEmpty else { return [] }
        
        var chunks: [TextChunk] = []
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle short text - no chunking needed
        if cleanText.count <= initialChunkSize {
            return [TextChunk(text: cleanText, isFirstChunk: true, chunkIndex: 0)]
        }
        
        // Find the first natural break within initial chunk size
        let firstChunk = extractFirstChunk(from: cleanText)
        chunks.append(TextChunk(text: firstChunk, isFirstChunk: true, chunkIndex: 0))
        
        // Process remaining text
        let remainingText = String(cleanText.dropFirst(firstChunk.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainingText.isEmpty {
            let remainingChunks = chunkLargerText(remainingText, startIndex: 1)
            chunks.append(contentsOf: remainingChunks)
        }
        
        return chunks
    }
    
    private func extractFirstChunk(from text: String) -> String {
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        
        // For INSTANT startup, try longer micro chunks that give background time
        let microSize = min(120, text.count) // Try 120 chars first - need time for background processing
        let microSubstring = String(text.prefix(microSize))
        
        // Look for very early sentence boundary for micro chunk
        if let microSentenceEnd = microSubstring.rangeOfCharacter(from: sentenceEnders, options: .backwards),
           microSentenceEnd.upperBound.utf16Offset(in: microSubstring) > 35 { // Need longer chunk for background processing time
            let chunk = String(microSubstring[..<microSentenceEnd.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                print("🚀 MICRO chunk: \(chunk.count) chars")
                return chunk
            }
        }
        
        // Try slightly larger ultra-fast chunks
        let ultraFastSize = min(200, text.count)
        let fastSubstring = String(text.prefix(ultraFastSize))
        
        // Look for early sentence boundary for ultra-fast chunk
        if let earlySentenceEnd = fastSubstring.rangeOfCharacter(from: sentenceEnders, options: .backwards),
           earlySentenceEnd.upperBound.utf16Offset(in: fastSubstring) > 60 { // Ensure enough time for background
            let chunk = String(fastSubstring[..<earlySentenceEnd.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                print("🚀 Ultra-fast chunk: \(chunk.count) chars")
                return chunk
            }
        }
        
        // Fallback to larger initial chunk size for more processing time
        let target = min(300, text.count) // Increased from initialChunkSize to give more time
        let substring = String(text.prefix(target))
        
        // Look for sentence boundary within target size
        if let lastSentenceEnd = substring.rangeOfCharacter(from: sentenceEnders, options: .backwards) {
            let endIndex = lastSentenceEnd.upperBound
            let chunk = String(substring[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty && chunk.count > 80 { // Ensure it's long enough for processing time
                print("🚀 Fast chunk: \(chunk.count) chars")
                return chunk
            }
        }
        
        // No sentence boundary found, try other punctuation (, ; :)
        let otherPunctuation = CharacterSet(charactersIn: ",;:")
        if let punctuationEnd = substring.rangeOfCharacter(from: otherPunctuation, options: .backwards) {
            let chunk = String(substring[...punctuationEnd.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if chunk.count > 30 { // Ensure it's meaningful
                print("🚀 Punctuation chunk: \(chunk.count) chars")
                return chunk
            }
        }
        
        // Look for word boundary
        let words = substring.components(separatedBy: .whitespacesAndNewlines)
        if words.count > 1 {
            let chunk = words.dropLast().joined(separator: " ")
            print("🚀 Word-boundary chunk: \(chunk.count) chars")
            return chunk
        }
        
        // Fallback to character limit
        print("🚀 Fallback chunk: \(substring.count) chars")
        return substring
    }
    
    private func chunkLargerText(_ text: String, startIndex: Int) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var remaining = text
        var index = startIndex
        
        while !remaining.isEmpty {
            let chunk = extractChunk(from: remaining, maxSize: maxChunkSize)
            chunks.append(TextChunk(text: chunk, isFirstChunk: false, chunkIndex: index))
            
            remaining = String(remaining.dropFirst(chunk.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            index += 1
        }
        
        return chunks
    }
    
    private func extractChunk(from text: String, maxSize: Int) -> String {
        if text.count <= maxSize {
            return text
        }
        
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        let target = maxSize
        
        let substring = String(text.prefix(target))
        
        // Look for sentence boundary
        if let lastSentenceEnd = substring.rangeOfCharacter(from: sentenceEnders, options: .backwards) {
            let endIndex = lastSentenceEnd.upperBound
            let chunk = String(substring[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty && chunk.count >= maxSize / 4 { // Ensure chunk isn't too small
                return chunk
            }
        }
        
        // Look for word boundary
        let words = substring.components(separatedBy: .whitespacesAndNewlines)
        if words.count > 1 {
            return words.dropLast().joined(separator: " ")
        }
        
        // Fallback to character limit
        return substring
    }
}

// Enhanced OpenAI Service
class OpenAIService {
    static let shared = OpenAIService()
    
    private let session = URLSession.shared
    
    private init() {}
    
    func synthesizeText(_ text: String, voice: String, apiKey: String) async throws -> Data {
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY" else {
            throw NSError(domain: "TTSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = OpenAITTSRequest(
            model: "tts-1", // Using tts-1 for fastest response (tts-1-hd available for higher quality)
            input: text,
            voice: voice,
            response_format: "aac"
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TTSError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage: String
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                errorMessage = "OpenAI API Error: \(message)"
                
                // Check for specific string length error
                if message.contains("String should have at most 4096 characters") {
                    print("❌ Text too long for OpenAI TTS API (max 4096 chars)")
                    throw NSError(domain: "TTSError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Text is too long. Please break it into smaller sections."])
                }
            } else {
                errorMessage = "OpenAI TTS failed with status code: \(httpResponse.statusCode)"
            }
            print("❌ OpenAI TTS Error - Status: \(httpResponse.statusCode), Response: \(String(data: data, encoding: .utf8) ?? "No response data")")
            throw NSError(domain: "TTSError", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        return data
    }
}

// Thread-safe counter actor
actor Actor {
    private var count = 0
    
    func increment() -> Int {
        count += 1
        return count
    }
}

@MainActor
class TTSViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var selectedVoice: TTSVoice = .alloy
    @Published var selectedSystemVoice: IOSSystemVoice = .ava // Add iOS system voice selection
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: AudioPlayerDelegate?
    #if os(macOS)
    private var synthesizer = NSSpeechSynthesizer()
    #else
    private var synthesizer = AVSpeechSynthesizer()
    #endif
    private var speechDelegate: SpeechSynthesizerDelegate?
    private var openAIAPIKey: String
    private var currentText: String = ""
    
    // Advanced TTS components
    private let chunkManager = TTSChunkManager()
    private let audioCache = AudioCache.shared
    private let openAIService = OpenAIService.shared
    
    // Playback state
    private var firstChunkPlayer: AVAudioPlayer?
    private var isPlayingFirstChunk = false
    internal var hasTransitionedToFullAudio = false
    private var firstChunkDuration: Double = 0
    
    // Available voices computed property
    #if os(iOS)
    var availableSystemVoices: [IOSSystemVoice] {
        return IOSSystemVoice.allCases.filter { $0.speechVoice != nil }
    }
    #endif
    
    // Internal methods for delegate access
    internal func isFirstChunkPlayer(_ player: AVAudioPlayer) -> Bool {
        return player === firstChunkPlayer
    }
    
    internal func isFullAudioReady() -> Bool {
        return audioPlayer != nil
    }
    
    internal func setFirstChunkDuration(_ duration: Double) {
        firstChunkDuration = duration
    }
    
    init(openAIAPIKey: String) {
        self.openAIAPIKey = openAIAPIKey
        // Set up delegates and keep strong references
        let sDelegate = SpeechSynthesizerDelegate(ttsViewModel: self)
        self.speechDelegate = sDelegate
        self.synthesizer.delegate = sDelegate
        
        // List available voices for debugging
        #if os(iOS)
        listAvailableVoices()
        
        // Set default to first available premium voice or fallback to system default
        let availableVoices = IOSSystemVoice.allCases.filter { $0.speechVoice != nil }
        if let firstAvailable = availableVoices.first {
            selectedSystemVoice = firstAvailable
            print("🎙️ Default voice set to: \(firstAvailable.displayName)")
        } else {
            selectedSystemVoice = .systemDefault
            print("🎙️ Using system default voice")
        }
        #endif
    }
    
    func updateOpenAIAPIKey(_ apiKey: String) {
        self.openAIAPIKey = apiKey
    }
    
    // Function to list available voices for debugging
    #if os(iOS)
    private func listAvailableVoices() {
        print("🗣️ Available iOS Voices:")
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for voice in voices {
            print("   - \(voice.name) (\(voice.identifier)) - \(voice.language)")
        }
        
        // Check if premium voices are available
        for systemVoice in IOSSystemVoice.allCases {
            if let voice = systemVoice.speechVoice {
                print("✅ \(systemVoice.displayName) is available")
            } else {
                print("❌ \(systemVoice.displayName) is NOT available")
            }
        }
    }
    #endif
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        currentText = text
        isPlaying = true
        progress = 0.0
        errorMessage = nil
        statusMessage = "Starting synthesis..."
        
        // Try OpenAI TTS first with advanced features
        Task {
            do {
                try await performSimpleOpenAITTS(text)
            } catch {
                print("OpenAI TTS failed: \(error), falling back to system TTS")
                await MainActor.run {
                    self.speakWithSystemTTS(text)
                }
            }
        }
    }
    
    func speakWithOpenAI(_ text: String) {
        guard !text.isEmpty else { return }
        
        currentText = text
        isPlaying = true
        progress = 0.0
        errorMessage = nil
        statusMessage = "Processing with OpenAI..."
        
        Task {
            do {
                try await performSimpleOpenAITTS(text)
            } catch {
                await MainActor.run {
                    self.errorMessage = "OpenAI TTS failed: \(error.localizedDescription)"
                    // Don't set isPlaying to false immediately - let the user see the error
                    self.statusMessage = "Error occurred"
                    print("OpenAI TTS error: \(error)")
                }
            }
        }
    }
    
    func speakWithLocalTTS(_ text: String) {
        guard !text.isEmpty else { return }
        
        currentText = text
        isPlaying = true
        progress = 0.0
        errorMessage = nil
        statusMessage = "Using local TTS..."
        
        speakWithSystemTTS(text)
    }
    
    func stop() {
        // Clean up audio players
        audioPlayer?.stop()
        audioPlayer = nil
        firstChunkPlayer?.stop()
        firstChunkPlayer = nil
        
        // Clean up speech synthesizer
        #if os(macOS)
        synthesizer.stopSpeaking()
        #else
        synthesizer.stopSpeaking(at: .immediate)
        #endif
        
        // Reset state
        isPlaying = false
        isPlayingFirstChunk = false
        hasTransitionedToFullAudio = false
        firstChunkDuration = 0
        progress = 0.0
        errorMessage = nil
        statusMessage = ""
    }
    
    // MARK: - Advanced OpenAI TTS Implementation
    
    private func performSimpleOpenAITTS(_ text: String) async throws {
        guard !openAIAPIKey.isEmpty && openAIAPIKey != "YOUR_OPENAI_API_KEY" else {
            throw NSError(domain: "TTSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        let voice = selectedVoice.rawValue
        
        // Check cache first for instant playback
        if let cachedAudio = audioCache.cachedAudio(for: text, voice: voice) {
            print("⚡ INSTANT: Audio found in cache!")
            await MainActor.run {
                self.statusMessage = "Playing instantly from cache..."
                self.playAudioData(cachedAudio, isFromCache: true)
            }
            return
        }
        
        // Prioritize FAST startup - use chunking for anything longer than very short text
        if text.count <= 600 { // Small texts only - prioritize speed over simplicity
            print("🚀 Using single-chunk approach for short text (\(text.count) chars)")
            try await performSingleChunkTTS(text, voice: voice)
            return
        }
        
        // For anything longer, use fast chunking strategy for immediate startup
        print("🚀 Using fast chunking for immediate startup (\(text.count) chars)")
        try await performQueuedChunkTTS(text, voice: voice)
    }
    
    private func performSingleChunkTTS(_ text: String, voice: String) async throws {
        await MainActor.run {
            self.statusMessage = "Synthesizing audio..."
        }
        
        let startTime = Date()
        let audioData = try await openAIService.synthesizeText(text, voice: voice, apiKey: openAIAPIKey)
        let synthesisTime = Date().timeIntervalSince(startTime)
        
        print("⚡ Single chunk synthesis completed in \(String(format: "%.2f", synthesisTime))s")
        
        await MainActor.run {
            self.audioCache.cacheAudio(audioData, for: text, voice: voice)
            self.statusMessage = "Playing audio..."
            self.playAudioData(audioData, isFromCache: false)
        }
    }
    
    private func performQueuedChunkTTS(_ text: String, voice: String) async throws {
        print("🚀 Using improved sequential strategy (\(text.count) chars)")
        
        let overallStartTime = Date()
        await MainActor.run {
            self.statusMessage = "Starting immediately..."
        }
        
        // For longer text, process the full text in the background and just play the first chunk quickly
        let chunks = chunkManager.chunkText(text)
        
        // Process ONLY first chunk immediately for instant startup
        let firstChunk = chunks[0]
        let firstChunkStartTime = Date()
        let firstChunkAudio = try await openAIService.synthesizeText(firstChunk.text, voice: voice, apiKey: openAIAPIKey)
        let firstChunkTime = Date().timeIntervalSince(firstChunkStartTime)
        
        print("⚡ First chunk ready in \(String(format: "%.2f", firstChunkTime))s! Starting playback...")
        
        // Start playing first chunk immediately
        await MainActor.run {
            self.statusMessage = "Playing first part..."
            self.playFirstChunk(firstChunkAudio)
        }
        
        // Process remaining chunks in background while respecting 4096 char limit
        if chunks.count > 1 {
            print("🎯 Processing remaining chunks in background for seamless continuation...")
            
            Task {
                do {
                    // Split the text into smaller chunks for maximum parallelism
                    let safeChunks = self.createSafeChunks(from: text, maxSize: 800) // Smaller chunks = more parallel processing
                    print("🚀 Background processing \(safeChunks.count) chunks with full parallelism")
                    
                    // Process ALL chunks in parallel at once - maximum speed
                    let allAudioData = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
                        for (index, chunk) in safeChunks.enumerated() {
                            group.addTask {
                                print("📦 Processing chunk \(index + 1)/\(safeChunks.count) (\(chunk.count) chars)")
                                let chunkAudio = try await self.openAIService.synthesizeText(chunk, voice: voice, apiKey: self.openAIAPIKey)
                                return (index, chunkAudio)
                            }
                        }
                        
                        var results: [(Int, Data)] = []
                        for try await result in group {
                            results.append(result)
                            
                            // Update progress in real-time
                            await MainActor.run {
                                let progress = Double(results.count) / Double(safeChunks.count)
                                self.statusMessage = "Processing: \(Int(progress * 100))% complete..."
                            }
                        }
                        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
                    }
                    
                    // Combine all audio data
                    await MainActor.run {
                        self.statusMessage = "Combining audio chunks..."
                    }
                    
                    let fullAudio = self.combineAudioData(allAudioData)
                    print("✅ Full audio ready! Combined \(allAudioData.count) chunks, \(fullAudio.count) bytes")
                    
                    await MainActor.run {
                        self.statusMessage = "Preparing seamless transition..."
                        self.audioCache.cacheAudio(fullAudio, for: text, voice: voice)
                        self.prepareFullAudioTransition(fullAudio)
                    }
                } catch {
                    print("❌ Background processing failed: \(error)")
                    // Continue with just the first chunk
                    await MainActor.run {
                        self.statusMessage = "Playing first part only due to processing error"
                    }
                }
            }
        } else {
            // Single chunk - just cache it
            await MainActor.run {
                self.audioCache.cacheAudio(firstChunkAudio, for: text, voice: voice)
            }
        }
    }
    
    private func performChunkedTTS(_ text: String, voice: String) async throws {
        await MainActor.run {
            self.statusMessage = "Processing first chunk for immediate playback..."
        }
        
        // Chunk the text
        let chunks = chunkManager.chunkText(text)
        
        // Process first chunk immediately for instant playback
        let firstChunk = chunks[0]
        let firstChunkAudio = try await openAIService.synthesizeText(firstChunk.text, voice: voice, apiKey: openAIAPIKey)
        
        // Start playing first chunk immediately
        await MainActor.run {
            self.statusMessage = "Playing first part..."
            self.playFirstChunk(firstChunkAudio)
        }
        
        // Process remaining chunks if any
        if chunks.count > 1 {
            print("🎯 Starting background processing of \(chunks.count - 1) remaining chunks...")
            
            // Start background processing
            Task {
                do {
                    let remainingChunks = Array(chunks[1...])
                    let remainingAudioData = try await self.processRemainingChunks(remainingChunks, voice: voice)
                    
                    // Combine all audio data (simple concatenation for now)
                    let allAudioData = [firstChunkAudio] + remainingAudioData
                    let combinedAudio = self.combineAudioData(allAudioData)
                    
                    print("✅ Background processing complete! Combined audio: \(combinedAudio.count) bytes")
                    
                    // Cache the complete audio
                    await MainActor.run {
                        self.audioCache.cacheAudio(combinedAudio, for: text, voice: voice)
                        self.prepareFullAudioTransition(combinedAudio)
                    }
                } catch {
                    print("❌ Background processing failed: \(error)")
                    await MainActor.run {
                        self.statusMessage = "Background processing failed, continuing with first chunk"
                    }
                }
            }
        } else {
            print("ℹ️ Single chunk only, no background processing needed")
        }
    }
    
        private func processRemainingChunks(_ chunks: [TTSChunkManager.TextChunk], voice: String) async throws -> [Data] {
        let startTime = Date()
        print("🚀 Processing \(chunks.count) remaining chunks...")
        
        await MainActor.run {
            self.statusMessage = "Processing remaining chunks..."
        }
        
        var results: [Data] = []
        let maxConcurrent = 2 // Reduced concurrent requests to avoid API throttling
        
        // Process in batches
        for batchStart in stride(from: 0, to: chunks.count, by: maxConcurrent) {
            let batchEnd = min(batchStart + maxConcurrent, chunks.count)
            let batch = Array(chunks[batchStart..<batchEnd])
            
            print("📦 Processing batch \(batchStart/maxConcurrent + 1): chunks \(batchStart+1)-\(batchEnd)")
            
            let batchResults = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
                for chunk in batch {
                    group.addTask {
                        let audioData = try await self.openAIService.synthesizeText(chunk.text, voice: voice, apiKey: self.openAIAPIKey)
                        return (chunk.chunkIndex, audioData)
                    }
                }
                
                var batchData: [(Int, Data)] = []
                for try await result in group {
                    batchData.append(result)
                }
                return batchData.sorted { $0.0 < $1.0 }.map { $0.1 } // Sort by index and return data
            }
            
            results.append(contentsOf: batchResults)
            print("✅ Batch complete: \(results.count)/\(chunks.count) chunks done")
            
            // Update progress
            await MainActor.run {
                let progress = Double(results.count) / Double(chunks.count)
                self.statusMessage = "Processing: \(Int(progress * 100))%"
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("🏁 All remaining chunks processed in \(String(format: "%.2f", elapsed)) seconds")
        
        return results
    }
    
    private func playFirstChunk(_ audioData: Data) {
        do {
            firstChunkPlayer = try AVAudioPlayer(data: audioData)
            let delegate = AudioPlayerDelegate(ttsViewModel: self)
            self.audioDelegate = delegate
            firstChunkPlayer?.delegate = delegate
            firstChunkPlayer?.prepareToPlay()
            
            isPlayingFirstChunk = true
            hasTransitionedToFullAudio = false
            firstChunkDuration = firstChunkPlayer?.duration ?? 0
            
            if firstChunkPlayer?.play() == true {
                statusMessage = "Playing first part..."
                startFirstChunkProgressTracking()
            } else {
                throw NSError(domain: "TTSError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to start first chunk playback"])
            }
        } catch {
            print("Failed to play first chunk: \(error)")
            errorMessage = "Audio playback failed: \(error.localizedDescription)"
            isPlaying = false
            statusMessage = ""
        }
    }
    
    private func prepareFullAudioTransition(_ fullAudioData: Data) {
        do {
            print("🎬 Preparing full audio transition with \(fullAudioData.count) bytes")
            audioPlayer = try AVAudioPlayer(data: fullAudioData)
            let delegate = AudioPlayerDelegate(ttsViewModel: self)
            self.audioDelegate = delegate
            audioPlayer?.delegate = delegate
            
            if audioPlayer?.prepareToPlay() == true {
                print("✅ Full audio prepared successfully")
                statusMessage = "Ready for seamless transition..."
            } else {
                print("⚠️ Failed to prepare full audio")
                audioPlayer = nil
            }
        } catch {
            print("❌ Failed to prepare full audio: \(error)")
            audioPlayer = nil
            // Continue with first chunk only
        }
    }
    
    internal func transitionToFullAudio() {
        guard let fullPlayer = audioPlayer, !hasTransitionedToFullAudio else { 
            print("⚠️ Cannot transition - fullPlayer: \(audioPlayer != nil), hasTransitioned: \(hasTransitionedToFullAudio)")
            return 
        }
        
        print("🔄 Transitioning to full audio...")
        hasTransitionedToFullAudio = true
        isPlayingFirstChunk = false
        
        // Get current playback position from first chunk (might be 0 if already finished)
        let currentTime = firstChunkPlayer?.currentTime ?? 0
        let storedDuration = firstChunkDuration
        print("📍 First chunk position: \(String(format: "%.2f", currentTime))s, stored duration: \(String(format: "%.2f", storedDuration))s")
        
        // Stop first chunk player
        firstChunkPlayer?.stop()
        firstChunkPlayer = nil
        
        // Calculate where to start in the full audio to avoid repetition
        let startPosition: Double
        if currentTime == 0 && storedDuration > 0 {
            // First chunk finished completely (currentTime reset to 0)
            // Start the full audio near the end of first chunk content to continue seamlessly
            startPosition = storedDuration * 0.95 // Start at 95% of first chunk duration
            print("🎯 First chunk completed, starting full audio at 95% of first chunk duration")
        } else if currentTime > 0 {
            // First chunk was interrupted, continue from current position
            startPosition = currentTime
            print("🎯 First chunk interrupted, continuing from current position")
        } else {
            // Fallback - start from beginning (shouldn't happen but safety)
            startPosition = 0
            print("⚠️ Fallback - starting from beginning")
        }
        
        fullPlayer.currentTime = startPosition
        
        print("🎯 Transition: currentTime=\(String(format: "%.2f", currentTime))s, storedDuration=\(String(format: "%.2f", storedDuration))s, starting full audio at \(String(format: "%.2f", startPosition))s")
        
        if fullPlayer.play() {
            statusMessage = "Continuing seamlessly..."
            startAudioProgressTracking()
            print("✅ Full audio started from position \(String(format: "%.2f", fullPlayer.currentTime))s")
        } else {
            print("❌ Failed to start full audio player")
            // Don't stop here - let the first chunk finish naturally
            isPlaying = false
            statusMessage = ""
        }
    }
    
    private func createSafeChunks(from text: String, maxSize: Int) -> [String] {
        guard text.count > maxSize else { return [text] }
        
        var chunks: [String] = []
        var remaining = text
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        
        while !remaining.isEmpty {
            if remaining.count <= maxSize {
                chunks.append(remaining)
                break
            }
            
            // Find a good breaking point within maxSize
            let searchRange = String(remaining.prefix(maxSize))
            
            // Try to break at sentence boundary
            if let lastSentenceEnd = searchRange.rangeOfCharacter(from: sentenceEnders, options: .backwards) {
                let endIndex = lastSentenceEnd.upperBound
                let chunk = String(searchRange[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !chunk.isEmpty && chunk.count >= maxSize / 5 { // Allow smaller chunks for faster processing
                    chunks.append(chunk)
                    remaining = String(remaining.dropFirst(chunk.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
            }
            
            // Try to break at word boundary
            let words = searchRange.components(separatedBy: .whitespacesAndNewlines)
            if words.count > 1 {
                let chunk = words.dropLast().joined(separator: " ")
                chunks.append(chunk)
                remaining = String(remaining.dropFirst(chunk.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            
            // Fallback: break at character limit
            let chunk = String(remaining.prefix(maxSize))
            chunks.append(chunk)
            remaining = String(remaining.dropFirst(maxSize))
        }
        
        print("📝 Split text into \(chunks.count) safe chunks (max \(maxSize) chars each)")
        return chunks
    }

    private func combineAudioData(_ audioDataArray: [Data]) -> Data {
        // For AAC data, simple concatenation still has limitations
        // This approach is improved but not perfect - ideally we'd use proper audio processing
        // However, this works reasonably well for most use cases
        var combinedData = Data()
        for audioData in audioDataArray {
            combinedData.append(audioData)
        }
        return combinedData
    }

    private func playAudioData(_ audioData: Data, isFromCache: Bool) {
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            let delegate = AudioPlayerDelegate(ttsViewModel: self)
            self.audioDelegate = delegate
            audioPlayer?.delegate = delegate
            audioPlayer?.prepareToPlay()
            
            if audioPlayer?.play() == true {
                statusMessage = isFromCache ? "Playing from cache..." : "Playing..."
                startAudioProgressTracking()
            } else {
                throw NSError(domain: "TTSError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio playback"])
            }
        } catch {
            print("Failed to play audio: \(error)")
            errorMessage = "Audio playback failed: \(error.localizedDescription)"
            isPlaying = false
            statusMessage = ""
        }
    }
    

    
    private func speakWithSystemTTS(_ text: String) {
        #if os(macOS)
        // Use the macOS system default (enhanced) voice via NSSpeechSynthesizer
        if !synthesizer.startSpeaking(text) {
            self.errorMessage = "Failed to start system TTS"
            self.isPlaying = false
            self.statusMessage = ""
            return
        }
        #else
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate  // Use default rate instead of 0.5
        utterance.volume = 1.0
        
        // Set the selected premium voice
        if let voice = selectedSystemVoice.speechVoice {
            utterance.voice = voice
            print("🗣️ Using iOS voice: \(selectedSystemVoice.displayName)")
        } else {
            print("⚠️ Selected voice not available, falling back to system default")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        synthesizer.speak(utterance)
        #endif
        startSystemTTSProgressTracking()
    }
    
    // MARK: - Progress Tracking
    
    private func startFirstChunkProgressTracking() {
        guard let player = firstChunkPlayer else { return }
        
        let startTime = Date()
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isPlayingFirstChunk {
                if player.isPlaying {
                    // For first chunk, show progress as a portion of total
                    self.progress = (player.currentTime / player.duration) * 0.3 // First chunk is ~30% of progress
                    
                    // Update status with time info
                    let elapsed = Date().timeIntervalSince(startTime)
                    self.statusMessage = "Playing first part... (\(String(format: "%.1f", elapsed))s)"
                } else if player.currentTime > 0 {
                    // First chunk finished playing (currentTime > 0 means it played something)
                    timer.invalidate()
                    if !self.hasTransitionedToFullAudio {
                        let elapsed = Date().timeIntervalSince(startTime)
                        print("⏱️ First chunk finished after \(String(format: "%.2f", elapsed)) seconds")
                        // Transition to full audio if ready
                        self.transitionToFullAudio()
                    }
                }
                // Otherwise, playback hasn't started yet (buffering), so keep waiting
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func startAudioProgressTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.audioPlayer else {
                timer.invalidate()
                return
            }
            
            // Workaround: Immediately after calling `play()`, `AVAudioPlayer.isPlaying` may still
            // be `false` for a short moment while the audio starts buffering.  We don't want to
            // treat that brief gap as playback having ended – it causes `isPlaying` to flip back
            // to `false`, hiding the TTS control UI while the audio is actually about to start.

            if player.isPlaying {
                // Normal progress update during playback
                self.progress = player.currentTime / player.duration
            } else {
                // If playback hasn't truly started yet (currentTime ≈ 0), keep waiting.
                if player.currentTime == 0 {
                    return // don't stop, wait for next tick
                }

                // Otherwise, playback is finished.
                self.progress = 1.0
                self.isPlaying = false
                self.statusMessage = ""
                timer.invalidate()
            }
        }
    }
    
    private func startSystemTTSProgressTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.synthesizer.isSpeaking {
                // Simulate progress for system TTS
                self.progress = min(self.progress + 0.01, 0.95)
            } else if self.isPlaying {
                self.progress = 1.0
                self.isPlaying = false
                self.statusMessage = ""
                timer.invalidate()
            }
        }
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var ttsViewModel: TTSViewModel?
    
    init(ttsViewModel: TTSViewModel) {
        self.ttsViewModel = ttsViewModel
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard let tts = self.ttsViewModel else { return }
            
            if tts.isFirstChunkPlayer(player) {
                print("🎵 First chunk finished playing (successfully: \(flag))")
                // Store the duration before the player resets
                let firstChunkDuration = player.duration
                tts.setFirstChunkDuration(firstChunkDuration)
                
                // First chunk finished
                if !tts.hasTransitionedToFullAudio {
                    if tts.isFullAudioReady() {
                        print("🔄 Full audio is ready, transitioning...")
                        tts.transitionToFullAudio()
                    } else {
                        print("⚠️ Full audio not ready yet - waiting a bit more...")
                        // Full audio not ready, wait a moment and try again
                        tts.statusMessage = "Processing continues..."
                        
                        // Try multiple times with longer delays - more patient approach
                        var retryCount = 0
                        func retryTransition() {
                            retryCount += 1
                            let delay = Double(retryCount) * 0.5 // Longer delays: 0.5s, 1.0s, 1.5s, 2.0s, 2.5s
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                if tts.isFullAudioReady() && !tts.hasTransitionedToFullAudio {
                                    print("🔄 Full audio ready after \(String(format: "%.1f", delay))s delay (attempt \(retryCount)), transitioning...")
                                    tts.transitionToFullAudio()
                                } else if retryCount < 8 { // Try up to 8 times (total ~20 seconds)
                                    print("⏳ Full audio still not ready - retry \(retryCount)/8...")
                                    retryTransition()
                                } else {
                                    print("⚠️ Full audio still not ready after 8 attempts - ending gracefully")
                                    tts.isPlaying = false
                                    tts.progress = 1.0
                                    tts.statusMessage = "Playback complete"
                                }
                            }
                        }
                        retryTransition()
                    }
                }
            } else {
                print("🎵 Main audio finished playing (successfully: \(flag))")
                // Main audio finished
                tts.isPlaying = false
                tts.progress = 1.0
                tts.statusMessage = ""
            }
        }
    }
}

class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var ttsViewModel: TTSViewModel?
    
    init(ttsViewModel: TTSViewModel) {
        self.ttsViewModel = ttsViewModel
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.ttsViewModel?.isPlaying = false
            self.ttsViewModel?.progress = 1.0
            self.ttsViewModel?.statusMessage = ""
        }
    }
    
    #if os(macOS)
    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        if finishedSpeaking {
            DispatchQueue.main.async {
                self.ttsViewModel?.isPlaying = false
                self.ttsViewModel?.progress = 1.0
                self.ttsViewModel?.statusMessage = ""
            }
        }
    }
    #endif
}

#if os(macOS)
extension SpeechSynthesizerDelegate: NSSpeechSynthesizerDelegate {}
#endif

struct TTSControlsView: View {
    @ObservedObject var viewModel: TTSViewModel
    
    var body: some View {
        // Improved Mac layout - organized in cards
        VStack(spacing: 16) {
            // Voice Selection Row
            HStack(spacing: 24) {
                // OpenAI Voice Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .font(.headline)
                        Text("OpenAI Voice")
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Picker("OpenAI Voice", selection: $viewModel.selectedVoice) {
                        ForEach(TTSVoice.allCases, id: \.self) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
                
                // iOS System Voice Card
                #if os(iOS)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "speaker.wave.3")
                            .foregroundColor(.green)
                            .font(.headline)
                        Text("Local TTS")
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Picker("System Voice", selection: $viewModel.selectedSystemVoice) {
                        ForEach(viewModel.availableSystemVoices, id: \.self) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
                #endif
            }
            
            // Actions Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.orange)
                        .font(.headline)
                    Text("Actions")
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Button("Clear Cache") {
                    AudioCache.shared.clearCache()
                }
                .font(.subheadline)
                .buttonStyle(.plain)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Playback Control Card
            if viewModel.isPlaying {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "play.circle")
                            .foregroundColor(.purple)
                            .font(.headline)
                        Text("Playback")
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                            Text("Playing...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            viewModel.stop()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)
                        .disabled(!viewModel.isPlaying)
                    }
                }
                .padding(16)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Progress bar
            if viewModel.progress > 0 && viewModel.progress < 1 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Audio Generation Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .scaleEffect(y: 1.5) // Make progress bar thicker
                        .tint(.blue)
                }
                .padding(16)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - WebContentView
struct WebContentView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    let baseFontSize: Double
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    
    var body: some View {
        ZStack {
            Color.systemBackground.edgesIgnoringSafeArea(.all)
            if let url = viewModel.currentURL {
                // Check if this is a Reddit URL
                let isReddit = url.host?.contains("reddit.com") ?? false
                
                #if os(iOS)
                // On iPad, apply Mac-like behavior - no padding for non-Reddit sites to allow scroll-under
                // On iPhone, keep the padding
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad: Like Mac, only add padding for Reddit
                    if isReddit {
                        WebViewRepresentable(url: url, viewModel: viewModel, baseFontSize: baseFontSize)
                            .padding(.top, calculateTopPadding(isReddit: true))
                    } else {
                        // Non-Reddit on iPad: No padding, content scrolls under tab bar like Mac
                        WebViewRepresentable(url: url, viewModel: viewModel, baseFontSize: baseFontSize)
                    }
                } else {
                    // iPhone: Keep existing behavior with padding
                    WebViewRepresentable(url: url, viewModel: viewModel, baseFontSize: baseFontSize)
                        .padding(.top, calculateTopPadding(isReddit: isReddit))
                }
                #else
                // macOS: Apply appropriate padding
                WebViewRepresentable(url: url, viewModel: viewModel, baseFontSize: baseFontSize)
                    .padding(.top, calculateTopPadding(isReddit: isReddit))
                #endif
            } else {
                Text("Enter a URL to begin")
                    .font(.system(size: baseFontSize))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func calculateTopPadding(isReddit: Bool) -> CGFloat {
        #if os(iOS)
        if isReddit {
            // Reddit needs more padding to clear the tab bar completely
            let safeAreaTop: CGFloat
            if #available(iOS 15.0, *) {
                let scenes = UIApplication.shared.connectedScenes
                let windowScene = scenes.first as? UIWindowScene
                safeAreaTop = windowScene?.windows.first?.safeAreaInsets.top ?? 44
            } else {
                safeAreaTop = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44
            }
            return tabBarHeight + safeAreaTop
        } else {
            // Other websites need more padding on iPad to avoid cutting off the top
            // iPad needs more padding because of the tab bar position
            return UIDevice.current.userInterfaceIdiom == .pad ? 20 : 10
        }
        #else
        if isReddit {
            // On macOS, Reddit needs full offset
            return tabBarHeight + 52
        } else {
            // Other websites just need a small padding
            return 10
        }
        #endif
    }
}

// MARK: - ReadyNotificationsView
struct ReadyNotificationsView: View {
    @Binding var summaryReady: Bool
    @Binding var showSummary: Bool
    @Binding var qnaReady: Bool
    @Binding var showQnA: Bool
    @Binding var summaryWasDismissed: Bool
    @Binding var summaryWasShown: Bool
    @Binding var qnaWasDismissed: Bool
    @Binding var summaryDragOffset: CGFloat
    @Binding var qnaDragOffset: CGFloat
    @ObservedObject var viewModel: SummarizerViewModel
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    
    var body: some View {
        VStack {
            // Add top spacing to push notifications below tab bar
            #if os(iOS)
            Spacer()
                .frame(height: 40)  // Same as our panel offset
            #else
            Spacer()
                .frame(height: 30)  // Same as our panel offset for macOS
            #endif
            
            Spacer()
            HStack {
                if summaryReady && !showSummary && !viewModel.summary.isEmpty {
                    Button {
                        showSummary = true
                        summaryWasDismissed = false
                        summaryWasShown = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Summary Ready")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 18))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if qnaReady && !showQnA && !viewModel.qaHistory.isEmpty {
                    Button {
                        #if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone && showSummary {
                            // First dismiss summary, then show Q&A with delay
                            showSummary = false
                            summaryDragOffset = 0  // Reset summary offset
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                                showQnA = true
                                qnaWasDismissed = false
                            }
                        } else {
                            qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                            showQnA = true
                            qnaWasDismissed = false
                        }
                        #else
                        qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                        showQnA = true
                        qnaWasDismissed = false
                        #endif
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Answer Ready")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 18))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut, value: summaryReady)
        .animation(.easeInOut, value: qnaReady)
    }
}

// MARK: - ControlButtonsView
struct ControlButtonsView: View {
    @Binding var summaryReady: Bool
    @Binding var isGeneratingSummary: Bool
    @Binding var showSummary: Bool
    @Binding var summaryWasDismissed: Bool
    @Binding var summaryWasShown: Bool
    @Binding var qnaReady: Bool
    @Binding var showQnA: Bool
    @Binding var qnaWasDismissed: Bool
    @Binding var showProgress: Bool
    @Binding var summaryDragOffset: CGFloat
    @Binding var qnaDragOffset: CGFloat
    @ObservedObject var viewModel: SummarizerViewModel
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    
    var body: some View {
        VStack {
            // Add top spacing to push control buttons below tab bar
            #if os(iOS)
            Spacer()
                .frame(height: 40)  // Same as our panel offset
            #else
            Spacer()
                .frame(height: 30)  // Same as our panel offset for macOS
            #endif
            
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    // Summary toggle button
                    if (summaryReady || isGeneratingSummary) && !showSummary && (!viewModel.summary.isEmpty || isGeneratingSummary) {
                        Button {
                            showSummary = true
                            summaryWasDismissed = false
                            summaryWasShown = true
                        } label: {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .padding(8)
                                .background(.ultraThinMaterial.opacity(0.01))
                                .glassEffect(.regular.interactive(), in: Circle())
                                .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Q&A toggle button
                    if (qnaReady || viewModel.isAsking || !viewModel.qaHistory.isEmpty) && !showQnA && !viewModel.qaHistory.isEmpty {
                        Button {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone && showSummary {
                                // First dismiss summary, then show Q&A with delay
                                showSummary = false
                                summaryDragOffset = 0  // Reset summary offset
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                                    showQnA = true
                                    qnaWasDismissed = false
                                }
                            } else {
                                qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                                showQnA = true
                                qnaWasDismissed = false
                            }
                            #else
                            qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                            showQnA = true
                            qnaWasDismissed = false
                            #endif
                        } label: {
                            Image(systemName: "questionmark.bubble")
                                .font(.title2)
                                .padding(8)
                                .background(.ultraThinMaterial.opacity(0.01))
                                .glassEffect(.regular.interactive(), in: Circle())
                                .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Progress toggle button
                    if (viewModel.state == .summarizing) && !showProgress {
                        Button {
                            showProgress = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .padding(8)
                                .background(.ultraThinMaterial.opacity(0.01))
                                .glassEffect(.regular.interactive(), in: Circle())
                                .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
            }
            Spacer()
        }
    }
}

// MARK: - MainContentArea
struct MainContentArea: View {
    @Binding var showSummary: Bool
    @Binding var showQnA: Bool
    @Binding var isGeneratingSummary: Bool
    @Binding var summaryWasDismissed: Bool
    @Binding var qnaWasDismissed: Bool
    @ObservedObject var viewModel: SummarizerViewModel
    let baseFontSize: Double
    
    var body: some View {
        ZStack {
            // Web content view
            WebContentView(viewModel: viewModel, baseFontSize: baseFontSize)
            
            // Tap-to-dismiss overlay removed to allow webview scrolling
            // Users can still dismiss panels using:
            // - X button in panel header
            // - Swipe gesture to the right
            // - Back/chevron button
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.tabID) private var tabID: UUID?
    @StateObject private var viewModel: SummarizerViewModel
    @StateObject private var ttsViewModel: TTSViewModel
    @StateObject private var bookmarkManager = BookmarkManager()
    @State private var showQnA = false
    @State private var showSummary = false
    @State private var showProgress = true
    @State private var showBookmarks = false
    @State private var question = ""
    @State private var summaryHeight: CGFloat = 300
    @GestureState private var dragState = DragState.inactive
    @State private var showSettings = false
    @State private var summaryReady = false
    @State private var qnaReady = false
    @State private var summaryWasDismissed = false
    @State private var qnaWasDismissed = false
    @State private var isGeneratingSummary = false
    @State private var summaryDragOffset: CGFloat = 0
    @State private var qnaDragOffset: CGFloat = 0
    @State private var summaryWasShown: Bool = false
    
    // Dark mode and font size preferences
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("baseFontSize") private var baseFontSize: Double = 14.0
    
    // API Keys storage
    @AppStorage("geminiAPIKey") private var storedGeminiAPIKey = ""
    @AppStorage("openAIAPIKey") private var storedOpenAIAPIKey = ""
    @AppStorage("selectedAIProvider") private var selectedAIProvider: AIProvider = .gemini
    
    init() {
        // Use stored API keys if available
        let geminiAPIKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        let openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        let storedProvider = UserDefaults.standard.string(forKey: "selectedAIProvider")
        let selectedProvider: AIProvider = storedProvider != nil ? AIProvider(rawValue: storedProvider!) ?? .gemini : .gemini
        
        let geminiService = GeminiService(apiKey: geminiAPIKey)
        let summarizerViewModel = SummarizerViewModel(geminiService: geminiService)
        summarizerViewModel.selectedAIProvider = selectedProvider
        
        _viewModel = StateObject(wrappedValue: summarizerViewModel)
        _ttsViewModel = StateObject(wrappedValue: TTSViewModel(openAIAPIKey: openAIAPIKey))
    }
    
    var mainContentView: some View {
        ZStack {
            // Main content area
            MainContentArea(
                showSummary: $showSummary,
                showQnA: $showQnA,
                isGeneratingSummary: $isGeneratingSummary,
                summaryWasDismissed: $summaryWasDismissed,
                qnaWasDismissed: $qnaWasDismissed,
                viewModel: viewModel,
                baseFontSize: baseFontSize
            )
            
            // Ready notifications
            ReadyNotificationsView(
                summaryReady: $summaryReady,
                showSummary: $showSummary,
                qnaReady: $qnaReady,
                showQnA: $showQnA,
                summaryWasDismissed: $summaryWasDismissed,
                summaryWasShown: $summaryWasShown,
                qnaWasDismissed: $qnaWasDismissed,
                summaryDragOffset: $summaryDragOffset,
                qnaDragOffset: $qnaDragOffset,
                viewModel: viewModel
            )
            
            // Control buttons
            ControlButtonsView(
                summaryReady: $summaryReady,
                isGeneratingSummary: $isGeneratingSummary,
                showSummary: $showSummary,
                summaryWasDismissed: $summaryWasDismissed,
                summaryWasShown: $summaryWasShown,
                qnaReady: $qnaReady,
                showQnA: $showQnA,
                qnaWasDismissed: $qnaWasDismissed,
                showProgress: $showProgress,
                summaryDragOffset: $summaryDragOffset,
                qnaDragOffset: $qnaDragOffset,
                viewModel: viewModel
            )
        }
    }
    
    private func calculateTabBarHeight() -> CGFloat {
        #if os(iOS)
        // Just a tiny bit lower - adding 5 more points
        return 40
        #else
        // macOS - a tiny bit lower
        return 30
        #endif
    }
    
    var sidePanels: some View {
        Group {
            // Summary side panel
            if showSummary {
                MacSummaryPanelView(
                    viewModel: viewModel,
                    ttsViewModel: ttsViewModel,
                    baseFontSize: baseFontSize,
                    onDismiss: {
                        showSummary = false
                        if isGeneratingSummary {
                            summaryWasDismissed = true
                        }
                    }
                )
                #if os(iOS)
                .frame(width: UIDevice.current.userInterfaceIdiom == .phone ? UIScreen.main.bounds.width : 600)
                .padding(.bottom, UIDevice.current.userInterfaceIdiom == .phone ? 90 : 0)
                .offset(x: UIDevice.current.userInterfaceIdiom == .phone ? -10 + summaryDragOffset : summaryDragOffset)
                .gesture(
                    SimultaneousGesture(
                        // Touch gesture for direct touch
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    summaryDragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                let screenWidth = UIDevice.current.userInterfaceIdiom == .phone ? UIScreen.main.bounds.width : 600
                                if value.translation.width > 50 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        summaryDragOffset = screenWidth
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showSummary = false
                                        summaryDragOffset = 0
                                        if isGeneratingSummary {
                                            summaryWasDismissed = true
                                        }
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        summaryDragOffset = 0
                                    }
                                }
                            },
                        // Trackpad gesture for Magic Keyboard
                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    summaryDragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                let screenWidth = UIDevice.current.userInterfaceIdiom == .phone ? UIScreen.main.bounds.width : 600
                                if value.translation.width > 50 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        summaryDragOffset = screenWidth
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showSummary = false
                                        summaryDragOffset = 0
                                        if isGeneratingSummary {
                                            summaryWasDismissed = true
                                        }
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        summaryDragOffset = 0
                                    }
                                }
                            }
                    )
                )
                #else
                .frame(width: 600)
                .offset(x: summaryDragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                summaryDragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 50 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    summaryDragOffset = 600
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showSummary = false
                                    summaryDragOffset = 0
                                    if isGeneratingSummary {
                                        summaryWasDismissed = true
                                    }
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    summaryDragOffset = 0
                                }
                            }
                        }
                )
                #endif
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut, value: showSummary)
            }
            
            // Q&A Panel for iPhone (overlay)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone && showQnA {
                MacQnAPanelView(
                    viewModel: viewModel,
                    ttsViewModel: ttsViewModel,
                    question: $question,
                    qnaReady: $qnaReady,
                    baseFontSize: baseFontSize,
                    onDismiss: {
                        showQnA = false
                        if viewModel.isAsking {
                            qnaWasDismissed = true
                        }
                    }
                )
                .frame(width: UIScreen.main.bounds.width)
                .padding(.bottom, 90)
                .offset(x: (summaryWasShown ? -45 : -10) + qnaDragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                qnaDragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 50 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    qnaDragOffset = UIScreen.main.bounds.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showQnA = false
                                    qnaDragOffset = 0
                                    if viewModel.isAsking {
                                        qnaWasDismissed = true
                                    }
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    qnaDragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut, value: showQnA)
            }
            #endif
            
            // Q&A side panel (only for iPad and Mac)
            #if os(macOS)
            if showQnA {
                MacQnAPanelView(
                    viewModel: viewModel,
                    ttsViewModel: ttsViewModel,
                    question: $question,
                    qnaReady: $qnaReady,
                    baseFontSize: baseFontSize,
                    onDismiss: {
                        showQnA = false
                        if viewModel.isAsking {
                            qnaWasDismissed = true
                        }
                    }
                )
                .frame(width: 600)
                .offset(x: qnaDragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                qnaDragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 50 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    qnaDragOffset = 600
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showQnA = false
                                    qnaDragOffset = 0
                                    if viewModel.isAsking {
                                        qnaWasDismissed = true
                                    }
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    qnaDragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut, value: showQnA)
            }
            #elseif os(iOS)
            if UIDevice.current.userInterfaceIdiom != .phone && showQnA {
                MacQnAPanelView(
                    viewModel: viewModel,
                    ttsViewModel: ttsViewModel,
                    question: $question,
                    qnaReady: $qnaReady,
                    baseFontSize: baseFontSize,
                    onDismiss: {
                        showQnA = false
                        if viewModel.isAsking {
                            qnaWasDismissed = true
                        }
                    }
                )
                .frame(width: 600)
                .offset(x: qnaDragOffset)
                .gesture(
                    SimultaneousGesture(
                        // Touch gesture for direct touch
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    qnaDragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width > 50 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        qnaDragOffset = 600
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showQnA = false
                                        qnaDragOffset = 0
                                        if viewModel.isAsking {
                                            qnaWasDismissed = true
                                        }
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        qnaDragOffset = 0
                                    }
                                }
                            },
                        // Trackpad gesture for Magic Keyboard
                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    qnaDragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width > 50 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        qnaDragOffset = 600
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showQnA = false
                                        qnaDragOffset = 0
                                        if viewModel.isAsking {
                                            qnaWasDismissed = true
                                        }
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        qnaDragOffset = 0
                                    }
                                }
                            }
                    )
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut, value: showQnA)
            }
            #endif
        }
    }
    
    @ViewBuilder
    var contentLayout: some View {
        ZStack(alignment: .bottom) {
            // Base layer: WebView fills entire space
            mainContentView
                .background {
                    ZStack {
                        // ALWAYS visible dramatic background for glass effects
                        GlassBackgroundView(variant: .summary)
                            .opacity(0.8)
                        
                        // Additional overlay when Q&A is shown
                        if showQnA {
                            GlassBackgroundView(variant: .qna)
                                .opacity(0.6)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showQnA)
                }
            
            // Overlay layer: Panels on top
            VStack {
                // Push panels down below tab bar
                Spacer()
                    .frame(height: calculateTabBarHeight())
                
                HStack(alignment: .top) {
                    // Bookmarks panel on the left
                    if showBookmarks {
                        BookmarksView(
                            bookmarkManager: bookmarkManager,
                            onSelectBookmark: { urlString in
                                viewModel.urlString = urlString
                                Task {
                                    await viewModel.loadURL()
                                }
                                showBookmarks = false
                            },
                            onDismiss: {
                                showBookmarks = false
                            }
                        )
                        .frame(width: 300)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .animation(.easeInOut, value: showBookmarks)
                    }
                    
                    Spacer()
                        .allowsHitTesting(false)  // Allow touches to pass through
                    
                    // Summary and Q&A panels on the right
                    sidePanels
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer(minLength: 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(
                viewModel: viewModel,
                bookmarkManager: bookmarkManager,
                showSummary: $showSummary,
                showQnA: $showQnA,
                showSettings: $showSettings,
                showBookmarks: $showBookmarks,
                summaryReady: $summaryReady,
                summaryWasDismissed: $summaryWasDismissed,
                isGeneratingSummary: $isGeneratingSummary,
                summaryWasShown: $summaryWasShown
            )
            
            contentLayout
            
            // Bottom bar for iPhone only
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                BottomToolbarView(
                    viewModel: viewModel,
                    showSummary: $showSummary,
                    showQnA: $showQnA,
                    summaryReady: $summaryReady,
                    summaryWasDismissed: $summaryWasDismissed,
                    isGeneratingSummary: $isGeneratingSummary,
                    summaryWasShown: $summaryWasShown
                )
                .background(Color.secondaryBackground)
            }
            #endif
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .environment(\.baseFontSize, baseFontSize)
        // Report tab metadata up to TabContainerView
        .onChange(of: viewModel.pageTitle) { newTitle in
            #if os(iOS) || os(macOS)
            if let tabID = tabID {
                NotificationCenter.default.post(name: .tabMetaUpdated, object: nil, userInfo: [
                    "tabID": tabID,
                    "title": newTitle
                ])
            }
            #endif
        }
        .onChange(of: viewModel.currentURL) { newURL in
            #if os(iOS) || os(macOS)
            if let tabID = tabID, let url = newURL {
                NotificationCenter.default.post(name: .tabMetaUpdated, object: nil, userInfo: [
                    "tabID": tabID,
                    "url": url.absoluteString
                ])
            }
            #endif
        }
        // Global Escape (macOS) to dismiss Summary/Q&A regardless of focus (e.g., after TTS)
        .onReceive(NotificationCenter.default.publisher(for: .closePanels)) { _ in
            #if os(macOS)
            // if panels are open, close them
            if showSummary { showSummary = false }
            if showQnA { showQnA = false }
            #endif
        }
        .overlay(
            Group {
                // Reddit API Error overlay
                if let redditError = viewModel.redditAPIError {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        RedditErrorView(
                            error: redditError,
                            onRetry: {
                                viewModel.retryLastAction()
                            },
                            onDismiss: {
                                viewModel.dismissRedditError()
                            }
                        )
                        .frame(maxWidth: 500)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: viewModel.redditAPIError != nil)
                }
                
                // Loading overlay (now dismissible)
                if viewModel.state == .summarizing && showProgress {
                    DismissibleLoadingOverlayView(
                        viewModel: viewModel,
                        onDismiss: {
                            showProgress = false
                        }
                    )
                }
                
                if showSettings {
                    SettingsView(
                        showSettings: $showSettings,
                        isDarkMode: $isDarkMode,
                        baseFontSize: $baseFontSize,
                        geminiAPIKey: $storedGeminiAPIKey,
                        openAIAPIKey: $storedOpenAIAPIKey,
                        selectedAIProvider: $selectedAIProvider,
                        viewModel: viewModel,
                        ttsViewModel: ttsViewModel
                    )
                }
            }
        )
        .onChange(of: summaryReady) { ready in
            if ready && summaryWasDismissed {
                showSummary = true
                summaryWasDismissed = false
                summaryWasShown = true
            }
        }
        .onChange(of: selectedAIProvider) { provider in
            print("🔄 ContentView: selectedAIProvider changed to: \(provider.displayName)")
            viewModel.updateAIProvider(provider)
        }
        .onChange(of: qnaReady) { ready in
            if ready && qnaWasDismissed {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone && showSummary {
                    // First dismiss summary, then show Q&A with delay
                    showSummary = false
                    summaryDragOffset = 0  // Reset summary offset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                        showQnA = true
                        qnaWasDismissed = false
                    }
                } else {
                    qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                    showQnA = true
                    qnaWasDismissed = false
                }
                #else
                qnaDragOffset = 0  // Ensure Q&A offset starts at 0
                showQnA = true
                qnaWasDismissed = false
                #endif
            }
        }
        .onChange(of: viewModel.currentURL) { _ in
            // Reset all UI states when navigating to a new URL
            showSummary = false
            showQnA = false
            summaryDragOffset = 0
            qnaDragOffset = 0
            summaryWasShown = false
            showProgress = true
            summaryReady = false
            qnaReady = false
            summaryWasDismissed = false
            qnaWasDismissed = false
            isGeneratingSummary = false
        }
        .onChange(of: viewModel.summary) { newSummary in
            // Reset summary ready state when summary is cleared
            if newSummary.isEmpty {
                summaryReady = false
            }
        }
        .onChange(of: viewModel.qaHistory.count) { newCount in
            // Reset Q&A ready state when history is cleared
            if newCount == 0 {
                qnaReady = false
            }
        }
        .onChange(of: viewModel.shouldShowSummary) { shouldShow in
            if shouldShow {
                summaryReady = true
                showSummary = true
                summaryWasShown = true
                viewModel.shouldShowSummary = false // Reset the flag
            }
        }
    }
}

// MARK: - Reddit Error Display Component
struct RedditErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Reddit API Error")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("✕") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let redditError = error as? RedditAPIError,
                   let recovery = redditError.recoveryDescription {
                    Text("💡 " + recovery)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 4)
        .padding()
    }
}

// MARK: - Mac Summary Panel View
struct MacSummaryPanelView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var ttsViewModel: TTSViewModel
    let baseFontSize: Double
    let onDismiss: () -> Void
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    
    // Adaptive font size - larger for iPad
    private var adaptiveFontSize: Double {
        #if os(iOS)
        return baseFontSize * 1.6  // 60% larger for iOS/iPad
        #else
        return baseFontSize * 1.2  // 20% larger for Mac
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // TTS Control Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Summary")
                        .font(.headline)
                    if let count = viewModel.commentCount {
                        Text("📊 \(count) comments extracted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // OpenAI TTS Button
                Button {
                    if ttsViewModel.isPlaying {
                        ttsViewModel.stop()
                    } else {
                        ttsViewModel.speakWithOpenAI(viewModel.summary)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.caption)
                        Text("OpenAI")
                            .font(.caption)
                            .bold()
                            .fixedSize()
                    }
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .disabled(viewModel.summary.isEmpty)
                
                // Local TTS Button
                Button {
                    if ttsViewModel.isPlaying {
                        ttsViewModel.stop()
                    } else {
                        ttsViewModel.speakWithLocalTTS(viewModel.summary)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.caption)
                        Text("Local")
                            .font(.caption)
                            .bold()
                            .fixedSize()
                    }
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .disabled(viewModel.summary.isEmpty)
                
                // Copy Button
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = viewModel.summary
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.summary, forType: .string)
                    #endif
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .disabled(viewModel.summary.isEmpty)
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .bold()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
            }
            .padding()
            .background(.ultraThinMaterial.opacity(0.015))  // very minimal blur for header
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // TTS Controls when playing
            if ttsViewModel.isPlaying {
                TTSControlsView(viewModel: ttsViewModel)
                    .padding()
            }
            
            // Summary content
            ScrollView {
                if viewModel.summary.isEmpty {
                    Text("Summary will appear here")
                        .padding()
                        .foregroundColor(.secondary)
                } else {
                    FullMarkdownTextView(viewModel.summary, fontSize: adaptiveFontSize, lineSpacing: 4)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 400)
        .frame(maxHeight: 600)  // Limited height to make it more compact
        .background(.ultraThinMaterial.opacity(0.01))  // extremely minimal blur
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))  // Limit touch area
        .shadow(radius: 3, y: 1)
        #if os(iOS)
        // Add pinch gesture for iPad (works with touch and trackpad)
        .gesture(
            MagnificationGesture()
                .onEnded { value in
                    if value < 0.8 {  // Pinch in to close
                        withAnimation(.easeOut(duration: 0.2)) {
                            onDismiss()
                        }
                    }
                }
        )
        #endif
    }
}

// MARK: - Mac Q&A Panel View
struct MacQnAPanelView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @ObservedObject var ttsViewModel: TTSViewModel
    @Binding var question: String
    @Binding var qnaReady: Bool
    let baseFontSize: Double
    let onDismiss: () -> Void
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    
    // Adaptive font size - larger for iPad
    private var adaptiveFontSize: Double {
        #if os(iOS)
        return baseFontSize * 1.6  // 60% larger for iOS/iPad
        #else
        return baseFontSize * 1.2  // 20% larger for Mac
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Q&A Header
            HStack {
                VStack(alignment: .leading) {
                    if let count = viewModel.commentCount {
                        Text("Q&A - 📊 \(count) comments available")
                            .font(.headline)
                    } else {
                        Text("Q&A")
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .bold()
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
            }
            .padding(.horizontal)
            .padding(.top)
            .glassEffect(.regular.interactive())
            
            HStack(spacing: 8) {
                            TextField("Ask a question", text: $question)
                .textFieldStyle(AdaptiveLiquidGlassTextFieldStyle())
                    .disabled(viewModel.isAsking)
                    .onSubmit {
                        if !question.isEmpty && !viewModel.isAsking {
                            Task {
                                await viewModel.askQuestion(question)
                                question = ""
                                qnaReady = true
                            }
                        }
                    }

                Button("Ask") {
                    Task {
                        await viewModel.askQuestion(question)
                        question = ""
                        qnaReady = true
                    }
                }
                .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                .disabled(question.isEmpty || viewModel.isAsking)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            if viewModel.isAsking {
                ProgressView()
                    .padding()
            }
            
            // TTS Controls when playing or preparing
            if ttsViewModel.isPlaying || !ttsViewModel.statusMessage.isEmpty || ttsViewModel.errorMessage != nil {
                VStack(spacing: 8) {
                    TTSControlsView(viewModel: ttsViewModel)
                    
                    // Show status message
                    if !ttsViewModel.statusMessage.isEmpty {
                        Text(ttsViewModel.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Show error if any
                    if let error = ttsViewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    if ttsViewModel.progress > 0 && ttsViewModel.progress < 1 {
                        ProgressView(value: ttsViewModel.progress)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
            }
            
            ScrollView {
                if !viewModel.qaHistory.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.qaHistory.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Q: \(viewModel.qaHistory[index].question)")
                                    .font(.system(size: adaptiveFontSize, weight: .bold))
                                
                                HStack(alignment: .top) {
                                    Text("A:")
                                        .font(.system(size: adaptiveFontSize, weight: .bold))
                                    VStack(alignment: .leading, spacing: 4) {
                                        FullMarkdownTextView(viewModel.qaHistory[index].answer, fontSize: adaptiveFontSize, lineSpacing: 4)
                                        
                                        // TTS Controls for answers
                                        HStack {
                                            // OpenAI TTS Button
                                            Button {
                                                if ttsViewModel.isPlaying {
                                                    ttsViewModel.stop()
                                                } else {
                                                    ttsViewModel.speakWithOpenAI(viewModel.qaHistory[index].answer)
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                                        .font(.caption)
                                                    Text("OpenAI")
                                                        .font(.caption2)
                                                }
                                            }
                                            .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                                            
                                            // Local TTS Button
                                            Button {
                                                if ttsViewModel.isPlaying {
                                                    ttsViewModel.stop()
                                                } else {
                                                    ttsViewModel.speakWithLocalTTS(viewModel.qaHistory[index].answer)
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: ttsViewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                                        .font(.caption)
                                                    Text("Local")
                                                        .font(.caption2)
                                                }
                                            }
                                            .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                                            
                                            // Copy Button for Q&A answers
                                            Button {
                                                #if os(iOS)
                                                UIPasteboard.general.string = viewModel.qaHistory[index].answer
                                                #else
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(viewModel.qaHistory[index].answer, forType: .string)
                                                #endif
                                            } label: {
                                                Image(systemName: "doc.on.clipboard")
                                                    .font(.caption)
                                            }
                                            .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                                            
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .padding(4)
                            .background(.ultraThinMaterial.opacity(0.005))  // nearly invisible blur
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(4)
                } else if !viewModel.isAsking {
                    Text("Enter your question about the content")
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
        }
        .frame(width: 400)
        .frame(maxHeight: 600)  // Limited height to make it more compact
        .background(.ultraThinMaterial.opacity(0.01))  // extremely minimal blur
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))  // Limit touch area
        .shadow(radius: 3, y: 1)
        #if os(iOS)
        // Add pinch gesture for iPad (works with touch and trackpad)
        .gesture(
            MagnificationGesture()
                .onEnded { value in
                    if value < 0.8 {  // Pinch in to close
                        withAnimation(.easeOut(duration: 0.2)) {
                            onDismiss()
                        }
                    }
                }
        )
        #endif
    }
}

// MARK: - Dismissible Loading Overlay View
struct DismissibleLoadingOverlayView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Dismissible background - more transparent
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 24) {
                // Close button at top
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .bold()
                    }
                    .buttonStyle(AdaptiveLiquidGlassButtonStyle(cornerRadius: 8, isCompact: true))
                }
                .padding(.horizontal, 40)
                
                // Progress content with glass effect
                VStack(spacing: 24) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(1.5)
                    
                    ProgressTrackingView(viewModel: viewModel)
                        .allowsHitTesting(false) // This prevents the progress view from blocking taps
                    
                    Text("Tap anywhere or ✕ to dismiss")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(30)
                .background(.ultraThinMaterial.opacity(0.01))  // extremely minimal blur
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(radius: 3, y: 1)
                .allowsHitTesting(false) // Allow taps to pass through to the background
            }
        }
        .allowsHitTesting(true) // Ensure the overlay itself can receive taps
    }
}



#if os(iOS)
// MARK: - Bottom Toolbar for iPhone
struct BottomToolbarView: View {
    @ObservedObject var viewModel: SummarizerViewModel
    @Binding var showSummary: Bool
    @Binding var showQnA: Bool
    @Binding var summaryReady: Bool
    @Binding var summaryWasDismissed: Bool
    @Binding var isGeneratingSummary: Bool
    @Binding var summaryWasShown: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Summary button with menu
            Menu {
                Button {
                    isGeneratingSummary = true
                    showSummary = true
                    summaryReady = false
                    summaryWasDismissed = false
                    summaryWasShown = true
                    Task {
                        await viewModel.summarize(length: .short)
                        isGeneratingSummary = false
                        summaryReady = true
                        if summaryWasDismissed {
                            showSummary = true
                            summaryWasDismissed = false
                            summaryWasShown = true
                        }
                    }
                } label: {
                    Label("Short Summary", systemImage: "text.badge.minus")
                    Text("2 paragraphs max")
                }
                
                Button {
                    isGeneratingSummary = true
                    showSummary = true
                    summaryReady = false
                    summaryWasDismissed = false
                    summaryWasShown = true
                    Task {
                        await viewModel.summarize(length: .long)
                        isGeneratingSummary = false
                        summaryReady = true
                        if summaryWasDismissed {
                            showSummary = true
                            summaryWasDismissed = false
                            summaryWasShown = true
                        }
                    }
                } label: {
                    Label("Detailed Summary", systemImage: "text.badge.plus")
                    Text("Comprehensive")
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 20))
                    Text("Summary")
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.currentURL == nil)
            
            // Q&A button
            Button {
                showQnA.toggle()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "questionmark.bubble")
                        .font(.system(size: 20))
                    Text("Q&A")
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.currentURL == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .padding(.bottom, 8) // Small padding for home indicator
    }
}
#endif

// MARK: - Subtle Background for Glass Effects
struct GlassBackgroundView: View {
    let variant: BackgroundVariant
    
    enum BackgroundVariant {
        case summary
        case qna
        case settings
    }
    
    var body: some View {
        ZStack {
            // Subtle gradient with higher contrast
            baseGradient
            
            // Static geometric pattern for glass to blur
            GeometricPatternView(variant: variant)
        }
    }
    
    @ViewBuilder
    private var baseGradient: some View {
        switch variant {
        case .summary:
            // MUCH higher contrast gradient for dramatic glass effect
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.5),
                    Color.indigo.opacity(0.7),
                    Color.cyan.opacity(0.4),
                    Color.white.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .qna:
            // MUCH higher contrast gradient for dramatic glass effect
            LinearGradient(
                colors: [
                    Color.green.opacity(0.6),
                    Color.teal.opacity(0.5),
                    Color.mint.opacity(0.7),
                    Color.blue.opacity(0.4),
                    Color.white.opacity(0.3)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .settings:
            // Higher contrast neutral gradient
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.5),
                    Color.secondary.opacity(0.4),
                    Color.primary.opacity(0.3),
                    Color.white.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct GeometricPatternView: View {
    let variant: GlassBackgroundView.BackgroundVariant
    
    var body: some View {
        Canvas { context, size in
            // More visible diagonal lines pattern for glass to blur
            let lineSpacing: CGFloat = 30
            let lineWidth: CGFloat = 2
            
            for i in stride(from: -size.height, to: size.width + size.height, by: lineSpacing) {
                let path = Path { path in
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i + size.height, y: size.height))
                }
                context.stroke(path, with: .color(patternColor.opacity(0.3)), lineWidth: lineWidth)
            }
            
            // Add more visible dots for texture
            for _ in 0..<100 {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                    with: .color(patternColor.opacity(0.4))
                )
            }
            
            // Add some larger shapes for more visual interest
            for _ in 0..<20 {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let size = Double.random(in: 8...15)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size)),
                    with: .color(patternColor.opacity(0.2))
                )
            }
        }
    }
    
    private var patternColor: Color {
        switch variant {
        case .summary:
            return .white
        case .qna:
            return .white
        case .settings:
            return .primary
        }
    }
}
