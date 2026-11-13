import Foundation
import WhiteGramCore

/// Tracks pending message read states for "Read-on-Action" functionality.
/// Defers sending read receipts to Telegram servers until the user explicitly takes an action
/// (sends a message, reacts, sends media) in that specific chat.
public final class ReadOnActionTracker {
    public static let shared = ReadOnActionTracker()
    
    private let lock = NSLock()
    /// Map of peer ID to the highest seen MessageId pending read acknowledgment.
    private var pendingReads: [PeerId: MessageId] = [:]
    
    /// Optional closure handler invoked when a pending read receipt should be dispatched to TelegramCore.
    public var dispatchReadHistoryHandler: ((_ peerId: PeerId, _ messageId: MessageId) -> Void)?
    
    public init() {}
    
    /// Records a pending unread message when a user views a message in a chat while read suppression is active.
    /// Updates to the highest message ID if multiple messages are viewed.
    public func recordPendingRead(peerId: PeerId, messageId: MessageId) {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = pendingReads[peerId] {
            if messageId.id > existing.id {
                pendingReads[peerId] = messageId
                WhiteGramLog.debug("Updated pending read for peer \(peerId) to msg \(messageId.id)")
            }
        } else {
            pendingReads[peerId] = messageId
            WhiteGramLog.debug("Recorded new pending read for peer \(peerId) at msg \(messageId.id)")
        }
    }
    
    /// Returns the currently pending unread message ID for a given peer, if any.
    public func pendingMessageId(for peerId: PeerId) -> MessageId? {
        lock.lock()
        defer { lock.unlock() }
        return pendingReads[peerId]
    }
    
    /// Returns whether there is an unread acknowledgment pending for the given peer.
    public func hasPendingRead(for peerId: PeerId) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingReads[peerId] != nil
    }
    
    /// Flushes and marks history as read for a peer when the user performs an active action in that chat.
    /// - Parameters:
    ///   - peerId: The peer where the user performed an action (e.g. sent message, reaction).
    ///   - bridge: Optional TelegramAccountContextBridge to dispatch the read receipt.
    /// - Returns: The MessageId that was marked as read, or nil if no read was pending.
    @discardableResult
    public func flushPendingRead(for peerId: PeerId, using bridge: TelegramAccountContextBridge? = nil) -> MessageId? {
        lock.lock()
        guard let messageId = pendingReads.removeValue(forKey: peerId) else {
            lock.unlock()
            return nil
        }
        lock.unlock()
        
        WhiteGramLog.info("Read-on-action triggered for peer \(peerId.id) at message \(messageId.id)")
        
        // Dispatch via bridge if provided
        bridge?.markHistoryAsRead(peerId: peerId, maxMessageId: messageId)
        
        // Dispatch via closure handler if registered
        dispatchReadHistoryHandler?(peerId, messageId)
        
        return messageId
    }
    
    /// Flushes all pending read receipts across all chats.
    public func flushAllPendingReads(using bridge: TelegramAccountContextBridge? = nil) {
        lock.lock()
        let items = pendingReads
        pendingReads.removeAll()
        lock.unlock()
        
        for (peerId, messageId) in items {
            WhiteGramLog.info("Flushing pending read for peer \(peerId.id) at message \(messageId.id)")
            bridge?.markHistoryAsRead(peerId: peerId, maxMessageId: messageId)
            dispatchReadHistoryHandler?(peerId, messageId)
        }
    }
    
    /// Clears any pending read for a peer without dispatching (e.g. if chat was deleted or ignored).
    public func clearPendingRead(for peerId: PeerId) {
        lock.lock()
        defer { lock.unlock() }
        pendingReads.removeValue(forKey: peerId)
    }
    
    /// Clears all pending reads.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        pendingReads.removeAll()
    }
    
    /// Snapshot of current pending reads for debugging/diagnostics.
    public var pendingReadSnapshot: [PeerId: MessageId] {
        lock.lock()
        defer { lock.unlock() }
        return pendingReads
    }
}
