// swift-tools-version: 5.9
//
// Package.swift – Issue 10
//
// All AWC runtime dependencies are Apple system frameworks (Foundation,
// Combine, Network, OSLog).  No third-party packages are required.
// This manifest declares the package structure and the test target so that
// `swift test` can run the AWCTests suite.

import PackageDescription

let package = Package(
    name: "AWC",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17)
    ],
    products: [],          // App target; no library product needed for SPM
    dependencies: [],      // No external package dependencies
    targets: [
        // MARK: Test target
        //
        // Tests live in Tests/AWCTests/ and cover timers, async operations,
        // and error-handling paths introduced in Issues 6, 7, and 8.
        // The target has no source dependency on the main app target because
        // the app ships as an Xcode project; tests exercise isolated helpers
        // and stub types only.
        .testTarget(
            name: "AWCTests",
            dependencies: [],
            path: "Tests/AWCTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
