import Foundation
import WhiteGramCore

// MARK: - Gift Rarity

public enum GiftRarity: String, Codable, CaseIterable, Comparable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case unique = "unique" // Unique NFT Collectible
    
    public var title: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        case .unique: return "Unique NFT"
        }
    }
    
    public var tier: Int {
        switch self {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        case .unique: return 5
        }
    }
    
    public var baseCraftValue: Int {
        switch self {
        case .common: return 10
        case .rare: return 35
        case .epic: return 120
        case .legendary: return 400
        case .unique: return 1500
        }
    }
    
    public var starsPriceEquivalent: Int {
        switch self {
        case .common: return 25
        case .rare: return 100
        case .epic: return 500
        case .legendary: return 2500
        case .unique: return 10000
        }
    }
    
    public var hexColor: String {
        switch self {
        case .common: return "#8E8E93"
        case .rare: return "#007AFF"
        case .epic: return "#AF52DE"
        case .legendary: return "#FF9500"
        case .unique: return "#FF2D55"
        }
    }
    
    public var gradientHexColors: [String] {
        switch self {
        case .common:
            return ["#8E8E93", "#636366"]
        case .rare:
            return ["#007AFF", "#5856D6"]
        case .epic:
            return ["#AF52DE", "#5856D6"]
        case .legendary:
            return ["#FF9500", "#FF2D55"]
        case .unique:
            return ["#FF2D55", "#9B51E0", "#00F0FF"]
        }
    }
    
    public var badgeEmoji: String {
        switch self {
        case .common: return "⚪️"
        case .rare: return "🔵"
        case .epic: return "🟣"
        case .legendary: return "🟠"
        case .unique: return "💎"
        }
    }
    
    public static func < (lhs: GiftRarity, rhs: GiftRarity) -> Bool {
        return lhs.tier < rhs.tier
    }
}

// MARK: - NFT Attributes

public struct NFTAttributes: Codable, Hashable, Equatable {
    public let tokenId: String
    public let contractAddress: String
    public let serialNumber: Int
    public let totalEditions: Int
    public let modelName: String
    public let backdropName: String
    public let symbol: String
    public let rarityScore: Double
    public let mintDate: Date
    public let blockchain: String
    public var ownerAddress: String
    public var properties: [String: String]
    
    public init(
        tokenId: String,
        contractAddress: String = "EQB-WhiteGramGiftsV2MasterContractAddress",
        serialNumber: Int,
        totalEditions: Int,
        modelName: String,
        backdropName: String = "Cosmic Nebula",
        symbol: String = "WNFT",
        rarityScore: Double = 95.0,
        mintDate: Date = Date(),
        blockchain: String = "TON",
        ownerAddress: String = "EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N",
        properties: [String: String] = [:]
    ) {
        self.tokenId = tokenId
        self.contractAddress = contractAddress
        self.serialNumber = serialNumber
        self.totalEditions = totalEditions
        self.modelName = modelName
        self.backdropName = backdropName
        self.symbol = symbol
        self.rarityScore = rarityScore
        self.mintDate = mintDate
        self.blockchain = blockchain
        self.ownerAddress = ownerAddress
        self.properties = properties
    }
    
    public var formattedEdition: String {
        return "#\(serialNumber) of \(totalEditions)"
    }
    
    public var explorerUrl: URL? {
        return URL(string: "https://tonscan.org/address/\(contractAddress)")
    }
}

// MARK: - Gift Transfer Record

public struct GiftTransferRecord: Codable, Hashable, Identifiable {
    public let id: String
    public let giftId: String
    public let fromUserId: Int64
    public let toUserId: Int64
    public let fromUsername: String?
    public let toUsername: String?
    public let timestamp: Date
    public let message: String?
    public let isAnonymous: Bool
    public let transactionHash: String?
    
