// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Awareness",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AwarenessCore", targets: ["AwarenessCore"]),
        .executable(name: "Awareness", targets: ["Awareness"])
    ],
    targets: [
        .target(
            name: "AwarenessCore",
            path: "Core"
        ),
        .executableTarget(
            name: "Awareness",
            dependencies: ["AwarenessCore"],
            path: "App"
        ),
        .testTarget(
            name: "AwarenessCoreTests",
            dependencies: ["AwarenessCore"],
            path: "Tests/AwarenessCoreTests"
        )
    ]
)
