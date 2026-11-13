//
//  ProfileSyncService.swift
//  WhiteGram
//
//  Created for WhiteGram iOS.
//  Copyright © 2026 WhiteGram. All rights reserved.
//

import Foundation
import Network
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
import WhiteGramCore

// MARK: - Configuration

public struct ProfileSyncConfiguration: Sendable {
    public var baseURL: URL
    public var syncInterval: TimeInterval
    public var maxRetryAttempts: Int
    public var cacheMaxAge: TimeInterval
    public var autoSyncOnReconnect: Bool
    public var backgroundTaskIdentifier: String
    public var authTokenProvider: (@Sendable () -> String?)?
    
    public init(
        baseURL: URL = URL(string: "https://api.whitegram.org/v1/profile")!,
        syncInterval: TimeInterval = 300.0, // 5 minutes
        maxRetryAttempts: Int = 5,
        cacheMaxAge: TimeInterval = 86400 * 7, // 7 days
        autoSyncOnReconnect: Bool = true,
        backgroundTaskIdentifier: String = "org.whitegram.profilesync.refresh",
        authTokenProvider: (@Sendable () -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.syncInterval = syncInterval
        self.maxRetryAttempts = maxRetryAttempts
        self.cacheMaxAge = cacheMaxAge
        self.autoSyncOnReconnect = autoSyncOnReconnect
        self.backgroundTaskIdentifier = backgroundTaskIdentifier
        self.authTokenProvider = authTokenProvider
    }
}

// MARK: - ProfileSyncService

public final class ProfileSyncService: @unchecked Sendable {
    public static let shared = ProfileSyncService()
    
    // MARK: - Notifications
    public static let profileDidUpdateNotification = Notification.Name("ProfileSyncService.profileDidUpdate")
    public static let badgeStatusDidUpdateNotification = Notification.Name("ProfileSyncService.badgeStatusDidUpdate")
    public static let syncStateDidChangeNotification = Notification.Name("ProfileSyncService.syncStateDidChange")
    
    // MARK: - Dependencies & Core Engines
    private let networkClient: ProfileSyncNetworkClient
    private let diskCache: ProfileDiskCache
    private let cryptoVerifier: ProfileSyncCrypto
    
    // Background Network Monitoring & Scheduling
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "org.whitegram.profilesync.networkmonitor", qos: .utility)
    private let syncQueue = DispatchQueue(label: "org.whitegram.profilesync.syncqueue", qos: .utility)
    private var syncTimer: DispatchSourceTimer?
    
    // Concurrency & State Locks
    private let lock = NSRecursiveLock()
    private var inFlightTasks: [Int64: Task<UserProfileSyncData, Error>] = [:]
    
    // Reactive Publishers
    private let stateSubject = CurrentValueSubject<ProfileSyncState, Never>(.idle)
    public var statePublisher: AnyPublisher<ProfileSyncState, Never> {
        return stateSubject.eraseToAnyPublisher()
    }
    
    private let profileSubjectsLock = NSLock()
    private var profileSubjects: [Int64: CurrentValueSubject<UserProfileSyncData?, Never>] = [:]
    
    // Public State
    public var configuration: ProfileSyncConfiguration {
        didSet {
            networkClient.baseURL = configuration.baseURL
            networkClient.authTokenProvider = configuration.authTokenProvider
            diskCache.maxCacheAge = configuration.cacheMaxAge
            restartPeriodicTimer()
        }
    }
    
    public private(set) var isOnline: Bool = true
    public private(set) var currentUserId: Int64?
    public var currentPeerId: PeerId? {
        guard let id = currentUserId else { return nil }
        return PeerId(id)
    }
    
    public var currentState: ProfileSyncState {
        return stateSubject.value
    }
    
    // MARK: - Initialization
    
    public init(
        configuration: ProfileSyncConfiguration = ProfileSyncConfiguration(),
        diskCache: ProfileDiskCache = .shared,
        networkClient: ProfileSyncNetworkClient? = nil,
        cryptoVerifier: ProfileSyncCrypto = .shared
    ) {
        self.configuration = configuration
        self.diskCache = diskCache
        self.cryptoVerifier = cryptoVerifier
        
        let client = networkClient ?? ProfileSyncNetworkClient(baseURL: configuration.baseURL)
        client.authTokenProvider = configuration.authTokenProvider
        self.networkClient = client
        
        self.pathMonitor = NWPathMonitor()
        
        // Start Silent Background Synchronization immediately by default
        setupNetworkMonitoring()
        startPeriodicBackgroundTimer()
        setupLifecycleObservers()
        registerBackgroundTasksIfAvailable()
        
        WhiteGramLog.info("ProfileSyncService initialized. Silent background synchronization running.")
    }
    
