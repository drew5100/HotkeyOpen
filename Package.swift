// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HotkeyOpen",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "HotkeyOpen",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "HotkeyOpen",
            exclude: [
                "Resources",
                "HotkeyOpen.entitlements",
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
