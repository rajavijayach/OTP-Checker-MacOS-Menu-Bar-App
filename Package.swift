// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OTPChecker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OTPChecker", targets: ["OTPChecker"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
    ],
    targets: [
        .executableTarget(
            name: "OTPChecker",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ]
        ),
    ]
)
