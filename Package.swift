// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TailPort",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "TailPort",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