    public init(
        id: String = UUID().uuidString,
        giftId: String,
        fromUserId: Int64,
        toUserId: Int64,
        fromUsername: String? = nil,
        toUsername: String? = nil,
        timestamp: Date = Date(),
        message: String? = nil,
        isAnonymous: Bool = false,
        transactionHash: String? = nil
    ) {
        self.id = id
        self.giftId = giftId
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.fromUsername = fromUsername
        self.toUsername = toUsername
        self.timestamp = timestamp
        self.message = message
        self.isAnonymous = isAnonymous
        self.transactionHash = transactionHash ?? "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}

// MARK: - WhiteGram Gift Model

public struct WhiteGramGift: Codable, Hashable, Identifiable, Equatable {
    public let id: String
    public let slug: String
    public var title: String
    public var descriptionText: String
    public var iconEmoji: String
    public var iconImageName: String?
    public var lottieAnimationName: String?
    public var rarity: GiftRarity
    public var isUniqueNFT: Bool
    public var nftAttributes: NFTAttributes?
    
    public var originalSenderId: Int64?
    public var originalSenderName: String?
    public var currentOwnerId: Int64
    public var sentDate: Date
    public var giftMessage: String?
    
    public var isPinnedToShelf: Bool
    public var shelfOrder: Int
    public var starsPrice: Int
    public var isUnpacked: Bool
    public var transferHistory: [GiftTransferRecord]
    
    public init(
        id: String = UUID().uuidString,
        slug: String,
        title: String,
        descriptionText: String,
        iconEmoji: String,
        iconImageName: String? = nil,
        lottieAnimationName: String? = nil,
        rarity: GiftRarity,
        isUniqueNFT: Bool = false,
        nftAttributes: NFTAttributes? = nil,
        originalSenderId: Int64? = nil,
        originalSenderName: String? = nil,
        currentOwnerId: Int64 = 0,
        sentDate: Date = Date(),
        giftMessage: String? = nil,
        isPinnedToShelf: Bool = false,
        shelfOrder: Int = 0,
        starsPrice: Int? = nil,
        isUnpacked: Bool = true,
        transferHistory: [GiftTransferRecord] = []
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.descriptionText = descriptionText
        self.iconEmoji = iconEmoji
        self.iconImageName = iconImageName
        self.lottieAnimationName = lottieAnimationName
        self.rarity = rarity
        self.isUniqueNFT = isUniqueNFT || rarity == .unique || nftAttributes != nil
        self.nftAttributes = nftAttributes
        self.originalSenderId = originalSenderId
        self.originalSenderName = originalSenderName
        self.currentOwnerId = currentOwnerId
        self.sentDate = sentDate
        self.giftMessage = giftMessage
        self.isPinnedToShelf = isPinnedToShelf
        self.shelfOrder = shelfOrder
        self.starsPrice = starsPrice ?? rarity.starsPriceEquivalent
        self.isUnpacked = isUnpacked
        self.transferHistory = transferHistory
    }
    
    // MARK: - Effective Valuation & Crafting Probabilities
    
    public var effectiveValue: Int {
        if isUniqueNFT, let nft = nftAttributes {
            let editionBonus = max(1, 1000 - nft.serialNumber) / 10
            return rarity.baseCraftValue + editionBonus + Int(nft.rarityScore * 5)
        }
        return rarity.baseCraftValue
    }
    
    /// Dynamic real craft chance calculation (25% per slotted gift ingredient).
    /// Used by CraftWorkshopViewController (4 ingredient slots -> up to 100%).
    public static func craftSuccessChance(ingredientCount: Int) -> Double {
        let clamped = max(0, min(4, ingredientCount))
        return Double(clamped) * 25.0
    }
    
    /// Upgrader win probability calculation based on stake vs target gift value.
    /// Used by UpgraderViewController to calculate live chance arc and percentage.
    public static func upgradeSuccessChance(stake: WhiteGramGift, target: WhiteGramGift) -> Double {
        let stakeVal = max(1, Double(stake.effectiveValue))
        let targetVal = max(1, Double(target.effectiveValue))
        
        if stakeVal >= targetVal {
            return 95.0
        }
        
        let ratio = stakeVal / targetVal
        let calculated = ratio * 90.0 // 10% house edge margin
        return max(1.0, min(95.0, (calculated * 10.0).rounded() / 10.0))
    }
    
    /// Evaluates target rarity output when crafting ingredients together.
    public static func determineCraftOutcomeRarity(ingredients: [WhiteGramGift]) -> GiftRarity {
        guard !ingredients.isEmpty else { return .common }
        let totalScore = ingredients.reduce(0) { $0 + $1.rarity.tier }
        let avgScore = Double(totalScore) / Double(ingredients.count)
        
        if ingredients.count == 4 && ingredients.allSatisfy({ $0.rarity >= .legendary }) {
            return .unique
        } else if avgScore >= 3.5 {
            return .legendary
        } else if avgScore >= 2.5 {
            return .epic
        } else if avgScore >= 1.5 {
            return .rare
        } else {
            return .common
        }
    }
    
    // MARK: - Mock Catalog & Presets
    
    public static var defaultCatalog: [WhiteGramGift] {
        return [
            WhiteGramGift(
                slug: "delicious_cake",
                title: "Delicious Cake",
                descriptionText: "A sweet festive cake with lit candles. Brings good mood and party vibes.",
                iconEmoji: "🎂",
                rarity: .common,
                starsPrice: 25
            ),
            WhiteGramGift(
                slug: "blue_star",
                title: "Azure Star",
                descriptionText: "Glowing Telegram azure star symbol of appreciation.",
                iconEmoji: "⭐",
                rarity: .common,
                starsPrice: 50
            ),
            WhiteGramGift(
                slug: "neon_heart",
                title: "Neon Heart",
                descriptionText: "Cybernetic glowing neon heart pulsing with infinite love.",
                iconEmoji: "💖",
                rarity: .rare,
                starsPrice: 100
            ),
            WhiteGramGift(
                slug: "rocket_ship",
                title: "Cosmic Rocket",
                descriptionText: "Hypersonic rocket heading straight To The Moon and beyond.",
                iconEmoji: "🚀",
                rarity: .rare,
                starsPrice: 150
            ),
            WhiteGramGift(
                slug: "golden_trophy",
                title: "Champion Trophy",
                descriptionText: "Pure 24K gold trophy for top tier community champions and leaders.",
                iconEmoji: "🏆",
                rarity: .epic,
                starsPrice: 500
            ),
            WhiteGramGift(
                slug: "durov_cap",
                title: "Pavel's Black Cap",
                descriptionText: "Legendary iconic cap worn during historic privacy battles.",
                iconEmoji: "🧢",
                rarity: .epic,
                starsPrice: 750
            ),
            WhiteGramGift(
                slug: "cyber_dragon",
                title: "Cybernetic Dragon",
                descriptionText: "Mythical mechanized beast breathing holographic blue flame.",
                iconEmoji: "🐉",
                rarity: .legendary,
                starsPrice: 2500
            ),
            WhiteGramGift(
                slug: "pepe_crown",
                title: "Pepe Emperor Crown",
                descriptionText: "Unique NFT: Emerald-encrusted imperial crown forged on TON blockchain.",
                iconEmoji: "👑",
                rarity: .unique,
                isUniqueNFT: true,
                nftAttributes: NFTAttributes(
                    tokenId: "WNFT-00042",
                    serialNumber: 42,
                    totalEditions: 500,
                    modelName: "Emerald Emperor Pepe Crown",
                    backdropName: "Royal Velvet Emerald",
                    rarityScore: 99.4,
                    properties: ["Gem": "Pure Colombian Emerald", "Material": "TON Platinum", "Edition": "Genesis"]
                ),
                starsPrice: 10000
            ),
            WhiteGramGift(
                slug: "astral_portal",
                title: "Astral Diamond Portal",
                descriptionText: "Unique NFT: Trans-dimensional gateway pulsating with quantum particle effects.",
                iconEmoji: "🌀",
                rarity: .unique,
                isUniqueNFT: true,
                nftAttributes: NFTAttributes(
                    tokenId: "WNFT-00007",
                    serialNumber: 7,
                    totalEditions: 100,
                    modelName: "Quantum Astral Portal",
                    backdropName: "Infinite Multiverse",
                    rarityScore: 99.9,
                    properties: ["Dimension": "5th Dimension", "Core": "White Hole Singularity", "Aura": "Ultra Rare"]
                ),
                starsPrice: 25000
            )
        ]
    }
    
    public static func mockUserCollection(userId: Int64) -> [WhiteGramGift] {
        var gifts = defaultCatalog
        for i in 0..<gifts.count {
            gifts[i].currentOwnerId = userId
            gifts[i].isPinnedToShelf = (i < 4)
            gifts[i].shelfOrder = i
            gifts[i].isUnpacked = true
            if i % 2 == 1 {
                gifts[i].originalSenderName = "Alice"
                gifts[i].giftMessage = "Congratulations from WhiteGram squad! 🎉"
            }
        }
        return gifts
    }
}
