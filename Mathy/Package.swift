// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mathy",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "Mathy",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
            ],
            path: "Mathy",
            exclude: [
                "Info.plist",
                "Mathy.entitlements",
                "Assets.xcassets",
            ],
            resources: [
                .copy("Resources/latex_preview.html"),
                .copy("Resources/katex"),
                .copy("Resources/mathy_server.py"),
                .copy("Resources/requirements.txt"),
            ]
        ),
    ]
)
