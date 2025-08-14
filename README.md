# URLSum 5.0

A lightweight cross-platform SwiftUI application for IpadOS and macOS that extracts, summarizes, and provides interactive Q&A for web content using Gemini or Apple's models ( local and cloud)

![CleanShot 2025-08-14 at 12 55 13@2x](https://github.com/user-attachments/assets/62c75f8f-6dab-4940-953d-663538794190)


# Features

### Web Content Processing
- **Universal Web Loading**: Load and display any web page in an integrated WebView
- **Smart Content Extraction**: Automatically extract meaningful content from web pages
- **Reddit Integration**: Special handling for Reddit posts with full comment extraction including nested threads

### AI-Powered Summarization
- **Google Gemini Integration**: Powered by Google's Gemini 2.5 Flash model for fast, accurate summaries
- **Option to use Apple local foundation model and also Apple's cloud model through the use of the SHortcuts app, since that cloud model is not available on the SDK
- **Context-Aware Summaries**: Different summarization approaches for Reddit vs. general web content
- **Interactive Q&A**: Ask questions about loaded content and get AI-powered answers

### Text-to-Speech (TTS)
- **Dual TTS Support**: 
  - OpenAI TTS API for high-quality voice synthesis
  - System voices including premium iOS voices (Ava, Zoe, etc.)
- **Smart Text Chunking**: Intelligent text splitting for natural speech flow
- **Audio Caching**: Efficient caching system for OpenAI TTS audio files
- **Playback Controls**: Full playback control with pause, resume, and progress tracking

### User Experience
- **Dark Mode**: Full dark mode support with system integration
- **Adjustable Font Sizes**: Customizable font sizing (10-24pt) affecting both UI and WebView content
- **Cross-Platform**: Native SwiftUI implementation for both iOS and macOS
- **Bookmarks**: Save and manage favorite URLs for quick access
- **Multi-Tab Support**: Handle multiple web pages simultaneously

### 🔧 Technical Features
- **Content Blocking**: iOS content blocking rules for ads and trackers
- **Font Scaling**: Dynamic WebView font scaling via CSS injection
- **Responsive Design**: Adaptive UI that works on iPhone, iPad, and Mac
- **Secure API Key Storage**: Keys stored securely in app preferences

## Installation

### Prerequisites
- **Xcode 26 beta +** (for building and running)
- **iOS 26 beta  **macOS Tahoe beta**
- **Google Gemini API Key** (required)
- ** To use Apple cloud model, it is rerquired to have this shortcut installed https://www.icloud.com/shortcuts/c968c84b2853425198c90f6a52e8a424
- On MAcOS shortucts app is running on the backgroud hrough its cli, so invisible ot user but on IpadOS it must open the SHortucts app while running the query t the model, there is no way around it. 
- **OpenAI API Key** (optional, for enhanced TTS)


### Building from Source

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Joaov41/URLSUM.git
   cd URLSUM
   ```

2. **Open in Xcode**
   ```bash
   open urlsum2.xcodeproj
   ```

3. **Build and Run**
   
   **For iOS Simulator:**
   ```bash
   xcodebuild -project urlsum2.xcodeproj -scheme urlsum2 -sdk iphonesimulator build
   ```
   
   **For macOS:**
   ```bash
   xcodebuild -project urlsum2.xcodeproj -scheme urlsum2 -sdk macosx build
   ```
   
   **Or simply press `Cmd+R` in Xcode to build and run**

## API Setup

### Setting Up API Keys (In-App)

URLSum provides a built-in settings interface for configuring your API keys securely:

1. **Launch the app** and tap the settings icon (⚙️)
2. **API Keys section** will be available in settings
3. **Enter your API keys**:
   - **Gemini API Key**: Required for content summarization
   - **OpenAI API Key**: Optional, for enhanced TTS features

### Getting API Keys

#### Google Gemini API
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy the key and paste it in URLSum settings

#### OpenAI API (Optional)
1. Visit [OpenAI API Keys](https://platform.openai.com/api-keys)
2. Create a new API key
3. Copy the key and paste it in URLSum settings

> **Note**: API keys are stored securely in the app's user defaults and are not hardcoded in the source code.

## Usage

### Basic Web Summarization
1. **Enter URL**: Type or paste any web URL in the input field
2. **Load Content**: Tap "Load" to fetch and display the webpage
3. **Get Summary**: Tap "Summarize" to generate an AI-powered summary
4. **Ask Questions**: Use the Q&A feature to ask specific questions about the content

### Reddit Posts
- URLSum automatically detects Reddit URLs
- Extracts complete comment threads including nested replies
- Provides comment count statistics
- Handles "load more" comments automatically

### Text-to-Speech
1. **After summarizing content**, TTS controls will appear
2. **Choose voice type**: OpenAI TTS or System voices
3. **Play/Pause**: Control audio playback
4. **Premium voices available on iOS**: Ava, Zoe, and other high-quality options

### Settings
- **Dark Mode**: Toggle in the settings menu
- **Font Size**: Adjust from 10-24pt using the slider
- **API Keys**: Configure Gemini and OpenAI API keys
- **AI Provider**: Choose between different AI providers
- **Bookmarks**: Save frequently visited URLs

## Project Structure

```
urlsum2/
├── ContentView.swift          # Main app logic and UI
├── WebViewRepresentable.swift # Cross-platform WebView wrapper
├── RedditAPI.swift           # Reddit content extraction
├── BookmarkManager.swift     # URL bookmark management
├── TTSViewModel.swift        # Text-to-speech management
├── OpenAIService.swift       # OpenAI TTS integration
├── TTSService.swift          # System TTS integration
└── Supporting Files/
    ├── Assets.xcassets/      # App icons and images
    ├── urlsum2App.swift      # App entry point
    └── urlsum2.entitlements  # App permissions
```

## Dependencies

- **GoogleGenerativeAI** (0.5.6) - Google Gemini API integration
- **SwiftSoup** (2.7.6) - HTML parsing and content extraction

## Platform-Specific Features

### iOS
- Content blocking rules for improved privacy
- Premium system voices (Neural voices)
- Native iOS UI components and navigation

### macOS
- AppKit integration where needed
- macOS-specific window management
- Native macOS UI patterns

## Security & Privacy

✅ **Secure API Key Storage**: API keys are stored in app user defaults, not hardcoded
✅ **No Data Collection**: The app processes content locally and only sends data to your configured AI services
✅ **Content Blocking**: Built-in ad and tracker blocking for better privacy (iOS)

## Testing

Run the test suite:
```bash
# Unit tests
xcodebuild test -project urlsum2.xcodeproj -scheme urlsum2 -sdk iphonesimulator

# macOS tests
xcodebuild test -project urlsum2.xcodeproj -scheme urlsum2 -sdk macosx
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is available for personal and educational use. Please respect the terms of service of the integrated APIs (Google Gemini, OpenAI).

## Troubleshooting

### Common Issues

**API Key Errors:**
- Ensure you've entered valid API keys in the app settings
- Check that your API quotas are not exceeded
- Verify your internet connection

**Build Errors:**
- Ensure you have the latest Xcode version
- Clean build folder: `Product > Clean Build Folder`
- Reset Package Dependencies: `File > Packages > Reset Package Caches`

**TTS Not Working:**
- Check device volume settings
- Verify microphone permissions (if required)
- For iOS: ensure premium voices are downloaded in Settings > Accessibility > Spoken Content
- Ensure OpenAI API key is configured if using OpenAI TTS

**WebView Issues:**
- Try refreshing the page
- Check if the website blocks embedded views
- For Reddit: use old.reddit.com URLs for better compatibility

## Support

For issues, feature requests, or questions:
- Open an issue on GitHub
- Check the [CLAUDE.md](CLAUDE.md) file for detailed technical documentation

---

**URLSum 5.0** - Transform any web content into digestible, interactive summaries with the power of AI.
