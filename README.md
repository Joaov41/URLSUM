# SwiftUI macOS Application - This is an extremely light and fast  webview that summarizes all URL's with Q&A capabilities.
It has dedicated code for reddit url's, in that case, the app will extract all comments and make it available for summarization and Q&A

![CleanShot 2025-02-04 at 13 21 48@2x](https://github.com/user-attachments/assets/3000ee64-3e6a-4926-a7a4-9dbdaa0d8615)

![CleanShot 2025-02-04 at 13 24 01@2x](https://github.com/user-attachments/assets/db66b2c4-d92b-44c0-8eb1-79087b1d73c1)


## Overview
This is a macOS application built with SwiftUI, leveraging various frameworks including Combine, WebKit, SwiftSoup, and AppKit.

## Features
- Utilizes SwiftUI for a modern, declarative UI.
- Integrates with `WebKit` for web content rendering.
- Parses HTML content using `SwiftSoup`.
- Manages macOS windows using `AppKit`.
- There is also an IOS version available.

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
- Insert youyr Gemini key here

  let geminiService = GeminiService(apiKey: "YOUR API KEY")

## Dependencies
- [SwiftSoup](https://github.com/scinfu/SwiftSoup): HTML parser for Swift.
- [Combine](https://developer.apple.com/documentation/combine): Apple's reactive framework.

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


