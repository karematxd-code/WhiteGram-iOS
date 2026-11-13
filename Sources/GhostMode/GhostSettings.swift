import Foundation
import Combine
import WhiteGramCore

/// Sound sending behavior when ghost mode is involved.
public enum SendWithoutSoundPolicy: String, Codable, CaseIterable, Equatable {
    case never = "never"
    case inGhostMode = "in_ghost_mode"
    case always = "always"
}

/// Pre-configured privacy profiles for Ghost Mode.
public enum GhostSettingsPreset: String, CaseIterable, Equatable {
    case fullGhost = "full_ghost"
    case stealthOnly = "stealth_only"
    case unreadStealth = "unread_stealth"
    case off = "off"
    
    public var title: String {
        switch self {
        case .fullGhost:
            return "Full Ghost (Полный призрак)"
        case .stealthOnly:
            return "Stealth Online (Скрытый онлайн)"
        case .unreadStealth:
            return "Unread Stealth (Невидимка по прочтению)"
        case .off:
            return "Disabled (Выключен)"
        }
    }
}

/// Model encapsulating all Ghost Mode configuration parameters.
public struct GhostSettings: Codable, Equatable {
    /// Master toggle for Ghost Mode.
    public var isEnabled: Bool
    
    /// Suppress online presence (account.updateStatus offline: false).
    public var suppressOnlinePresence: Bool
    
    /// Suppress typing & activity indicators (messages.setTyping).
    public var suppressTypingIndicator: Bool
    
    /// Suppress read receipts for chat messages (messages.readHistory & channels.readHistory).
    public var suppressReadReceipts: Bool
    
    /// Suppress story view receipts (stories.readStories).
    public var suppressStoryRead: Bool
    
    /// Suppress media upload progress broadcasts.
    public var suppressUploadProgress: Bool
    
    /// When true, messages are only marked as read when sending a reply, reaction, or taking explicit action.
    public var readOnAction: Bool
    
    /// When enabled, outgoing messages can be automatically delayed/scheduled to prevent presence leaks.
    public var scheduledSendingEnabled: Bool
    
    /// Default delay in seconds for scheduled ghost sending.
    public var scheduledSendingDelaySeconds: Int
    
    /// Policy determining when messages should be sent silently without alert sounds.
    public var sendWithoutSound: SendWithoutSoundPolicy
    
    /// Immediately send an offline packet (account.updateStatus offline: true) after intentional or accidental online status.
    public var sendOfflinePacketAfterOnline: Bool
    
    /// Prompt or warn before viewing ephemeral stories if ghost mode is inactive.
    public var suggestGhostModeBeforeStory: Bool
    
    public init(
        isEnabled: Bool = true,
        suppressOnlinePresence: Bool = true,
        suppressTypingIndicator: Bool = true,
        suppressReadReceipts: Bool = true,
        suppressStoryRead: Bool = true,
        suppressUploadProgress: Bool = true,
        readOnAction: Bool = true,
        scheduledSendingEnabled: Bool = false,
        scheduledSendingDelaySeconds: Int = 5,
        sendWithoutSound: SendWithoutSoundPolicy = .inGhostMode,
        sendOfflinePacketAfterOnline: Bool = true,
        suggestGhostModeBeforeStory: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.suppressOnlinePresence = suppressOnlinePresence
        self.suppressTypingIndicator = suppressTypingIndicator
        self.suppressReadReceipts = suppressReadReceipts
        self.suppressStoryRead = suppressStoryRead
        self.suppressUploadProgress = suppressUploadProgress
        self.readOnAction = readOnAction
        self.scheduledSendingEnabled = scheduledSendingEnabled
        self.scheduledSendingDelaySeconds = scheduledSendingDelaySeconds
        self.sendWithoutSound = sendWithoutSound
        self.sendOfflinePacketAfterOnline = sendOfflinePacketAfterOnline
        self.suggestGhostModeBeforeStory = suggestGhostModeBeforeStory
    }
    
    public static var `default`: GhostSettings {
        return GhostSettings()
    }
    
    public static var disabled: GhostSettings {
        var settings = GhostSettings()
        settings.isEnabled = false
        settings.suppressOnlinePresence = false
        settings.suppressTypingIndicator = false
        settings.suppressReadReceipts = false
        settings.suppressStoryRead = false
        settings.suppressUploadProgress = false
        settings.readOnAction = false
        settings.scheduledSendingEnabled = false
        settings.sendWithoutSound = .never
        settings.sendOfflinePacketAfterOnline = false
        settings.suggestGhostModeBeforeStory = false
        return settings
    }
    
