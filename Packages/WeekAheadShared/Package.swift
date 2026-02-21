// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeekAheadShared",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [
        .library(name: "WeekAheadShared", targets: ["WeekAheadShared"])
    ],
    targets: [
        .target(name: "WeekAheadShared", path: "Sources/WeekAheadShared")
    ]
)
