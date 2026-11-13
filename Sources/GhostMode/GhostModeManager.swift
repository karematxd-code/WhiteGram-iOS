import Foundation
import Combine
import WhiteGramCore

/// Central coordinator for WhiteGram Ghost Mode.
/// Manages privacy policies, TelegramCore RPC interception, Read-on-Action synchronization,
/// and scheduled/silent message dispatch.
public final class GhostModeManager {
    public static let shared = GhostModeManager()
    
    public let settingsStore: GhostSettingsStore
    public let hooks: TelegramCoreInterceptionHooks
    public let readTracker: ReadOnActionTracker
    public let scheduledSender: ScheduledSendingManager
    
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()
    
    public init(
        settingsStore: GhostSettingsStore = .shared,
        hooks: TelegramCoreInterceptionHooks = .shared,
        readTracker: ReadOnActionTracker = .shared,
        scheduledSender: ScheduledSendingManager = .shared
    ) {
        self.settingsStore = settingsStore
        self.hooks = hooks
        self.readTracker = readTracker
        self.scheduledSender = scheduledSender
        
        setupReadOnActionHandler()
    }
    
    private func setupReadOnActionHandler() {
        // Wire up default readTracker handler to log and notify
        readTracker.dispatchReadHistoryHandler = { peerId, messageId in
            WhiteGramLog.info("ReadOnAction triggered dispatch: peer=\(peerId.id), maxId=\(messageId.id)")
        }
    }
    
    // MARK: - Settings Access
    
    /// Current active global ghost settings.
    public var settings: GhostSettings {
        return settingsStore.currentSettings
    }
    
    /// Combine publisher streaming settings changes.
    public var settingsPublisher: AnyPublisher<GhostSettings, Never> {
        return settingsStore.settingsPublisher
    }
    
    /// Quick check if Ghost Mode master toggle is currently active.
    public var isGhostModeActive: Bool {
        return settings.isEnabled
    }
    
    /// Retrieves settings applicable to a specific account ID or global fallback.
    public func settings(for accountId: String? = nil) -> GhostSettings {
        return settingsStore.settings(for: accountId)
    }
    
    /// Updates settings via mutation closure and persists them.
    public func updateSettings(_ mutate: (inout GhostSettings) -> Void) {
        settingsStore.updateGlobalSettings(mutate)
    }
    
    /// Toggles the master Ghost Mode switch on or off.
    /// - Returns: The new state of isEnabled.
    @discardableResult
    public func toggleGhostMode() -> Bool {
        var newState = false
        updateSettings {
            $0.isEnabled.toggle()
            newState = $0.isEnabled
        }
        WhiteGramLog.info("Ghost Mode toggled to \(newState)")
        return newState
    }
    
    /// Applies a preset configuration profile.
    public func applyPreset(_ preset: GhostSettingsPreset) {
        let newSettings = GhostSettings.preset(preset)
        updateSettings { $0 = newSettings }
        WhiteGramLog.info("Applied ghost preset: \(preset.rawValue)")
    }
    
    // MARK: - TelegramCore Interception
    
    /// Returns true if an online presence packet (`account.updateStatus offline:false`) can be sent.
    public func canSendOnlineStatus(accountId: String? = nil) -> Bool {
        let decision = hooks.interceptUpdateStatus(isOnline: true, accountId: accountId)
        return !decision.isSuppressed
    }
    
    /// Returns true if a typing/action indicator (`messages.setTyping`) can be sent.
    public func canSendTyping(peerId: PeerId, action: TypingIndicatorStatus = .typing, accountId: String? = nil) -> Bool {
        let decision = hooks.interceptTyping(peerId: peerId, action: action, accountId: accountId)
        return !decision.isSuppressed
    }
    
    /// Returns true if message history read receipts can be sent immediately.
    public func canMarkHistoryAsRead(peerId: PeerId, maxMessageId: MessageId, isChannel: Bool = false, accountId: String? = nil) -> Bool {
        let decision = hooks.interceptReadHistory(peerId: peerId, maxMessageId: maxMessageId, isChannel: isChannel, accountId: accountId)
        return !decision.isSuppressed
    }
    
