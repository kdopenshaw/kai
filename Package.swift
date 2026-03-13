// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kai",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Kai",
            path: "Sources/Kai",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
