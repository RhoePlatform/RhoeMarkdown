import Foundation

// MARK: - Debug Logger for Infinite Loop Hunting

public struct DebugLogger {
    nonisolated(unsafe) public static var isEnabled = false
    nonisolated(unsafe) private static var lastPosition: String.Index?
    nonisolated(unsafe) private static var samePositionCount = 0
    nonisolated(unsafe) private static var methodCallCount: [String: Int] = [:]
    
    public static func log(_ message: String, position: String.Index? = nil) {
        guard isEnabled else { return }
        
        // Check for stuck position
        if let pos = position {
            if pos == lastPosition {
                samePositionCount += 1
                if samePositionCount > 100 {
                    print("🚨 INFINITE LOOP DETECTED! Position stuck at index: \(pos)")
                    print("🚨 Last message: \(message)")
                    fatalError("Infinite loop detected!")
                }
            } else {
                samePositionCount = 0
                lastPosition = pos
            }
        }
        
        print("🔍 \(message)")
    }
    
    public static func trackMethod(_ method: String) {
        guard isEnabled else { return }
        
        methodCallCount[method, default: 0] += 1
        
        if methodCallCount[method]! > 10000 {
            print("🚨 Method '\(method)' called \(methodCallCount[method]!) times!")
            print("🚨 Call frequency:")
            for (m, count) in methodCallCount.sorted(by: { $0.value > $1.value }).prefix(10) {
                print("   \(m): \(count) calls")
            }
            fatalError("Excessive method calls detected!")
        }
    }
    
    public static func reset() {
        lastPosition = nil
        samePositionCount = 0
        methodCallCount.removeAll()
    }
}