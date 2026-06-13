// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenNook",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "OpenNook",
            path: "Sources/OpenNook",
            exclude: [
                "Resources/Info.plist",
                "Resources/OpenNook.entitlements"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
