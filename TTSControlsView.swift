import SwiftUI
import AVFoundation

struct TTSControlsView: View {
    @ObservedObject var viewModel: TTSViewModel
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Menu {
                    Menu("OpenAI Voices") {
                        ForEach(OpenAIVoice.allCases, id: \\.rawValue) { voice in
                            Button(voice.displayName) {
                                viewModel.setVoice(.openAI(voice))
                            }
                        }
                    }
                    
                    Menu("System Voices") {
                        #if os(iOS)
                        // Premium voices section
                        Section("Premium Voices") {
                            ForEach(iOSPremiumVoice.allCases, id: \\.rawValue) { premiumVoice in
                                Button {
                                    viewModel.setVoice(.system(premiumVoice.rawValue))
                                } label: {
                                    Text(premiumVoice.displayName)
                                }
                            }
                        }
                        
                        Divider()
                        #endif
                        
                        // System Default option
                        Button {
                            viewModel.setVoice(.system("com.apple.speech.synthesis.voice.system.default"))
                        } label: {
                            HStack {
                                Text("Ava (Default Premium)")
                                Text("★")
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Divider()
                        
                        // Other voices
                        ForEach(viewModel.systemVoices, id: \\.identifier) { voice in
                            Button {
                                viewModel.setVoice(.system(voice.identifier))
                            } label: {
                                HStack {
                                    Text(voice.name)
                                    #if os(iOS)
                                    if voice.quality == .enhanced || voice.quality == .premium {
                                        Text("Premium")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    #endif
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.wave.2")
                        Text(getVoiceDisplayName())
                    }
                }
                .disabled(viewModel.isPlaying)
                
                Spacer()
                
                if viewModel.isPlaying {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 4)
                }
                
                Button {
                    if viewModel.isPlaying {
                        viewModel.stop()
                    } else {
                        viewModel.speak(text)
                    }
                } label: {
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .padding(8)
                        .background(viewModel.isPlaying ? Color.red : Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
            }
            
            if viewModel.progress > 0 && viewModel.progress < 1 {
                ProgressView(value: viewModel.progress) {
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.caption2)
                }
                .progressViewStyle(.linear)
            }
            
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
    }
    
    private func getVoiceDisplayName() -> String {
        switch viewModel.selectedVoiceType {
        case .openAI(let voice):
            return voice.displayName
        case .system(let identifier):
            if identifier == "com.apple.speech.synthesis.voice.system.default" {
                return "Ava (Premium) ★"
            }
            #if os(iOS)
            // Check if it's a known premium voice
            if let premiumVoice = iOSPremiumVoice(rawValue: identifier) {
                return premiumVoice.displayName
            }
            #endif
            // Check regular system voices
            if let voice = viewModel.systemVoices.first(where: { $0.identifier == identifier }) {
                #if os(iOS)
                let qualityIndicator = (voice.quality == .enhanced || voice.quality == .premium) ? " ★" : ""
                return voice.name + qualityIndicator
                #else
                return voice.name
                #endif
            }
            return "System Voice"
        }
    }
} 