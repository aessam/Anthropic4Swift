// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Anthropic4Swift",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Anthropic4Swift",
            targets: ["Anthropic4Swift"]
        ),
        .executable(
            name: "Examples",
            targets: ["Examples"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Anthropic4Swift"
        ),
        .executableTarget(
            name: "Examples",
            dependencies: ["Anthropic4Swift"]
        ),
        .testTarget(
            name: "Anthropic4SwiftTests",
            dependencies: ["Anthropic4Swift"]
        ),
    ]
)
