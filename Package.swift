// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "kagibako",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "kagibako-scan", targets: ["kagibako-scan"]),
        .executable(name: "KagibakoApp", targets: ["KagibakoApp"]),
        .library(name: "KagibakoScan", targets: ["KagibakoScan"]),
    ],
    targets: [
        .target(name: "KagibakoScan"),
        .executableTarget(name: "kagibako-scan", dependencies: ["KagibakoScan"]),
        .executableTarget(name: "KagibakoApp", dependencies: ["KagibakoScan"]),
        .testTarget(name: "KagibakoScanTests", dependencies: ["KagibakoScan"]),
    ]
)
