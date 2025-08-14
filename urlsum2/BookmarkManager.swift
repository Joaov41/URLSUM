import Foundation

struct Bookmark: Codable, Identifiable {
    let id = UUID()
    let url: String
    let title: String
    let dateAdded: Date
    
    init(url: String, title: String) {
        self.url = url
        self.title = title
        self.dateAdded = Date()
    }
}

class BookmarkManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    
    private let bookmarksKey = "SavedBookmarks"
    
    init() {
        loadBookmarks()
    }
    
    func addBookmark(url: String, title: String) {
        let bookmark = Bookmark(url: url, title: title)
        bookmarks.append(bookmark)
        saveBookmarks()
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }
    
    func isBookmarked(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }
    
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
    }
}