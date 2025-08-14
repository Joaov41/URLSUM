import SwiftUI

struct BookmarksView: View {
    @ObservedObject var bookmarkManager: BookmarkManager
    let onSelectBookmark: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bookmarks")
                    .font(.headline)
                
                Spacer()
                
                Button("✕") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.title2)
            }
            .padding()
            .background(Color.clear)
            .glassEffect()
            
            // Bookmarks list
            if bookmarkManager.bookmarks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No bookmarks yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click the bookmark button to save pages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(bookmarkManager.bookmarks) { bookmark in
                        BookmarkRow(
                            bookmark: bookmark,
                            onSelect: {
                                onSelectBookmark(bookmark.url)
                            },
                            onDelete: {
                                bookmarkManager.removeBookmark(bookmark)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .background {
            ZStack {
                // Neutral transparent background like iPad
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.gray.opacity(0.03),
                        Color.white.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Clear overlay for glass effect
                Color.clear
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Text(bookmark.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

