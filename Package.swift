// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VendingIosSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "VendingIosSDK",
            targets: ["VendingIosSDK"]
        ),
    ],
    dependencies: [
        // No external dependencies - uses only system frameworks
    ],
    targets: [
        .target(
            name: "VendingIosSDK",
            dependencies: [],
            path: "VendingIosSDK",
            exclude: ["Info.plist"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
    ]
)

