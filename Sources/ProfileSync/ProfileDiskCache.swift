//
//  ProfileDiskCache.swift
//  WhiteGram
//
//  Created for WhiteGram iOS.
//  Copyright © 2026 WhiteGram. All rights reserved.
//

import Foundation
import WhiteGramCore

public final class ProfileDiskCache: @unchecked Sendable {
    public static let shared = ProfileDiskCache()
    
    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let profilesDirectory: URL
    private let outboxFileURL: URL
    private let metadataFileURL: URL
    
    private let lock = NSLock()
    private var memoryCache: [Int64: UserProfileSyncData] = [:]
    private var outboxCache: [SyncOperation] = []
    
    public var maxCacheAge: TimeInterval = 86400 * 7 // 7 days default
    
    public init(customBaseDirectory: URL? = nil) {
        if let customDir = customBaseDirectory {
            self.baseDirectory = customDir
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.baseDirectory = appSupport.appendingPathComponent("WhiteGram/ProfileSync", isDirectory: true)
        }
        
        self.profilesDirectory = baseDirectory.appendingPathComponent("profiles", isDirectory: true)
        self.outboxFileURL = baseDirectory.appendingPathComponent("outbox.json")
        self.metadataFileURL = baseDirectory.appendingPathComponent("cache_meta.json")
        
        createDirectoriesIfNeeded()
        loadOutboxFromDisk()
    }
    
    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: profilesDirectory.path) {
            #if os(iOS) || targetEnvironment(macCatalyst)
            let attributes: [FileAttributeKey: Any]? = [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ]
            #else
            let attributes: [FileAttributeKey: Any]? = nil
            #endif
            try? fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true, attributes: attributes)
        }
    }
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    // MARK: - Profile Operations
    
    public func saveProfile(_ profile: UserProfileSyncData) throws {
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Update memory cache
        memoryCache[profile.userId] = profile
        
        // 2. Persist to isolated profile file atomically
        let fileURL = profilesDirectory.appendingPathComponent("profile_\(profile.userId).json")
        let data = try jsonEncoder.encode(profile)
        try data.write(to: fileURL, options: [.atomic])
        
        WhiteGramLog.debug("Profile for user \(profile.userId) saved to disk cache [\(fileURL.lastPathComponent)]. Badges count: \(profile.badges.count)")
    }
    
    public func loadProfile(for userId: Int64) -> UserProfileSyncData? {
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Check memory cache first
        if let cached = memoryCache[userId] {
            return cached
        }
        
        // 2. Check disk file
        let fileURL = profilesDirectory.appendingPathComponent("profile_\(userId).json")
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        do {
            let profile = try jsonDecoder.decode(UserProfileSyncData.self, from: data)
            memoryCache[userId] = profile
            return profile
        } catch {
            WhiteGramLog.error("Failed to decode profile from disk cache for user \(userId): \(error.localizedDescription)")
            return nil
        }
    }
    
    public func deleteProfile(for userId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        
        memoryCache.removeValue(forKey: userId)
        let fileURL = profilesDirectory.appendingPathComponent("profile_\(userId).json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    public func allCachedProfiles() -> [UserProfileSyncData] {
        lock.lock()
        defer { lock.unlock() }
        
        guard let files = try? fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil) else {
            return Array(memoryCache.values)
        }
        
        var results: [UserProfileSyncData] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let profile = try? jsonDecoder.decode(UserProfileSyncData.self, from: data) {
                results.append(profile)
                memoryCache[profile.userId] = profile
            }
        }
        return results
    }
    
    // MARK: - Outbox Operations (Offline Queue)
    
    private func loadOutboxFromDisk() {
        guard fileManager.fileExists(atPath: outboxFileURL.path),
              let data = try? Data(contentsOf: outboxFileURL) else {
            self.outboxCache = []
            return
        }
        
        if let operations = try? jsonDecoder.decode([SyncOperation].self, from: data) {
            self.outboxCache = operations
            WhiteGramLog.info("Loaded \(operations.count) pending outbox operations from disk.")
        }
    }
    
    private func persistOutboxToDisk() {
        do {
            let data = try jsonEncoder.encode(outboxCache)
            try data.write(to: outboxFileURL, options: [.atomic])
        } catch {
            WhiteGramLog.error("Failed to persist outbox to disk: \(error.localizedDescription)")
        }
    }
    
    public func enqueueOperation(_ operation: SyncOperation) {
        lock.lock()
        defer { lock.unlock() }
        
        outboxCache.append(operation)
        persistOutboxToDisk()
        WhiteGramLog.info("Enqueued outbox operation [\(operation.type.rawValue)] for user \(operation.userId). Total pending: \(outboxCache.count)")
    }
    
    public func getPendingOperations() -> [SyncOperation] {
        lock.lock()
        defer { lock.unlock() }
        return outboxCache
    }
    
    public func removeOperation(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        outboxCache.removeAll { $0.id == id }
        persistOutboxToDisk()
    }
    
    public func removeOperations(ids: [UUID]) {
        lock.lock()
        defer { lock.unlock() }
        
        let idSet = Set(ids)
        outboxCache.removeAll { idSet.contains($0.id) }
        persistOutboxToDisk()
    }
    
    public func updateOperation(_ operation: SyncOperation) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = outboxCache.firstIndex(where: { $0.id == operation.id }) {
            outboxCache[index] = operation
            persistOutboxToDisk()
        }
    }
    
    public func clearOutbox() {
        lock.lock()
        defer { lock.unlock() }
        
        outboxCache.removeAll()
        persistOutboxToDisk()
    }
    
    // MARK: - Eviction & Maintenance
    
    public func purgeExpiredProfiles() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let files = try? fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        let now = Date()
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let modDate = attributes[.modificationDate] as? Date {
                if now.timeIntervalSince(modDate) > maxCacheAge {
                    try? fileManager.removeItem(at: file)
                    WhiteGramLog.info("Evicted expired profile disk cache file: \(file.lastPathComponent)")
                }
            }
        }
    }
    
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        
        memoryCache.removeAll()
        outboxCache.removeAll()
        try? fileManager.removeItem(at: profilesDirectory)
        try? fileManager.removeItem(at: outboxFileURL)
        createDirectoriesIfNeeded()
    }
}
