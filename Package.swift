// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Nacrelum",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "Nacrelum",
            targets: ["Nacrelum"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Nacrelum",
            path: "Sources/Nacrelum",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
