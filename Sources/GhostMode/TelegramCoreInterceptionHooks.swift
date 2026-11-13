import Foundation
import WhiteGramCore

/// Outcome of evaluating an MTProto or TelegramCore request against Ghost Mode rules.
public enum GhostInterceptionDecision<T>: Equatable {
    /// Allow the request to proceed to the Telegram network as normal.
    case allow
    /// Suppress (drop) the request from hitting Telegram servers, optionally returning a synthetic result.
    case suppress(simulatedResult: T?)
    /// Request was modified before sending.
    case modify
    
    public var isSuppressed: Bool {
        if case .suppress = self { return true }
        return false
    }
}

/// Core interception hooks for TelegramCore network RPC calls and user presence events.
public final class TelegramCoreInterceptionHooks {
    public static let shared = TelegramCoreInterceptionHooks()
    
    private let settingsStore: GhostSettingsStore
    private let readTracker: ReadOnActionTracker
    
    public init(settingsStore: GhostSettingsStore = .shared, readTracker: ReadOnActionTracker = .shared) {
        self.settingsStore = settingsStore
        self.readTracker = readTracker
    }
    
    // MARK: - 1. Online Presence Interception (account.updateStatus)
    
    /// Evaluates whether an `account.updateStatus` request should be dispatched or suppressed.
    /// - Parameters:
    ///   - isOnline: True when client intends to mark the account as online (`offline: false`).
    ///   - accountId: Optional account identifier for multi-account support.
    /// - Returns: `.suppress` if online presence should be hidden; `.allow` if offline or ghost mode is inactive.
    public func interceptUpdateStatus(isOnline: Bool, accountId: String? = nil) -> GhostInterceptionDecision<Bool> {
        let settings = settingsStore.settings(for: accountId)
        
        guard settings.isEnabled else {
            return .allow
        }
        
        // Suppress online status broadcasts to prevent revealing presence
        if isOnline && settings.suppressOnlinePresence {
            WhiteGramLog.info("Intercepted and suppressed account.updateStatus(offline: false) [Ghost Mode Active]")
            return .suppress(simulatedResult: true)
        }
        
        // Allow explicit offline packets through so the user appears offline immediately
        WhiteGramLog.debug("Allowing account.updateStatus(offline: \(!isOnline)) to proceed")
        return .allow
    }
    
    // MARK: - 2. Typing Indicator Interception (messages.setTyping)
    
    /// Evaluates whether a typing or action indicator (`messages.setTyping`) should be suppressed.
    /// - Parameters:
    ///   - peerId: Target chat peer.
    ///   - action: The user action (typing, recording audio, uploading media, etc.).
    ///   - accountId: Optional account identifier.
    /// - Returns: `.suppress` to block the typing packet; `.allow` otherwise.
    public func interceptTyping(
        peerId: PeerId,
        action: TypingIndicatorStatus,
        accountId: String? = nil
    ) -> GhostInterceptionDecision<Bool> {
        let settings = settingsStore.settings(for: accountId)
        
        guard settings.isEnabled else {
            return .allow
        }
        
        // Check general typing suppression
        if settings.suppressTypingIndicator {
            switch action {
            case .typing, .choosingSticker:
                WhiteGramLog.debug("Suppressed messages.setTyping(\(action)) for peer \(peerId.id)")
                return .suppress(simulatedResult: true)
            case .recordingVideo, .recordingAudio:
                WhiteGramLog.debug("Suppressed media recording status for peer \(peerId.id)")
                return .suppress(simulatedResult: true)
            case .uploadingVideo, .uploadingAudio, .uploadingPhoto, .uploadingFile:
                if settings.suppressUploadProgress {
                    WhiteGramLog.debug("Suppressed media upload progress status for peer \(peerId.id)")
                    return .suppress(simulatedResult: true)
                }
            }
        }
        
        return .allow
    }
    
    // MARK: - 3. Read Receipts Interception (messages.readHistory & channels.readHistory)
    
    /// Evaluates whether marking message history as read (`messages.readHistory`, `channels.readHistory`) should be suppressed.
    /// - Parameters:
    ///   - peerId: The chat peer whose messages are being viewed.
    ///   - maxMessageId: The maximum message ID reached in the chat viewport.
    ///   - isChannel: True if target is a supergroup or channel.
    ///   - accountId: Optional account identifier.
    /// - Returns: `.suppress` to prevent sending the read receipt over the wire.
    public func interceptReadHistory(
        peerId: PeerId,
        maxMessageId: MessageId,
        isChannel: Bool = false,
        accountId: String? = nil
    ) -> GhostInterceptionDecision<Bool> {
        let settings = settingsStore.settings(for: accountId)
        
        guard settings.isEnabled else {
            return .allow
        }
        
        if settings.suppressReadReceipts {
            // If readOnAction is active, record this read position so it can be flushed on reply/action
            if settings.readOnAction {
                readTracker.recordPendingRead(peerId: peerId, messageId: maxMessageId)
                WhiteGramLog.debug("Recorded deferred read for peer \(peerId.id) at maxId \(maxMessageId.id)")
            }
            
            let rpc = isChannel ? "channels.readHistory" : "messages.readHistory"
            WhiteGramLog.info("Suppressed \(rpc) for peer \(peerId.id) up to maxId \(maxMessageId.id) [Ghost Mode]")
            return .suppress(simulatedResult: true)
        }
        
        return .allow
    }
    
    // MARK: - 4. Stories Read Receipts Interception (stories.readStories)
    
