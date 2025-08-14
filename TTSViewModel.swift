import Foundation
import AVFoundation
import SwiftUI

enum TTSVoiceType {
    case openAI(OpenAIVoice)
    case system(String)
}

@MainActor
class TTSViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var selectedVoiceType: TTSVoiceType = .openAI(.alloy)
    @Published var systemVoices: [AVSpeechSynthesisVoice] = []
    @Published var error: String?
    @Published var progress: Double = 0
    
    private let openAIService = OpenAIService.shared
    private var currentPlayer: AVAudioPlayer?
    
    init(openAIAPIKey: String) {
        openAIService.configure(withAPIKey: openAIAPIKey)
        systemVoices = openAIService.getAvailableSystemVoices()
        
        // Use system default voice to respect user's iOS Settings choice
        selectedVoiceType = .system("com.apple.speech.synthesis.voice.system.default")
    }
    
    func updateOpenAIAPIKey(_ apiKey: String) {
        openAIService.configure(withAPIKey: apiKey)
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Stop any existing playback
        stop()
        
        isPlaying = true
        error = nil
        progress = 0
        
        Task {
            do {
                switch selectedVoiceType {
                case .openAI(let voice):
                    let player = try await openAIService.synthesizeSpeech(
                        text: text,
                        voice: voice,
                        progressHandler: { [weak self] progress in
                            Task { @MainActor in
                                self?.progress = progress
                            }
                        },
                        onFirstChunkReady: { [weak self] firstChunkPlayer in
                            Task { @MainActor in
                                self?.currentPlayer = firstChunkPlayer
                                firstChunkPlayer.play()
                            }
                        }
                    )
                    
                    // When complete audio is ready
                    currentPlayer = player
                    player.play()
                    
                case .system(let identifier):
                    await openAIService.speakWithSystem(text, voiceIdentifier: identifier)
                }
            } catch {
                self.error = error.localizedDescription
                isPlaying = false
            }
        }
    }
    
    func stop() {
        Task {
            await openAIService.stopPlayback()
            currentPlayer?.stop()
            currentPlayer = nil
            isPlaying = false
            progress = 0
        }
    }
    
    func setVoice(_ voice: TTSVoiceType) {
        selectedVoiceType = voice
    }
    
    // Method for OpenAI TTS
    func speakWithOpenAI(_ text: String) {
        // Force OpenAI voice and speak
        selectedVoiceType = .openAI(.alloy)
        speak(text)
    }
    
    // Method for Local TTS
    func speakWithLocalTTS(_ text: String) {
        // Force system default voice and speak
        selectedVoiceType = .system("com.apple.speech.synthesis.voice.system.default")
        speak(text)
    }
} 