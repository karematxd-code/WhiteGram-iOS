import Foundation
import WhiteGramCore

/// Coordinates scheduled sending and silent delivery to preserve the ghost presence illusion.
public final class ScheduledSendingManager {
    public static let shared = ScheduledSendingManager()
    
    private let lock = NSLock()
    
    /// Scheduled message metadata tracked locally.
    public struct ScheduledGhostMessage: Identifiable, Codable {
        public let id: String
        public let peerId: PeerId
        public let scheduledTimestamp: Int32
        public let isSilent: Bool
        public let createdAt: Date
        
        public init(id: String = UUID().uuidString, peerId: PeerId, scheduledTimestamp: Int32, isSilent: Bool, createdAt: Date = Date()) {
            self.id = id
            self.peerId = peerId
            self.scheduledTimestamp = scheduledTimestamp
            self.isSilent = isSilent
            self.createdAt = createdAt
        }
    }
    
    private var scheduledMessages: [String: ScheduledGhostMessage] = [:]
    
    public init() {}
    
    /// Calculates a future Unix timestamp (Int32) for scheduling a message.
    /// - Parameter delaySeconds: Optional delay in seconds. Defaults to settings or 5 seconds.
    /// - Returns: Unix timestamp for scheduleDate in Telegram MTProto.
    public func calculateScheduleTimestamp(delaySeconds: Int? = nil) -> Int32 {
        let delay = delaySeconds ?? GhostSettingsStore.shared.currentSettings.scheduledSendingDelaySeconds
        let target = Date().addingTimeInterval(TimeInterval(max(delay, 1)))
        return Int32(target.timeIntervalSince1970)
    }
    
    /// Evaluates settings and adjusts outgoing message parameters before dispatching through TelegramCore.
    /// - Parameters:
    ///   - peerId: Target recipient chat/peer.
    ///   - scheduleDate: Inout parameter containing existing schedule date or receiving newly calculated date.
    ///   - sendSilently: Inout parameter determining whether notification sound is disabled.
    /// - Returns: True if any parameter was modified by Ghost Mode policies.
    @discardableResult
    public func prepareOutgoingMessage(
        peerId: PeerId,
        scheduleDate: inout Int32?,
        sendSilently: inout Bool,
        settings: GhostSettings? = nil
    ) -> Bool {
        let activeSettings = settings ?? GhostSettingsStore.shared.currentSettings
        guard activeSettings.isEnabled else { return false }
        
        var modified = false
        
        // Adjust silent sending according to policy
        switch activeSettings.sendWithoutSound {
        case .always:
            if !sendSilently {
                sendSilently = true
                modified = true
            }
        case .inGhostMode:
            if activeSettings.isEnabled && !sendSilently {
                sendSilently = true
                modified = true
            }
        case .never:
            break
        }
        
        // Auto-schedule message if ghost scheduled sending is enabled and not already scheduled
        if activeSettings.scheduledSendingEnabled && scheduleDate == nil {
            let scheduledTime = calculateScheduleTimestamp(delaySeconds: activeSettings.scheduledSendingDelaySeconds)
            scheduleDate = scheduledTime
            modified = true
            
            trackScheduledMessage(peerId: peerId, timestamp: scheduledTime, isSilent: sendSilently)
            WhiteGramLog.info("Outgoing message to \(peerId.id) auto-scheduled for +\(activeSettings.scheduledSendingDelaySeconds)s (ts: \(scheduledTime))")
        }
        
        return modified
    }
    
    /// Tracks a scheduled ghost message locally.
    public func trackScheduledMessage(peerId: PeerId, timestamp: Int32, isSilent: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let item = ScheduledGhostMessage(peerId: peerId, scheduledTimestamp: timestamp, isSilent: isSilent)
        scheduledMessages[item.id] = item
    }
    
    /// Returns all currently tracked scheduled ghost messages.
    public var trackedMessages: [ScheduledGhostMessage] {
        lock.lock()
        defer { lock.unlock() }
        return Array(scheduledMessages.values)
    }
    
    /// Clears expired tracked messages older than the given cutoff date.
    public func pruneExpiredTrackedMessages(before date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Int32(date.timeIntervalSince1970)
        scheduledMessages = scheduledMessages.filter { $0.value.scheduledTimestamp > cutoff }
    }
}
