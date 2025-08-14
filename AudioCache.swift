import Foundation

class AudioCache {
    static let shared = AudioCache()
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("TTSCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Set cache limits
        cache.countLimit = 100 // Maximum number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    func cacheAudio(_ data: Data, for key: String) {
        let cacheKey = NSString(string: key)
        cache.setObject(data as NSData, forKey: cacheKey)
        
        // Also save to disk
        let fileURL = cacheDirectory.appendingPathComponent(key.md5)
        try? data.write(to: fileURL)
    }
    
    func getCachedAudio(for key: String) -> Data? {
        let cacheKey = NSString(string: key)
        
        // Check memory cache first
        if let data = cache.object(forKey: cacheKey) {
            return data as Data
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.md5)
        if let data = try? Data(contentsOf: fileURL) {
            // Add back to memory cache
            cache.setObject(data as NSData, forKey: cacheKey)
            return data
        }
        
        return nil
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MD5 extension for cache keys
extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
} 