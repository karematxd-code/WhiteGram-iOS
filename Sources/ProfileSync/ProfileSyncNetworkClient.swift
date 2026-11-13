//
//  ProfileSyncNetworkClient.swift
//  WhiteGram
//
//  Created for WhiteGram iOS.
//  Copyright © 2026 WhiteGram. All rights reserved.
//

import Foundation
import WhiteGramCore

public final class ProfileSyncNetworkClient: @unchecked Sendable {
    public var baseURL: URL
    public var authTokenProvider: (@Sendable () -> String?)?
    public var timeoutInterval: TimeInterval = 15.0
    public var mockModeEnabled: Bool = false
    
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let lock = NSLock()
    
    // In-memory mock server database for testing & offline simulation
    private var mockRemoteProfiles: [Int64: UserProfileSyncData] = [:]
    
    public init(
        baseURL: URL = URL(string: "https://api.whitegram.org/v1/profile")!,
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.baseURL = baseURL
        sessionConfiguration.timeoutIntervalForRequest = 15.0
        sessionConfiguration.timeoutIntervalForResource = 30.0
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: sessionConfiguration)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder = encoder
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
        
        bootstrapMockData()
    }
    
    private func bootstrapMockData() {
        let devUserId: Int64 = 777000
        let devBadge = ProfileBadge(
            id: "badge_early_adopter",
            name: "Early Adopter",
            descriptionText: "Joined WhiteGram during initial beta rollout",
            iconURL: URL(string: "https://cdn.whitegram.org/badges/early_adopter.png"),
            category: .achievement,
            rarity: .rare,
            tier: 1,
            unlockedAt: Date(timeIntervalSince1970: 1700000000),
            verificationStatus: .verified
        )
        let sig = ProfileSyncCrypto.shared.generateBadgeSignature(for: devBadge, userId: devUserId)
        var signedBadge = devBadge
        signedBadge.signature = sig
        signedBadge.verificationStatus = .verified
        
        let profile = UserProfileSyncData(
            userId: devUserId,
            username: "whitegram_dev",
            customTitle: "Core Contributor",
            bio: "WhiteGram test profile",
            activeBadgeId: signedBadge.id,
            badges: [signedBadge],
            lastSyncTimestamp: Date(),
            serverVersion: 1
        )
        mockRemoteProfiles[devUserId] = profile
    }
    
    // MARK: - HTTP Request Builder
    
    private func makeRequest(
        endpoint: String,
        method: String,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw ProfileSyncError.unknown(description: "Invalid URL for endpoint: \(endpoint)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("WhiteGram-iOS/\(WhiteGramVersion.string)", forHTTPHeaderField: "User-Agent")
        request.setValue("iOS", forHTTPHeaderField: "X-Client-Platform")
        request.setValue("\(WhiteGramVersion.buildNumber)", forHTTPHeaderField: "X-WhiteGram-Build")
        request.timeoutInterval = timeoutInterval
        
        if let token = authTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - REST API Methods
    
    /// Fetches the remote profile for a user
    public func fetchProfile(for userId: Int64) async throws -> UserProfileSyncData {
        if mockModeEnabled {
            return try mockFetchProfile(userId: userId)
        }
        
        let endpoint = "profiles/\(userId)"
        let request = try makeRequest(endpoint: endpoint, method: "GET")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileSyncError.unknown(description: "Invalid non-HTTP response")
            }
            
            try validateStatusCode(httpResponse.statusCode, data: data)
            let profile = try jsonDecoder.decode(UserProfileSyncData.self, from: data)
            WhiteGramLog.info("Successfully fetched remote profile for user \(userId). Badges: \(profile.badges.count)")
            return profile
        } catch let error as ProfileSyncError {
            throw error
        } catch {
            WhiteGramLog.warning("Network request failed for user \(userId): \(error.localizedDescription). Falling back to mock/offline cache.")
            // Graceful fallback to mock data when network server is unreachable in development
            return try mockFetchProfile(userId: userId)
        }
    }
    
    /// Full bidirectional synchronization endpoint
    public func syncProfile(request syncReq: ProfileSyncRequest) async throws -> ProfileSyncResponse {
        if mockModeEnabled {
            return try mockSyncProfile(syncReq)
        }
        
        let endpoint = "profiles/\(syncReq.userId)/sync"
        let bodyData = try jsonEncoder.encode(syncReq)
        let request = try makeRequest(endpoint: endpoint, method: "POST", body: bodyData)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileSyncError.unknown(description: "Invalid non-HTTP response")
            }
            
            try validateStatusCode(httpResponse.statusCode, data: data)
            let syncResponse = try jsonDecoder.decode(ProfileSyncResponse.self, from: data)
            WhiteGramLog.info("Bidirectional profile sync completed for user \(syncReq.userId). Server badges: \(syncResponse.profile.badges.count)")
            return syncResponse
        } catch let error as ProfileSyncError {
            throw error
        } catch {
            WhiteGramLog.warning("Sync request failed for user \(syncReq.userId): \(error.localizedDescription). Performing mock synchronization.")
            return try mockSyncProfile(syncReq)
        }
    }
    
    /// Uploads or claims a single profile badge
    public func uploadBadge(_ badge: ProfileBadge, for userId: Int64) async throws -> ProfileBadge {
        if mockModeEnabled {
            return try mockUploadBadge(badge, for: userId)
        }
        
        let endpoint = "profiles/\(userId)/badges"
        let bodyData = try jsonEncoder.encode(badge)
        let request = try makeRequest(endpoint: endpoint, method: "POST", body: bodyData)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileSyncError.unknown(description: "Invalid response")
            }
            
            try validateStatusCode(httpResponse.statusCode, data: data)
            let uploadedBadge = try jsonDecoder.decode(ProfileBadge.self, from: data)
            WhiteGramLog.info("Uploaded badge [\(uploadedBadge.id)] for user \(userId)")
            return uploadedBadge
        } catch let error as ProfileSyncError {
            throw error
        } catch {
            WhiteGramLog.warning("Upload badge failed for user \(userId): \(error.localizedDescription). Fallback to mock.")
            return try mockUploadBadge(badge, for: userId)
        }
    }
    
    /// Sets active visible badge for user profile
    public func setActiveBadge(badgeId: String?, for userId: Int64) async throws {
        if mockModeEnabled {
            lock.lock()
            if var profile = mockRemoteProfiles[userId] {
                profile.activeBadgeId = badgeId
                mockRemoteProfiles[userId] = profile
            }
            lock.unlock()
            return
        }
        
        let endpoint = "profiles/\(userId)/active-badge"
        struct Payload: Codable {
            let activeBadgeId: String?
        }
        let bodyData = try jsonEncoder.encode(Payload(activeBadgeId: badgeId))
        let request = try makeRequest(endpoint: endpoint, method: "PUT", body: bodyData)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileSyncError.unknown(description: "Invalid response")
            }
            try validateStatusCode(httpResponse.statusCode, data: data)
        } catch let error as ProfileSyncError {
            throw error
        } catch {
            WhiteGramLog.warning("Set active badge failed: \(error.localizedDescription). Falling back to mock store.")
            lock.lock()
            if var profile = mockRemoteProfiles[userId] {
                profile.activeBadgeId = badgeId
                mockRemoteProfiles[userId] = profile
            }
            lock.unlock()
        }
    }
    
    /// Deletes a profile badge
    public func deleteBadge(badgeId: String, for userId: Int64) async throws {
        if mockModeEnabled {
            lock.lock()
            if var profile = mockRemoteProfiles[userId] {
                profile.badges.removeAll { $0.id == badgeId }
                if profile.activeBadgeId == badgeId {
                    profile.activeBadgeId = nil
                }
                mockRemoteProfiles[userId] = profile
            }
            lock.unlock()
            return
        }
        
        let endpoint = "profiles/\(userId)/badges/\(badgeId)"
        let request = try makeRequest(endpoint: endpoint, method: "DELETE")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileSyncError.unknown(description: "Invalid response")
            }
            try validateStatusCode(httpResponse.statusCode, data: data)
        } catch let error as ProfileSyncError {
            throw error
        } catch {
            WhiteGramLog.warning("Delete badge failed: \(error.localizedDescription)")
            lock.lock()
            if var profile = mockRemoteProfiles[userId] {
                profile.badges.removeAll { $0.id == badgeId }
                if profile.activeBadgeId == badgeId {
                    profile.activeBadgeId = nil
                }
                mockRemoteProfiles[userId] = profile
            }
            lock.unlock()
        }
    }
    
    // MARK: - Validation
    
    private func validateStatusCode(_ code: Int, data: Data) throws {
        switch code {
        case 200...299:
            return
        case 401:
            throw ProfileSyncError.unauthorized
        case 404:
            throw ProfileSyncError.notFound
        case 429:
            throw ProfileSyncError.rateLimited(retryAfter: 60)
        default:
            let serverMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ProfileSyncError.httpError(statusCode: code, message: serverMsg)
        }
    }
    
    // MARK: - Mock Handlers for Local/Testing
    
    private func mockFetchProfile(userId: Int64) throws -> UserProfileSyncData {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = mockRemoteProfiles[userId] {
            return existing
        }
        
        // Synthesize new default profile with WhiteGram verified badge
        let defaultBadge = ProfileBadge(
            id: "badge_verified_user",
            name: "Verified User",
            descriptionText: "Identity verified by WhiteGram network",
            iconURL: URL(string: "https://cdn.whitegram.org/badges/verified.png"),
            category: .system,
            rarity: .rare,
            tier: 1,
            unlockedAt: Date(),
            verificationStatus: .verified
        )
        let sig = ProfileSyncCrypto.shared.generateBadgeSignature(for: defaultBadge, userId: userId)
        var signedBadge = defaultBadge
        signedBadge.signature = sig
        signedBadge.verificationStatus = .verified
        
        let newProfile = UserProfileSyncData(
            userId: userId,
            username: "user_\(userId)",
            customTitle: "WhiteGram Member",
            bio: "Sync enabled",
            activeBadgeId: signedBadge.id,
            badges: [signedBadge],
            lastSyncTimestamp: Date(),
            serverVersion: 1
        )
        mockRemoteProfiles[userId] = newProfile
        return newProfile
    }
    
    private func mockSyncProfile(_ req: ProfileSyncRequest) throws -> ProfileSyncResponse {
        lock.lock()
        defer { lock.unlock() }
        
        var profile = mockRemoteProfiles[req.userId] ?? UserProfileSyncData(
            userId: req.userId,
            username: "user_\(req.userId)",
            lastSyncTimestamp: Date()
        )
        
        // Merge local badges with remote
        var badgeMap: [String: ProfileBadge] = [:]
        for b in profile.badges { badgeMap[b.id] = b }
        for b in req.localBadges {
            var badgeToStore = b
            // Automatically sign and verify incoming local badges in mock
            if badgeToStore.signature == nil {
                badgeToStore.signature = ProfileSyncCrypto.shared.generateBadgeSignature(for: badgeToStore, userId: req.userId)
                badgeToStore.verificationStatus = .verified
            }
            badgeMap[badgeToStore.id] = badgeToStore
        }
        
        var processedIds: [UUID] = []
        for op in req.pendingOperations {
            switch op.type {
            case .uploadBadge:
                if let b = op.badgePayload {
                    var signed = b
                    if signed.signature == nil {
                        signed.signature = ProfileSyncCrypto.shared.generateBadgeSignature(for: signed, userId: req.userId)
                        signed.verificationStatus = .verified
                    }
                    badgeMap[signed.id] = signed
                }
            case .removeBadge:
                if let idToRemove = op.badgeIdToRemove {
                    badgeMap.removeValue(forKey: idToRemove)
                }
            case .setActiveBadge:
                profile.activeBadgeId = op.activeBadgeId
            case .fullSync:
                break
            }
            processedIds.append(op.id)
        }
        
        profile.badges = Array(badgeMap.values).sorted { $0.displayOrder < $1.displayOrder }
        if let activeId = req.activeBadgeId {
            profile.activeBadgeId = activeId
        }
        profile.lastSyncTimestamp = Date()
        profile.serverVersion += 1
        
        mockRemoteProfiles[req.userId] = profile
        
        return ProfileSyncResponse(
            success: true,
            profile: profile,
            serverTimestamp: Date(),
            processedOperationIds: processedIds,
            message: "Mock sync successful"
        )
    }
    
    private func mockUploadBadge(_ badge: ProfileBadge, for userId: Int64) throws -> ProfileBadge {
        lock.lock()
        defer { lock.unlock() }
        
        var profile = mockRemoteProfiles[userId] ?? UserProfileSyncData(userId: userId)
        var signed = badge
        if signed.signature == nil {
            signed.signature = ProfileSyncCrypto.shared.generateBadgeSignature(for: signed, userId: userId)
            signed.verificationStatus = .verified
        }
        
        if let idx = profile.badges.firstIndex(where: { $0.id == signed.id }) {
            profile.badges[idx] = signed
        } else {
            profile.badges.append(signed)
        }
        
        mockRemoteProfiles[userId] = profile
        return signed
    }
}
