// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TestDoublesToolPlugin",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .plugin(
            name: "TestDoublesToolPlugin",
            targets: ["TestDoublesToolPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TestDoublesGenerator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .plugin(
            name: "TestDoublesToolPlugin",
            capability: .buildTool(),
            dependencies: ["TestDoublesGenerator"]
        )
    ]
)
