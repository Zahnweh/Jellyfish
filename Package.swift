// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jellyfish",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Jellyfish",
            dependencies: [],
            path: "Sources/Jellyfish",
            resources: [
                .process("snippets.json"),
                .copy("StatusBarTemplate@2x.png"),
            ]
        )
    ]
)
