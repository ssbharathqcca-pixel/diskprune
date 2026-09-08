// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DiskPrune",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DiskPrune", targets: ["DiskPrune"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DiskPrune",
            dependencies: [],
            path: "Sources/DiskPrune"
        ),
        .testTarget(
            name: "DiskPruneTests",
            dependencies: ["DiskPrune"],
            path: "Tests/DiskPruneTests"
        )
    ]
)
