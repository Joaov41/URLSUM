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
    
    #if os(iOS)
    func addContentBlockingRules(to configuration: WKWebViewConfiguration) {
        let blockRules = """
        [
            {
                "trigger": {
                    "url-filter": "doubleclick\\\\.net",
                    "resource-type": ["document", "script", "image", "style-sheet", "raw"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "googletagmanager\\\\.com",
                    "resource-type": ["script"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "google-analytics\\\\.com",
                    "resource-type": ["script", "image"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "googlesyndication\\\\.com",
                    "resource-type": ["document", "script", "image", "style-sheet", "raw"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "adnxs\\\\.com",
                    "resource-type": ["document", "script", "image", "style-sheet", "raw"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "adsystem\\\\.com",
                    "resource-type": ["document", "script", "image", "style-sheet", "raw"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "amazon-adsystem\\\\.com",
                    "resource-type": ["document", "script", "image", "style-sheet", "raw"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "facebook\\\\.com/tr",
                    "resource-type": ["script", "image"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "scorecardresearch\\\\.com",
                    "resource-type": ["script", "image"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "redditmedia\\\\.com/ads",
                    "resource-type": ["script", "image", "document"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "events\\\\.redditmedia\\\\.com",
                    "resource-type": ["script", "xmlhttprequest"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "alb\\\\.reddit\\\\.com",
                    "resource-type": ["script", "xmlhttprequest"],
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "reddit\\\\.com/api/v2/ad",
                    "resource-type": ["xmlhttprequest", "document"],
                    "load-type": ["first-party", "third-party"]
                },
                "action": {
                    "type": "block"
                }
            }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ContentBlockingRules",
            encodedContentRuleList: blockRules
        ) { list, error in
            if let list = list {
                configuration.userContentController.add(list)
                print("✅ Content blocking rules loaded successfully")
            } else if let error = error {
                print("❌ Error loading content blocking rules: \\(error)")
            }
        }
    }
    #endif
    
    func makeWebView() -> WKWebView {
        // Configure WebView with necessary settings
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Add content blocking rules for iOS
        #if os(iOS)
        addContentBlockingRules(to: config)
        #endif
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Set custom user agent to mimic a real desktop browser
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        webView.customUserAgent = userAgent
        
        // Configure navigation gestures based on platform
        #if os(iOS)
        // On iOS, check if we're on iPad with Stage Manager support
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, disable edge swipes to avoid conflicts with window resizing
            // Users can use the navigation buttons or keyboard shortcuts instead
            webView.allowsBackForwardNavigationGestures = false
            
            // Add two-finger swipe gestures that work anywhere in the view
            // These won't conflict with window resizing
            // (Will be configured in coordinator)
        } else {
            // On iPhone, edge swipes are fine since there's no window resizing
            webView.allowsBackForwardNavigationGestures = true
        }
        #else
        // On macOS, the default gestures work well
        webView.allowsBackForwardNavigationGestures = true
        #endif
        
        // Fix for macOS trackpad click issues
        #if os(macOS)
        // Disable the default context menu on right-click to improve click detection
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Add CSS to improve link click detection
        let clickFixScript = WKUserScript(source: """
            /* Improve link click detection on macOS */
            a, button, [onclick], [role="button"], [role="link"] {
                -webkit-user-select: none;
                cursor: pointer !important;
            }
            
            /* Ensure links have a proper hit area */
            a {
                display: inline-block;
                min-height: 1em;
                position: relative;
            }
        """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        
        webView.configuration.userContentController.addUserScript(clickFixScript)
        #endif
        
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
                'div[data-testid="login-gate"]',
                // Reddit ads removal
                'div[data-testid="promoted-post"]',
                'div[data-promoted="true"]',
                'div[id*="promoted"]',
                'span:has-text("promoted")',
                'div[data-before-content="promoted"]',
                'div.promotedlink',
                'div.promoted',
                'article[data-promoted="true"]',
                'shreddit-ad-post',
                '[is-ads="true"]',
                'div.ad-container',
                'div.GoogleActiveViewInnerContainer',
                'div[data-google-query-id]',
                'iframe[id^="google_ads"]',
                // Reddit premium prompts
                'div[data-testid="premium-banner"]',
                'div.premium-banner-outer',
                // Sidebar ads
                'div.sidebar-ad',
                'div.ad-banner'
            ];
            
            elementsToRemove.forEach(selector => {
                try {
                    document.querySelectorAll(selector).forEach(element => {
                        element.style.display = 'none';
                        element.remove();
                    });
                } catch (e) {
                    // Ignore selector errors
                }
            });
            
            // Hide promoted posts by checking text content
            document.querySelectorAll('span').forEach(span => {
                if (span.textContent?.toLowerCase() === 'promoted') {
                    let parent = span.closest('article, div[data-testid*="post"]');
                    if (parent) {
                        parent.style.display = 'none';
                        parent.remove();
                    }
                }
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
        
        // Inject CSS to hide ads
        function injectAdBlockCSS() {
            const style = document.createElement('style');
            style.textContent = `
                /* Hide Reddit ads and promoted content */
                div[data-testid="promoted-post"],
                div[data-promoted="true"],
                article[data-promoted="true"],
                shreddit-ad-post,
                [is-ads="true"],
                div.promotedlink,
                div.promoted,
                .promotedlink,
                .promoted-post,
                div[id*="promoted"],
                div[data-before-content="promoted"],
                div.GoogleActiveViewInnerContainer,
                div[data-google-query-id],
                iframe[id^="google_ads"],
                div.ad-container,
                div.sidebar-ad,
                div.ad-banner,
                /* Hide premium prompts */
                div[data-testid="premium-banner"],
                div.premium-banner-outer,
                /* Hide "Get Coins" button */
                button[aria-label="Get Coins"],
                /* Hide promoted user flair */
                span[title="Promoted"] {
                    display: none !important;
                    height: 0 !important;
                    visibility: hidden !important;
                }
            `;
            document.head.appendChild(style);
        }
        
        // Run both cleanup and comment button fix periodically
        function runAllFixes() {
            cleanupReddit();
            fixCommentButton();
            injectAdBlockCSS();
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
    let baseFontSize: Double
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    @Environment(\.tabBarTopPadding) private var tabBarTopPadding: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.setupURLObserver(for: webView)
        context.coordinator.setupNavigationGestures(for: webView)
        viewModel.setWebView(webView)
        loadURL(url, in: webView)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Check if URL has changed and update view model
        if let currentURL = uiView.url, currentURL != viewModel.currentURL {
            Task {
                await viewModel.updateURL(currentURL)
            }
        }
        
        if uiView.url != url {
            loadURL(url, in: uiView)
        }
        
        // Apply font size scaling
        let fontScale = baseFontSize / 14.0 // 14 is our default font size
        
        // Check if this is a Reddit URL
        let isReddit = uiView.url?.host?.contains("reddit.com") ?? false
        
        let cssString: String
        if isReddit {
            // For Reddit: only apply text scaling, no padding needed since we handle it at view level
            cssString = """
            /* Reddit-specific text scaling */
            /* Post titles */
            h1, h2, h3, h4, h5, h6,
            [data-testid="post-title"],
            [data-click-id="title"],
            a[slot="title"] {
                font-size: \(fontScale * 100)% !important;
            }
            
            /* Post body and comment text */
            [data-testid="post-rtjson-content"] p,
            [data-testid="comment-rtjson-content"] p,
            .md p, .md li,
            div[slot="text-body"] p,
            div[slot="comment"] p,
            [style*="--commentText"] {
                font-size: \(fontScale * 100)% !important;
                line-height: \(fontScale * 1.5) !important;
            }
            
            /* Comment metadata (username, time, etc) */
            [data-testid="comment-author-link"],
            [data-testid="post-author-link"],
            time, .score {
                font-size: \(fontScale * 90)% !important;
            }
            
            /* Preserve layout - don't scale containers, buttons, or UI elements */
            button, input, select, textarea {
                font-size: inherit !important;
            }
            """
        } else {
            // For non-Reddit sites: use the original approach
            cssString = """
            html {
                font-size: \(fontScale * 100)% !important;
            }
            """
        }
        
        let jsString = """
        var style = document.getElementById('custom-font-size-style');
        if (!style) {
            style = document.createElement('style');
            style.id = 'custom-font-size-style';
            document.head.appendChild(style);
        }
        style.innerHTML = `\(cssString)`;
        """
        
        uiView.evaluateJavaScript(jsString) { result, error in
            if let error = error {
                print("Error applying font size: \(error)")
            }
        }
        
        // Handle scroll insets based on device and content type
        // Note: isReddit is already declared above
        
        if isReddit {
            // Reddit already has padding at view level, reset insets
            uiView.scrollView.contentInset.top = 0
            uiView.scrollView.scrollIndicatorInsets.top = 0
            uiView.scrollView.contentInsetAdjustmentBehavior = .automatic
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad non-Reddit: Add content inset to push initial content down
            // but still allow scrolling under tab bar
            uiView.scrollView.contentInset.top = 55  // Reduced gap for better appearance
            uiView.scrollView.scrollIndicatorInsets.top = 55
            uiView.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // iPhone: Reset insets
            uiView.scrollView.contentInset.top = 0
            uiView.scrollView.scrollIndicatorInsets.top = 0
            uiView.scrollView.contentInsetAdjustmentBehavior = .automatic
        }
    }
}
#else
struct WebViewRepresentable: NSViewRepresentable, WebViewRepresentableBase {
    let url: URL
    let viewModel: SummarizerViewModel
    let baseFontSize: Double
    @Environment(\.tabBarHeight) private var tabBarHeight: CGFloat
    @Environment(\.tabBarTopPadding) private var tabBarTopPadding: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.setupURLObserver(for: webView)
        context.coordinator.setupNavigationGestures(for: webView)
        viewModel.setWebView(webView)
        loadURL(url, in: webView)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Check if URL has changed and update view model
        if let currentURL = nsView.url, currentURL != viewModel.currentURL {
            Task {
                await viewModel.updateURL(currentURL)
            }
        }
        
        if nsView.url != url {
            loadURL(url, in: nsView)
        }
        
        // Apply font size scaling and add Reddit-specific top offset
        let fontScale = baseFontSize / 14.0 // 14 is our default font size
        let isReddit = nsView.url?.host?.contains("reddit.com") ?? false
        let cssString: String = {
            if isReddit {
                let topOffset = max(Int(ceil(tabBarHeight + tabBarTopPadding)), 56)
                return """
                /* Top offset to avoid app tab bar overlap */
                :root, html { scroll-padding-top: \(topOffset)px !important; }
                body { padding-top: \(topOffset)px !important; }

                html { font-size: \(fontScale * 100)% !important; }
                """
            } else {
                return """
                html { font-size: \(fontScale * 100)% !important; }
                """
            }
        }()
        
        let jsString = """
        var style = document.getElementById('custom-font-size-style');
        if (!style) {
            style = document.createElement('style');
            style.id = 'custom-font-size-style';
            document.head.appendChild(style);
        }
        style.innerHTML = `\(cssString)`;
        """
        
        nsView.evaluateJavaScript(jsString) { result, error in
            if let error = error {
                print("Error applying font size: \(error)")
            }
        }
    }
}
#endif

class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let parent: WebViewRepresentableBase
    private var urlObservation: NSKeyValueObservation?
    private weak var webView: WKWebView?
    #if os(iOS)
    private let edgeInset: CGFloat = 60.0 // Ignore gestures within 60 points of edges
    private var parentView: WebViewRepresentable?
    #endif
    
    init(_ parent: WebViewRepresentableBase) {
        self.parent = parent
        #if os(iOS)
        self.parentView = parent as? WebViewRepresentable
        #endif
        super.init()
    }
    
    func setupURLObserver(for webView: WKWebView) {
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            guard let self = self, let url = webView.url else { return }
            Task {
                await self.parent.updateViewModel(with: url)
            }
        }
    }
    
    #if os(iOS)
    func setupNavigationGestures(for webView: WKWebView) {
        self.webView = webView
        
        // Only add custom gestures on iPad where edge swipes conflict with window resizing
        if UIDevice.current.userInterfaceIdiom == .pad {
            print("🎯 Setting up iPad navigation gestures")
            
            // 1. Single-finger swipe for TOUCH (avoiding edges)
            // Create custom swipe recognizers that ignore edge areas
            let touchSwipeBack = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
            touchSwipeBack.direction = .right
            touchSwipeBack.numberOfTouchesRequired = 1
            // Only allow direct touch, not trackpad
            touchSwipeBack.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
            touchSwipeBack.delegate = self
            webView.addGestureRecognizer(touchSwipeBack)
            
            let touchSwipeForward = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeForward))
            touchSwipeForward.direction = .left
            touchSwipeForward.numberOfTouchesRequired = 1
            touchSwipeForward.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
            touchSwipeForward.delegate = self
            webView.addGestureRecognizer(touchSwipeForward)
            
            // 2. Two-finger swipe for TRACKPAD
            let trackpadSwipeBack = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
            trackpadSwipeBack.direction = .right
            trackpadSwipeBack.numberOfTouchesRequired = 2
            // Allow indirect (trackpad) touches
            trackpadSwipeBack.allowedTouchTypes = [UITouch.TouchType.indirectPointer.rawValue as NSNumber]
            webView.addGestureRecognizer(trackpadSwipeBack)
            
            let trackpadSwipeForward = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeForward))
            trackpadSwipeForward.direction = .left
            trackpadSwipeForward.numberOfTouchesRequired = 2
            trackpadSwipeForward.allowedTouchTypes = [UITouch.TouchType.indirectPointer.rawValue as NSNumber]
            webView.addGestureRecognizer(trackpadSwipeForward)
            
            // 3. Also support two-finger touch swipes as fallback
            let twoFingerTouchSwipeBack = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
            twoFingerTouchSwipeBack.direction = .right
            twoFingerTouchSwipeBack.numberOfTouchesRequired = 2
            twoFingerTouchSwipeBack.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
            webView.addGestureRecognizer(twoFingerTouchSwipeBack)
            
            let twoFingerTouchSwipeForward = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeForward))
            twoFingerTouchSwipeForward.direction = .left
            twoFingerTouchSwipeForward.numberOfTouchesRequired = 2
            twoFingerTouchSwipeForward.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
            webView.addGestureRecognizer(twoFingerTouchSwipeForward)
            
            print("✅ Navigation gestures configured:")
            print("   - Touch: Single-finger swipe (avoiding edges)")
            print("   - Trackpad: Two-finger swipe")
        }
        // On iPhone, the default edge swipes are already enabled
    }
    
    @objc private func handleSwipeBack() {
        if webView?.canGoBack == true {
            print("🔙 Navigation: Going back")
            webView?.goBack()
            // Haptic feedback for navigation
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    @objc private func handleSwipeForward() {
        if webView?.canGoForward == true {
            print("🔜 Navigation: Going forward")
            webView?.goForward()
            // Haptic feedback for navigation
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    #else
    func setupNavigationGestures(for webView: WKWebView) {
        // Not needed on macOS, using default gestures
    }
    #endif
    
    deinit {
        urlObservation?.invalidate()
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
        
        #if os(macOS)
        // On macOS, ensure link clicks are handled properly
        // This helps with trackpad click detection
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.allow)
            return
        }
        #endif
        
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
                if let title = webView.title, !title.isEmpty {
                    await parent.viewModel.updatePageTitle(title)
                }
            }
        }
        
        // Apply font size when page loads
        if let webViewRep = parent as? WebViewRepresentable {
            let fontScale = webViewRep.baseFontSize / 14.0
            
            // Check if this is a Reddit URL
            let isReddit = webView.url?.host?.contains("reddit.com") ?? false
            
            let cssString: String
            if isReddit {
                // For Reddit: only apply text scaling, no padding needed since we handle it at view level
                cssString = """
                /* Reddit-specific text scaling */
                /* Post titles */
                h1, h2, h3, h4, h5, h6,
                [data-testid="post-title"],
                [data-click-id="title"],
                a[slot="title"] {
                    font-size: \(fontScale * 100)% !important;
                }
                
                /* Post body and comment text */
                [data-testid="post-rtjson-content"] p,
                [data-testid="comment-rtjson-content"] p,
                .md p, .md li,
                div[slot="text-body"] p,
                div[slot="comment"] p,
                [style*="--commentText"] {
                    font-size: \(fontScale * 100)% !important;
                    line-height: \(fontScale * 1.5) !important;
                }
                
                /* Comment metadata (username, time, etc) */
                [data-testid="comment-author-link"],
                [data-testid="post-author-link"],
                time, .score {
                    font-size: \(fontScale * 90)% !important;
                }
                
                /* Preserve layout - don't scale containers, buttons, or UI elements */
                button, input, select, textarea {
                    font-size: inherit !important;
                }
                """
            } else {
                // For non-Reddit sites: use the original approach
                cssString = """
                html {
                    font-size: \(fontScale * 100)% !important;
                }
                """
            }
            
            let jsString = """
            var style = document.getElementById('custom-font-size-style');
            if (!style) {
                style = document.createElement('style');
                style.id = 'custom-font-size-style';
                document.head.appendChild(style);
            }
            style.innerHTML = `\(cssString)`;
            """
            
            webView.evaluateJavaScript(jsString) { result, error in
                if let error = error {
                    print("Error applying font size on load: \(error)")
                }
            }
            
            // Handle scroll insets based on device and content type
            #if os(iOS)
            // Note: isReddit is already declared above
            
            if isReddit {
                // Reddit already has padding at view level, reset insets
                webView.scrollView.contentInset.top = 0
                webView.scrollView.scrollIndicatorInsets.top = 0
                webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad non-Reddit: Add content inset to push initial content down
                // but still allow scrolling under tab bar
                webView.scrollView.contentInset.top = 55  // Reduced gap for better appearance
                webView.scrollView.scrollIndicatorInsets.top = 55
                webView.scrollView.contentInsetAdjustmentBehavior = .never
            } else {
                // iPhone: Reset insets
                webView.scrollView.contentInset.top = 0
                webView.scrollView.scrollIndicatorInsets.top = 0
                webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            }
            #endif
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

// MARK: - UIGestureRecognizerDelegate for iOS
#if os(iOS)
extension Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only apply edge detection to single-finger direct touch swipes
        if let swipeGesture = gestureRecognizer as? UISwipeGestureRecognizer,
           swipeGesture.numberOfTouchesRequired == 1 {
            
            // Check if this is a direct touch swipe (not trackpad)
            let allowedTypes = swipeGesture.allowedTouchTypes
            if allowedTypes.contains(UITouch.TouchType.direct.rawValue as NSNumber) {
            
            // Get the touch location
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            guard let view = gestureRecognizer.view else { return true }
            
            let bounds = view.bounds
            
            // Check if the gesture started too close to the edges
            // This prevents conflict with window resizing
            let isTooCloseToEdge = location.x < edgeInset || 
                                   location.x > (bounds.width - edgeInset) ||
                                   location.y < edgeInset ||
                                   location.y > (bounds.height - edgeInset)
            
                if isTooCloseToEdge {
                    print("⚠️ Swipe ignored: Too close to edge (x: \(location.x), y: \(location.y))")
                    return false
                }
                
                print("✅ Swipe allowed: Safe distance from edge (x: \(location.x), y: \(location.y))")
                return true
            }
        }
        
        // Allow all other gestures (two-finger, trackpad, etc.)
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our swipe gestures to work alongside scrolling
        if gestureRecognizer is UISwipeGestureRecognizer {
            return true
        }
        return false
    }
}
#endif
