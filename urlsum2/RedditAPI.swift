import Foundation

// MARK: - Extensions for Utility Functions

// Extension for asynchronous mapping over a sequence
extension Sequence {
    func asyncMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}

// Extension to format Date objects into relative time strings
extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// Extension to format integers with abbreviations (e.g., 1.2k, 3.4M)
extension Int {
    func formatUsingAbbreviation() -> String {
        let num = Double(self)
        switch num {
        case 1_000_000...:
            return "\(String(format: "%.1f", num / 1_000_000))M"
        case 1_000...:
            return "\(String(format: "%.1f", num / 1_000))k"
        default:
            return "\(self)"
        }
    }
}

// Extension to split an array into chunks of a specified size
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - RedditAPI Class

class RedditAPI {
    
    // MARK: - Properties
    
    /// Stored link_id for fetching more comments
    private var linkId: String?
    
    /// Maximum number of retry attempts for fetching "more" items
    private let maxRetryCount = 5
    
    /// Delay factor for exponential backoff (in seconds)
    private let backoffFactor: Double = 2.0
    
    /// Semaphore to limit concurrent network requests
    private let semaphore = DispatchSemaphore(value: 3) // Adjust based on system capabilities
    
    // MARK: - Public Method to Get Content
    
    /// Fetches and extracts content from a given Reddit URL.
    ///
    /// - Parameters:
    ///   - url: The Reddit post URL.
    ///   - includeAllComments: Flag to include all comments in the extraction.
    /// - Returns: A formatted string containing the post metadata and comments.
    func getContent(from url: URL, includeAllComments: Bool = true) async throws -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.scheme = "https"
        components.host = "www.reddit.com"
        
        // Handle root URL by redirecting to "/hot"
        if url.absoluteString.matches(of: /https?:\/\/(www\.)?reddit\.com\/?$/).count > 0 {
            components.path = "/hot"
        }
        
        // Append ".json" to the path if not already present
        if !components.path.hasSuffix(".json") {
            components.path += ".json"
        }
        
        // Add "limit=1000" query parameter for comment-heavy posts
        if components.path.contains("/comments/") {
            if components.queryItems == nil {
                components.queryItems = []
            }
            components.queryItems?.append(URLQueryItem(name: "limit", value: "1000"))
        }
        
        guard let apiURL = components.url else {
            throw URLError(.badURL)
        }
        
        print("🌐 Fetching from: \(apiURL)")
        
