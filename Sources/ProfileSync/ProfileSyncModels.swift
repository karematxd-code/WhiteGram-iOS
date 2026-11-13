//
//  ProfileSyncModels.swift
//  WhiteGram
//
//  Created for WhiteGram iOS.
//  Copyright © 2026 WhiteGram. All rights reserved.
//

import Foundation
import WhiteGramCore

// MARK: - Badge Rarity

public enum BadgeRarity: String, Codable, CaseIterable, Sendable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case mythic = "mythic"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        case .mythic: return "Mythic"
        case .custom: return "Custom"
        }
    }
    
    public var hexColor: String {
        switch self {
        case .common: return "#8E8E93"
        case .uncommon: return "#34C759"
        case .rare: return "#007AFF"
        case .epic: return "#AF52DE"
        case .legendary: return "#FF9500"
        case .mythic: return "#FF2D55"
        case .custom: return "#5856D6"
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        case .mythic: return 5
        case .custom: return 6
        }
    }
}

// MARK: - Badge Category

public enum BadgeCategory: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case achievement = "achievement"
    case nftGift = "nft_gift"
    case supporter = "supporter"
    case developer = "developer"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .system: return "Official"
        case .achievement: return "Achievement"
        case .nftGift: return "NFT Gift"
        case .supporter: return "Supporter"
        case .developer: return "Developer"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Signature Algorithm

public enum SignatureAlgorithm: String, Codable, Sendable {
    case ed25519 = "Ed25519"
    case ecdsaP256 = "ECDSA_P256_SHA256"
    case hmacSha256 = "HMAC_SHA256"
}

// MARK: - Verification Status

public enum VerificationStatus: String, Codable, Sendable {
    case verified = "verified"
    case unverified = "unverified"
    case expired = "expired"
    case tampered = "tampered"
    case signatureMissing = "signature_missing"
    case revoked = "revoked"
    case serverUnreachable = "server_unreachable"
    
    public var isValid: Bool {
        return self == .verified
    }
    
    public var displayText: String {
        switch self {
        case .verified: return "Cryptographically Verified"
        case .unverified: return "Unverified"
        case .expired: return "Signature Expired"
        case .tampered: return "Verification Failed (Tampered)"
        case .signatureMissing: return "Missing Signature"
        case .revoked: return "Revoked by Issuer"
        case .serverUnreachable: return "Verification Offline"
        }
    }
}

// MARK: - Badge Verification Signature

public struct BadgeVerificationSignature: Codable, Equatable, Hashable, Sendable {
    public let signature: String
    public let publicKeyId: String
    public let algorithm: SignatureAlgorithm
    public let signedPayload: String
    public let issuedAt: Date
    public let expiresAt: Date?
    public let issuer: String
    
    public init(
        signature: String,
        publicKeyId: String,
        algorithm: SignatureAlgorithm,
        signedPayload: String,
        issuedAt: Date,
        expiresAt: Date? = nil,
        issuer: String = "org.whitegram.auth"
    ) {
        self.signature = signature
        self.publicKeyId = publicKeyId
        self.algorithm = algorithm
        self.signedPayload = signedPayload
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.issuer = issuer
    }
}

// MARK: - Profile Badge

public struct ProfileBadge: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var descriptionText: String
    public var iconURL: URL?
    public var category: BadgeCategory
    public var rarity: BadgeRarity
    public var tier: Int
    public let unlockedAt: Date
    public var expiresAt: Date?
    public var attributes: [String: String]
    public var signature: BadgeVerificationSignature?
    public var verificationStatus: VerificationStatus
    public var displayOrder: Int
    
    public var isExpired: Bool {
        if let expiresAt = expiresAt {
            return expiresAt < Date()
        }
        return false
    }
    
    public var isVerified: Bool {
        return verificationStatus == .verified && !isExpired
    }
    
    public init(
        id: String,
        name: String,
        descriptionText: String,
        iconURL: URL? = nil,
        category: BadgeCategory = .system,
        rarity: BadgeRarity = .common,
        tier: Int = 1,
        unlockedAt: Date = Date(),
        expiresAt: Date? = nil,
        attributes: [String: String] = [:],
        signature: BadgeVerificationSignature? = nil,
        verificationStatus: VerificationStatus = .unverified,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.iconURL = iconURL
        self.category = category
        self.rarity = rarity
        self.tier = tier
        self.unlockedAt = unlockedAt
        self.expiresAt = expiresAt
        self.attributes = attributes
        self.signature = signature
        self.verificationStatus = verificationStatus
        self.displayOrder = displayOrder
    }
}

// MARK: - User Profile Sync Data

public struct UserProfileSyncData: Codable, Equatable, Sendable {
    public let userId: Int64
    public var username: String?
    public var customTitle: String?
    public var bio: String?
    public var activeBadgeId: String?
    public var badges: [ProfileBadge]
    public var lastSyncTimestamp: Date
    public var serverVersion: Int64
    public var profileSignature: BadgeVerificationSignature?
    
    public var peerId: PeerId {
        return PeerId(userId)
    }
    
    public var activeBadge: ProfileBadge? {
        guard let activeBadgeId = activeBadgeId else { return nil }
        return badges.first { $0.id == activeBadgeId }
    }
    
    public var verifiedBadges: [ProfileBadge] {
        return badges.filter { $0.isVerified }
    }
    