    deinit {
        pathMonitor.cancel()
        syncTimer?.cancel()
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        #endif
    }
    
    // MARK: - Current User Setup
    
    public func setCurrentUser(id: Int64) {
        lock.lock()
        self.currentUserId = id
        lock.unlock()
        
        WhiteGramLog.info("Current user set to \(id). Performing initial silent background sync.")
        Task {
            await self.silentBackgroundSync(for: id)
        }
    }
    
    public func setCurrentUser(peerId: PeerId) {
        setCurrentUser(id: peerId.id)
    }
    
    // MARK: - Silent Background Sync Engine (No Manual Toggles)
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isConnected = (path.status == .satisfied)
            
            self.lock.lock()
            let statusChanged = (self.isOnline != isConnected)
            self.isOnline = isConnected
            let activeUser = self.currentUserId
            self.lock.unlock()
            
            if isConnected {
                WhiteGramLog.info("Network satisfied. Connected via \(path.isExpensive ? "Cellular" : "Wi-Fi/LAN").")
                if statusChanged && self.configuration.autoSyncOnReconnect {
                    // Automatically & silently flush queued offline outbox and perform sync
                    Task {
                        await self.flushOutboxAndSyncSilently(userId: activeUser)
                    }
                }
            } else {
                WhiteGramLog.warning("Network connection lost. Transitioned to offline persistent cache mode.")
                self.updateState(.offline)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    private func startPeriodicBackgroundTimer() {
        syncTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: syncQueue)
        let interval = configuration.syncInterval
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(10))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let userId = self.currentUserId
            let online = self.isOnline
            self.lock.unlock()
            
