//
//  ProfileSyncTests.swift
//  WhiteGramTests
//
//  Created for WhiteGram iOS.
//  Copyright © 2026 WhiteGram. All rights reserved.
//

import XCTest
import Combine
@testable import WhiteGramCore
@testable import ProfileSync

final class ProfileSyncTests: XCTestCase {
    
    private var tempDirectory: URL!
    private var testDiskCache: ProfileDiskCache!
    private var mockNetworkClient: ProfileSyncNetworkClient!
    private var testService: ProfileSyncService!
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
        
        // Create an isolated temporary directory for test cache
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileSyncTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        testDiskCache = ProfileDiskCache(customBaseDirectory: tempDirectory)
        mockNetworkClient = ProfileSyncNetworkClient()
        mockNetworkClient.mockModeEnabled = true
        
        testService = ProfileSyncService(
            configuration: ProfileSyncConfiguration(
                syncInterval: 60.0,
                autoSyncOnReconnect: true
            ),
            diskCache: testDiskCache,
            networkClient: mockNetworkClient,
            cryptoVerifier: ProfileSyncCrypto.shared
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        testService = nil
        testDiskCache = nil
        mockNetworkClient = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }
    
    // MARK: - Model & Rarity Tests
    
    func testBadgeRarityProperties() {
        XCTAssertEqual(BadgeRarity.common.displayName, "Common")
        XCTAssertEqual(BadgeRarity.rare.displayName, "Rare")
        XCTAssertEqual(BadgeRarity.legendary.displayName, "Legendary")
        XCTAssertEqual(BadgeRarity.mythic.displayName, "Mythic")
        
        XCTAssertFalse(BadgeRarity.common.hexColor.isEmpty)
        XCTAssertFalse(BadgeRarity.legendary.hexColor.isEmpty)
        XCTAssertTrue(BadgeRarity.mythic.sortOrder > BadgeRarity.common.sortOrder)
    }
    
    func testProfileBadgeCreation() {
        let badge = ProfileBadge(
            id: "badge_og_hunter",
            name: "OG Hunter",
            descriptionText: "Found critical bugs during WhiteGram alpha",
            category: .achievement,
            rarity: .epic,
            tier: 2,
            unlockedAt: Date(),
            attributes: ["bountyId": "101", "role": "security"]
        )
        
        XCTAssertEqual(badge.id, "badge_og_hunter")
        XCTAssertEqual(badge.category, .achievement)
        XCTAssertEqual(badge.rarity, .epic)
        XCTAssertEqual(badge.tier, 2)
        XCTAssertEqual(badge.attributes["bountyId"], "101")
        XCTAssertFalse(badge.isExpired)
        XCTAssertFalse(badge.isVerified) // unverified because no signature yet
    }
    
    // MARK: - Cryptographic Signatures Tests
    
    func testBadgeCryptographicSignatureVerification() {
        let crypto = ProfileSyncCrypto.shared
        let userId: Int64 = 987654321
        
        var badge = ProfileBadge(
            id: "badge_verified_vip",
            name: "VIP Donor",
            descriptionText: "Generous WhiteGram supporter",
            category: .supporter,
            rarity: .legendary,
            tier: 3,
            unlockedAt: Date(timeIntervalSince1970: 1700000000)
        )
        
        // Generate cryptographic signature
        let sig = crypto.generateBadgeSignature(for: badge, userId: userId)
        badge.signature = sig
        
        // Verify valid signature
        let status = crypto.verifyBadgeSignature(badge, for: userId)
        XCTAssertEqual(status, .verified)
        
        badge.verificationStatus = status
        XCTAssertTrue(badge.isVerified)
    }
    
    func testTamperedBadgeDetection() {
        let crypto = ProfileSyncCrypto.shared
        let userId: Int64 = 987654321
        
        var badge = ProfileBadge(
            id: "badge_verified_vip",
            name: "VIP Donor",
            descriptionText: "Supporter",
            category: .supporter,
            rarity: .common,
            tier: 1,
            unlockedAt: Date(timeIntervalSince1970: 1700000000)
        )
        
        // Sign common tier 1 badge
        let sig = crypto.generateBadgeSignature(for: badge, userId: userId)
        badge.signature = sig
        
        // Tamper with the badge attributes (attempting to elevate to Mythic Tier 5)
        badge.rarity = .mythic
        badge.tier = 5
        
        let status = crypto.verifyBadgeSignature(badge, for: userId)
        XCTAssertEqual(status, .tampered)
        
        badge.verificationStatus = status
        XCTAssertFalse(badge.isVerified)
    }
    
    func testExpiredSignatureDetection() {
        let crypto = ProfileSyncCrypto.shared
        let userId: Int64 = 987654321
        
        let badge = ProfileBadge(
            id: "badge_season_pass",
            name: "Season 1 Pass",
            descriptionText: "Seasonal badge",
            category: .achievement,
            rarity: .rare,
            tier: 1,
            unlockedAt: Date(timeIntervalSince1970: 1600000000)
        )
        
        let expiredDate = Date(timeIntervalSince1970: 1605000000)
        let sig = BadgeVerificationSignature(
            signature: "dummy_sig",
            publicKeyId: ProfileSyncCrypto.defaultDevKeyId,
            algorithm: .hmacSha256,
            signedPayload: crypto.canonicalPayload(for: badge, userId: userId),
            issuedAt: Date(timeIntervalSince1970: 1600000000),
            expiresAt: expiredDate
        )
        
        var expiredBadge = badge
        expiredBadge.signature = sig
        
        let status = crypto.verifyBadgeSignature(expiredBadge, for: userId)
        XCTAssertEqual(status, .expired)
    }
    
