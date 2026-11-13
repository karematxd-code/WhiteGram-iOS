import XCTest
@testable import WhiteGramCore
@testable import Gifts
@testable import Upgrader

#if canImport(UIKit)
import UIKit
#endif

final class UpgraderTests: XCTestCase {
    
    // MARK: - Chance Formula Tests
    
    func testCraftChanceFormulaExact25PercentPerSlot() {
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 0), 0.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 1), 25.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 2), 50.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 3), 75.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 4), 100.0)
        
        // Clamping edge cases
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: -1), 0.0)
        XCTAssertEqual(WhiteGramGift.craftSuccessChance(ingredientCount: 5), 100.0)
    }
    
    func testUpgraderSuccessChanceFormula() {
        let lowStake = WhiteGramGift(
            slug: "common_gift",
            title: "Common Gift",
            descriptionText: "Common",
            iconEmoji: "🎁",
            rarity: .common,
            starsPrice: 25
        )
        
        let highTarget = WhiteGramGift(
            slug: "epic_gift",
            title: "Epic Gift",
            descriptionText: "Epic",
            iconEmoji: "🚀",
            rarity: .epic,
            starsPrice: 500
        )
        
        let chance = WhiteGramGift.upgradeSuccessChance(stake: lowStake, target: highTarget)
        XCTAssertGreaterThanOrEqual(chance, 1.0)
        XCTAssertLessThanOrEqual(chance, 95.0)
        
        // Equal or higher stake caps at 95%
        let equalChance = WhiteGramGift.upgradeSuccessChance(stake: highTarget, target: lowStake)
        XCTAssertEqual(equalChance, 95.0)
    }
    
    func testDetermineCraftOutcomeRarity() {
        let common1 = WhiteGramGift(slug: "c1", title: "C1", descriptionText: "", iconEmoji: "1", rarity: .common)
        let common2 = WhiteGramGift(slug: "c2", title: "C2", descriptionText: "", iconEmoji: "2", rarity: .common)
        let rare1 = WhiteGramGift(slug: "r1", title: "R1", descriptionText: "", iconEmoji: "3", rarity: .rare)
        let rare2 = WhiteGramGift(slug: "r2", title: "R2", descriptionText: "", iconEmoji: "4", rarity: .rare)
        
        // Empty
        XCTAssertEqual(WhiteGramGift.determineCraftOutcomeRarity(ingredients: []), .common)
        
        // All common -> Rare upgrade chance
        XCTAssertEqual(WhiteGramGift.determineCraftOutcomeRarity(ingredients: [common1, common2]), .common)
        
        // Mixed rare
        let mixedResult = WhiteGramGift.determineCraftOutcomeRarity(ingredients: [rare1, rare2])
        XCTAssertEqual(mixedResult, .rare)
        
        // Legendary ingredients
        let leg1 = WhiteGramGift(slug: "l1", title: "L1", descriptionText: "", iconEmoji: "👑", rarity: .legendary)
        let leg2 = WhiteGramGift(slug: "l2", title: "L2", descriptionText: "", iconEmoji: "👑", rarity: .legendary)
        let leg3 = WhiteGramGift(slug: "l3", title: "L3", descriptionText: "", iconEmoji: "👑", rarity: .legendary)
        let leg4 = WhiteGramGift(slug: "l4", title: "L4", descriptionText: "", iconEmoji: "👑", rarity: .legendary)
        
        let quadLegResult = WhiteGramGift.determineCraftOutcomeRarity(ingredients: [leg1, leg2, leg3, leg4])
        XCTAssertEqual(quadLegResult, .unique)
    }
    
    // MARK: - UI Component Initialization & Interaction Tests
    
    #if canImport(UIKit)
    func testRadialGaugeViewConfigurationAndChance() {
        let gauge = UpgraderRadialGaugeView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertNotNil(gauge)
        XCTAssertEqual(gauge.chance, 0.0)
        XCTAssertFalse(gauge.isSpinning)
        
        gauge.setChance(42.5, multiplier: 2.35, animated: false)
        XCTAssertEqual(gauge.chance, 42.5)
        XCTAssertEqual(gauge.percentageLabel.text, "42.50%")
        XCTAssertEqual(gauge.multiplierBadge.text, "x2.35")
        
        // Test reset
        gauge.resetNeedle(animated: false)
        XCTAssertEqual(gauge.currentNeedleAngle, 0.0)
    }
    
    func testUpgraderViewControllerChanceComputation() {
        let vc = UpgraderViewController()
        XCTAssertNotNil(vc)
        
        let (initialChance, initialMult) = vc.computeLiveChance()
        XCTAssertGreaterThanOrEqual(initialChance, 1.0)
        XCTAssertLessThanOrEqual(initialChance, 95.0)
        XCTAssertGreaterThan(initialMult, 0.0)
    }
    
    func testCraftWorkshopViewControllerChanceComputation() {
        let vc = CraftWorkshopViewController()
        XCTAssertNotNil(vc)
        
        // Initially 0 slots filled
        XCTAssertEqual(vc.computeCraftSuccessChance(), 0.0)
    }
    #endif
}
