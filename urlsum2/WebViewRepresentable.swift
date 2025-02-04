import SwiftUI
import WebKit

protocol WebViewRepresentableBase {
    var url: URL { get }
    var viewModel: SummarizerViewModel { get }
}

extension WebViewRepresentableBase {
    func updateViewModel(with url: URL) async {
        await viewModel.updateURL(url)
    }
    
    func makeWebView() -> WKWebView {
        // Configure WebView with necessary settings
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Set custom user agent to mimic a real desktop browser
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        webView.customUserAgent = userAgent
        
        // Enable back/forward swipe gestures
        webView.allowsBackForwardNavigationGestures = true
        
        // Combined script with both cleanup and comment button fix
        let script = """
        // Set referrer policy
        var meta = document.createElement('meta');
        meta.name = 'referrer';
        meta.content = 'strict-origin-when-cross-origin';
        document.head.appendChild(meta);
        
        // Handle cookie consent and overlays
        function cleanupReddit() {
            // Remove cookie banner and overlays
            const elementsToRemove = [
                'div[data-testid="COOKIE_BANNER"]',
                'div[data-testid="post-nsfw-warning"]',
                'div[data-testid="age-gate"]',
                'div[data-testid="login-gate"]'
            ];
            
            elementsToRemove.forEach(selector => {
                document.querySelectorAll(selector).forEach(element => element.remove());
            });
            
            // Set cookies
            const cookies = {
                'over18': '1',
                'eu_cookie_v2': '1'
            };
            
            Object.entries(cookies).forEach(([key, value]) => {
                document.cookie = `${key}=${value}; path=/; domain=.reddit.com`;
            });
        }
        
        // Fix for comment button
        function fixCommentButton() {
            const originalButton = document.querySelector('[data-testid="trigger-button"]');
            if (originalButton && !originalButton.hasAttribute('data-replaced')) {
                const newButton = document.createElement('button');
                newButton.innerHTML = originalButton.innerHTML;
                newButton.className = originalButton.className;
                newButton.setAttribute('data-testid', 'custom-trigger-button');
                newButton.style.width = '100%';
                newButton.style.textAlign = 'left';
                newButton.style.padding = '8px';
                newButton.style.cursor = 'text';
                
                newButton.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    const textArea = document.createElement('textarea');
                    textArea.style.width = '100%';
                    textArea.style.minHeight = '100px';
                    textArea.style.padding = '8px';
                    textArea.placeholder = 'Add a comment';
                    
                    newButton.parentElement.replaceChild(textArea, newButton);
                    textArea.focus();
                });
                
                originalButton.parentElement.replaceChild(newButton, originalButton);
                newButton.setAttribute('data-replaced', 'true');
            }
        }
        
        // Run both cleanup and comment button fix periodically
        function runAllFixes() {
            cleanupReddit();
            fixCommentButton();
        }
        
        // Initial run and set interval
        runAllFixes();
        setInterval(runAllFixes, 2000);
        """
        
        let wkScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(wkScript)
        
        return webView
    }
    
    func loadURL(_ url: URL, in webView: WKWebView) {
        // Use minimal headers to avoid interference
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
    }
}

#if os(iOS)
struct WebViewRepresentable: UIViewRepresentable, WebViewRepresentableBase {
    let url: URL
    let viewModel: SummarizerViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        viewModel.setWebView(webView)
        loadURL(url, in: webView)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            loadURL(url, in: uiView)
        }
    }
}
#else
struct WebViewRepresentable: NSViewRepresentable, WebViewRepresentableBase {
    let url: URL
    let viewModel: SummarizerViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        viewModel.setWebView(webView)
        loadURL(url, in: webView)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            loadURL(url, in: nsView)
        }
    }
}
#endif

class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let parent: WebViewRepresentableBase
    
    init(_ parent: WebViewRepresentableBase) {
        self.parent = parent
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            print("🌐 WebView - Deciding policy for URL: \(url)")
            
            // Allow reCAPTCHA and other Google domains
            if url.host?.contains("google.com") == true {
                decisionHandler(.allow)
                return
            }
            
            // Allow about:blank for iframes
            if url.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }
            
            // Only update ViewModel for main frame navigation
            if navigationAction.targetFrame?.isMainFrame == true {
                Task {
                    await parent.updateViewModel(with: url)
                }
            }
        }
        print("✅ Allowing navigation")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Allow all responses
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🔄 WebView - Started loading: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ WebView - Finished loading: \(webView.url?.absoluteString ?? "unknown")")
        if let url = webView.url {
            Task {
                await parent.updateViewModel(with: url)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView - Navigation failed with error: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView - Provisional navigation failed with error: \(error)")
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle window.open() by loading the URL in the same webview
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("🔔 JavaScript Alert: \(message)")
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("❓ JavaScript Confirm: \(message)")
        completionHandler(true)
    }
}
