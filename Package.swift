// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SayQuery",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SayQuery", targets: ["VoiceQueryApp"]),
        .executable(name: "SayQueryChecks", targets: ["VoiceQueryChecks"])
    ],
    targets: [
        .target(
            name: "VoiceQueryCore",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "VoiceQueryApp",
            dependencies: ["VoiceQueryCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "VoiceQueryChecks",
            dependencies: ["VoiceQueryCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
