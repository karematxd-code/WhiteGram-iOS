// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhiteGram",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "WhiteGramCore",
            targets: ["WhiteGramCore"]
        ),
        .library(
            name: "GhostMode",
            targets: ["GhostMode"]
        ),
        .library(
            name: "Gifts",
            targets: ["Gifts"]
        ),
        .library(
            name: "Upgrader",
            targets: ["Upgrader"]
        ),
        .library(
            name: "ProfileSync",
            targets: ["ProfileSync"]
        ),
        .library(
            name: "WhiteGramUI",
            targets: ["WhiteGramUI"]
        )
    ],
    dependencies: [
        // External dependencies when compiled standalone.
        // In full Telegram-iOS Bazel builds, TelegramCore and UI libraries are linked via Bazel targets.
    ],
    targets: [
        .target(
            name: "WhiteGramCore",
            dependencies: [],
            path: "Sources/WhiteGramCore",
            resources: []
        ),
        .target(
            name: "GhostMode",
            dependencies: [
                "WhiteGramCore"
            ],
            path: "Sources/GhostMode"
        ),
        .target(
            name: "Gifts",
            dependencies: [
                "WhiteGramCore"
            ],
            path: "Sources/Gifts"
        ),
        .target(
            name: "Upgrader",
            dependencies: [
                "WhiteGramCore",
                "Gifts"
            ],
            path: "Sources/Upgrader"
        ),
        .target(
            name: "ProfileSync",
            dependencies: [
                "WhiteGramCore"
            ],
            path: "Sources/ProfileSync"
        ),
        .target(
            name: "WhiteGramUI",
            dependencies: [
                "WhiteGramCore",
                "GhostMode",
                "Gifts",
                "Upgrader",
                "ProfileSync"
            ],
            path: "Sources/WhiteGramUI"
        ),
        .testTarget(
            name: "WhiteGramTests",
            dependencies: [
                "WhiteGramCore",
                "GhostMode",
                "Gifts",
                "Upgrader",
                "ProfileSync"
            ],
            path: "Tests/WhiteGramTests"
        )
    ]
)
