// swift-tools-version: 6.2
// RhoeMarkdown - semantic Markdown compiler and projection engine for Swift.

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .define("DEBUG", .when(configuration: .debug)),
]

let package = Package(
    name: "RhoeMarkdown",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "RhoeMarkdownKit", targets: ["RhoeMarkdownKit"]),
        .library(name: "RhoeMDCore", targets: ["RhoeMDCore"]),
        .library(name: "RhoeMDServer", targets: ["RhoeMDServer"]),
        .library(name: "RhoeMarkdownWasm", targets: ["RhoeMarkdownWasm"]),
        .library(name: "RhoeProjectKitCore", targets: ["RhoeProjectKitCore"]),
        .executable(name: "rhoemd", targets: ["rhoemd"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", revision: "a68a681c8adcd35be1b2b350a49cd0cf7031d084"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.3"),
        .package(url: "https://github.com/RhoePlatform/RhoeLiquid.git", from: "0.1.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "RhoeLoggingKit",
            path: "Sources/RhoeLoggingKit",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMarkdownModel",
            path: "Sources/RhoeMarkdownModel",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMarkdownParsing",
            dependencies: ["RhoeMarkdownModel"],
            path: "Sources/RhoeMarkdownParsing",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeDSLParsing",
            dependencies: ["RhoeMarkdownModel", "RhoeMarkdownParsing"],
            path: "Sources/RhoeDSLParsing",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMarkdownRendering",
            dependencies: ["RhoeMarkdownModel"],
            path: "Sources/RhoeMarkdownRendering",
            resources: [
                .copy("Resources/Icons"),
                .process("Resources/Emojis"),
            ],
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMarkdownPresentation",
            dependencies: [
                "RhoeLoggingKit",
                "RhoeMarkdownModel",
                "RhoeMarkdownParsing",
                "RhoeMarkdownRendering",
            ],
            path: "Sources/RhoeMarkdownPresentation",
            exclude: ["README.md"],
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMarkdownKit",
            dependencies: [
                "RhoeLoggingKit",
                "RhoeMarkdownModel",
                "RhoeMarkdownParsing",
                "RhoeMarkdownRendering",
                "RhoeMarkdownPresentation",
                "RhoeDSLParsing",
                .product(name: "RhoeLiquid", package: "RhoeLiquid"),
            ],
            path: "Sources/RhoeMarkdownKit",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeProjectKitCore",
            dependencies: ["RhoeMarkdownKit"],
            path: "Sources/RhoeProjectKitCore",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMDServer",
            dependencies: [
                "RhoeMarkdownKit",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
            ],
            path: "Sources/RhoeMDServer",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMDCore",
            dependencies: ["RhoeMarkdownKit", "RhoeProjectKitCore", "RhoeMDServer"],
            path: "Sources/RhoeMDCore",
            swiftSettings: strictSwiftSettings
        ),
        .executableTarget(
            name: "rhoemd",
            dependencies: ["RhoeMDCore", "RhoeMDServer", "RhoeMarkdownKit"],
            path: "Sources/rhoemd",
            swiftSettings: strictSwiftSettings
        ),
        .target(
            name: "RhoeMarkdownWasm",
            dependencies: [
                "RhoeMarkdownModel",
                "RhoeMarkdownParsing",
                "RhoeMarkdownRendering",
                .product(name: "RhoeLiquid", package: "RhoeLiquid"),
            ],
            path: "Sources/RhoeMarkdownWasm",
            swiftSettings: strictSwiftSettings
        ),
        .executableTarget(
            name: "rhoemd-benchmark",
            dependencies: ["RhoeMarkdownKit"],
            path: "Benchmarks/rhoemd-benchmark",
            swiftSettings: strictSwiftSettings
        ),
        .executableTarget(
            name: "benchmark-generator",
            dependencies: ["RhoeMarkdownKit"],
            path: "Benchmarks/benchmark-generator",
            swiftSettings: strictSwiftSettings
        ),
        .executableTarget(
            name: "benchmark-competition",
            dependencies: ["RhoeMarkdownKit"],
            path: "Benchmarks/benchmark-competition",
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "RhoeMarkdownKitTests",
            dependencies: [
                "RhoeMarkdownKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/RhoeMarkdownKitTests",
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "rhoemdTests",
            dependencies: [
                "RhoeMDCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/rhoemdTests",
            swiftSettings: strictSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
