// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FurElise",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "FurElise", path: "Sources/FurElise")
    ]
)
