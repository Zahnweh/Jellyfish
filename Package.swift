// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jellyfish",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Jellyfish",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Jellyfish",
            resources: [
                .process("snippets.json"),
                .copy("StatusBarTemplate@2x.png"),
            ]
        )
    ]
)
