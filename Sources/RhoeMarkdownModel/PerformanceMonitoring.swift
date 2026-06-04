import Foundation

public struct PerformanceThresholds: Sendable, Equatable, Codable {
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let executionTime: Double

    public init(
        cpuUsage: Double = 0.8,
        memoryUsage: Double = 0.7,
        executionTime: Double = 1.0
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.executionTime = executionTime
    }
}

public enum MetricUnit: String, Sendable, Codable {
    case count
    case milliseconds
    case seconds
    case bytes
    case ratio
}

public struct PerformanceMetric: Sendable, Codable {
    public let name: String
    public let value: Double
    public let unit: MetricUnit
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        name: String,
        value: Double,
        unit: MetricUnit,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public struct PerformanceStatistics: Sendable, Codable {
    public let metricCount: Int
    public let warningThresholds: PerformanceThresholds
    public let benchmarkingEnabled: Bool
    public let simdOptimizationEnabled: Bool
    public let lastRecordedAt: Date?

    public init(
        metricCount: Int,
        warningThresholds: PerformanceThresholds,
        benchmarkingEnabled: Bool,
        simdOptimizationEnabled: Bool,
        lastRecordedAt: Date?
    ) {
        self.metricCount = metricCount
        self.warningThresholds = warningThresholds
        self.benchmarkingEnabled = benchmarkingEnabled
        self.simdOptimizationEnabled = simdOptimizationEnabled
        self.lastRecordedAt = lastRecordedAt
    }
}

public final class PerformanceMonitor: @unchecked Sendable {
    public static let shared = PerformanceMonitor()

    #if !os(WASI)
    private let lock = NSLock()
    #endif
    private var metrics: [PerformanceMetric] = []
    private var thresholds = PerformanceThresholds()
    private var benchmarkingEnabled = false
    private var simdOptimizationEnabled = false

    private init() {}

    public func configure(
        warningThresholds: PerformanceThresholds = .init(),
        enableSIMDOptimization: Bool = false,
        enableBenchmarking: Bool = false
    ) {
        #if !os(WASI)
        lock.withLock {
            thresholds = warningThresholds
            benchmarkingEnabled = enableBenchmarking
            simdOptimizationEnabled = enableSIMDOptimization
        }
        #else
        thresholds = warningThresholds
        benchmarkingEnabled = enableBenchmarking
        simdOptimizationEnabled = enableSIMDOptimization
        #endif
    }

    public func recordMetric(
        name: String,
        value: Double,
        unit: MetricUnit,
        metadata: [String: String] = [:]
    ) {
        let metric = PerformanceMetric(
            name: name,
            value: value,
            unit: unit,
            metadata: metadata
        )

        #if !os(WASI)
        lock.withLock {
            metrics.append(metric)
        }
        #else
        metrics.append(metric)
        #endif
    }

    public func getStatistics() -> PerformanceStatistics {
        #if !os(WASI)
        lock.withLock {
            PerformanceStatistics(
                metricCount: metrics.count,
                warningThresholds: thresholds,
                benchmarkingEnabled: benchmarkingEnabled,
                simdOptimizationEnabled: simdOptimizationEnabled,
                lastRecordedAt: metrics.last?.timestamp
            )
        }
        #else
        PerformanceStatistics(
            metricCount: metrics.count,
            warningThresholds: thresholds,
            benchmarkingEnabled: benchmarkingEnabled,
            simdOptimizationEnabled: simdOptimizationEnabled,
            lastRecordedAt: metrics.last?.timestamp
        )
        #endif
    }

    public func getAllMetrics() -> [PerformanceMetric] {
        #if !os(WASI)
        lock.withLock { metrics }
        #else
        metrics
        #endif
    }
}
