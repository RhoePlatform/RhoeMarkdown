//
//  RhoeLoggingKit.swift
//  RhoeLoggingKit
//
//  Core logging engine extracted from RhoeConsoleKit
//  Provides system-wide logging capabilities without UI dependencies
//

import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// RhoeLoggingKit - Core logging engine
///
/// This package provides the fundamental logging infrastructure
/// that other packages can depend on without circular dependencies.
///
public struct RhoeLoggingKit {
    public static let version = "1.0.0"
    
    private init() {}
}

// MARK: - Log Levels

/// Log level enumeration with visual indicators
public enum LogLevel: Int, CaseIterable, Sendable, Comparable {
    case debug = 0
    case info = 1
    case notice = 2
    case warning = 3
    case error = 4
    case fault = 5
    
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        }
    }
    
    public var emoji: String {
        switch self {
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .notice: return "📝"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fault: return "💥"
        }
    }
    
    #if canImport(OSLog)
    public var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .default
        case .warning: return .info
        case .error: return .error
        case .fault: return .fault
        }
    }
    #endif
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Categories

/// Logging category for organization and filtering
public struct LogCategory: Hashable, Sendable {
    /// The display name of the category
    public let name: String
    
    /// The subsystem identifier for OSLog integration
    public let subsystem: String
    
    /// Creates a new logging category
    public init(name: String, subsystem: String = "com.rhoesuite") {
        self.name = name
        self.subsystem = subsystem
    }
    
    // MARK: - Predefined Categories
    
    /// General purpose logging
    public static let general = LogCategory(name: "General")
    
    /// User interface events
    public static let ui = LogCategory(name: "UI")
    
    /// Network operations
    public static let network = LogCategory(name: "Network")
    
    /// Database operations
    public static let database = LogCategory(name: "Database")
    
    /// Performance metrics
    public static let performance = LogCategory(name: "Performance")
    
    /// Security events
    public static let security = LogCategory(name: "Security")
    
    /// Analytics tracking
    public static let analytics = LogCategory(name: "Analytics")
    
    /// Error handling
    public static let errors = LogCategory(name: "Errors")
    
    /// Terminal operations
    public static let terminal = LogCategory(name: "Terminal")
    
    /// Git operations
    public static let git = LogCategory(name: "Git")
    
    /// AI operations
    public static let ai = LogCategory(name: "AI")
}

// MARK: - Log Entry

/// Represents a single log entry
public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let metadata: [String: String]
    public let file: String
    public let function: String
    public let line: Int
    
    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata ?? [:]
        self.file = file
        self.function = function
        self.line = line
    }
    
    /// Formatted message for console output
    public var formattedMessage: String {
        let time = DateFormatter.localizedString(from: timestamp, dateStyle: .none, timeStyle: .medium)
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        return "\(time) [\(level.name)] \(level.emoji) \(category.name) | \(message) (\(fileName):\(line))"
    }
}

// MARK: - Log Destination Protocol

/// Protocol for log destinations
public protocol LogDestination: Sendable {
    func write(_ entry: LogEntry)
}

// MARK: - Console Destination

/// Default console output destination
public struct ConsoleDestination: LogDestination {
    public init() {}
    
    public func write(_ entry: LogEntry) {
        print(entry.formattedMessage)
    }
}

// MARK: - File Destination

/// File output destination
public struct FileDestination: LogDestination {
    private let fileURL: URL
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    public func write(_ entry: LogEntry) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: entry.timestamp)
        let logLine = "\(timestamp) [\(entry.level.name)] \(entry.category.name): \(entry.message)\n"
        
        if let data = logLine.data(using: .utf8) {
            try? data.append(to: fileURL)
        }
    }
}

extension Data {
    fileprivate func append(to url: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try self.write(to: url)
        }
    }
}

// MARK: - Logger

/// The main logger class
public class RhoeLogger: @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [LogEntry] = []
    
    public var entries: [LogEntry] {
        lock.withLock { _entries }
    }
    
    private let destinations: [any LogDestination]
    private let maxEntries: Int
    #if canImport(OSLog)
    private let osLogger: Logger
    #endif
    
    /// Shared logger instance
    public static let shared = RhoeLogger()
    
    /// Initialize a logger with destinations
    public init(
        destinations: [any LogDestination] = [ConsoleDestination()],
        maxEntries: Int = 10000
    ) {
        self.destinations = destinations
        self.maxEntries = maxEntries
        #if canImport(OSLog)
        self.osLogger = Logger(subsystem: "com.rhoesuite.logging", category: "RhoeLogger")
        #endif
    }
    
    /// Main logging function
    public func log(
        level: LogLevel,
        category: LogCategory = .general,
        message: String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        // Add to entries (thread-safe)
        lock.withLock {
            _entries.append(entry)
            
            // Limit size
            if _entries.count > maxEntries {
                _entries.removeFirst(_entries.count - maxEntries)
            }
        }
        
        #if canImport(OSLog)
        osLogger.log(level: level.osLogType, "\(message, privacy: .public)")
        #endif
        
        // Write to destinations
        for destination in destinations {
            destination.write(entry)
        }
    }
    
    // MARK: - Convenience Methods
    
    public func debug(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func notice(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .notice, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func fault(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .fault, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log an Error object
    public func logError(
        _ error: any Error,
        context: String = "",
        category: LogCategory = .errors,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var metadata: [String: String] = [
            "error_type": String(describing: type(of: error))
        ]
        
        if let nsError = error as NSError? {
            metadata["error_domain"] = nsError.domain
            metadata["error_code"] = String(nsError.code)
        }
        
        let message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log performance metrics
    public func logPerformance(
        operation: String,
        duration: TimeInterval,
        category: LogCategory = .performance,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let formattedDuration = String(format: "%.3fms", duration * 1000)
        let message = "\(operation) completed in \(formattedDuration)"
        
        var performanceMetadata = metadata
        performanceMetadata["operation"] = operation
        performanceMetadata["duration"] = formattedDuration
        
        let level: LogLevel = duration > 1.0 ? .warning : .info
        
        log(level: level, category: category, message: message, metadata: performanceMetadata, file: file, function: function, line: line)
    }
    
    /// Clear all log entries
    public func clear() {
        lock.withLock {
            _entries.removeAll()
        }
    }
    
    /// Get entries filtered by level
    public func entries(minLevel: LogLevel) -> [LogEntry] {
        lock.withLock {
            _entries.filter { $0.level >= minLevel }
        }
    }
    
    /// Get entries filtered by category
    public func entries(category: LogCategory) -> [LogEntry] {
        lock.withLock {
            _entries.filter { $0.category == category }
        }
    }
}

// MARK: - Global Logger

/// The global logger instance
public let logger = RhoeLogger.shared

// MARK: - Quick Access Functions

/// Logs a debug message
public func logDebug(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    logger.debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

/// Logs an info message
public func logInfo(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    logger.info(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

/// Logs a warning message
public func logWarning(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    logger.warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

/// Logs an error message
public func logError(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    logger.error(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

/// Logs a fault message
public func logFault(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    logger.fault(message, category: category, metadata: metadata, file: file, function: function, line: line)
}
