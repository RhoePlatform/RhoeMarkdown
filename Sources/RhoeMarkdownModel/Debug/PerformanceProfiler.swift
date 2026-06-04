import Foundation

// MARK: - Performance Profiling Tools

public struct PerformanceProfiler: Sendable {
    nonisolated(unsafe) public static var isEnabled = false
    
    nonisolated(unsafe) private static var measurements: [String: [Double]] = [:]
    #if canImport(Dispatch)
    private static let queue = DispatchQueue(label: "profiler.queue")
    #endif

    public static func measure<T>(_ label: String, operation: () throws -> T) rethrows -> T {
        guard isEnabled else { return try operation() }

        let startTime = Date().timeIntervalSinceReferenceDate
        let result = try operation()
        let duration = Date().timeIntervalSinceReferenceDate - startTime

        #if canImport(Dispatch)
        queue.async {
            measurements[label, default: []].append(duration * 1000)
        }
        #else
        measurements[label, default: []].append(duration * 1000)
        #endif

        return result
    }

    public static func measureAsync<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
        guard isEnabled else { return try await operation() }

        let startTime = Date().timeIntervalSinceReferenceDate
        let result = try await operation()
        let duration = Date().timeIntervalSinceReferenceDate - startTime

        #if canImport(Dispatch)
        queue.async {
            measurements[label, default: []].append(duration * 1000)
        }
        #else
        measurements[label, default: []].append(duration * 1000)
        #endif

        return result
    }

    public static func reset() {
        #if canImport(Dispatch)
        queue.sync {
            measurements.removeAll()
        }
        #else
        measurements.removeAll()
        #endif
    }

    public static func printReport() {
        #if canImport(Dispatch)
        queue.sync {
            print("\n🔬 Performance Profile Report")
            print("=" * 50)
            
            let sortedMeasurements = measurements.sorted { $0.value.reduce(0, +) > $1.value.reduce(0, +) }
            
            for (label, times) in sortedMeasurements {
                let total = times.reduce(0, +)
                let avg = total / Double(times.count)
                let count = times.count
                
                print("\n📊 \(label)")
                print("   Total: \(String(format: "%.2f", total))ms")
                print("   Average: \(String(format: "%.2f", avg))ms")
                print("   Count: \(count)")
                
                if count > 1 {
                    let min = times.min() ?? 0
                    let max = times.max() ?? 0
                    print("   Range: \(String(format: "%.2f", min))ms - \(String(format: "%.2f", max))ms")
                }
            }
            
            print("\n" + "=" * 50)
        }
        #endif
    }

    public static func getMeasurements() -> [String: [Double]] {
        #if canImport(Dispatch)
        return queue.sync { measurements }
        #else
        return measurements
        #endif
    }
}

// MARK: - Debug Extensions

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}