    /// Intercepts arbitrary MTProto RPC call by method name.
    public func interceptMTProto(method: String, params: [String: Any], accountId: String? = nil) -> GhostInterceptionDecision<Any> {
        return hooks.interceptMTProtoRpc(method: method, params: params, accountId: accountId)
    }
    
    // MARK: - Read-on-Action Handling
    
    /// Records that the user viewed messages up to `messageId` in `peerId`.
    /// When read suppression is active, this is staged locally until an action occurs.
    public func recordPendingRead(peerId: PeerId, messageId: MessageId) {
        readTracker.recordPendingRead(peerId: peerId, messageId: messageId)
    }
    
    /// Called when the user takes an explicit action in a chat (e.g. sends a reply, sticker, reaction).
    /// If Read-on-Action is enabled, any pending read receipt for this peer is flushed to the server.
    public func didPerformOutgoingAction(peerId: PeerId, bridge: TelegramAccountContextBridge? = nil) {
        guard settings.readOnAction else { return }
        
        if let flushedMessageId = readTracker.flushPendingRead(for: peerId, using: bridge) {
            WhiteGramLog.info("Did perform action in peer \(peerId.id) -> flushed read receipt at msg \(flushedMessageId.id)")
        }
    }
    
    /// Manually marks a chat history as read regardless of ghost suppression (e.g. from context menu or chat header).
    public func manuallyMarkAsRead(peerId: PeerId, maxMessageId: MessageId, bridge: TelegramAccountContextBridge? = nil) {
        readTracker.clearPendingRead(for: peerId)
        bridge?.markHistoryAsRead(peerId: peerId, maxMessageId: maxMessageId)
        WhiteGramLog.info("Manually marked history as read for peer \(peerId.id) at \(maxMessageId.id)")
    }
    
    /// Returns pending unread message ID for a given chat, if currently held by Read-on-Action.
    public func pendingMessageId(for peerId: PeerId) -> MessageId? {
        return readTracker.pendingMessageId(for: peerId)
    }
    
    /// Number of chats currently having deferred read receipts.
    public var pendingReadCount: Int {
        return readTracker.pendingReadSnapshot.count
    }
    
    // MARK: - Scheduled Sending & Silent Delivery
    
    /// Prepares parameters for an outgoing message before dispatch to TelegramCore.
    /// Handles silent delivery flag and ghost auto-scheduling.
    @discardableResult
    public func prepareOutgoingMessage(
        peerId: PeerId,
        scheduleDate: inout Int32?,
        sendSilently: inout Bool
    ) -> Bool {
        return scheduledSender.prepareOutgoingMessage(
            peerId: peerId,
            scheduleDate: &scheduleDate,
            sendSilently: &sendSilently,
            settings: settings
        )
    }
    
    /// Calculates a scheduled timestamp for Ghost delayed sending.
    public func calculateScheduledDate(delaySeconds: Int? = nil) -> Int32 {
        return scheduledSender.calculateScheduleTimestamp(delaySeconds: delaySeconds)
    }
    
    // MARK: - Bridge & Safety Hooks
    
    /// Creates a hooked wrapper around an existing account context bridge to intercept calls transparently.
    public func hookAccountBridge(_ bridge: TelegramAccountContextBridge) -> HookedTelegramAccountBridge {
        return HookedTelegramAccountBridge(underlying: bridge, hooks: hooks, readTracker: readTracker)
    }
    
    /// Sends an explicit offline packet (account.updateStatus offline: true) to Telegram servers
    /// if `sendOfflinePacketAfterOnline` is configured.
    public func dispatchOfflinePacketIfNeeded(using bridge: TelegramAccountContextBridge?) {
        guard settings.isEnabled && settings.sendOfflinePacketAfterOnline else { return }
        WhiteGramLog.info("Dispatching offline safety packet to enforce offline state")
        bridge?.updateStatus(isOnline: false)
    }
}
