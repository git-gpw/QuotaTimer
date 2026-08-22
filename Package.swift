// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuotaTimer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "QuotaTimerShared",
            path: "Sources/QuotaTimerShared"
        ),
        .binaryTarget(
            name: "Sparkle",
            path: "Frameworks/Sparkle.xcframework"
        ),
        .executableTarget(
            name: "QuotaTimer",
            dependencies: [
                "QuotaTimerShared",
                "Sparkle",
            ],
            path: "Sources/QuotaTimer",
            exclude: ["Info.plist", "QuotaTimer.entitlements"]
        ),
        .executableTarget(
            name: "QuotaTimerCLI",
            dependencies: ["QuotaTimerShared"],
            path: "Sources/QuotaTimerCLI"
        ),
        .executableTarget(
            name: "QuotaTimerTestRunner",
            dependencies: ["QuotaTimerShared"],
            path: "Tests/QuotaTimerTestRunner",
            resources: [.copy("Fixtures")]
        ),
    ]
)
