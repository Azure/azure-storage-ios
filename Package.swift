// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AZSClient",
    platforms: [
        .iOS(.v8),
    ],
    products: [
        .library(
            name: "AZSClient",
            targets: ["AZSClient"])
    ],
    targets: [
        .target(
            name: "AZSClient",
            path: "Lib/Azure Storage Client Library/Azure Storage Client Library",
            publicHeadersPath: "./")
    ]
)
