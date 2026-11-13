import Foundation
import WhiteGramCore

public enum GiftStorageError: LocalizedError {
    case giftNotFound
    case notOwnedByUser
    case invalidRecipient
    case cannotTransferToSelf
    case craftFailed
    
    public var errorDescription: String? {
        switch self {
        case .giftNotFound:
            return "Gift was not found in the repository."
        case .notOwnedByUser:
            return "You do not own this gift."
        case .invalidRecipient:
            return "Invalid recipient user ID or username specified."
        case .cannotTransferToSelf:
            return "Cannot transfer a gift to yourself."
        case .craftFailed:
            return "Crafting attempt failed."
        }
    }
}

public final class GiftStorage {
    public static let shared = GiftStorage()
    
    public static let didUpdateGiftsNotification = Notification.Name("WhiteGramGiftsDidUpdate")
    public static let didTransferGiftNotification = Notification.Name("WhiteGramGiftTransferred")
    
    private let storageKey = "whitegram_stored_gifts_v1"
    private let filename = "gifts_inventory.json"
    private let lock = NSRecursiveLock()
    
    private var cache: [String: WhiteGramGift] = [:]
    private var isLoaded: Bool = false
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Persistence & Loading
    
    public func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        
        if let stored: [WhiteGramGift] = WhiteGramStorage.shared.load([WhiteGramGift].self, from: filename) {
            self.cache = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
            self.isLoaded = true
            WhiteGramLog.info("GiftStorage: Loaded \(self.cache.count) gifts from disk cache.")
        } else {
            self.cache = [:]
            self.isLoaded = true
            WhiteGramLog.info("GiftStorage: No existing gift storage found on disk; starting fresh.")
        }
    }
    
    public func saveToDisk() {
        lock.lock()
        defer { lock.unlock() }
        
        let giftArray = Array(cache.values)
        do {
            try WhiteGramStorage.shared.save(giftArray, to: filename)
            WhiteGramLog.debug("GiftStorage: Saved \(giftArray.count) gifts to disk.")
            NotificationCenter.default.post(name: GiftStorage.didUpdateGiftsNotification, object: self)
        } catch {
            WhiteGramLog.error("GiftStorage: Failed to save gifts to disk: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mock Initializer
    
    public func seedInitialDataIfNeeded(for userId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        
        let owned = getGifts(for: userId)
        if owned.isEmpty {
            let mockGifts = WhiteGramGift.mockUserCollection(userId: userId)
            for gift in mockGifts {
                cache[gift.id] = gift
            }
            saveToDisk()
            WhiteGramLog.info("GiftStorage: Seeded \(mockGifts.count) mock gifts for user \(userId).")
        }
    }
    
    // MARK: - Query Methods
    
    public func allGifts() -> [WhiteGramGift] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cache.values)
    }
    
    public func getGift(byId id: String) -> WhiteGramGift? {
        lock.lock()
        defer { lock.unlock() }
        return cache[id]
    }
    
    public func getGifts(for ownerId: Int64) -> [WhiteGramGift] {
        lock.lock()
        defer { lock.unlock() }
        return cache.values
            .filter { $0.currentOwnerId == ownerId }
            .sorted { (lhs, rhs) -> Bool in
                if lhs.isPinnedToShelf != rhs.isPinnedToShelf {
                    return lhs.isPinnedToShelf && !rhs.isPinnedToShelf
                }
                return lhs.shelfOrder < rhs.shelfOrder
            }
    }
    
    public func getShelfGifts(for ownerId: Int64) -> [WhiteGramGift] {
        lock.lock()
        defer { lock.unlock() }
        return cache.values
            .filter { $0.currentOwnerId == ownerId && $0.isPinnedToShelf }
            .sorted { $0.shelfOrder < $1.shelfOrder }
    }
    
    public func saveGift(_ gift: WhiteGramGift) {
        lock.lock()
        defer { lock.unlock() }
        cache[gift.id] = gift
        saveToDisk()
    }
    
    public func removeGift(id: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: id)
        saveToDisk()
    }
    
    // MARK: - Shelf Management
    
    @discardableResult
    public func togglePinToShelf(giftId: String, ownerId: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard var gift = cache[giftId], gift.currentOwnerId == ownerId else {
            return false
        }
        
        gift.isPinnedToShelf.toggle()
        if gift.isPinnedToShelf {
            let currentPinned = getShelfGifts(for: ownerId)
            gift.shelfOrder = currentPinned.count
        }
        cache[giftId] = gift
        saveToDisk()
        return gift.isPinnedToShelf
    }
    
    public func reorderShelf(ownerId: Int64, giftIds: [String]) {
        lock.lock()
        defer { lock.unlock() }
        for (index, id) in giftIds.enumerated() {
            if var gift = cache[id], gift.currentOwnerId == ownerId {
                gift.isPinnedToShelf = true
                gift.shelfOrder = index
                cache[id] = gift
            }
        }
        saveToDisk()
    }
    
    public func markAsUnpacked(giftId: String) {
        lock.lock()
        defer { lock.unlock() }
        guard var gift = cache[giftId] else { return }
        gift.isUnpacked = true
        cache[giftId] = gift
        saveToDisk()
    }
    
    // MARK: - Direct Peer-to-Peer Transfer (No Bot Command Required)
    
    @discardableResult
    public func transferGift(
        giftId: String,
        fromUserId: Int64,
        toUserId: Int64,
        toUsername: String? = nil,
        message: String? = nil,
        isAnonymous: Bool = false
    ) throws -> WhiteGramGift {
        lock.lock()
        defer { lock.unlock() }
        
        guard toUserId != 0 else {
            throw GiftStorageError.invalidRecipient
        }
        
        guard fromUserId != toUserId else {
            throw GiftStorageError.cannotTransferToSelf
        }
        
        guard var gift = cache[giftId] else {
            throw GiftStorageError.giftNotFound
        }
        
        guard gift.currentOwnerId == fromUserId else {
            throw GiftStorageError.notOwnedByUser
        }
        
        // Record transfer
        let record = GiftTransferRecord(
            giftId: giftId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            fromUsername: isAnonymous ? nil : (gift.originalSenderName ?? "User_\(fromUserId)"),
            toUsername: toUsername,
            timestamp: Date(),
            message: message,
            isAnonymous: isAnonymous
        )
        
        gift.transferHistory.append(record)
        gift.currentOwnerId = toUserId
        gift.isPinnedToShelf = true // Automatically pin to recipient's shelf
        gift.isUnpacked = false // Requires recipient to open/unpack with animation!
        gift.sentDate = Date()
        gift.giftMessage = message
        if !isAnonymous {
            gift.originalSenderId = fromUserId
            gift.originalSenderName = record.fromUsername
        } else {
            gift.originalSenderId = nil
            gift.originalSenderName = "Anonymous"
        }
        
        // Update recipient shelf order
        let recipientShelfCount = getShelfGifts(for: toUserId).count
        gift.shelfOrder = recipientShelfCount
        
        cache[giftId] = gift
        saveToDisk()
        
        WhiteGramLog.info("GiftStorage: Gift '\(gift.title)' (\(giftId)) transferred from \(fromUserId) to \(toUserId) seamlessly without bot command.")
        
        NotificationCenter.default.post(
            name: GiftStorage.didTransferGiftNotification,
            object: gift,
            userInfo: [
                "gift": gift,
                "fromUserId": fromUserId,
                "toUserId": toUserId,
                "record": record
            ]
        )
        
        return gift
    }
    
    public func getTransferHistory(for giftId: String) -> [GiftTransferRecord] {
        lock.lock()
        defer { lock.unlock() }
        return cache[giftId]?.transferHistory ?? []
    }
    
    // MARK: - Workshop Crafting & Upgrader Hooks
    
    public func craftGifts(
        ingredients: [WhiteGramGift],
        ownerId: Int64
    ) -> (success: Bool, rolledChance: Double, outputGift: WhiteGramGift?) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !ingredients.isEmpty else {
            return (false, 0.0, nil)
        }
        
        let chance = WhiteGramGift.craftSuccessChance(ingredientCount: ingredients.count)
        let roll = Double.random(in: 0.0...100.0)
        let isSuccess = roll <= chance
        
        // Consume ingredients
        for ingredient in ingredients {
            cache.removeValue(forKey: ingredient.id)
        }
        
        if isSuccess {
            let targetRarity = WhiteGramGift.determineCraftOutcomeRarity(ingredients: ingredients)
            let isNFT = (targetRarity == .unique)
            
            var nftAttr: NFTAttributes? = nil
            if isNFT {
                let editionNum = Int.random(in: 1...100)
                nftAttr = NFTAttributes(
                    tokenId: "CRAFT-NFT-\(UUID().uuidString.prefix(6).uppercased())",
                    serialNumber: editionNum,
                    totalEditions: 100,
                    modelName: "Masterpiece Crafted Artifact",
                    backdropName: "Cosmic Workshop Core",
                    rarityScore: 98.0,
                    properties: ["Origin": "WhiteGram Craft Workshop", "Ingredients": "\(ingredients.count) Items"]
                )
            }
            
            let crafted = WhiteGramGift(
                slug: "crafted_\(UUID().uuidString.prefix(8).lowercased())",
                title: isNFT ? "Masterpiece Artifact NFT" : "Crafted \(targetRarity.title) Trophy",
                descriptionText: "Forged directly in WhiteGram Craft Workshop with \(Int(chance))% success rate.",
                iconEmoji: isNFT ? "💎" : (targetRarity == .legendary ? "⚡️" : "🔮"),
                rarity: targetRarity,
                isUniqueNFT: isNFT,
                nftAttributes: nftAttr,
                currentOwnerId: ownerId,
                sentDate: Date(),
                isPinnedToShelf: true,
                isUnpacked: true
            )
            
            cache[crafted.id] = crafted
            saveToDisk()
            return (true, roll, crafted)
        } else {
            saveToDisk()
            return (false, roll, nil)
        }
    }
}
