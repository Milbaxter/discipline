// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "discipline",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "discipline", path: "Sources/discipline")
    ]
)
