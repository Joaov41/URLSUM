# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

URLSum is a cross-platform (iOS/macOS) SwiftUI application that:
- Loads and displays web pages in a WebView
- Extracts and summarizes content using Google's Gemini API
- Provides special handling for Reddit posts with full comment extraction
- Offers Text-to-Speech functionality using OpenAI API and system voices
- Includes Q&A functionality for loaded content
- Supports dark mode and adjustable font sizes

## Build and Run Commands

### iOS Development
```bash
# Open in Xcode
open urlsum2.xcodeproj

# Build from command line (iOS Simulator)
xcodebuild -project urlsum2.xcodeproj -scheme urlsum2 -sdk iphonesimulator build

# Run tests
xcodebuild test -project urlsum2.xcodeproj -scheme urlsum2 -sdk iphonesimulator

# Run a specific test
xcodebuild test -project urlsum2.xcodeproj -scheme urlsum2 -sdk iphonesimulator -only-testing:urlsum2Tests/TestClassName/testMethodName
```

### macOS Development
```bash
# Build for macOS
xcodebuild -project urlsum2.xcodeproj -scheme urlsum2 -sdk macosx build

# Run tests for macOS
xcodebuild test -project urlsum2.xcodeproj -scheme urlsum2 -sdk macosx

# Clean build
xcodebuild clean -project urlsum2.xcodeproj -scheme urlsum2
```

### Debugging and Development
```bash
# List available schemes
xcodebuild -list -project urlsum2.xcodeproj

# Build with specific configuration
xcodebuild -project urlsum2.xcodeproj -scheme urlsum2 -configuration Debug
xcodebuild -project urlsum2.xcodeproj -scheme urlsum2 -configuration Release
```

## Architecture

### Core Components

1. **ContentView.swift** - Main UI and view model (urlsum2/ContentView.swift)
   - Contains `SummarizerViewModel` which manages all app state
   - Implements content extraction, summarization, and Q&A logic
   - Handles TTS playback through `TTSViewModel`
   - Settings management (dark mode, font size)

2. **WebViewRepresentable.swift** - Cross-platform WebView wrapper
   - Conditional compilation for iOS (`UIViewRepresentable`) and macOS (`NSViewRepresentable`)
   - Implements content blocking rules for iOS
   - Handles font size scaling via CSS injection
   - Special handling for Reddit comment sections

3. **Content Extraction System**
   - `ContentExtractor` protocol with implementations:
     - `RedditContentExtractor` - Uses RedditAPI for full comment extraction
     - `WebContentExtractor` - Generic web scraping using SwiftSoup
   - Returns tuple: `(content: String, commentCount: Int?)`

4. **API Services**
   - **GeminiService** (in ContentView.swift) - Google Gemini API integration
     - Model: `gemini-2.0-flash-thinking-exp-1219` 
     - Configured with `thinkingBudget: 0` for faster responses
   - **OpenAIService.swift** - OpenAI TTS API
   - **TTSService.swift** - System TTS voices (iOS premium voices)

5. **Reddit Integration**
   - **RedditAPI.swift** - Handles Reddit post and comment extraction
   - Recursively fetches all comments including "load more" threads
   - Formats comments with proper indentation and metadata

### State Management

- Uses SwiftUI's `@StateObject`, `@Published`, and `@AppStorage`
- Main state in `SummarizerViewModel`:
  - URL management
  - Summary and Q&A history
  - Loading states
  - Error handling
  - Comment counting for Reddit posts
- Persistent settings via `@AppStorage`:
  - `isDarkMode` - Dark mode preference
  - `baseFontSize` - Font size (10-24pt)

### TTS Architecture

- **TTSViewModel.swift** - Main TTS state management
- **TTSChunkManager.swift** - Handles text chunking for natural speech
- **AudioCache.swift** - Caches OpenAI TTS audio files
- **TTSControlsView.swift** - UI controls for TTS playback
- **TTSService.swift** - System voice integration

### Supporting Components

- **BookmarkManager.swift** - URL bookmark management
- **BookmarksView.swift** - Bookmarks UI

## Dependencies

Swift Package Manager dependencies (see Package.resolved):
- `GoogleGenerativeAI` (0.5.6) - For Gemini API
- `SwiftSoup` (2.7.6) - For HTML parsing

## Security Considerations

⚠️ **API Keys are currently hardcoded in source** - This is a security risk:
- Gemini API key in ContentView.swift
- OpenAI API key in OpenAIService.swift

These should be moved to secure storage (Keychain) or environment variables.

## Platform-Specific Features

### iOS
- Content blocking rules for ads/trackers
- Premium system voices (Ava, Zoe, etc.)
- UIKit integration where needed

### macOS
- AppKit integration
- NSColor for system colors
- macOS-specific window management

## Testing Approach

The project includes test targets:
- `urlsum2Tests` - Unit tests
- `urlsum2UITests` - UI tests

Run tests via Xcode or xcodebuild commands above.

## Key Implementation Details

1. **Reddit Comment Extraction**
   - Handles nested comment threads
   - Fetches "load more" comments recursively
   - Preserves comment metadata (author, score, time)
   - Formats with proper indentation

2. **Font Size Scaling**
   - Base font size stored in `@AppStorage("baseFontSize")`
   - WebView scaling via CSS zoom injection
   - Affects summary text, Q&A, and web content
   - Scaling formula: `zoom = (baseFontSize / 14.0) * 100%`

3. **Dark Mode**
   - Controlled by `@AppStorage("isDarkMode")`
   - Applied via `.preferredColorScheme` modifier
   - Default enabled

4. **Content Summarization**
   - Different prompts for Reddit vs general web content
   - Full content sent to Gemini API
   - Comment count displayed for Reddit posts

5. **Error Handling**
   - Network errors wrapped in custom error types
   - UI displays error messages in alerts
   - Retry logic for failed requests

## Recent Changes

- Consolidated TTS code into main ContentView.swift
- Added Settings view with dark mode toggle and font size slider
- Removed duplicate ContentView.swift files
- Implemented WebView font scaling based on user preference