    public static func preset(_ preset: GhostSettingsPreset) -> GhostSettings {
        switch preset {
        case .fullGhost:
            return GhostSettings(
                isEnabled: true,
                suppressOnlinePresence: true,
                suppressTypingIndicator: true,
                suppressReadReceipts: true,
                suppressStoryRead: true,
                suppressUploadProgress: true,
                readOnAction: true,
                scheduledSendingEnabled: true,
                scheduledSendingDelaySeconds: 5,
                sendWithoutSound: .inGhostMode,
                sendOfflinePacketAfterOnline: true,
                suggestGhostModeBeforeStory: true
            )
        case .stealthOnly:
            var s = GhostSettings()
            s.isEnabled = true
            s.suppressOnlinePresence = true
            s.suppressTypingIndicator = true
            s.suppressReadReceipts = false
            s.suppressStoryRead = false
            s.suppressUploadProgress = true
            s.readOnAction = false
            s.scheduledSendingEnabled = false
            s.sendWithoutSound = .never
            s.sendOfflinePacketAfterOnline = true
            return s
        case .unreadStealth:
            var s = GhostSettings()
            s.isEnabled = true
            s.suppressOnlinePresence = false
            s.suppressTypingIndicator = false
            s.suppressReadReceipts = true
            s.suppressStoryRead = true
            s.suppressUploadProgress = false
            s.readOnAction = true
            s.scheduledSendingEnabled = false
            s.sendWithoutSound = .never
            s.sendOfflinePacketAfterOnline = false
            return s
        case .off:
            return .disabled
        }
    }
}

/// Notification fired whenever GhostSettings change.
public extension Notification.Name {
    static let ghostSettingsDidChange = Notification.Name("org.whitegram.ghostSettingsDidChange")
}

/// Persistent store managing Ghost Mode configuration globally and per account.
public final class GhostSettingsStore {
    public static let shared = GhostSettingsStore()
    
    private let storageFileName = "ghost_settings.json"
    private let globalKey = "global_ghost_settings"
    private let accountKeyPrefix = "ghost_settings_account_"
    private let lock = NSLock()
    
    private let settingsSubject: CurrentValueSubject<GhostSettings, Never>
    public var settingsPublisher: AnyPublisher<GhostSettings, Never> {
        return settingsSubject.eraseToAnyPublisher()
    }
    
    private var cachedSettings: GhostSettings
    private var accountOverrides: [String: GhostSettings] = [:]
    
    private init() {
        let initial: GhostSettings
        if let loaded = WhiteGramStorage.shared.load(GhostSettings.self, from: storageFileName) {
            initial = loaded
        } else {
            initial = .default
        }
        self.cachedSettings = initial
        self.settingsSubject = CurrentValueSubject(initial)
        
        loadAccountOverrides()
    }
    
    private func loadAccountOverrides() {
        if let overrides = WhiteGramStorage.shared.load([String: GhostSettings].self, from: "ghost_account_overrides.json") {
            self.accountOverrides = overrides
        }
    }
    
    private func persistSettings() {
        do {
            try WhiteGramStorage.shared.save(cachedSettings, to: storageFileName)
            try WhiteGramStorage.shared.save(accountOverrides, to: "ghost_account_overrides.json")
        } catch {
            WhiteGramLog.error("Failed to persist ghost settings: \(error)")
        }
    }
    
    public var currentSettings: GhostSettings {
        lock.lock()
        defer { lock.unlock() }
        return cachedSettings
    }
    
    public func settings(for accountId: String? = nil) -> GhostSettings {
        lock.lock()
        defer { lock.unlock() }
        if let accountId = accountId, let override = accountOverrides[accountId] {
            return override
        }
        return cachedSettings
    }
    
    public func updateGlobalSettings(_ mutate: (inout GhostSettings) -> Void) {
        lock.lock()
        mutate(&cachedSettings)
        let updated = cachedSettings
        persistSettings()
        lock.unlock()
        
        settingsSubject.send(updated)
        NotificationCenter.default.post(name: .ghostSettingsDidChange, object: updated)
        WhiteGramLog.info("Global GhostSettings updated: isEnabled=\(updated.isEnabled)")
    }
    
    public func setAccountOverride(_ settings: GhostSettings?, for accountId: String) {
        lock.lock()
        if let settings = settings {
            accountOverrides[accountId] = settings
        } else {
            accountOverrides.removeValue(forKey: accountId)
        }
        persistSettings()
        lock.unlock()
        
        WhiteGramLog.info("Account override updated for \(accountId)")
    }
    
    public func resetToDefaults() {
        updateGlobalSettings { $0 = .default }
    }
}
