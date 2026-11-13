import XCTest
@testable import WhiteGramCore
@testable import GhostMode

// MARK: - Mock Account Context Bridge for Testing

final class MockTelegramAccountBridge: TelegramAccountContextBridge {
    var accountId: String = "test_account_1"
    var currentUserId: PeerId = PeerId(12345678)
    
    var lastUpdatedOnlineStatus: Bool?
    var sentTypingEvents: [(peerId: PeerId, action: TypingIndicatorStatus)] = []
    var readHistoryEvents: [(peerId: PeerId, maxMessageId: MessageId)] = []
    
    func updateStatus(isOnline: Bool) {
        lastUpdatedOnlineStatus = isOnline
    }
    
    func sendTyping(peerId: PeerId, action: TypingIndicatorStatus) {
        sentTypingEvents.append((peerId, action))
    }
    
    func markHistoryAsRead(peerId: PeerId, maxMessageId: MessageId) {
        readHistoryEvents.append((peerId, maxMessageId))
    }
    
    func reset() {
        lastUpdatedOnlineStatus = nil
        sentTypingEvents.removeAll()
        readHistoryEvents.removeAll()
    }
}

// MARK: - GhostMode Unit Tests

final class GhostModeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset settings to default full ghost mode before each test
        GhostSettingsStore.shared.resetToDefaults()
        ReadOnActionTracker.shared.reset()
    }
    
    func testGhostSettingsDefaults() {
        let settings = GhostSettings.default
        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(settings.suppressOnlinePresence)
        XCTAssertTrue(settings.suppressTypingIndicator)
        XCTAssertTrue(settings.suppressReadReceipts)
        XCTAssertTrue(settings.suppressStoryRead)
        XCTAssertTrue(settings.suppressUploadProgress)
        XCTAssertTrue(settings.readOnAction)
        XCTAssertFalse(settings.scheduledSendingEnabled)
        XCTAssertEqual(settings.sendWithoutSound, .inGhostMode)
        XCTAssertTrue(settings.sendOfflinePacketAfterOnline)
    }
    
    func testGhostSettingsPresets() {
        let full = GhostSettings.preset(.fullGhost)
        XCTAssertTrue(full.isEnabled)
        XCTAssertTrue(full.suppressOnlinePresence)
        XCTAssertTrue(full.suppressReadReceipts)
        XCTAssertTrue(full.scheduledSendingEnabled)
        
        let stealth = GhostSettings.preset(.stealthOnly)
        XCTAssertTrue(stealth.isEnabled)
        XCTAssertTrue(stealth.suppressOnlinePresence)
        XCTAssertFalse(stealth.suppressReadReceipts)
        
        let unread = GhostSettings.preset(.unreadStealth)
        XCTAssertTrue(unread.isEnabled)
        XCTAssertFalse(unread.suppressOnlinePresence)
        XCTAssertTrue(unread.suppressReadReceipts)
        
        let disabled = GhostSettings.preset(.off)
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertFalse(disabled.suppressOnlinePresence)
        XCTAssertFalse(disabled.suppressTypingIndicator)
        XCTAssertFalse(disabled.suppressReadReceipts)
    }
    
    func testOnlinePresenceSuppression() {
        let manager = GhostModeManager.shared
        manager.applyPreset(.fullGhost)
        
        // When ghost mode is on, online status must be suppressed
        let onlineDecision = manager.hooks.interceptUpdateStatus(isOnline: true)
        XCTAssertTrue(onlineDecision.isSuppressed)
        XCTAssertFalse(manager.canSendOnlineStatus())
        
        // Offline status packet must be allowed through
        let offlineDecision = manager.hooks.interceptUpdateStatus(isOnline: false)
        XCTAssertFalse(offlineDecision.isSuppressed)
        XCTAssertEqual(offlineDecision, .allow)
        
        // When ghost mode is disabled, online status is allowed
        manager.toggleGhostMode() // turns false
        XCTAssertFalse(manager.isGhostModeActive)
        XCTAssertTrue(manager.canSendOnlineStatus())
    }
    
    func testTypingIndicatorSuppression() {
        let manager = GhostModeManager.shared
        manager.applyPreset(.fullGhost)
        let peer = PeerId(9990001)
        
        // Typing, voice recording, sticker selection should be suppressed
        XCTAssertFalse(manager.canSendTyping(peerId: peer, action: .typing))
        XCTAssertFalse(manager.canSendTyping(peerId: peer, action: .recordingAudio))
        XCTAssertFalse(manager.canSendTyping(peerId: peer, action: .choosingSticker))
        XCTAssertFalse(manager.canSendTyping(peerId: peer, action: .uploadingPhoto))
        
        // When typing suppression is turned off
        manager.updateSettings { $0.suppressTypingIndicator = false }
        XCTAssertTrue(manager.canSendTyping(peerId: peer, action: .typing))
    }
    
    func testReadReceiptsAndReadOnActionFlow() {
        let manager = GhostModeManager.shared
        manager.applyPreset(.fullGhost)
        let peer = PeerId(444555)
        let msg1 = MessageId(peerId: peer, namespace: 0, id: 101)
        let msg2 = MessageId(peerId: peer, namespace: 0, id: 105)
        
        // Viewing messages should be suppressed on server
        let decision1 = manager.hooks.interceptReadHistory(peerId: peer, maxMessageId: msg1)
        XCTAssertTrue(decision1.isSuppressed)
        
        // Read on action should have recorded msg1
        XCTAssertEqual(manager.pendingMessageId(for: peer)?.id, 101)
        
        // Viewing higher msg updates the recorded ID
        _ = manager.hooks.interceptReadHistory(peerId: peer, maxMessageId: msg2)
        XCTAssertEqual(manager.pendingMessageId(for: peer)?.id, 105)
        
        // Mock bridge for action dispatch
        let mockBridge = MockTelegramAccountBridge()
        
        // User performs action (replies in chat) -> should flush read receipt for msg2
        manager.didPerformOutgoingAction(peerId: peer, bridge: mockBridge)
        
        XCTAssertEqual(mockBridge.readHistoryEvents.count, 1)
        XCTAssertEqual(mockBridge.readHistoryEvents.first?.peerId, peer)
        XCTAssertEqual(mockBridge.readHistoryEvents.first?.maxMessageId.id, 105)
        
        // Pending read should now be cleared
        XCTAssertNil(manager.pendingMessageId(for: peer))
    }
    
    func testScheduledSendingParameters() {
        let manager = GhostModeManager.shared
        manager.updateSettings {
            $0.isEnabled = true
            $0.scheduledSendingEnabled = true
            $0.scheduledSendingDelaySeconds = 8
            $0.sendWithoutSound = .inGhostMode
        }
        
        let peer = PeerId(777)
        var scheduleDate: Int32? = nil
        var sendSilently: Bool = false
        
        let modified = manager.prepareOutgoingMessage(peerId: peer, scheduleDate: &scheduleDate, sendSilently: &sendSilently)
        XCTAssertTrue(modified)
        XCTAssertTrue(sendSilently)
        XCTAssertNotNil(scheduleDate)
        
        let now = Int32(Date().timeIntervalSince1970)
        XCTAssertGreaterThanOrEqual(scheduleDate!, now + 7)
    }
    
    func testHookedAccountBridge() {
        let mockBridge = MockTelegramAccountBridge()
        let manager = GhostModeManager.shared
        manager.applyPreset(.fullGhost)
        
        let hookedBridge = manager.hookAccountBridge(mockBridge)
        
        // Attempting to send online status should be blocked
        hookedBridge.updateStatus(isOnline: true)
        XCTAssertNil(mockBridge.lastUpdatedOnlineStatus)
        
        // Attempting to send typing should be blocked
        hookedBridge.sendTyping(peerId: PeerId(111), action: .typing)
        XCTAssertTrue(mockBridge.sentTypingEvents.isEmpty)
        
        // Attempting to mark history as read should be blocked
        let msg = MessageId(peerId: PeerId(111), namespace: 0, id: 50)
        hookedBridge.markHistoryAsRead(peerId: PeerId(111), maxMessageId: msg)
        XCTAssertTrue(mockBridge.readHistoryEvents.isEmpty)
        
        // Forced offline status packet must bypass suppression
        hookedBridge.forceOfflineStatus()
        XCTAssertEqual(mockBridge.lastUpdatedOnlineStatus, false)
        
        // Forced mark read must bypass suppression
        hookedBridge.forceMarkHistoryAsRead(peerId: PeerId(111), maxMessageId: msg)
        XCTAssertEqual(mockBridge.readHistoryEvents.count, 1)
        XCTAssertEqual(mockBridge.readHistoryEvents.first?.maxMessageId.id, 50)
    }
    
    func testUniversalMTProtoRPCInterception() {
        let manager = GhostModeManager.shared
        manager.applyPreset(.fullGhost)
        
        // Update status
        let statusDecision = manager.interceptMTProto(method: "account.updateStatus", params: ["offline": false])
        XCTAssertTrue(statusDecision.isSuppressed)
        
        // Typing
        let typingDecision = manager.interceptMTProto(method: "messages.setTyping", params: ["peer_id": Int64(123), "action": TypingIndicatorStatus.typing])
        XCTAssertTrue(typingDecision.isSuppressed)
        
        // Read history
        let readDecision = manager.interceptMTProto(method: "messages.readHistory", params: ["peer_id": Int64(123), "max_id": Int32(42)])
        XCTAssertTrue(readDecision.isSuppressed)
        
        // Stories
        let storyDecision = manager.interceptMTProto(method: "stories.readStories", params: ["peer_id": Int64(123), "max_id": Int32(7)])
        XCTAssertTrue(storyDecision.isSuppressed)
        
        // Unknown method allowed
        let unknownDecision = manager.interceptMTProto(method: "messages.getDialogs", params: [:])
        XCTAssertEqual(unknownDecision, .allow)
    }
}
