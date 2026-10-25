// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MCPCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MCPCore", targets: ["MCPCore"])
    ],
    targets: [
        .target(
            name: "MCPCore",
            path: "Sources"
        ),
        .testTarget(
            name: "MCPCoreTests",
            dependencies: ["MCPCore"],
            path: "Tests"
        )
    ]
)
