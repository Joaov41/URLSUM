import SwiftUI
import Combine
import Foundation
import WebKit
import SwiftSoup
import AppKit

// MARK: - HostingWindowFinder
struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> ()
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
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
    
    func summarizeContent(_ text: String) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        let parameters = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: "Summarize the following text, if you detect the text are Reddit comments,follow these instructions:identify and explain the primary tooics and discussiopns being addressed, highlight key themes, viewpoints present in the conversation. Ensure the summary is clear and provide a final summary:\n\n" + text)
                ])
            ]
        )
        // Log the content and length
        print("📄 Sending content for summarization:")
        print("📄 Content length: \(text.count) characters")
        print("📄 Full content: \(text)")
        
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
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
        
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
        
        Please provide a clear and concise answer based on the context above.
        """
        
        let parameters = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt)
                ])
            ]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(parameters)
        
        print("🔍 Q&A Request:")
        print("URL: \(url)")
        print("Prompt length: \(prompt.count) characters")
        
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
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
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
    func extractContent(from url: URL) async throws -> String
}

struct RedditContentExtractor: ContentExtractor {
    private let api = RedditAPI()
    
    func extractContent(from url: URL) async throws -> String {
        print("📍 RedditContentExtractor - Starting extraction for URL: \(url)")
        return try await api.getContent(from: url)
    }
}

// MARK: - WebContentExtractor
struct WebContentExtractor: ContentExtractor {
    func extractContent(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        let doc = try SwiftSoup.parse(htmlString)
        try doc.select("script, style, nav, footer, header, aside").remove()
        
        if let articleContent = try doc.select("article").first()?.text() {
            return cleanText(articleContent)
        }
        
        if let mainContent = try doc.select("main").first()?.text() {
            return cleanText(mainContent)
        }
        
        return cleanText(try doc.body()?.text() ?? "")
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
    @Published var qaHistory: [(question: String, answer: String)] = []
    private var previousQuestion: String = ""
    private var previousAnswer: String = ""
    
    private let geminiService: GeminiService
    
    enum ViewState {
        case idle
        case loading
        case summarizing
        case asking
        case error(String)
    }
    
    init(geminiService: GeminiService) {
        self.geminiService = geminiService
    }
    
    func loadURL() async {
        await updateURL(URL(string: urlString) ?? URL(string: "about:blank")!)
    }
    
    func updateURL(_ url: URL) async {
        var cleanURL = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.contains("://") {
            cleanURL = "https://" + cleanURL
        }
        cleanURL = cleanURL.replacingOccurrences(of: "https.", with: "https://")
        
        guard let validURL = URL(string: cleanURL) else {
            state = .error("Invalid URL")
            return
        }
        
        if currentURL != validURL {
            extractedText = ""
            summary = ""
            answer = ""
        }
        
        currentURL = validURL
        urlString = validURL.absoluteString
    }
    
    weak var webView: WKWebView?
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }
    
    func summarize() async {
        guard let webView = webView,
              let url = webView.url else {
            state = .error("No URL loaded")
            return
        }
        
        print("🔍 Summarizing content from URL: \(url)")
        state = .loading
        
        do {
            let extractor = ContentExtractionFactory.createExtractor(for: url)
            let content = try await extractor.extractContent(from: url)
            extractedText = content
            
            state = .summarizing
            summary = try await geminiService.summarizeContent(content)
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
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
        state = .loading
        isAsking = true
        errorMessage = ""
        answer = ""
        
        do {
            let extractor = ContentExtractionFactory.createExtractor(for: url)
            let content = try await extractor.extractContent(from: url)
            
            if content.isEmpty {
                state = .error("No content found")
                errorMessage = "No content found to analyze"
                return
            }
            
            extractedText = content
            print("📝 Extracted content length: \(content.count)")
            
            state = .asking
            let newAnswer = try await geminiService.qnaContent(content, question: question, previousQuestion: previousQuestion.isEmpty ? nil : previousQuestion, previousAnswer: previousAnswer.isEmpty ? nil : previousAnswer)
            
            // Store current Q&A for next time
            previousQuestion = question
            previousAnswer = newAnswer
            print("✅ Received answer: \(newAnswer)")
            
            if newAnswer.isEmpty {
                state = .error("Empty response")
                errorMessage = "No answer received from AI"
                return
            }
            
            await MainActor.run {
                answer = newAnswer
                qaHistory.append((question: question, answer: newAnswer))
                state = .idle
            }
        } catch let error as GeminiError {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            print("❌ GeminiError: \(error.localizedDescription)")
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = "Failed to process question: \(error.localizedDescription)"
            print("❌ Error: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isAsking = false
        }
    }
    
    func clear() {
        urlString = ""
        currentURL = nil
        extractedText = ""
        summary = ""
        answer = ""
        errorMessage = ""
        previousQuestion = ""
        previousAnswer = ""
        qaHistory = []
        state = .idle
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel: SummarizerViewModel
    @State private var showQnA = false
    @State private var showSummary = false
    @State private var question = ""
    @State private var summaryHeight: CGFloat = 300 // Default height
    @GestureState private var dragState = DragState.inactive
    @State private var isGeneratingSummary = false

    
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
    
    init() {
        let geminiService = GeminiService(apiKey: "YOUR API KEY ")
        _viewModel = StateObject(wrappedValue: SummarizerViewModel(geminiService: geminiService))
    }
    
    var body: some View {
        ZStack {
            // Dark mode background
            Color(.windowBackgroundColor)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top toolbar
                HStack(spacing: 8) {
                    TextField("Enter URL", text: $viewModel.urlString)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await viewModel.loadURL() }
                        }
                    
                    Button("Load") {
                        Task { await viewModel.loadURL() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Summarize") {
                        isGeneratingSummary = true  // Show spinner
                        Task {
                            await viewModel.summarize()
                            isGeneratingSummary = false  // Hide spinner
                            showSummary = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.currentURL == nil)
                    
                    Button("Q&A") {
                        showQnA.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color(.windowBackgroundColor))
                
                // Main content
                if let url = viewModel.currentURL {
                    WebViewRepresentable(url: url, viewModel: viewModel)
                } else {
                    Text("Enter a URL to begin")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Loading overlay
            if isGeneratingSummary {
                ZStack {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Generating summary...")
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color(.windowBackgroundColor).opacity(0.8))
                    .cornerRadius(10)
                }
            }
            
            // Bottom resizable summary sheet
            if showSummary {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Drag handle
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
                                    .onEnded { value in
                                        let newHeight = summaryHeight - value.translation.height
                                        summaryHeight = min(max(newHeight, 200), geometry.size.height * 0.8)
                                    }
                            )
                        
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
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        ScrollView {
                            Text(viewModel.summary.isEmpty ? "Summary will appear here" : viewModel.summary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(radius: 10)
                    .frame(height: summaryHeight + dragState.translation.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: showSummary)
                }
            }
            
            if showQnA {
                VStack {
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
                    }
                    .padding()
                    
                    HStack {
                        TextField("Enter your question", text: $question)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isAsking)
                        
                        Button(action: {
                            Task {
                                await viewModel.askQuestion(question)
                            }
                        }) {
                            Text("Ask")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(question.isEmpty || viewModel.isAsking)
                    }
                    .padding(.horizontal)
                    
                    if viewModel.isAsking {
                        ProgressView("Processing question...")
                            .padding()
                    }
                    
                    ScrollView {
                        if !viewModel.qaHistory.isEmpty {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(viewModel.qaHistory.indices, id: \.self) { index in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Q: \(viewModel.qaHistory[index].question)")
                                            .fontWeight(.bold)
                                        Text("A: \(viewModel.qaHistory[index].answer)")
                                            .textSelection(.enabled)
                                    }
                                    .padding()
                                    .background(Color(.windowBackgroundColor).opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                        } else if !viewModel.isAsking {
                            Text("Enter your question about the content")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
                .frame(width: 400, height: 400)
                .background(Color(.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding()
                .onDisappear {
                    question = ""
                    viewModel.answer = ""
                    viewModel.qaHistory = []
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    }
