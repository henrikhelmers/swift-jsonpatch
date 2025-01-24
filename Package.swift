// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JSONPatch",
    platforms: [.iOS(.v16), .macOS(.v14), .tvOS(.v16)],
    products: [
        .library(
            name: "JSONPatch",
            targets: ["JSONPatch"]
        )
    ],
    targets: [
        .target(
            name: "JSONPatch",
            dependencies: [],
            // WORKAROUND: This should only exist in the test target
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "JSONPatchTests",
            dependencies: ["JSONPatch"],
            path: "Tests"
            // resources: [.process("Resources")]
        )
    ]
)
