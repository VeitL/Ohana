// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PlantRoomStackDemo",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PlantRoomStackDemo",
            targets: ["PlantRoomStackDemo"]
        )
    ],
    targets: [
        .target(name: "PlantRoomStackDemo")
    ]
)
