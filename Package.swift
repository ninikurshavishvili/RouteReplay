// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RouteReplay",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RouteReplay", targets: ["RouteReplay"])
    ],
    targets: [
        .target(name: "RouteReplay"),
        .testTarget(name: "RouteReplayTests", dependencies: ["RouteReplay"])
    ]
)
