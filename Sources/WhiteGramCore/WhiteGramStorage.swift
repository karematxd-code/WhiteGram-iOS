import Foundation

public final class WhiteGramStorage {
    public static let shared = WhiteGramStorage()
    
    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let userDefaults: UserDefaults
    private let lock = NSLock()
    
    private init() {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            self.baseDirectory = containerURL.appendingPathComponent("WhiteGram", isDirectory: true)
            self.userDefaults = UserDefaults(suiteName: appGroup) ?? .standard
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("WhiteGram", isDirectory: true)
            self.userDefaults = .standard
        }
        
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }
    
    public func fileURL(for component: String) -> URL {
        return baseDirectory.appendingPathComponent(component)
    }
    
    public func save<T: Encodable>(_ object: T, to filename: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(object)
        try data.write(to: url, options: .atomic)
    }
    
    public func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: filename)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    public func set<T>(_ value: T?, forKey key: String) {
        userDefaults.set(value, forKey: "whitegram_\(key)")
    }
    
    public func get<T>(forKey key: String) -> T? {
        return userDefaults.object(forKey: "whitegram_\(key)") as? T
    }
    
    public func bool(forKey key: String, default defaultValue: Bool = false) -> Bool {
        let fullKey = "whitegram_\(key)"
        if userDefaults.object(forKey: fullKey) == nil {
            return defaultValue
        }
        return userDefaults.bool(forKey: fullKey)
    }
}