        var request = URLRequest(url: apiURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Fetch data from Reddit API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Bad status: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        let isCommentThread = url.pathComponents.contains("comments")
        
        do {
            if isCommentThread {
                let postContent = try await extractPostContent(from: data, includeAllComments: includeAllComments)
                return postContent
            } else {
                let subredditContent = try extractSubredditContent(from: data)
                return subredditContent
            }
        } catch {
            print("❌ Extraction error: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Method to Handle Rate Limiting
    
    /// Handles rate limiting by implementing exponential backoff.
    ///
    /// - Parameter retryCount: The current retry attempt count.
    private func handleRateLimit(retryCount: Int) async throws {
        let delaySeconds = pow(backoffFactor, Double(retryCount))
        let delay = UInt64(delaySeconds * 1_000_000_000) // Convert to nanoseconds
        print("⏳ Handling rate limit by waiting for \(delaySeconds) seconds...")
        try await Task.sleep(nanoseconds: delay)
    }
    
    // MARK: - Extract Post Content
    
    /// Extracts post metadata and comments from the fetched data.
    ///
    /// - Parameters:
    ///   - data: The raw data fetched from Reddit API.
    ///   - includeAllComments: Flag to include all comments in the extraction.
    /// - Returns: A formatted string containing the post metadata and comments.
    private func extractPostContent(from data: Data, includeAllComments: Bool) async throws -> String {
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
              jsonArray.count >= 2 else {
            throw URLError(.cannotParseResponse)
        }
        
        // Parse post data
        guard let postListing = jsonArray[0] as? [String: Any],
              let postData = (postListing["data"] as? [String: Any])?["children"] as? [[String: Any]],
              let post = postData.first?["data"] as? [String: Any],
              let postId = post["id"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        // Set link_id for future use
        self.linkId = "t3_\(postId)"
        print("🔗 Link ID set to: \(self.linkId!)")
        
        // Build post metadata
        var content = buildPostMetadata(from: post)
        
        // Add post content (selftext)
        if let selftext = post["selftext"] as? String, !selftext.isEmpty {
            content.append("\n\(selftext)")
        }
        
        // Process comments
        if includeAllComments {
            guard let commentListing = jsonArray[1] as? [String: Any],
                  let commentData = commentListing["data"] as? [String: Any],
                  let comments = commentData["children"] as? [[String: Any]] else {
                return content.joined(separator: "\n")
            }
            
            let allComments = try await fetchAllComments(initialComments: comments)
            content.append("\n\nCOMMENTS:")
            content.append(contentsOf: allComments)
            
            // Log the total number of comments extracted
            print("✅ Total comments extracted: \(allComments.count)")
            
            // Placeholder for sending comments to an LLM
            // Uncomment and implement your LLM sending logic here
            // sendToLLM(comments: allComments)
            // print("✅ Sent \(allComments.count) comments to the LLM.")
        }
        
        return content.joined(separator: "\n")
    }
    
    // MARK: - Build Post Metadata
    
    /// Constructs metadata strings from the post data.
    ///
    /// - Parameter post: The post data dictionary.
    /// - Returns: An array of metadata strings.
    private func buildPostMetadata(from post: [String: Any]) -> [String] {
        var metadata = [String]()
        
        if let title = post["title"] as? String {
            metadata.append("📌 \(title)")
        }
        if let author = post["author"] as? String {
            metadata.append("👤 u/\(author)")
        }
        if let subreddit = post["subreddit"] as? String {
            metadata.append("🏷️ r/\(subreddit)")
        }
        if let created = post["created_utc"] as? Double {
            metadata.append("🕒 \(Date(timeIntervalSince1970: created).relativeFormatted)")
        }
        if let score = post["score"] as? Int {
            metadata.append("⭐ \(score.formatUsingAbbreviation())")
        }
        if let numComments = post["num_comments"] as? Int {
            metadata.append("💬 \(numComments.formatUsingAbbreviation())")
        }
        if let over18 = post["over_18"] as? Bool, over18 {
            metadata.append("🔞 NSFW")
        }
        
        return metadata
    }
    
    // MARK: - Extract Comments Recursively
    
    /// Recursively extracts comments from a list of comment children.
    ///
    /// - Parameters:
    ///   - children: An array of comment children dictionaries.
    ///   - depth: The current depth of comment nesting.
    /// - Returns: An array of formatted comment strings.
    private func extractComments(from children: [[String: Any]], depth: Int = 0) -> [String] {
        print("📝 Extracting comments (depth: \(depth), count: \(children.count))")
        var comments: [String] = []
        
        for (index, child) in children.enumerated() {
            print("📝 Processing comment \(index + 1) at depth \(depth)")
            
            guard let kind = child["kind"] as? String else {
                print("⚠️ Comment \(index + 1): No kind found")
                continue
            }
            
            print("📝 Comment kind: \(kind)")
            
            guard let data = child["data"] as? [String: Any] else {
                print("⚠️ Comment \(index + 1): No data found")
                continue
            }
            
            if kind == "more" {
                print("📝 Found 'more' comment")
                if let count = data["count"] as? Int,
                   let childrenIds = data["children"] as? [String] {
                    let moreText = "... \(count) more replies (tap to load)"
                    comments.append(moreText)
                    print("✅ Added more comments indicator: \(moreText)")
                    print("📝 More comments IDs: \(childrenIds)")
                }
                continue
            }
            
            if kind == "t1" {
                print("📝 Processing t1 comment")
                
                // Extract comment content
                let content: String
                if let contentText = data["contentText"] as? String {
                    content = contentText
                } else if let body = data["body"] as? String {
                    content = body
                } else {
                    print("⚠️ Comment \(index + 1): No content found")
                    continue
                }
                
                var comment = String(repeating: "  ", count: depth)
                
                if let author = data["author"] as? String {
                    comment += "u/\(author): "
                }
                
                comment += content
                
                if let score = data["score"] as? Int {
                    comment += " [\(score) points]"
                }
                
                comments.append(comment)
                print("✅ Added comment from u/\(data["author"] as? String ?? "unknown")")
                
                // Handle nested replies
                if let replies = data["replies"] as? [String: Any],
                   let repliesData = replies["data"] as? [String: Any],
                   let replyChildren = repliesData["children"] as? [[String: Any]] {
                    print("📝 Processing \(replyChildren.count) nested replies")
                    let nestedComments = extractComments(from: replyChildren, depth: depth + 1)
                    comments.append(contentsOf: nestedComments)
                    print("✅ Added \(nestedComments.count) nested comments")
                }
            }
        }
        
        return comments
    }
    
    // MARK: - Fetch All Comments
    
    /// Fetches all comments by processing initial comments and recursively handling "more" items.
    ///
    /// - Parameter initialComments: The initial array of comment children.
    /// - Returns: An array of formatted comment strings.
    private func fetchAllComments(initialComments: [[String: Any]]) async throws -> [String] {
        guard let linkId = self.linkId else {
            throw URLError(.badURL) // Or a custom error indicating link_id is missing
        }
        
        var allComments = [String]()
        var queue: [(children: [[String: Any]], depth: Int)] = [(initialComments, 0)]
        var retryCount = 0
        var totalMoreItemsFound = 0
        var totalMoreItemsProcessed = 0
        
        while !queue.isEmpty {
            let batch = queue.removeFirst()
            let (comments, moreItems) = try await processCommentBatch(children: batch.children, depth: batch.depth)
            allComments.append(contentsOf: comments)
            
            // Track total "more" items found
            totalMoreItemsFound += moreItems.count
            print("🔍 Found \(moreItems.count) 'more' items in this batch. Total 'more' items found: \(totalMoreItemsFound)")
            
            for moreItem in moreItems {
                do {
                    let moreComments = try await fetchMoreChildren(children: moreItem.ids, depth: moreItem.depth, linkId: linkId)
                    queue.append((moreComments, moreItem.depth))
                    totalMoreItemsProcessed += 1
                    print("🔍 Processed 'more' item \(totalMoreItemsProcessed)/\(totalMoreItemsFound)")
                } catch {
                    print("⚠️ Error fetching more comments: \(error.localizedDescription). Retry count: \(retryCount)")
                    if retryCount < maxRetryCount {
                        retryCount += 1
                        print("🔄 Retrying to fetch more comments (Attempt \(retryCount))...")
                        try await handleRateLimit(retryCount: retryCount)
                        // Re-append the same moreItem for retry
                        do {
                            let retryMoreComments = try await fetchMoreChildren(children: moreItem.ids, depth: moreItem.depth, linkId: linkId)
                            queue.append((retryMoreComments, moreItem.depth))
                        } catch {
                            print("❌ Failed to fetch more comments on retry: \(error.localizedDescription)")
                            continue
                        }
                    } else {
                        print("❌ Failed to fetch more comments after \(retryCount) retries.")
                        continue
                    }
                }
            }
        }
        
        // Log the total number of comments fetched
        print("✅ Fetched a total of \(allComments.count) comments.")
        
        return allComments
    }
    
    // MARK: - Fetch More Children Comments
    
    /// Fetches additional comments referenced by a "more" item.
    ///
    /// - Parameters:
    ///   - children: An array of comment IDs to fetch.
    ///   - depth: The current depth of comment nesting.
    ///   - linkId: The `link_id` of the Reddit post.
    /// - Returns: An array of comment dictionaries.
    private func fetchMoreChildren(children: [String], depth: Int, linkId: String) async throws -> [[String: Any]] {
        let chunkSize = 100 // Reddit's API limit per request
        var allComments = [[String: Any]]()
        
        let chunks = children.chunked(into: chunkSize)
        
        for (index, chunk) in chunks.enumerated() {
            semaphore.wait() // Control concurrency
            defer { semaphore.signal() }
            
            var components = URLComponents(string: "https://www.reddit.com/api/morechildren.json")!
            components.queryItems = [
                URLQueryItem(name: "api_type", value: "json"),
                URLQueryItem(name: "link_id", value: linkId),
                URLQueryItem(name: "children", value: chunk.joined(separator: ",")),
                URLQueryItem(name: "sort", value: "confidence"),
                URLQueryItem(name: "limit_children", value: "false"),
                URLQueryItem(name: "depth", value: "10")
            ]
            
            guard let url = components.url else {
                print("❌ Failed to construct URL for chunk \(index + 1)")
                continue
            }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type for chunk \(index + 1)")
                    continue
                }
                
                if httpResponse.statusCode == 429 {
                    print("⚠️ Rate limited, waiting before retrying chunk \(index + 1)...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    // Retry the same chunk after delay
                    let retryComments = try await fetchMoreChildren(children: chunk, depth: depth, linkId: linkId)
                    allComments.append(contentsOf: retryComments)
                    continue
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ Bad status: \(httpResponse.statusCode) for chunk \(index + 1)")
                    continue
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let jsonData = json?["json"] as? [String: Any],
                      let dataDict = jsonData["data"] as? [String: Any],
                      let things = dataDict["things"] as? [[String: Any]] else {
                    print("❌ Failed to parse JSON structure for chunk \(index + 1)")
                    continue
                }
                
                if things.isEmpty {
                    print("⚠️ 'More' item fetched zero comments for chunk \(index + 1).")
                } else {
                    allComments.append(contentsOf: things)
                    print("✅ Added \(things.count) comments from chunk \(index + 1)")
                }
                
                // Respect rate limits by introducing a delay between chunks
                if index < chunks.count - 1 {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                }
                
            } catch {
                print("⚠️ Error processing chunk \(index + 1): \(error.localizedDescription)")
                throw error // Propagate the error to handle retries
            }
        }
        
        return allComments
    }
    
    // MARK: - Format Individual Comment
    
    /// Formats a single comment into a readable string.
    ///
    /// - Parameters:
    ///   - data: The comment data dictionary.
    ///   - depth: The current depth of comment nesting.
    /// - Returns: A formatted comment string.
    private func formatComment(data: [String: Any], depth: Int) -> String {
        var comment = String(repeating: "  ", count: depth)
        
        if let author = data["author"] as? String {
            comment += "👤 u/\(author): "
        }
        
        if let body = data["body"] as? String {
            comment += body
        } else if let contentText = data["contentText"] as? String {
            comment += contentText
        }
        
        if let score = data["score"] as? Int {
            comment += " [\(score) points]"
        }
        
        return comment
    }
    
    // MARK: - Extract Subreddit Content
    
    /// Extracts and formats content from a subreddit listing.
    ///
    /// - Parameter data: The raw data fetched from Reddit API.
    /// - Returns: A formatted string containing subreddit posts.
    private func extractSubredditContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let children = dataDict["children"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        
        return children.compactMap { child -> String? in
            guard let data = child["data"] as? [String: Any] else { return nil }
            return formatPostListing(data: data)
        }.joined(separator: "\n\n")
    }
    
    // MARK: - Format Post Listing
    
    /// Formats a single post listing into a readable string.
    ///
    /// - Parameter data: The post data dictionary.
    /// - Returns: A formatted post string.
    private func formatPostListing(data: [String: Any]) -> String {
        var post = [String]()
        
        if let title = data["title"] as? String {
            post.append("📌 \(title)")
        }
        if let author = data["author"] as? String {
            post.append("👤 u/\(author)")
        }
        if let score = data["score"] as? Int {
            post.append("⭐ \(score)")
        }
        if let numComments = data["num_comments"] as? Int {
            post.append("💬 \(numComments)")
        }
        if let url = data["url"] as? String {
            post.append("🔗 \(url)")
        }
        
        return post.joined(separator: "\n")
    }
    
    // MARK: - Process Comment Batch
    
    /// Processes a batch of comments, extracting formatted comments and identifying "more" items.
    ///
    /// - Parameters:
    ///   - children: An array of comment children dictionaries.
    ///   - depth: The current depth of comment nesting.
    /// - Returns: A tuple containing formatted comments and identified "more" items.
    private func processCommentBatch(children: [[String: Any]], depth: Int) async throws -> (comments: [String], moreItems: [(ids: [String], depth: Int)]) {
        var comments = [String]()
        var moreItems = [(ids: [String], depth: Int)]()
        
        for child in children {
            guard let kind = child["kind"] as? String else { continue }
            
            switch kind {
            case "t1": // Regular comment
                if let data = child["data"] as? [String: Any] {
                    let comment = formatComment(data: data, depth: depth)
                    comments.append(comment)
                    
                    // Process replies recursively
                    if let replies = data["replies"] as? [String: Any],
                       let repliesData = replies["data"] as? [String: Any],
                       let replyChildren = repliesData["children"] as? [[String: Any]] {
                        let (nestedComments, nestedMore) = try await processCommentBatch(children: replyChildren, depth: depth + 1)
                        comments.append(contentsOf: nestedComments)
                        moreItems.append(contentsOf: nestedMore)
                    }
                }
                
            case "more": // "More" comments placeholder
                if let data = child["data"] as? [String: Any],
                   let childrenIds = data["children"] as? [String], !childrenIds.isEmpty {
                    moreItems.append((childrenIds, depth))
                }
                
            default:
                continue
            }
        }
        
        return (comments, moreItems)
    }
}
