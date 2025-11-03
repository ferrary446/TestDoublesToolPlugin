// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TestDoublesToolPlugin",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        // Products can be used to vend plugins, making them visible to other packages.
        .plugin(
            name: "TestDoublesToolPlugin",
            targets: ["TestDoublesToolPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        // The command line tool that generates test doubles
        .executableTarget(
            name: "TestDoublesGenerator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Sources2/TestDoublesGenerator"
        ),
        
        // The plugin that invokes the generator tool
        .plugin(
            name: "TestDoublesToolPlugin",
            capability: .buildTool(),
            dependencies: ["TestDoublesGenerator"],
            path: "Plugins/TestDoublesToolPlugin"
        ),
    ]
)
