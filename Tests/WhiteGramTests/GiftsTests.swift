import XCTest
@testable import WhiteGramCore
@testable import Gifts

final class GiftsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset or prepare in-memory test gifts
    }
    
    func testRarityHierarchyAndValues() {
        XCTAssertTrue(GiftRarity.common < GiftRarity.rare)
        XCTAssertTrue(GiftRarity.rare < GiftRarity.epic)
        XCTAssertTrue(GiftRarity.epic < GiftRarity.legendary)
        XCTAssertTrue(GiftRarity.legendary < GiftRarity.unique)
        
        XCTAssertEqual(GiftRarity.common.tier, 1)
        XCTAssertEqual(GiftRarity.unique.tier, 5)
        
        XCTAssertEqual(GiftRarity.common.baseCraftValue, 10)
        XCTAssertEqual(GiftRarity.unique.baseCraftValue, 1500)
    }
    
    func testRegularGiftInitializationAndEncoding() throws {
        let gift = WhiteGramGift(
            slug: "star_badge",
            title: "Azure Star",
            descriptionText: "Glowing star badge.",
            iconEmoji: "⭐",
            rarity: .common,
            currentOwnerId: 1001
        )
        
        XCTAssertEqual(gift.currentOwnerId, 1001)
        XCTAssertFalse(gift.isUniqueNFT)
        XCTAssertNil(gift.nftAttributes)
        XCTAssertEqual(gift.effectiveValue, 10)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(gift)
        let decoded = try JSONDecoder().decode(WhiteGramGift.self, from: data)
        XCTAssertEqual(gift.id, decoded.id)
        XCTAssertEqual(gift.title, decoded.title)
        XCTAssertEqual(gift.rarity, decoded.rarity)
    }
    
    func testUniqueNFTGiftAttributes() throws {
        let nft = NFTAttributes(
            tokenId: "WNFT-42",
            serialNumber: 42,
            totalEditions: 500,
            modelName: "Emerald Crown",
            rarityScore: 99.0
        )
        
        let gift = WhiteGramGift(
            slug: "pepe_crown",
            title: "Pepe Crown NFT",
            descriptionText: "Unique imperial emerald crown",
            iconEmoji: "👑",
            rarity: .unique,
            isUniqueNFT: true,
            nftAttributes: nft,
            currentOwnerId: 2002
        )
        
        XCTAssertTrue(gift.isUniqueNFT)
        XCTAssertNotNil(gift.nftAttributes)
        XCTAssertEqual(gift.nftAttributes?.formattedEdition, "#42 of 500")
        XCTAssertGreaterThan(gift.effectiveValue, GiftRarity.unique.baseCraftValue)
    }
    
    func testCraftSuccessFormula() {
        // Dynamic real chance calculation (25% per slotted gift)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 0), 0.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 1), 25.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 2), 50.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 3), 75.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 4), 100.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 5), 100.0) // clamped to 4 slots
    }
    
    func testUpgradeSuccessFormula() {
        let stakeCommon = WhiteGramGift(
            slug: "cake",
            title: "Cake",
            descriptionText: "",
            iconEmoji: "🎂",
            rarity: .common
        )
        
        let targetLegendary = WhiteGramGift(
            slug: "dragon",
            title: "Dragon",
            descriptionText: "",
            iconEmoji: "🐉",
            rarity: .legendary
        )
        
        let chance = WhiteGramGift.upgradeSuccessChance(stake: stakeCommon, target: targetLegendary)
        // Common base = 10, Legendary base = 400.
        // Ratio = 10 / 400 = 0.025 * 90% = 2.25%
        XCTAssertGreaterThanOrEqual(chance, 1.0)
        XCTAssertLessThanOrEqual(chance, 95.0)
        
        // When stake is equal or higher value than target
        let highChance = WhiteGramGift.upgradeSuccessChance(stake: targetLegendary, target: stakeCommon)
        XCTAssertEqual(highChance, 95.0)
    }
    
    func testStorageAndDirectP2PTransferWithoutBotCommand() throws {
        let storage = GiftStorage.shared
        let userA: Int64 = 777111
        let userB: Int64 = 888222
        
        var gift = WhiteGramGift(
            slug: "test_diamond",
            title: "Test Diamond",
            descriptionText: "Precious gemstone for transfer tests",
            iconEmoji: "💎",
            rarity: .epic,
            currentOwnerId: userA
        )
        
        storage.saveGift(gift)
        
        // Verify user A owns it
        let giftsA = storage.getGifts(for: userA)
        XCTAssertTrue(giftsA.contains(where: { $0.id == gift.id }))
        
        // Disallow self-transfer
        XCTAssertThrowsError(try storage.transferGift(
            giftId: gift.id,
            fromUserId: userA,
            toUserId: userA,
            message: "Self transfer"
        ))
        
        // Disallow non-owner transfer
        XCTAssertThrowsError(try storage.transferGift(
            giftId: gift.id,
            fromUserId: userB,
            toUserId: 999999,
            message: "Theft attempt"
        ))
        
        // Execute valid transfer from user A to user B without bot command requirement
        let transferred = try storage.transferGift(
            giftId: gift.id,
            fromUserId: userA,
            toUserId: userB,
            toUsername: "@alice",
            message: "Happy Birthday!",
            isAnonymous: false
        )
        
        XCTAssertEqual(transferred.currentOwnerId, userB)
        XCTAssertEqual(transferred.giftMessage, "Happy Birthday!")
        XCTAssertFalse(transferred.isUnpacked) // Packed for recipient to unpack
        XCTAssertTrue(transferred.isPinnedToShelf)
        XCTAssertEqual(transferred.transferHistory.count, 1)
        XCTAssertEqual(transferred.transferHistory.first?.fromUserId, userA)
        XCTAssertEqual(transferred.transferHistory.first?.toUserId, userB)
        XCTAssertEqual(transferred.transferHistory.first?.toUsername, "@alice")
        
        // Verify storage cache updated
        let giftsB = storage.getGifts(for: userB)
        XCTAssertTrue(giftsB.contains(where: { $0.id == gift.id }))
        
        let updatedA = storage.getGifts(for: userA)
        XCTAssertFalse(updatedA.contains(where: { $0.id == gift.id }))
        
        // Clean up
        storage.removeGift(id: gift.id)
    }
    
    func testShelfPinAndReorder() {
        let storage = GiftStorage.shared
        let userId: Int64 = 555666
        
        let g1 = WhiteGramGift(slug: "g1", title: "G1", descriptionText: "", iconEmoji: "1️⃣", rarity: .common, currentOwnerId: userId, isPinnedToShelf: false)
        let g2 = WhiteGramGift(slug: "g2", title: "G2", descriptionText: "", iconEmoji: "2️⃣", rarity: .rare, currentOwnerId: userId, isPinnedToShelf: false)
        
        storage.saveGift(g1)
        storage.saveGift(g2)
        
        let pinned1 = storage.togglePinToShelf(giftId: g1.id, ownerId: userId)
        XCTAssertTrue(pinned1)
        
        let shelf = storage.getShelfGifts(for: userId)
        XCTAssertEqual(shelf.count, 1)
        XCTAssertEqual(shelf.first?.id, g1.id)
        
        // Clean up
        storage.removeGift(id: g1.id)
        storage.removeGift(id: g2.id)
    }
    
    func testCraftingGifts() {
        let storage = GiftStorage.shared
        let userId: Int64 = 444333
        
        let ing1 = WhiteGramGift(slug: "i1", title: "Ing 1", descriptionText: "", iconEmoji: "🌱", rarity: .common, currentOwnerId: userId)
        let ing2 = WhiteGramGift(slug: "i2", title: "Ing 2", descriptionText: "", iconEmoji: "🌱", rarity: .common, currentOwnerId: userId)
        let ing3 = WhiteGramGift(slug: "i3", title: "Ing 3", descriptionText: "", iconEmoji: "🌱", rarity: .common, currentOwnerId: userId)
        let ing4 = WhiteGramGift(slug: "i4", title: "Ing 4", descriptionText: "", iconEmoji: "🌱", rarity: .common, currentOwnerId: userId)
        
        storage.saveGift(ing1)
        storage.saveGift(ing2)
        storage.saveGift(ing3)
        storage.saveGift(ing4)
        
        // 4 ingredients = 100% chance guaranteed
        let result = storage.craftGifts(ingredients: [ing1, ing2, ing3, ing4], ownerId: userId)
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.outputGift)
        
        // Verify ingredients removed
        XCTAssertNil(storage.getGift(byId: ing1.id))
        XCTAssertNil(storage.getGift(byId: ing2.id))
        XCTAssertNil(storage.getGift(byId: ing3.id))
        XCTAssertNil(storage.getGift(byId: ing4.id))
        
        if let output = result.outputGift {
            storage.removeGift(id: output.id)
        }
    }
}
