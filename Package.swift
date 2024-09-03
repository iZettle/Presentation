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
        .package(url: "https://github.com/iZettle/Flow.git", revision:"fce5caed4500e490c8fadcd28893a7f207438bfe")
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
