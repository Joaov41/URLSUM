import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
        case .echo: return "Echo (Warm)"
        case .fable: return "Fable (Expressive)"
        case .onyx: return "Onyx (Deep)"
        case .nova: return "Nova (Energetic)"
        case .shimmer: return "Shimmer (Clear)"
        }
    }
}

enum OpenAIError: LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case synthesisError
    case playbackError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Invalid OpenAI API key"
        case .invalidResponse: return "Invalid response from OpenAI"
        case .synthesisError: return "Failed to synthesize speech"
        case .playbackError: return "Failed to play audio"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

actor OpenAIService {
    static let shared = OpenAIService()
    
    private let chunkManager = TTSChunkManager()
    private let audioCache = AudioCache.shared
    private var apiKey: String?
    private var currentPlayer: AVAudioPlayer?
    private var isProcessingChunks = false
    
    private let systemSynthesizer = AVSpeechSynthesizer()
    
    private init() {
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
        self.apiKey = apiKey
    }
    
    func synthesizeSpeech(
        text: String,
        voice: OpenAIVoice,
        progressHandler: @escaping (Double) -> Void,
        onFirstChunkReady: @escaping (AVAudioPlayer) -> Void
    ) async throws -> AVAudioPlayer {
        guard !text.isEmpty else { throw OpenAIError.synthesisError }
        
        // Check cache first
        let cacheKey = "\(text)_\(voice.rawValue)"
        if let cachedAudio = audioCache.getCachedAudio(for: cacheKey) {
            let player = try AVAudioPlayer(data: cachedAudio)
            player.prepareToPlay()
            return player
        }
        
        // Process the entire text at once
        let audioData = try await synthesizeChunk(text, voice: voice)
        
        // Cache the audio
        audioCache.cacheAudio(audioData, for: cacheKey)
        
        // Create player
        let player = try AVAudioPlayer(data: audioData)
        player.prepareToPlay()
        return player
    }
    
    private func synthesizeChunk(_ text: String, voice: OpenAIVoice) async throws -> Data {
        guard let apiKey = apiKey else {
            throw OpenAIError.invalidAPIKey
        }
        
        let endpoint = "https://api.openai.com/v1/audio/speech"
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidResponse
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
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw OpenAIError.invalidResponse
            }
            
            return data
        } catch {
            throw OpenAIError.networkError(error)
        }
    }
    
    private func combineAudioData(_ dataArray: [Data]) async throws -> Data {
        // For now, just concatenate the data
        // In a real implementation, you'd want to properly combine the audio files
        return dataArray.reduce(Data()) { $0 + $1 }
    }
    
    func stopPlayback() {
        currentPlayer?.stop()
        currentPlayer = nil
        systemSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // Fallback to system TTS
    func speakWithSystem(_ text: String, voiceIdentifier: String) {
        // Stop any existing speech
        systemSynthesizer.stopSpeaking(at: .immediate)
        
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        #if os(iOS)
        if voiceIdentifier == "com.apple.speech.synthesis.voice.system.default" {
            // Use explicit premium voice exactly like the working app
            let premiumVoiceID = "com.apple.voice.premium.en-US.Ava"
            print("[OpenAI TTS] Attempting to use premium voice: \(premiumVoiceID)")
            
            if let premiumVoice = AVSpeechSynthesisVoice(identifier: premiumVoiceID) {
                print("[OpenAI TTS] Premium voice found: \(premiumVoice.name), quality: \(premiumVoice.quality.rawValue)")
                utterance.voice = premiumVoice
            } else {
                print("[OpenAI TTS] Premium voice NOT found, using default")
            }
        } else {
            // Try to use the specified voice
            print("[OpenAI TTS] Using specified voice: \(voiceIdentifier)")
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        
        // Log what voice we're actually using
        if let voice = utterance.voice {
            print("[OpenAI TTS] Final voice: \(voice.name), ID: \(voice.identifier), quality: \(voice.quality.rawValue)")
        } else {
            print("[OpenAI TTS] WARNING: No voice set on utterance")
        }
        #else
        // macOS
        if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        #endif
        
        systemSynthesizer.speak(utterance)
    }
    
    func getAvailableSystemVoices() -> [AVSpeechSynthesisVoice] {
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
        
        // Return premium voices first, then standard voices
        return premiumVoices + standardVoices
        #else
        // On macOS, return all voices as they are
        return allVoices
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