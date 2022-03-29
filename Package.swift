// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        .library(
            name: "Presentation",
            targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/izettle/Flow.git", .upToNextMajor(from: "1.10.0"))
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