    public init(
        userId: Int64,
        username: String? = nil,
        customTitle: String? = nil,
        bio: String? = nil,
        activeBadgeId: String? = nil,
        badges: [ProfileBadge] = [],
        lastSyncTimestamp: Date = Date(),
        serverVersion: Int64 = 1,
        profileSignature: BadgeVerificationSignature? = nil
    ) {
        self.userId = userId
        self.username = username
        self.customTitle = customTitle
        self.bio = bio
        self.activeBadgeId = activeBadgeId
        self.badges = badges
        self.lastSyncTimestamp = lastSyncTimestamp
        self.serverVersion = serverVersion
        self.profileSignature = profileSignature
    }
    
    public func badge(with id: String) -> ProfileBadge? {
        return badges.first { $0.id == id }
    }
}

// MARK: - Outbox Sync Operations

public enum SyncOperationType: String, Codable, Sendable {
    case uploadBadge = "upload_badge"
    case removeBadge = "remove_badge"
    case setActiveBadge = "set_active_badge"
    case fullSync = "full_sync"
}

public struct SyncOperation: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let userId: Int64
    public let type: SyncOperationType
    public let badgePayload: ProfileBadge?
    public let activeBadgeId: String?
    public let badgeIdToRemove: String?
    public let queuedAt: Date
    public var retryCount: Int
    public var lastAttemptAt: Date?
    
    public init(
        id: UUID = UUID(),
        userId: Int64,
        type: SyncOperationType,
        badgePayload: ProfileBadge? = nil,
        activeBadgeId: String? = nil,
        badgeIdToRemove: String? = nil,
        queuedAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.badgePayload = badgePayload
        self.activeBadgeId = activeBadgeId
        self.badgeIdToRemove = badgeIdToRemove
        self.queuedAt = queuedAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
    }
}

// MARK: - Profile Sync State

public enum ProfileSyncState: Equatable, Sendable {
    case idle
    case syncing(userId: Int64)
    case offline
    case synced(lastSync: Date)
    case failed(reason: String)
}

// MARK: - Profile Sync Errors

public enum ProfileSyncError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case httpError(statusCode: Int, message: String)
    case decodingFailed(reason: String)
    case encodingFailed(reason: String)
    case invalidSignature(reason: String)
    case cacheError(reason: String)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case notFound
    case cancelled
    case unknown(description: String)
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable. Queued for silent background synchronization."
        case .httpError(let code, let msg):
            return "Profile service HTTP error \(code): \(msg)"
        case .decodingFailed(let reason):
            return "Failed to decode profile response: \(reason)"
        case .encodingFailed(let reason):
            return "Failed to encode profile payload: \(reason)"
        case .invalidSignature(let reason):
            return "Cryptographic badge verification failed: \(reason)"
        case .cacheError(let reason):
            return "Persistent disk cache error: \(reason)"
        case .unauthorized:
            return "Unauthorized profile service request."
        case .rateLimited(let interval):
            let waitMsg = interval.map { " Retry after \(Int($0))s." } ?? ""
            return "Rate limit exceeded.\(waitMsg)"
        case .notFound:
            return "Profile not found on backend."
        case .cancelled:
            return "Profile sync operation was cancelled."
        case .unknown(let desc):
            return "Profile sync error: \(desc)"
        }
    }
}

// MARK: - REST API Request & Response Models

public struct ProfileSyncRequest: Codable, Sendable {
    public let userId: Int64
    public let clientVersion: String
    public let deviceId: String
    public let lastSyncTimestamp: Date
    public let localBadges: [ProfileBadge]
    public let activeBadgeId: String?
    public let pendingOperations: [SyncOperation]
    
    public init(
        userId: Int64,
        clientVersion: String,
        deviceId: String,
        lastSyncTimestamp: Date,
        localBadges: [ProfileBadge],
        activeBadgeId: String?,
        pendingOperations: [SyncOperation] = []
    ) {
        self.userId = userId
        self.clientVersion = clientVersion
        self.deviceId = deviceId
        self.lastSyncTimestamp = lastSyncTimestamp
        self.localBadges = localBadges
        self.activeBadgeId = activeBadgeId
        self.pendingOperations = pendingOperations
    }
}

public struct ProfileSyncResponse: Codable, Sendable {
    public let success: Bool
    public let profile: UserProfileSyncData
    public let serverTimestamp: Date
    public let processedOperationIds: [UUID]
    public let message: String?
    
    public init(
        success: Bool,
        profile: UserProfileSyncData,
        serverTimestamp: Date = Date(),
        processedOperationIds: [UUID] = [],
        message: String? = nil
    ) {
        self.success = success
        self.profile = profile
        self.serverTimestamp = serverTimestamp
        self.processedOperationIds = processedOperationIds
        self.message = message
    }
}

public struct RemoteVerificationResponse: Codable, Sendable {
    public let isVerified: Bool
    public let status: VerificationStatus
    public let badgeId: String
    public let issuer: String
    public let verifiedAt: Date
    public let details: String?
    
    public init(
        isVerified: Bool,
        status: VerificationStatus,
        badgeId: String,
        issuer: String,
        verifiedAt: Date = Date(),
        details: String? = nil
    ) {
        self.isVerified = isVerified
        self.status = status
        self.badgeId = badgeId
        self.issuer = issuer
        self.verifiedAt = verifiedAt
        self.details = details
    }
}
