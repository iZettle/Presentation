// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "Presentation",
            targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/iZettle/Flow.git", branch: "xcode-16")
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: ["Flow"],
            path: "Presentation"),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Presentation"],
            path: "PresentationTests"),
    ]
)
