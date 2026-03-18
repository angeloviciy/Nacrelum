// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PixelClaw",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "PixelClaw",
            targets: ["PixelClaw"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PixelClaw",
            path: "Sources/PixelClaw",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
