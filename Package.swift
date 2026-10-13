// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "StickControlCore",
    platforms: [.iOS(.v17)],
    products: [.library(name: "StickControlCore", targets: ["StickControlCore"])],
    targets: [
        .target(name: "StickControlCore", path: "StickControl/Core"),
        .testTarget(name: "StickControlCoreTests", dependencies: ["StickControlCore"])
    ]
)
