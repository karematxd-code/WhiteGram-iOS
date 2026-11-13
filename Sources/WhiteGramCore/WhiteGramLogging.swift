import Foundation
import os.log

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public final class WhiteGramLog {
    public static let shared = WhiteGramLog()
    private let subsystem = "org.whitegram.messenger"
    private let osLogger = Logger(subsystem: "org.whitegram.messenger", category: "WhiteGram")
    private let queue = DispatchQueue(label: "org.whitegram.logger.queue", qos: .utility)
    
    public var isDebugEnabled: Bool = true
    
    private init() {}
    
    public static func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(level: .debug, message: message(), file: file, function: function, line: line)
    }
    
    public static func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(level: .info, message: message(), file: file, function: function, line: line)
    }
    
    public static func warning(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(level: .warning, message: message(), file: file, function: function, line: line)
    }
    
    public static func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(level: .error, message: message(), file: file, function: function, line: line)
    }
    
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard isDebugEnabled || level != .debug else { return }
        
        let filename = (file as NSString).lastPathComponent
        let formatted = "[\(level.rawValue)] [\(filename):\(line)] \(function) -> \(message)"
        
        switch level {
        case .debug:
            osLogger.debug("\(formatted, privacy: .public)")
        case .info:
            osLogger.info("\(formatted, privacy: .public)")
        case .warning:
            osLogger.warning("\(formatted, privacy: .public)")
        case .error:
            osLogger.error("\(formatted, privacy: .public)")
        }
    }
}
