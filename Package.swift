// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CursorUsage",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CursorUsage", targets: ["CursorUsage"])
    ],
    targets: [
        .executableTarget(
            name: "CursorUsage",
            path: "Sources/CursorUsage",
            exclude: ["Resources"]
        )
    ]
)
