// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TravisShot",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0")),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "TravisShot",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                "Defaults",
            ],
            path: "LightShotClone",
            exclude: ["App/Info.plist"],
            resources: [.process("Resources/Assets.xcassets")]
        ),
        .testTarget(
            name: "TravisShotTests",
            dependencies: ["TravisShot"],
            path: "LightShotCloneTests"
        ),
    ]
)
