import SwiftUI
import Foundation

struct AppTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: URL? = nil
    var faviconURL: URL? = nil
}

final class TabManager: ObservableObject {
    @Published var tabs: [AppTab] = []
    @Published var selectedID: UUID?
    private var tabCount = 0
    
    init() { newTab() }
    
    func newTab(title: String? = nil) {
        tabCount += 1
        let tab = AppTab(id: UUID(), title: title ?? "New Tab")
        tabs.append(tab)
        selectedID = tab.id
    }
    
    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = (selectedID == id)
        tabs.remove(at: idx)
        if tabs.isEmpty { newTab(); return }
        if wasSelected { selectedID = tabs[min(idx, tabs.count - 1)].id }
    }
    
    func select(_ id: UUID) { selectedID = id }
    func selectNext() {
        guard let sel = selectedID, let i = tabs.firstIndex(where: { $0.id == sel }) else { return }
        selectedID = tabs[(i + 1) % tabs.count].id
    }
    func selectPrevious() {
        guard let sel = selectedID, let i = tabs.firstIndex(where: { $0.id == sel }) else { return }
        selectedID = tabs[(i - 1 + tabs.count) % tabs.count].id
    }
}

private struct TabIDKey: EnvironmentKey { static let defaultValue: UUID? = nil }
extension EnvironmentValues { var tabID: UUID? { get { self[TabIDKey.self] } set { self[TabIDKey.self] = newValue } } }

// Share measured tab bar height via environment for dynamic webview offsets
private struct TabBarHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues { var tabBarHeight: CGFloat { get { self[TabBarHeightKey.self] } set { self[TabBarHeightKey.self] = newValue } } }

// Extra top padding applied when overlaying the tab bar (e.g., macOS toolbar gap)
private struct TabBarTopPaddingKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues { var tabBarTopPadding: CGFloat { get { self[TabBarTopPaddingKey.self] } set { self[TabBarTopPaddingKey.self] = newValue } } }

extension Notification.Name {
    static let newTabRequested = Notification.Name("newTabRequested")
    static let tabMetaUpdated = Notification.Name("tabMetaUpdated")
    static let closePanels = Notification.Name("closePanels")
}

private func faviconURL(for url: URL) -> URL? {
    guard let host = url.host else { return nil }
    return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
}

struct TabBarView: View {
    @ObservedObject var manager: TabManager
    @Environment(\.colorScheme) private var currentColorScheme
    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(manager.tabs) { tab in
                        TabChip(
                            title: tab.title.isEmpty ? (tab.url?.host ?? "Untitled") : tab.title,
                            favicon: tab.faviconURL,
                            isSelected: tab.id == manager.selectedID,
                            onSelect: { manager.select(tab.id) },
                            onClose: { manager.closeTab(tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            Button(action: { manager.newTab() }) {
                Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).padding(6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: .command)
            .help("New Tab (⌘T)")
        }
        .background {
            if #available(iOS 26.0, macOS 15.0, *) {
                ZStack {
                    Color.clear.glassEffect(.regular.interactive(), in: Rectangle())
                    if currentColorScheme == .dark {
                        Color.white.opacity(0.06)
                    } else {
                        Color.black.opacity(0.05)
                    }
                }
            } else {
                #if os(iOS)
                VisualEffectBlur(style: .systemUltraThinMaterial)
                #else
                VisualEffectBlur(material: .headerView, blendingMode: .withinWindow, state: .active)
                #endif
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
        }
        #if os(iOS)
        // Ignore safe area to allow content to scroll underneath
        .ignoresSafeArea(edges: .top)
        #endif
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TabBarHeightPreferenceKey.self, value: geo.size.height)
            }
        )
    }
}

