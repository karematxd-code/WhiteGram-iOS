import Foundation

#if canImport(TelegramCore)
import TelegramCore
import Postbox
import SwiftSignalKit
#else

// MARK: - Standalone TelegramCore Protocol Stubs & Compatibility Layer
// These types provide clean interfaces when compiling WhiteGram modules standalone
// or under unit test runners without the full Telegram-iOS monorepo.

public struct PeerId: Hashable, Codable, CustomStringConvertible {
    public let id: Int64
    public init(_ id: Int64) {
        self.id = id
    }
    public var description: String {
        return "\(id)"
    }
}

public struct MessageId: Hashable, Codable, CustomStringConvertible {
    public let peerId: PeerId
    public let namespace: Int32
    public let id: Int32
    
    public init(peerId: PeerId, namespace: Int32, id: Int32) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }
    
    public var description: String {
        return "\(peerId.id):\(namespace):\(id)"
    }
}

public enum UserPresence: Equatable {
    case offline
    case online(until: Int32)
}

public enum TypingIndicatorStatus: Equatable {
    case typing
    case recordingVideo
    case uploadingVideo
    case recordingAudio
    case uploadingAudio
    case uploadingPhoto
    case uploadingFile
    case choosingSticker
}

public protocol TelegramAccountContextBridge: AnyObject {
    var accountId: String { get }
    var currentUserId: PeerId { get }
    func updateStatus(isOnline: Bool)
    func sendTyping(peerId: PeerId, action: TypingIndicatorStatus)
    func markHistoryAsRead(peerId: PeerId, maxMessageId: MessageId)
}

#endif
