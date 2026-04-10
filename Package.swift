// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeBuddy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CodeBuddy",
            path: "Sources"
        )
    ]
)
