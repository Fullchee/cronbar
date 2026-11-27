// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Cronbar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CronbarCore"),
        .executableTarget(name: "Cronbar", dependencies: ["CronbarCore"]),
        .testTarget(
            name: "CronbarCoreTests",
            dependencies: ["CronbarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