    // MARK: - Disk Cache Persistence Tests
    
    func testProfileDiskCachePersistence() throws {
        let userId: Int64 = 11223344
        let badge = ProfileBadge(
            id: "badge_collector",
            name: "Collector",
            descriptionText: "Collected 10 gifts",
            category: .nftGift,
            rarity: .mythic,
            tier: 1
        )
        
        let profile = UserProfileSyncData(
            userId: userId,
            username: "collector_pro",
            customTitle: "Whale",
            bio: "WhiteGram Gifts Collector",
            activeBadgeId: badge.id,
            badges: [badge],
            lastSyncTimestamp: Date(),
            serverVersion: 42
        )
        
        // Save to isolated disk cache
        try testDiskCache.saveProfile(profile)
        
        // Read back from disk cache
        let loaded = testDiskCache.loadProfile(for: userId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.userId, userId)
        XCTAssertEqual(loaded?.username, "collector_pro")
        XCTAssertEqual(loaded?.customTitle, "Whale")
        XCTAssertEqual(loaded?.activeBadgeId, badge.id)
        XCTAssertEqual(loaded?.badges.count, 1)
        XCTAssertEqual(loaded?.badges.first?.id, "badge_collector")
    }
    
    func testOutboxQueueOperations() {
        let userId: Int64 = 556677
        let badge = ProfileBadge(
            id: "badge_outbox_test",
            name: "Offline Badge",
            descriptionText: "Created while offline",
            category: .custom,
            rarity: .rare
        )
        
        let op1 = SyncOperation(
            userId: userId,
            type: .uploadBadge,
            badgePayload: badge
        )
        let op2 = SyncOperation(
            userId: userId,
            type: .setActiveBadge,
            activeBadgeId: badge.id
        )
        
        testDiskCache.enqueueOperation(op1)
        testDiskCache.enqueueOperation(op2)
        
        var pending = testDiskCache.getPendingOperations()
        XCTAssertEqual(pending.count, 2)
        
        // Remove first operation
        testDiskCache.removeOperation(id: op1.id)
        pending = testDiskCache.getPendingOperations()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, op2.id)
        
        // Clear outbox
        testDiskCache.clearOutbox()
        XCTAssertEqual(testDiskCache.getPendingOperations().count, 0)
    }
    
    // MARK: - Service Orchestration Tests
    
    func testProfileSyncServiceFetchAndCache() async throws {
        let peerId = PeerId(777000)
        
        // Fetch profile
        let profile = try await testService.fetchProfile(for: peerId, forceRefresh: true)
        XCTAssertEqual(profile.userId, 777000)
        XCTAssertFalse(profile.badges.isEmpty)
        
        // Check immediate synchronous read from local cache
        let cached = testService.cachedProfile(for: peerId)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.userId, 777000)
        XCTAssertEqual(cached?.badges.count, profile.badges.count)
    }
    
    func testUploadBadgeAndVerification() async throws {
        let userId: Int64 = 888123
        testService.setCurrentUser(id: userId)
        
        let newBadge = ProfileBadge(
            id: "badge_crafting_master",
            name: "Crafting Master",
            descriptionText: "Successfully upgraded 100 items",
            category: .achievement,
            rarity: .legendary,
            tier: 2
        )
        
        // Upload badge
        let uploaded = try await testService.uploadBadge(newBadge, for: userId)
        XCTAssertEqual(uploaded.id, newBadge.id)
        XCTAssertTrue(uploaded.isVerified)
        
        // Set as active badge
        try await testService.setActiveBadge(badgeId: uploaded.id, for: userId)
        
        // Verify local cached profile reflects active badge
        let cached = testService.cachedProfile(for: userId)
        XCTAssertEqual(cached?.activeBadgeId, uploaded.id)
        XCTAssertTrue(cached?.badges.contains(where: { $0.id == uploaded.id }) ?? false)
    }
    
    func testSilentOutboxFlush() async throws {
        let userId: Int64 = 999333
        
        // Manually enqueue outbox operation
        let badge = ProfileBadge(
            id: "badge_offline_sync",
            name: "Offline Queued",
            descriptionText: "Pending sync",
            category: .custom,
            rarity: .uncommon
        )
        let op = SyncOperation(
            userId: userId,
            type: .uploadBadge,
            badgePayload: badge
        )
        testDiskCache.enqueueOperation(op)
        XCTAssertEqual(testDiskCache.getPendingOperations().count, 1)
        
        // Flush outbox
        let flushedCount = try await testService.flushOutbox()
        XCTAssertEqual(flushedCount, 1)
        XCTAssertEqual(testDiskCache.getPendingOperations().count, 0)
    }
}
