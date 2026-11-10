// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FurElise",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Автообновление.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.6.4"),
    ],
    targets: [
        .executableTarget(
            name: "FurElise",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/FurElise",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