            guard online, let uid = userId else { return }
            WhiteGramLog.debug("Silent background periodic tick. Syncing profile for user \(uid).")
            Task {
                await self.silentBackgroundSync(for: uid)
            }
        }
        timer.resume()
        self.syncTimer = timer
    }
    
    private func restartPeriodicTimer() {
        startPeriodicBackgroundTimer()
    }
    
    private func setupLifecycleObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            WhiteGramLog.debug("App became active. Triggering silent incremental sync.")
            Task {
                if let userId = self.currentUserId {
                    await self.silentBackgroundSync(for: userId)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            WhiteGramLog.debug("App entered background. Purging stale disk caches.")
            self.syncQueue.async {
                self.diskCache.purgeExpiredProfiles()
            }
        }
        #endif
    }
    
    private func registerBackgroundTasksIfAvailable() {
        #if canImport(BackgroundTasks) && (os(iOS) || targetEnvironment(macCatalyst))
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: configuration.backgroundTaskIdentifier,
                using: nil
            ) { [weak self] task in
                guard let appRefreshTask = task as? BGAppRefreshTask else { return }
                self?.handleAppRefreshTask(appRefreshTask)
            }
        }
        #endif
    }
    
    #if canImport(BackgroundTasks) && (os(iOS) || targetEnvironment(macCatalyst))
    @available(iOS 13.0, *)
    private func handleAppRefreshTask(_ task: BGAppRefreshTask) {
        scheduleNextAppRefresh()
        
        task.expirationHandler = {
            WhiteGramLog.warning("Background app refresh task expired.")
        }
        
        Task {
            if let userId = self.currentUserId {
                await self.silentBackgroundSync(for: userId)
            }
            task.setTaskCompleted(success: true)
        }
    }
    
    @available(iOS 13.0, *)
    public func scheduleNextAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: configuration.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: configuration.syncInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
            WhiteGramLog.debug("Scheduled next background refresh task.")
        } catch {
            WhiteGramLog.debug("Could not schedule background refresh: \(error.localizedDescription)")
        }
    }
    #endif
    
    // MARK: - State Management
    
    private func updateState(_ state: ProfileSyncState) {
        lock.lock()
        stateSubject.send(state)
        lock.unlock()
        
        NotificationCenter.default.post(
            name: Self.syncStateDidChangeNotification,
            object: self,
            userInfo: ["state": state]
        )
    }
    
    // MARK: - Public Fetch & Sync APIs
    
    /// Synchronously retrieves profile from in-memory or offline disk cache without network delay
    public func cachedProfile(for peerId: PeerId) -> UserProfileSyncData? {
        return diskCache.loadProfile(for: peerId.id)
    }
    
    public func cachedProfile(for userId: Int64) -> UserProfileSyncData? {
        return diskCache.loadProfile(for: userId)
    }
    
    /// Fetches profile with stale-while-revalidate pattern:
    /// returns cached data if fresh, or fetches remotely and validates cryptographic signatures.
    @discardableResult
    public func fetchProfile(for peerId: PeerId, forceRefresh: Bool = false) async throws -> UserProfileSyncData {
        return try await fetchProfile(for: peerId.id, forceRefresh: forceRefresh)
    }
    
    @discardableResult
    public func fetchProfile(for userId: Int64, forceRefresh: Bool = false) async throws -> UserProfileSyncData {
        // 1. Check offline disk cache
        let cached = diskCache.loadProfile(for: userId)
        if !forceRefresh, let cached = cached {
            let cacheAge = Date().timeIntervalSince(cached.lastSyncTimestamp)
            if cacheAge < configuration.syncInterval {
                return cached
            }
        }
        
        // 2. Coalesce concurrent in-flight requests for the same user
        lock.lock()
        if let ongoing = inFlightTasks[userId] {
            lock.unlock()
            return try await ongoing.value
        }
        
        let task = Task<UserProfileSyncData, Error> { [weak self] in
            guard let self = self else { throw ProfileSyncError.cancelled }
            return try await self.performFetchProfile(for: userId)
        }
        inFlightTasks[userId] = task
        lock.unlock()
        
        defer {
            lock.lock()
            inFlightTasks.removeValue(forKey: userId)
            lock.unlock()
        }
        
        return try await task.value
    }
    
    private func performFetchProfile(for userId: Int64) async throws -> UserProfileSyncData {
        updateState(.syncing(userId: userId))
        
        do {
            var profile = try await networkClient.fetchProfile(for: userId)
            
            // Verify signatures on all incoming badges
            profile.badges = verifyBadges(profile.badges, for: userId)
            profile.lastSyncTimestamp = Date()
            
            // Store to offline persistent disk cache
            try diskCache.saveProfile(profile)
            
            notifyProfileUpdated(profile)
            updateState(.synced(lastSync: Date()))
            return profile
        } catch {
            WhiteGramLog.warning("Remote profile fetch failed for user \(userId): \(error.localizedDescription). Falling back to disk cache.")
            if let cached = diskCache.loadProfile(for: userId) {
                updateState(.synced(lastSync: cached.lastSyncTimestamp))
                return cached
            }
            updateState(.failed(reason: error.localizedDescription))
            throw error
        }
    }
    
    // MARK: - Badge Upload & Management
    
    /// Uploads or claims a profile badge.
    /// If offline, saves to disk cache and queues to persistent outbox for silent background sync.
    @discardableResult
    public func uploadBadge(_ badge: ProfileBadge, for peerId: PeerId) async throws -> ProfileBadge {
        return try await uploadBadge(badge, for: peerId.id)
    }
    
    @discardableResult
    public func uploadBadge(_ badge: ProfileBadge, for userId: Int64) async throws -> ProfileBadge {
        var badgeToUpload = badge
        
        // Ensure signature exists or generate development signature
        if badgeToUpload.signature == nil {
            badgeToUpload.signature = cryptoVerifier.generateBadgeSignature(for: badgeToUpload, userId: userId)
            badgeToUpload.verificationStatus = .verified
        } else {
            badgeToUpload.verificationStatus = cryptoVerifier.verifyBadgeSignature(badgeToUpload, for: userId)
        }
        
        // 1. Optimistically update local disk cache
        var profile = diskCache.loadProfile(for: userId) ?? UserProfileSyncData(userId: userId)
        if let idx = profile.badges.firstIndex(where: { $0.id == badgeToUpload.id }) {
            profile.badges[idx] = badgeToUpload
        } else {
            profile.badges.append(badgeToUpload)
        }
        profile.lastSyncTimestamp = Date()
        try? diskCache.saveProfile(profile)
        notifyProfileUpdated(profile)
        
        // 2. If offline, enqueue operation to persistent disk outbox
        lock.lock()
        let online = isOnline
        lock.unlock()
        
        if !online {
            WhiteGramLog.info("Device offline. Queuing badge upload [\(badgeToUpload.id)] to outbox.")
            let op = SyncOperation(
                userId: userId,
                type: .uploadBadge,
                badgePayload: badgeToUpload
            )
            diskCache.enqueueOperation(op)
            return badgeToUpload
        }
        
        // 3. Attempt direct network upload
        do {
            let uploaded = try await networkClient.uploadBadge(badgeToUpload, for: userId)
            WhiteGramLog.info("Badge [\(badgeToUpload.id)] uploaded successfully to backend.")
            return uploaded
        } catch {
            WhiteGramLog.warning("Direct upload failed. Enqueueing to persistent outbox: \(error.localizedDescription)")
            let op = SyncOperation(
                userId: userId,
                type: .uploadBadge,
                badgePayload: badgeToUpload
            )
            diskCache.enqueueOperation(op)
            return badgeToUpload
        }
    }
    
    /// Sets active visible badge for a user profile
    public func setActiveBadge(badgeId: String?, for peerId: PeerId) async throws {
        try await setActiveBadge(badgeId: badgeId, for: peerId.id)
    }
    
    public func setActiveBadge(badgeId: String?, for userId: Int64) async throws {
        // 1. Optimistically update local cache
        if var profile = diskCache.loadProfile(for: userId) {
            profile.activeBadgeId = badgeId
            try? diskCache.saveProfile(profile)
            notifyProfileUpdated(profile)
        }
        
        lock.lock()
        let online = isOnline
        lock.unlock()
        
        if !online {
            let op = SyncOperation(
                userId: userId,
                type: .setActiveBadge,
                activeBadgeId: badgeId
            )
            diskCache.enqueueOperation(op)
            return
        }
        
        do {
            try await networkClient.setActiveBadge(badgeId: badgeId, for: userId)
        } catch {
            let op = SyncOperation(
                userId: userId,
                type: .setActiveBadge,
                activeBadgeId: badgeId
            )
            diskCache.enqueueOperation(op)
        }
    }
    
    /// Removes a badge from user profile
    public func removeBadge(badgeId: String, for peerId: PeerId) async throws {
        try await removeBadge(badgeId: badgeId, for: peerId.id)
    }
    
    public func removeBadge(badgeId: String, for userId: Int64) async throws {
        // Optimistically update local cache
        if var profile = diskCache.loadProfile(for: userId) {
            profile.badges.removeAll { $0.id == badgeId }
            if profile.activeBadgeId == badgeId {
                profile.activeBadgeId = nil
            }
            try? diskCache.saveProfile(profile)
            notifyProfileUpdated(profile)
        }
        
        lock.lock()
        let online = isOnline
        lock.unlock()
        
        if !online {
            let op = SyncOperation(
                userId: userId,
                type: .removeBadge,
                badgeIdToRemove: badgeId
            )
            diskCache.enqueueOperation(op)
            return
        }
        
        do {
            try await networkClient.deleteBadge(badgeId: badgeId, for: userId)
        } catch {
            let op = SyncOperation(
                userId: userId,
                type: .removeBadge,
                badgeIdToRemove: badgeId
            )
            diskCache.enqueueOperation(op)
        }
    }
    
    // MARK: - Outbox Flush & Silent Sync
    
    /// Flushes queued outbox operations to backend and runs full sync silently
    @discardableResult
    public func flushOutbox() async throws -> Int {
        let pending = diskCache.getPendingOperations()
        guard !pending.isEmpty else { return 0 }
        
        WhiteGramLog.info("Flushing \(pending.count) queued outbox operations.")
        var successCount = 0
        var completedIds: [UUID] = []
        
        for var op in pending {
            if op.retryCount >= configuration.maxRetryAttempts {
                WhiteGramLog.warning("Dropping operation \(op.id) after \(op.retryCount) failed attempts.")
                completedIds.append(op.id)
                continue
            }
            
            do {
                switch op.type {
                case .uploadBadge:
                    if let badge = op.badgePayload {
                        _ = try await networkClient.uploadBadge(badge, for: op.userId)
                    }
                case .setActiveBadge:
                    try await networkClient.setActiveBadge(badgeId: op.activeBadgeId, for: op.userId)
                case .removeBadge:
                    if let idToRemove = op.badgeIdToRemove {
                        try await networkClient.deleteBadge(badgeId: idToRemove, for: op.userId)
                    }
                case .fullSync:
                    _ = try await performFetchProfile(for: op.userId)
                }
                
                completedIds.append(op.id)
                successCount += 1
            } catch {
                op.retryCount += 1
                op.lastAttemptAt = Date()
                diskCache.updateOperation(op)
                WhiteGramLog.error("Error executing outbox operation \(op.id): \(error.localizedDescription)")
            }
        }
        
        diskCache.removeOperations(ids: completedIds)
        return successCount
    }
    
    private func flushOutboxAndSyncSilently(userId: Int64?) async {
        do {
            _ = try await flushOutbox()
            if let uid = userId {
                await silentBackgroundSync(for: uid)
            }
        } catch {
            WhiteGramLog.error("Silent flush failed: \(error.localizedDescription)")
        }
    }
    
    private func silentBackgroundSync(for userId: Int64) async {
        do {
            let localProfile = diskCache.loadProfile(for: userId)
            let pending = diskCache.getPendingOperations().filter { $0.userId == userId }
            
            let syncReq = ProfileSyncRequest(
                userId: userId,
                clientVersion: WhiteGramVersion.string,
                deviceId: WhiteGramStorage.shared.get(forKey: "device_id") ?? UUID().uuidString,
                lastSyncTimestamp: localProfile?.lastSyncTimestamp ?? Date.distantPast,
                localBadges: localProfile?.badges ?? [],
                activeBadgeId: localProfile?.activeBadgeId,
                pendingOperations: pending
            )
            
            let syncResponse = try await networkClient.syncProfile(request: syncReq)
            
            var verifiedProfile = syncResponse.profile
            verifiedProfile.badges = verifyBadges(verifiedProfile.badges, for: userId)
            verifiedProfile.lastSyncTimestamp = Date()
            
            try diskCache.saveProfile(verifiedProfile)
            diskCache.removeOperations(ids: syncResponse.processedOperationIds)
            
            notifyProfileUpdated(verifiedProfile)
            updateState(.synced(lastSync: Date()))
            WhiteGramLog.info("Silent background sync completed successfully for user \(userId).")
        } catch {
            WhiteGramLog.warning("Silent background sync encountered non-fatal error: \(error.localizedDescription)")
            updateState(.failed(reason: error.localizedDescription))
        }
    }
    
    // MARK: - Verification Signatures Helper
    
    public func verifyBadge(_ badge: ProfileBadge, for userId: Int64) -> VerificationStatus {
        return cryptoVerifier.verifyBadgeSignature(badge, for: userId)
    }
    
    public func verifyBadge(_ badge: ProfileBadge, for peerId: PeerId) -> VerificationStatus {
        return cryptoVerifier.verifyBadgeSignature(badge, for: peerId.id)
    }
    
    private func verifyBadges(_ badges: [ProfileBadge], for userId: Int64) -> [ProfileBadge] {
        return badges.map { badge in
            var verified = badge
            let status = cryptoVerifier.verifyBadgeSignature(badge, for: userId)
            verified.verificationStatus = status
            if status != badge.verificationStatus {
                NotificationCenter.default.post(
                    name: Self.badgeStatusDidUpdateNotification,
                    object: self,
                    userInfo: ["badgeId": badge.id, "status": status]
                )
            }
            return verified
        }
    }
    
    // MARK: - Reactive Combine Stream
    
    public func profilePublisher(for userId: Int64) -> AnyPublisher<UserProfileSyncData, Never> {
        profileSubjectsLock.lock()
        defer { profileSubjectsLock.unlock() }
        
        let subject: CurrentValueSubject<UserProfileSyncData?, Never>
        if let existing = profileSubjects[userId] {
            subject = existing
        } else {
            let initial = diskCache.loadProfile(for: userId)
            let newSubject = CurrentValueSubject<UserProfileSyncData?, Never>(initial)
            profileSubjects[userId] = newSubject
            subject = newSubject
        }
        
        return subject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public func profilePublisher(for peerId: PeerId) -> AnyPublisher<UserProfileSyncData, Never> {
        return profilePublisher(for: peerId.id)
    }
    
    private func notifyProfileUpdated(_ profile: UserProfileSyncData) {
        // Update Combine subject
        profileSubjectsLock.lock()
        if let subject = profileSubjects[profile.userId] {
            subject.send(profile)
        } else {
            profileSubjects[profile.userId] = CurrentValueSubject(profile)
        }
        profileSubjectsLock.unlock()
        
        // Post NotificationCenter broadcast
        NotificationCenter.default.post(
            name: Self.profileDidUpdateNotification,
            object: self,
            userInfo: [
                "userId": profile.userId,
                "peerId": profile.peerId,
                "profile": profile
            ]
        )
    }
}
