#!/usr/bin/env swift

import Foundation
import RhoeMarkdownKit

// MARK: - Benchmark Runner for rhoemd 🏎️

struct Benchmark {
    let name: String
    let markdown: String
    let iterations: Int
    
    struct Result {
        let name: String
        let fileSize: Int
        let iterations: Int
        let totalTime: Double
        let averageTime: Double
        let throughput: Double // MB/s
        let minTime: Double
        let maxTime: Double
        
        func format() -> String {
            return """
            📊 \(name):
              File size:    \(formatBytes(fileSize))
              Iterations:   \(iterations)
              Average time: \(String(format: "%.2f", averageTime)) ms
              Min time:     \(String(format: "%.2f", minTime)) ms
              Max time:     \(String(format: "%.2f", maxTime)) ms
              Throughput:   \(String(format: "%.2f", throughput)) MB/s
            """
        }
        
        private func formatBytes(_ bytes: Int) -> String {
            if bytes < 1024 {
                return "\(bytes) B"
            } else if bytes < 1024 * 1024 {
                return String(format: "%.1f KB", Double(bytes) / 1024.0)
            } else {
                return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
            }
        }
    }
    
    func run() async -> Result {
        var times: [Double] = []
        times.reserveCapacity(iterations)
        
        // Warmup
        print("🔥 Warming up \(name)...")
        for _ in 0..<min(3, iterations/10) {
            _ = await RhoeMarkdownKit.parse(markdown)
        }
        
        // Actual benchmark
        print("🏃 Running \(name) benchmark (\(iterations) iterations)...")
        
        for i in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            _ = await RhoeMarkdownKit.parse(markdown)
            let end = CFAbsoluteTimeGetCurrent()
            times.append((end - start) * 1000) // Convert to milliseconds
            
            if iterations >= 10 && i % (iterations / 10) == 0 && i > 0 {
                print("  Progress: \(i * 100 / iterations)%")
            }
        }
        
        let totalTime = times.reduce(0, +)
        let averageTime = totalTime / Double(iterations)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        let throughput = Double(markdown.count) / (averageTime / 1000.0) / (1024.0 * 1024.0)
        
        return Result(
            name: name,
            fileSize: markdown.count,
            iterations: iterations,
            totalTime: totalTime,
            averageTime: averageTime,
            throughput: throughput,
            minTime: minTime,
            maxTime: maxTime
        )
    }
}

// MARK: - Test Suite

struct BenchmarkSuite {
    static func loadTestFile(_ name: String) -> String? {
        let path = "Benchmarks/\(name)"
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
    
    static func run() async {
        print("🚀 RhoeMarkdownKit Performance Benchmark Suite")
        print("=" * 50)
        print("Version: \(RhoeMarkdownKit.version)")
        print("Date: \(Date())")
        print("Platform: \(getSystemInfo())")
        print("=" * 50)
        print()
        
        // Define test cases
        let testCases = [
            ("tiny.md", 1000),
            ("small.md", 100),
            ("medium.md", 50),
            ("large.md", 10),
            ("huge.md", 3),
            ("deep_nesting.md", 50),
            ("stress_test.md", 20)
        ]
        
        var results: [Benchmark.Result] = []
        
        for (filename, iterations) in testCases {
            guard let markdown = loadTestFile(filename) else {
                print("❌ Failed to load \(filename)")
                continue
            }
            
            let benchmark = Benchmark(
                name: filename,
                markdown: markdown,
                iterations: iterations
            )
            
            let result = await benchmark.run()
            results.append(result)
            print(result.format())
            print()
        }
        
        // Summary
        print("\n" + "=" * 50)
        print("📈 PERFORMANCE SUMMARY")
        print("=" * 50)
        
        let totalThroughput = results.map { $0.throughput }.reduce(0, +) / Double(results.count)
        print("Average throughput: \(String(format: "%.2f", totalThroughput)) MB/s")
        
        // Performance vs file size analysis
        print("\n📊 Throughput by file size:")
        for result in results.sorted(by: { $0.fileSize < $1.fileSize }) {
            let sizeStr = result.fileSize < 1024 ? "\(result.fileSize) B" :
                          result.fileSize < 1024*1024 ? "\(result.fileSize/1024) KB" :
                          "\(result.fileSize/(1024*1024)) MB"
            print("  \(result.name): \(sizeStr) → \(String(format: "%.2f", result.throughput)) MB/s")
        }
        
        // Compare with baseline (if available)
        if let baselineThroughput = getBaselineThroughput() {
            let improvement = (totalThroughput / baselineThroughput - 1) * 100
            if improvement > 0 {
                print("\n🎯 Performance improvement: +\(String(format: "%.1f", improvement))% vs baseline")
            } else {
                print("\n⚠️  Performance regression: \(String(format: "%.1f", improvement))% vs baseline")
            }
        }
        
        print("\n✅ Benchmark complete!")
    }
    
    static func getSystemInfo() -> String {
        let info = ProcessInfo.processInfo
        return "\(info.operatingSystemVersionString), \(info.processorCount) cores"
    }
    
    static func getBaselineThroughput() -> Double? {
        // TODO: Load from previous run or cmark baseline
        return 2.5 // MB/s - typical cmark performance
    }
}

// Extension for string repetition
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// Run benchmarks
await BenchmarkSuite.run()