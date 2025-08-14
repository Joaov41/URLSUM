import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum TTSVoiceType {
    case openAI(OpenAIVoice)
    case system(String) // System voice identifier
}

// Common iOS premium voices
public enum iOSPremiumVoice: String, CaseIterable {
    case ava = "com.apple.voice.premium.en-US.Ava"
    case zoe = "com.apple.voice.premium.en-US.Zoe"
    case allison = "com.apple.voice.premium.en-US.Allison"
    case samantha = "com.apple.voice.premium.en-US.Samantha"
    case tom = "com.apple.voice.premium.en-US.Tom"
    case susan = "com.apple.voice.premium.en-US.Susan"
    case daniel = "com.apple.voice.premium.en-GB.Daniel"
    case kate = "com.apple.voice.premium.en-GB.Kate"
    case oliver = "com.apple.voice.premium.en-GB.Oliver"
    case serena = "com.apple.voice.premium.en-GB.Serena"
    
    public var displayName: String {
        switch self {
        case .ava: return "Ava (US) ★"
        case .zoe: return "Zoe (US) ★"
        case .allison: return "Allison (US) ★"
        case .samantha: return "Samantha (US) ★"
        case .tom: return "Tom (US) ★"
        case .susan: return "Susan (US) ★"
        case .daniel: return "Daniel (UK) ★"
        case .kate: return "Kate (UK) ★"
        case .oliver: return "Oliver (UK) ★"
        case .serena: return "Serena (UK) ★"
        }
    }
}

enum OpenAIVoice: String, CaseIterable {
    case alloy = "alloy"
    case echo = "echo"
    case fable = "fable"
    case onyx = "onyx"
    case nova = "nova"
    case shimmer = "shimmer"
    
    var displayName: String {
        switch self {
        case .alloy: return "Alloy (Balanced)"
        case .echo: return "Echo (Balanced)"
        case .fable: return "Fable (Versatile)"
        case .onyx: return "Onyx (Deep)"
        case .nova: return "Nova (Warm)"
        case .shimmer: return "Shimmer (Bright)"
        }
    }
}

enum TTSError: Error {
    case invalidAPIKey
    case invalidResponse
    case synthesisError
    case playbackError
    
    var localizedDescription: String {
        switch self {
        case .invalidAPIKey: return "Invalid OpenAI API key"
        case .invalidResponse: return "Invalid response from OpenAI"
        case .synthesisError: return "Failed to synthesize speech"
        case .playbackError: return "Failed to play audio"
        }
    }
}

class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSService()
    private let synthesizer = AVSpeechSynthesizer()
    private let audioCache = AudioCache.shared
    private var openAIAPIKey: String?
    private var currentPlayer: AVAudioPlayer?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        #if os(iOS)
        // Configure audio session for iOS to enable premium voices
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    func configure(withAPIKey apiKey: String) {
        self.openAIAPIKey = apiKey
    }
    
    func speak(_ text: String, voice: TTSVoiceType) async throws {
        switch voice {
        case .openAI(let openAIVoice):
            try await speakWithOpenAI(text, voice: openAIVoice)
        case .system(let identifier):
            speakWithSystem(text, voiceIdentifier: identifier)
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        currentPlayer?.stop()
    }
    
    private func speakWithOpenAI(_ text: String, voice: OpenAIVoice) async throws {
        guard let apiKey = openAIAPIKey else {
            throw TTSError.invalidAPIKey
        }
        
        // Check cache first
        let cacheKey = "\(text)_\(voice.rawValue)"
        if let cachedAudio = audioCache.getCachedAudio(for: cacheKey) {
            try await playAudioData(cachedAudio)
            return
        }
        
        // Prepare the request
        let endpoint = "https://api.openai.com/v1/audio/speech"
        guard let url = URL(string: endpoint) else {
            throw TTSError.invalidResponse
        }
        
        let parameters: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice.rawValue,
            "response_format": "aac"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TTSError.invalidResponse
        }
        
        // Cache the audio data
        audioCache.cacheAudio(data, for: cacheKey)
        
        // Play the audio
        try await playAudioData(data)
    }
    
    private func speakWithSystem(_ text: String, voiceIdentifier: String) {
        // Stop any existing speech
        synthesizer.stopSpeaking(at: .immediate)
        
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        #if os(iOS)
        if voiceIdentifier == "com.apple.speech.synthesis.voice.system.default" {
            // Use explicit premium voice exactly like the working app
            let premiumVoiceID = "com.apple.voice.premium.en-US.Ava"
            print("[TTS] Attempting to use premium voice: \(premiumVoiceID)")
            
            if let premiumVoice = AVSpeechSynthesisVoice(identifier: premiumVoiceID) {
                print("[TTS] Premium voice found: \(premiumVoice.name), quality: \(premiumVoice.quality.rawValue)")
                utterance.voice = premiumVoice
            } else {
                print("[TTS] Premium voice NOT found, using default")
            }
        } else {
            // Try to use the specified voice
            print("[TTS] Using specified voice: \(voiceIdentifier)")
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        
        // Log what voice we're actually using
        if let voice = utterance.voice {
            print("[TTS] Final voice: \(voice.name), ID: \(voice.identifier), quality: \(voice.quality.rawValue)")
        } else {
            print("[TTS] WARNING: No voice set on utterance")
        }
        #else
        // macOS
        if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        #endif
        
        synthesizer.speak(utterance)
    }
    
    private func playAudioData(_ data: Data) async throws {
        do {
            currentPlayer = try AVAudioPlayer(data: data)
            currentPlayer?.prepareToPlay()
            currentPlayer?.play()
        } catch {
            throw TTSError.playbackError
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Handle completion if needed
    }
    
    // Get available system voices
    func getAvailableSystemVoices() -> [AVSpeechSynthesisVoice] {
        var voices: [AVSpeechSynthesisVoice] = []
        
        // Add a special "System Default" voice that uses iOS Settings selection
        // Create a dummy voice to represent system default
        if let systemLanguage = AVSpeechSynthesisVoice.currentLanguageCode(),
           let dummyVoice = AVSpeechSynthesisVoice(language: systemLanguage) {
            // We'll use this to represent "System Default"
            voices.append(dummyVoice)
        }
        
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        #if os(iOS)
        // On iOS, prioritize premium voices
        let premiumVoices = allVoices.filter { voice in
            // Check if voice is premium/enhanced
            voice.quality == .enhanced || voice.quality == .premium
        }
        
        let standardVoices = allVoices.filter { voice in
            voice.quality == .default
        }
        
        // Return system default first, then premium voices, then standard voices
        return voices + premiumVoices + standardVoices
        #else
        // On macOS, return all voices as they are
        return voices + allVoices
        #endif
    }
    
    #if os(iOS)
    private func findPremiumVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // First try to find premium voice for exact language match
        if let premiumVoice = voices.first(where: { voice in
            voice.language == languageCode && 
            (voice.quality == .enhanced || voice.quality == .premium)
        }) {
            return premiumVoice
        }
        
        // If no exact match, try to find premium voice for language family
        let languagePrefix = languageCode.prefix(2)
        if let premiumVoice = voices.first(where: { voice in
            voice.language.hasPrefix(languagePrefix) && 
            (voice.quality == .enhanced || voice.quality == .premium)
        }) {
            return premiumVoice
        }
        
        // Fall back to any premium English voice
        if let englishPremium = voices.first(where: { voice in
            voice.language.hasPrefix("en") && 
            (voice.quality == .enhanced || voice.quality == .premium)
        }) {
            return englishPremium
        }
        
        return nil
    }
    #endif
} 