    /// Evaluates whether viewing ephemeral stories (`stories.readStories`) should be suppressed.
    /// - Parameters:
    ///   - peerId: The user or channel posting the story.
    ///   - maxStoryId: The story identifier viewed.
    ///   - accountId: Optional account identifier.
    /// - Returns: `.suppress` to keep the user hidden from the story viewer list.
    public func interceptStoryRead(
        peerId: PeerId,
        maxStoryId: Int32,
        accountId: String? = nil
    ) -> GhostInterceptionDecision<[Int32]> {
        let settings = settingsStore.settings(for: accountId)
        
        guard settings.isEnabled else {
            return .allow
        }
        
        if settings.suppressStoryRead {
            WhiteGramLog.info("Suppressed stories.readStories for peer \(peerId.id) story \(maxStoryId) [Ghost Mode]")
            return .suppress(simulatedResult: [maxStoryId])
        }
        
        return .allow
    }
    
    // MARK: - 5. Generic MTProto RPC Router
    
    /// Universal interception dispatch point matching MTProto method strings directly.
    /// Useful for hooking into MTProto transport serialization / Network.request pipelines.
    public func interceptMTProtoRpc(
        method: String,
        params: [String: Any],
        accountId: String? = nil
    ) -> GhostInterceptionDecision<Any> {
        switch method {
        case "account.updateStatus":
            let isOnline = (params["offline"] as? Bool) == false
            let decision = interceptUpdateStatus(isOnline: isOnline, accountId: accountId)
            switch decision {
            case .allow: return .allow
            case .suppress: return .suppress(simulatedResult: true)
            case .modify: return .modify
            }
            
        case "messages.setTyping":
            guard let peerIdValue = params["peer_id"] as? Int64 else { return .allow }
            let action = (params["action"] as? TypingIndicatorStatus) ?? .typing
            let decision = interceptTyping(peerId: PeerId(peerIdValue), action: action, accountId: accountId)
            switch decision {
            case .allow: return .allow
            case .suppress: return .suppress(simulatedResult: true)
            case .modify: return .modify
            }
            
        case "messages.readHistory", "channels.readHistory":
            guard let peerIdValue = params["peer_id"] as? Int64,
                  let maxId = params["max_id"] as? Int32 else { return .allow }
            let isChannel = (method == "channels.readHistory")
            let decision = interceptReadHistory(
                peerId: PeerId(peerIdValue),
                maxMessageId: MessageId(peerId: PeerId(peerIdValue), namespace: 0, id: maxId),
                isChannel: isChannel,
                accountId: accountId
            )
            switch decision {
            case .allow: return .allow
            case .suppress: return .suppress(simulatedResult: true)
            case .modify: return .modify
            }
            
        case "stories.readStories":
            guard let peerIdValue = params["peer_id"] as? Int64,
                  let maxId = params["max_id"] as? Int32 else { return .allow }
            let decision = interceptStoryRead(peerId: PeerId(peerIdValue), maxStoryId: maxId, accountId: accountId)
            switch decision {
            case .allow: return .allow
            case .suppress(let res): return .suppress(simulatedResult: res ?? [maxId])
            case .modify: return .modify
            }
            
        default:
            return .allow
        }
    }
}

// MARK: - TelegramAccountContextHookBridge

/// Wrapper around a TelegramAccountContextBridge that transparently enforces Ghost Mode hooks.
public final class HookedTelegramAccountBridge: TelegramAccountContextBridge {
    public let underlying: TelegramAccountContextBridge
    private let hooks: TelegramCoreInterceptionHooks
    private let readTracker: ReadOnActionTracker
    
    public init(
        underlying: TelegramAccountContextBridge,
        hooks: TelegramCoreInterceptionHooks = .shared,
        readTracker: ReadOnActionTracker = .shared
    ) {
        self.underlying = underlying
        self.hooks = hooks
        self.readTracker = readTracker
    }
    
    public var accountId: String {
        return underlying.accountId
    }
    
    public var currentUserId: PeerId {
        return underlying.currentUserId
    }
    
    public func updateStatus(isOnline: Bool) {
        let decision = hooks.interceptUpdateStatus(isOnline: isOnline, accountId: accountId)
        if !decision.isSuppressed {
            underlying.updateStatus(isOnline: isOnline)
        }
    }
    
    public func sendTyping(peerId: PeerId, action: TypingIndicatorStatus) {
        let decision = hooks.interceptTyping(peerId: peerId, action: action, accountId: accountId)
        if !decision.isSuppressed {
            underlying.sendTyping(peerId: peerId, action: action)
        }
    }
    
    public func markHistoryAsRead(peerId: PeerId, maxMessageId: MessageId) {
        let decision = hooks.interceptReadHistory(peerId: peerId, maxMessageId: maxMessageId, accountId: accountId)
        if !decision.isSuppressed {
            underlying.markHistoryAsRead(peerId: peerId, maxMessageId: maxMessageId)
        }
    }
    
    /// Forces dispatch of a pending read receipt, bypassing read suppression (e.g. for Read-on-Action).
    public func forceMarkHistoryAsRead(peerId: PeerId, maxMessageId: MessageId) {
        WhiteGramLog.info("Force dispatching markHistoryAsRead for peer \(peerId.id) at \(maxMessageId.id)")
        underlying.markHistoryAsRead(peerId: peerId, maxMessageId: maxMessageId)
    }
    
    /// Forces an immediate offline status packet to ensure cloud presence is cleared.
    public func forceOfflineStatus() {
        WhiteGramLog.info("Force dispatching updateStatus(isOnline: false)")
        underlying.updateStatus(isOnline: false)
    }
}
