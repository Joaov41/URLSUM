# SwiftUI macOS Application - This is an extremely light and fast  webview that summarizes all URL's with Q&A capabilities.
It has dedicated code for reddit ur'ss, in that case, the app will extract all comments and make it abailable for summarization and Q&A

## Overview
This is a macOS application built with SwiftUI, leveraging various frameworks including Combine, WebKit, SwiftSoup, and AppKit. The application appears to involve window manipulation using `NSViewRepresentable`, indicating potential integration of web content or advanced UI customization.

## Features
- Utilizes SwiftUI for a modern, declarative UI.
- Integrates with `WebKit` for web content rendering.
- Parses HTML content using `SwiftSoup`.
- Manages macOS windows using `AppKit`.

## Requirements
- macOS 12.0 or later
- Xcode 14 or later
- Swift 5+

## Installation
1. Clone the repository:
   ```sh
   git clone https://github.com/your-username/your-repo.git
   ```
2. Open the project in Xcode:
   ```sh
   cd your-repo
   open YourProject.xcodeproj
   ```
3. Build and run the project:
   - Select a macOS target.
   - Press `Cmd + R` to run.

## Usage
- Open the application and interact with the UI.
- Insert youyr Gemini key here

  let geminiService = GeminiService(apiKey: "YOUR API KEY")

## Dependencies
- [SwiftSoup](https://github.com/scinfu/SwiftSoup): HTML parser for Swift.
- [Combine](https://developer.apple.com/documentation/combine): Apple's reactive framework.

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


