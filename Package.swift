// swift-tools-version: 6.0
// ZIYON SAS — ZIYONRest

import PackageDescription

let package = Package(
    name: "ZIYONRest",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ZIYONRest",
            targets: ["ZIYONRest"]
        )
    ],
    targets: [
        .target(
            name: "ZIYONRest",
            path: "Sources/ZIYONRest"
        ),
        .testTarget(
            name: "ZIYONRestTests",
            dependencies: ["ZIYONRest"],
            path: "Tests/ZIYONRestTests"
        )
    ]
)
