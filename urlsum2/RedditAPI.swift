import Foundation

// MARK: - Reddit API Error Types
enum RedditAPIError: LocalizedError {
    case invalidURL
    case networkError(underlying: Error)
    case httpError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: Int?)
    case forbidden(reason: String)
    case postNotFound
    case subredditNotFound
    case parseError(reason: String)
    case commentsUnavailable
    case privateSubreddit
    case userBanned
    case contentDeleted
    case apiQuotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Reddit URL provided is not valid"
        case .networkError(let underlying):
            return "Network connection failed: \(underlying.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "Reddit server error (\(statusCode)): \(message ?? "Unknown error")"
        case .rateLimited(let retryAfter):
            if let retrySeconds = retryAfter {
                return "Too many requests to Reddit. Please try again in \(retrySeconds) seconds."
            } else {
                return "Too many requests to Reddit. Please wait a moment and try again."
            }
        case .forbidden(let reason):
            return "Access denied: \(reason)"
        case .postNotFound:
            return "This Reddit post was not found. It may have been deleted or the URL is incorrect."
        case .subredditNotFound:
            return "This subreddit was not found or may be private."
        case .parseError(let reason):
            return "Failed to parse Reddit data: \(reason)"
        case .commentsUnavailable:
            return "Comments are not available for this Reddit post."
        case .privateSubreddit:
            return "This subreddit is private and cannot be accessed."
        case .userBanned:
            return "Access to this content is restricted."
        case .contentDeleted:
            return "This Reddit content has been deleted."
        case .apiQuotaExceeded:
            return "Reddit API quota exceeded. Please try again later."
        }
    }
    
    var recoveryDescription: String? {
        switch self {
        case .rateLimited:
            return "Wait a few minutes before trying again"
        case .postNotFound, .subredditNotFound:
            return "Check the URL and try again"
        case .privateSubreddit, .userBanned:
            return "Try a different Reddit post or subreddit"
        case .networkError:
            return "Check your internet connection"
        case .contentDeleted:
            return "This content is no longer available"
        default:
            return "Try again or contact support if the problem persists"
        }
    }
}

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
    
    /// Maximum number of "more" requests to prevent infinite loops
    private let maxMoreRequests = 50
    
    /// Track the number of "more" requests made
    private var moreRequestCount = 0
    
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
    /// - Returns: A tuple containing the formatted string and an optional comment count (nil for non-post pages).
    func getContent(from url: URL, includeAllComments: Bool = true) async throws -> (content: String, commentCount: Int?) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.scheme = "https"
        components.host = "www.reddit.com"
        
        // Handle root URL by redirecting to "/hot"
        let urlString = url.absoluteString
        let isRootURL = urlString.hasPrefix("https://reddit.com/") && (urlString == "https://reddit.com/" || urlString == "https://reddit.com") ||
                       urlString.hasPrefix("https://www.reddit.com/") && (urlString == "https://www.reddit.com/" || urlString == "https://www.reddit.com") ||
                       urlString.hasPrefix("http://reddit.com/") && (urlString == "http://reddit.com/" || urlString == "http://reddit.com") ||
                       urlString.hasPrefix("http://www.reddit.com/") && (urlString == "http://www.reddit.com/" || urlString == "http://www.reddit.com")
        
        if isRootURL {
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
            throw RedditAPIError.invalidURL
        }
        
        print("🌐 Fetching from: \(apiURL)")
        
        var request = URLRequest(url: apiURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Fetch data from Reddit API
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Network error: \(error)")
            throw RedditAPIError.networkError(underlying: error)
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedditAPIError.httpError(statusCode: 0, message: "Invalid response format")
        }
        
        // Handle specific HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break // Success, continue processing
        case 403:
            // Check if it's a private subreddit or banned user
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.contains("private") {
                    throw RedditAPIError.privateSubreddit
                } else if responseString.contains("banned") {
                    throw RedditAPIError.userBanned
                } else {
                    throw RedditAPIError.forbidden(reason: "Access to this content is restricted")
                }
            } else {
                throw RedditAPIError.forbidden(reason: "Access denied")
            }
        case 404:
            // Determine if it's a post or subreddit that's not found
            if apiURL.path.contains("/comments/") {
                throw RedditAPIError.postNotFound
            } else {
                throw RedditAPIError.subredditNotFound
            }
        case 429:
            // Rate limited - try to extract retry-after header
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw RedditAPIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw RedditAPIError.httpError(statusCode: httpResponse.statusCode, message: "Reddit server error")
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RedditAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse JSON response
        do {
            // Check if it's a post or subreddit based on JSON structure
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
               jsonArray.count >= 2,
               let postListing = jsonArray[0] as? [String: Any],
               let postData = postListing["data"] as? [String: Any],
               (postData["children"] as? [[String: Any]])?.first?["kind"] as? String == "t3", // Check if it's a post (t3)
               let commentListing = jsonArray[1] as? [String: Any],
               commentListing["kind"] as? String == "Listing" { // Check if second element is comments (Listing)
                
                let (content, count) = try await extractPostContent(from: data, includeAllComments: includeAllComments)
                return (content, count) // Return content and count for posts
            } else {
                // Check if the response indicates deleted content
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String,
                   error.contains("deleted") || error.contains("removed") {
                    throw RedditAPIError.contentDeleted
                }
                
                // Assume it's a subreddit or other listing type
                let (content, _) = try extractSubredditContent(from: data) // Ignore nil count
                return (content, nil) // Return nil count for non-posts
            }
        } catch let error as RedditAPIError {
            // Re-throw Reddit API errors
            throw error
        } catch {
            print("❌ JSON parsing error: \(error)")
            throw RedditAPIError.parseError(reason: error.localizedDescription)
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
    /// - Returns: A tuple containing the formatted string and comment count.
    private func extractPostContent(from data: Data, includeAllComments: Bool) async throws -> (content: String, commentCount: Int) {
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
              jsonArray.count >= 2 else {
            throw RedditAPIError.parseError(reason: "Invalid Reddit API response structure")
        }
        
        // Parse post data
        guard let postListing = jsonArray[0] as? [String: Any],
              let postData = (postListing["data"] as? [String: Any])?["children"] as? [[String: Any]],
              let post = postData.first?["data"] as? [String: Any],
              let postId = post["id"] as? String else {
            throw RedditAPIError.parseError(reason: "Could not extract post data from Reddit response")
        }
        
        // Check if post is deleted or removed
        if let removed = post["removed_by_category"] as? String, !removed.isEmpty {
            throw RedditAPIError.contentDeleted
        }
        
        // Set link_id for future use and reset counter
        self.linkId = "t3_\(postId)"
        self.moreRequestCount = 0
        print("🔗 Link ID set to: \(self.linkId!)")
        
        // Build post metadata
        var content = buildPostMetadata(from: post)
        
        // Add post content (selftext)
        if let selftext = post["selftext"] as? String, !selftext.isEmpty {
            content.append("\n\(selftext)")
        }
        
        var allComments: [String] = []
        var allMoreItems: [(ids: [String], depth: Int)] = []
        var totalCommentCount = 0 // Initialize total count

        if includeAllComments {
            guard let commentListing = jsonArray[1] as? [String: Any],
                  let commentData = commentListing["data"] as? [String: Any],
                  let initialChildren = commentData["children"] as? [[String: Any]] else {
                print("⚠️ Could not parse initial comment data.")
                throw RedditAPIError.commentsUnavailable
            }
            
            // Process initial batch of comments
            var initialQueue: [(children: [[String: Any]], depth: Int)] = [(initialChildren, 0)]
            var processedMoreIds = Set<String>()
            
            while !initialQueue.isEmpty {
                let batch = initialQueue.removeFirst()
                let (batchComments, batchMoreItems, batchCount) = try await processCommentBatch(children: batch.children, depth: batch.depth)
                allComments.append(contentsOf: batchComments)
                totalCommentCount += batchCount // Add count from initial batch
                
                // Track unique "more" items
                for more in batchMoreItems {
                    let uniqueIds = more.ids.filter { !processedMoreIds.contains($0) }
                    if !uniqueIds.isEmpty {
                        allMoreItems.append((ids: uniqueIds, depth: more.depth))
                        processedMoreIds.formUnion(uniqueIds)
                    }
                }
            }

            // Fetch "more" comments if necessary
            if !allMoreItems.isEmpty {
                print("⏳ Fetching \(allMoreItems.reduce(0) { $0 + $1.ids.count }) more comment items...")
                do {
                    let moreResults = try await allMoreItems.asyncMap { (ids, depth) in
                        try await self.fetchMoreComments(ids: ids, depth: depth)
                    }
                    for (moreComments, moreCount) in moreResults {
                        allComments.append(contentsOf: moreComments)
                        totalCommentCount += moreCount // Add count from fetched 'more' comments
                    }
                } catch let error as RedditAPIError {
                    // If there's a Reddit API error while fetching more comments, 
                    // continue with what we have rather than failing completely
                    print("⚠️ Could not fetch additional comments: \(error.localizedDescription)")
                } catch {
                    print("⚠️ Unexpected error fetching more comments: \(error)")
                }
            }
        }
        
        // Combine post content and comments
        content.append("\n\n--- Comments ---")
        content.append(contentsOf: allComments)
        
        print("✅ Extracted post and \(totalCommentCount) comments.")
        return (content.joined(separator: "\n"), totalCommentCount) // Return total count
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
            let (comments, moreItems, commentCount) = try await processCommentBatch(children: batch.children, depth: batch.depth)
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
    /// - Returns: A tuple containing the formatted string and an optional comment count (nil for non-post pages).
    private func extractSubredditContent(from data: Data) throws -> (content: String, commentCount: Int?) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let children = dataDict["children"] as? [[String: Any]] else {
            throw RedditAPIError.parseError(reason: "Could not parse subreddit data from Reddit response")
        }
        
        // Check if subreddit has no posts
        if children.isEmpty {
            // This might be a private subreddit or one with no posts
            if let error = json["error"] as? String {
                if error.contains("private") || error.contains("forbidden") {
                    throw RedditAPIError.privateSubreddit
                }
            }
            return ("This subreddit appears to be empty or has no accessible posts.", nil)
        }
        
        let content = children.compactMap { child -> String? in
            guard let data = child["data"] as? [String: Any] else { return nil }
            return formatPostListing(data: data)
        }.joined(separator: "\n\n")
        
        return (content, nil) // Return nil for comment count
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
    /// - Returns: A tuple containing formatted comments, identified "more" items, and the count of comments processed.
    private func processCommentBatch(children: [[String: Any]], depth: Int) async throws -> (comments: [String], moreItems: [(ids: [String], depth: Int)], commentCount: Int) {
        var comments = [String]()
        var moreItems = [(ids: [String], depth: Int)]()
        var currentBatchCommentCount = 0 // Initialize count for this batch
        
        for child in children {
            guard let kind = child["kind"] as? String else { continue }
            
            switch kind {
            case "t1": // Regular comment
                if let data = child["data"] as? [String: Any] {
                    let comment = formatComment(data: data, depth: depth)
                    comments.append(comment)
                    currentBatchCommentCount += 1 // Increment count for t1 comment
                    
                    // Process replies recursively
                    if let replies = data["replies"] as? [String: Any],
                       let repliesData = replies["data"] as? [String: Any],
                       let replyChildren = repliesData["children"] as? [[String: Any]] {
                        let (nestedComments, nestedMore, nestedCount) = try await processCommentBatch(children: replyChildren, depth: depth + 1)
                        comments.append(contentsOf: nestedComments)
                        moreItems.append(contentsOf: nestedMore)
                        currentBatchCommentCount += nestedCount // Add count from nested calls
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
        
        return (comments, moreItems, currentBatchCommentCount) // Return count
    }
    
    // MARK: - Fetch More Comments
    
    /// Fetches additional comments referenced by a "more" item.
    ///
    /// - Parameters:
    ///   - ids: An array of comment IDs to fetch.
    ///   - depth: The depth of the comments being fetched.
    ///   - retryCount: The current retry attempt.
    /// - Returns: A tuple containing an array of formatted comment strings and the count of comments fetched.
    private func fetchMoreComments(ids: [String], depth: Int, retryCount: Int = 0) async throws -> (comments: [String], commentCount: Int) {
        // Check if we've exceeded the maximum number of "more" requests
        if moreRequestCount >= maxMoreRequests {
            print("🛑 Reached maximum number of 'more' requests (\(maxMoreRequests)). Stopping to prevent infinite loop.")
            return ([], 0)
        }
        
        // Ensure linkId is available
        guard let linkId = self.linkId else {
            print("⚠️ Link ID not found for fetching more comments.")
            return ([], 0)
        }
        
        moreRequestCount += 1
        print("⏳ Fetching more comments (depth: \(depth), ids: \(ids.count), retry: \(retryCount), request: \(moreRequestCount)/\(maxMoreRequests))")
        
        var comments = [String]()
        var totalCommentCount = 0 // Initialize count
        var consecutiveParseFailures = 0
        let maxConsecutiveParseFailures = 5 // Stop after 5 consecutive failures
        
        let chunkSize = 100 // Reddit's API limit per request
        let chunks = ids.chunked(into: chunkSize)
        
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
                
                // Handle specific status codes for more comments
                switch httpResponse.statusCode {
                case 200...299:
                    break // Success, continue processing
                case 429:
                    print("⚠️ Rate limited, waiting before retrying chunk \(index + 1)...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    // Retry the same chunk after delay
                    let retryComments = try await self.fetchMoreComments(ids: chunk, depth: depth, retryCount: retryCount)
                    comments.append(contentsOf: retryComments.comments)
                    totalCommentCount += retryComments.commentCount
                    continue
                case 404:
                    print("⚠️ Some comments in chunk \(index + 1) were not found (likely deleted)")
                    continue // Skip this chunk but continue with others
                case 403:
                    print("⚠️ Access denied to some comments in chunk \(index + 1)")
                    continue // Skip this chunk but continue with others
                default:
                    print("❌ HTTP error \(httpResponse.statusCode) for chunk \(index + 1)")
                    continue // Skip this chunk but continue with others
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("⚠️ Could not parse JSON response for chunk \(index + 1)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔍 Raw response: \(responseString.prefix(200))...")
                    }
                    continue
                }
                
                // Check for Reddit API errors in response
                if let jsonContent = json["json"] as? [String: Any],
                   let errors = jsonContent["errors"] as? [[String]], !errors.isEmpty {
                    print("⚠️ Reddit API returned errors for chunk \(index + 1): \(errors)")
                    continue
                }
                
                // Check if response contains valid data structure
                if let jsonData = json["json"] as? [String: Any],
                   let dataDict = jsonData["data"] as? [String: Any],
                   let things = dataDict["things"] as? [[String: Any]] {
                    // Process using the original structure
                    if things.isEmpty {
                        print("⚠️ 'More' item returned empty results for chunk \(index + 1).")
                    } else {
                        print("🧩 Processing fetched children using 'things' structure (count: \(things.count))")
                        let (newComments, moreItems, batchCount) = try await self.processCommentBatch(children: things, depth: depth)
                        comments.append(contentsOf: newComments)
                        totalCommentCount += batchCount
                        
                        // Handle nested 'more' items if any
                        if !moreItems.isEmpty {
                            print("🧩 Found nested 'more' items (count: \(moreItems.count))")
                            do {
                                let nestedResults = try await moreItems.asyncMap { (nestedIds, nestedDepth) in
                                    try await self.fetchMoreComments(ids: nestedIds, depth: nestedDepth)
                                }
                                for (nestedComments, nestedCount) in nestedResults {
                                    comments.append(contentsOf: nestedComments)
                                    totalCommentCount += nestedCount
                                }
                            } catch {
                                print("⚠️ Failed to fetch some nested comments: \(error.localizedDescription)")
                            }
                        }
                    }
                    continue
                }
                
                // Try alternative JSON structure (array format)
                guard let jsonArray = json["json"] as? [Any] else {
                    consecutiveParseFailures += 1
                    print("⚠️ Could not parse 'more' comments response structure for chunk \(index + 1) (consecutive failures: \(consecutiveParseFailures))")
                    print("🔍 Available keys in json: \(json.keys)")
                    if let jsonContent = json["json"] {
                        print("🔍 Type of json content: \(type(of: jsonContent))")
                    }
                    
                    // Stop if we have too many consecutive parse failures
                    if consecutiveParseFailures >= maxConsecutiveParseFailures {
                        print("🛑 Too many consecutive parse failures (\(consecutiveParseFailures)). Stopping to prevent infinite loop.")
                        break
                    }
                    continue
                }
                
                // Reset consecutive failures on successful parse
                consecutiveParseFailures = 0
                
                for item in jsonArray {
                    guard let listing = item as? [String: Any],
                          let data = listing["data"] as? [String: Any],
                          let children = data["children"] as? [[String: Any]] else {
                        print("⚠️ Could not parse 'more' comments response item.")
                        continue
                    }
                    
                    // Recursively process the fetched children
                    print("🧩 Processing fetched children (count: \(children.count))")
                    let (newComments, moreItems, batchCount) = try await self.processCommentBatch(children: children, depth: depth) // Get count
                    comments.append(contentsOf: newComments)
                    totalCommentCount += batchCount // Add count

                    // Handle nested 'more' items if any
                    if !moreItems.isEmpty {
                        print("🧩 Found nested 'more' items (count: \(moreItems.count))")
                        do {
                            let nestedResults = try await moreItems.asyncMap { (nestedIds, nestedDepth) in
                                try await self.fetchMoreComments(ids: nestedIds, depth: nestedDepth)
                            }
                            for (nestedComments, nestedCount) in nestedResults {
                                comments.append(contentsOf: nestedComments)
                                totalCommentCount += nestedCount // Add nested count
                            }
                        } catch {
                            print("⚠️ Failed to fetch some nested comments: \(error.localizedDescription)")
                            // Continue processing even if some nested comments fail
                        }
                    }
                }
                
                // Respect rate limits by introducing a delay between chunks
                if index < chunks.count - 1 {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                }
                
            } catch {
                print("⚠️ Error processing chunk \(index + 1): \(error.localizedDescription)")
                
                // Only retry for certain types of errors
                if retryCount < maxRetryCount {
                    var shouldRetry = false
                    
                    if let urlError = error as? URLError {
                        // Retry on network errors
                        shouldRetry = [.timedOut, .networkConnectionLost, .notConnectedToInternet].contains(urlError.code)
                    } else if error.localizedDescription.contains("rate") || error.localizedDescription.contains("429") {
                        // Retry on rate limiting
                        shouldRetry = true
                    }
                    
                    if shouldRetry {
                        let currentRetryCount = retryCount + 1
                        print("🔄 Retrying to fetch more comments (Attempt \(currentRetryCount))...")
                        try await self.handleRateLimit(retryCount: currentRetryCount)
                        // Re-append the same chunk for retry
                        let retryComments = try await self.fetchMoreComments(ids: chunk, depth: depth, retryCount: currentRetryCount)
                        comments.append(contentsOf: retryComments.comments)
                        totalCommentCount += retryComments.commentCount
                    } else {
                        print("❌ Non-retryable error for chunk \(index + 1): \(error.localizedDescription)")
                        continue // Skip this chunk but continue with others
                    }
                } else {
                    print("❌ Failed to fetch more comments after \(retryCount) retries.")
                    continue // Skip this chunk but continue with others
                }
            }
        }
        
        print("✅ Fetched \(totalCommentCount) more comments successfully.")
        return (comments, totalCommentCount)
    }
}
