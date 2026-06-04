# ``RhoeLoggingKit``

Core logging infrastructure for the RhoeSuite ecosystem.

## Overview

RhoeLoggingKit provides the fundamental logging engine that all RhoeSuite packages depend on. It was extracted from RhoeConsoleKit to eliminate circular dependencies and create a clean architectural separation between logging infrastructure and UI components.

## Architecture

The package follows a clean, layered architecture:

```
RhoeLoggingKit (Foundation Layer)
    ↑
RhoeConsoleKit (UI Layer)
    ↑
Application Layer
```

This separation ensures that packages like RhoeSyntaxKit can use logging without creating circular dependencies.

## Topics

### Essentials

- ``RhoeLogger``
- ``LogLevel``
- ``LogCategory``
- ``LogEntry``

### Destinations

- ``LogDestination``
- ``ConsoleDestination``
- ``FileDestination``

### Global Functions

- ``logger``
- ``logDebug(_:category:metadata:file:function:line:)``
- ``logInfo(_:category:metadata:file:function:line:)``
- ``logWarning(_:category:metadata:file:function:line:)``
- ``logError(_:category:metadata:file:function:line:)``
- ``logFault(_:category:metadata:file:function:line:)``

## Usage Examples

### Basic Logging

```swift
import RhoeLoggingKit

// Using the global logger
logger.info("Application started")
logger.warning("Low memory condition detected")
logger.error("Failed to connect to server")

// Using quick access functions
logInfo("User logged in", metadata: ["userId": "123"])
logError("Database query failed")
```

### Custom Logger Configuration

```swift
// Create logger with multiple destinations
let fileURL = URL(fileURLWithPath: "/tmp/app.log")
let customLogger = RhoeLogger(
    destinations: [
        ConsoleDestination(),
        FileDestination(fileURL: fileURL)
    ],
    maxEntries: 5000
)

// Log with category and metadata
customLogger.info(
    "API request completed",
    category: .network,
    metadata: [
        "endpoint": "/api/users",
        "method": "GET",
        "duration": "125ms"
    ]
)
```

### Performance Logging

```swift
let startTime = Date()

// Perform operation
let result = try await performDatabaseQuery()

let duration = Date().timeIntervalSince(startTime)
logger.logPerformance(
    operation: "Database Query",
    duration: duration,
    metadata: ["queryType": "SELECT", "rows": "\(result.count)"]
)
```

### Error Logging

```swift
do {
    try await riskyOperation()
} catch {
    logger.logError(
        error,
        context: "Failed to complete risky operation",
        category: .errors
    )
}
```

## Features

### Thread Safety

RhoeLogger uses NSLock to ensure thread-safe access to the entry collection:

```swift
private let lock = NSLock()
private var _entries: [LogEntry] = []

public var entries: [LogEntry] {
    lock.withLock { _entries }
}
```

### Memory Management

Automatic log rotation keeps memory usage under control:

```swift
if _entries.count > maxEntries {
    _entries.removeFirst(_entries.count - maxEntries)
}
```

### System Integration

Seamless integration with Apple's unified logging system:

```swift
osLogger.log(level: level.osLogType, "\(message, privacy: .public)")
```

## Migration from RhoeConsoleKit

If you were previously importing RhoeConsoleKit just for logging:

**Before:**
```swift
import RhoeConsoleKit

let logger = RhoeLogger.shared
logger.info("Message")
```

**After:**
```swift
import RhoeLoggingKit

let logger = RhoeLogger.shared  // Same API
logger.info("Message")          // Same usage
```

RhoeConsoleKit now re-exports all RhoeLoggingKit types, so existing code continues to work without changes.

## Requirements

- macOS 15.0+ / iOS 18.0+ / visionOS 2.0+
- Swift 6.0+
- RhoeFoundation