// PreferenceKey used internally to bubble up the measured tab bar height
private struct TabBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TabChip: View {
    let title: String
    let favicon: URL?
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var currentColorScheme
    var body: some View {
        HStack(spacing: 6) {
            if let favicon {
                if #available(iOS 15.0, macOS 12.0, *) {
                    AsyncImage(url: favicon) { img in img.resizable().scaledToFit() } placeholder: {
                        Image(systemName: "globe").resizable().scaledToFit().foregroundColor(.secondary)
                    }
                    .frame(width: 12, height: 12)
                    .cornerRadius(2)
                } else {
                    Image(systemName: "globe").resizable().scaledToFit().frame(width: 12, height: 12).foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "globe").resizable().scaledToFit().frame(width: 12, height: 12).foregroundColor(.secondary)
            }
            Text(title).lineLimit(1).font(.system(size: 12, weight: .medium))
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary) }
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: .command)
                .help("Close Tab (⌘W)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            if #available(iOS 26.0, macOS 15.0, *) {
                ZStack {
                    Color.clear.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10))
                    if currentColorScheme == .dark {
                        Color.white.opacity(0.05)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Color.black.opacity(0.04)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                #if os(iOS)
                RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
                #else
                VisualEffectBlur(material: .menu, blendingMode: .withinWindow, state: .active)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                #endif
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 0.75)
        )
        .onTapGesture(perform: onSelect)
    }
}

struct TabContainerView: View {
    @StateObject private var manager = TabManager()
    @State private var tabBarHeight: CGFloat = 0
    var body: some View {
        ZStack(alignment: .top) {
            let isReddit: Bool = {
                guard let sel = manager.selectedID, let tab = manager.tabs.first(where: { $0.id == sel }) else { return false }
                return tab.url?.host?.contains("reddit.com") == true
            }()
            #if os(macOS)
            let topGap: CGFloat = 52
            #else
            let topGap: CGFloat = 0
            #endif
            // Content fills the window, allowing the tab bar to blur it
            ZStack {
                ForEach(manager.tabs) { tab in
                    ContentView()
                        .id(tab.id)
                        .environment(\.tabID, tab.id)
                        .opacity(manager.selectedID == tab.id ? 1 : 0)
                        .allowsHitTesting(manager.selectedID == tab.id)
                        .zIndex(manager.selectedID == tab.id ? 1 : 0)
                }
                // Keyboard shortcuts targets (hidden)
                Button("") { if let id = manager.selectedID { manager.closeTab(id) } }
                    .keyboardShortcut("w", modifiers: .command).opacity(0).frame(width: 0, height: 0)
                Button("") { manager.selectNext() }
                    .keyboardShortcut(.tab, modifiers: [.control]).opacity(0).frame(width: 0, height: 0)
                Button("") { manager.selectPrevious() }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift]).opacity(0).frame(width: 0, height: 0)
            }
            .animation(.easeInOut(duration: 0.2), value: manager.selectedID)
            .background(Color.systemBackground)
            // Reverted: no extra top padding for Reddit; handled in WebView CSS/insets
        }
        .overlay(alignment: .top) {
            #if os(macOS)
            TabBarView(manager: manager)
                .padding(.top, 52)
            #elseif os(iOS)
            TabBarView(manager: manager)
                // Add padding for iPad to properly space it from toolbar (similar to Mac), keep iPhone as is
                .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 0)
            #endif
        }
        .onPreferenceChange(TabBarHeightPreferenceKey.self) { self.tabBarHeight = $0 }
        .environment(\.tabBarHeight, tabBarHeight)
        #if os(macOS)
        .environment(\.tabBarTopPadding, 52)
        #elseif os(iOS)
        // No extra padding needed for iOS devices
        .environment(\.tabBarTopPadding, 0)
        #endif
        .onAppear { if manager.tabs.isEmpty { manager.newTab() } }
        .onReceive(NotificationCenter.default.publisher(for: .newTabRequested)) { _ in manager.newTab() }
        .onReceive(NotificationCenter.default.publisher(for: .tabMetaUpdated)) { note in
            guard let info = note.userInfo, let tabID = info["tabID"] as? UUID, let idx = manager.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            var tab = manager.tabs[idx]
            if let title = info["title"] as? String { tab.title = title }
            if let urlString = info["url"] as? String, let url = URL(string: urlString) { tab.url = url; tab.faviconURL = faviconURL(for: url) }
            manager.tabs[idx] = tab
        }
    }
}
