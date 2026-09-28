// swift-tools-version: 6.2
import PackageDescription

// DesignKit: the app's identity — colour, type, spacing, motion, Horizon geometry — defined once (§6).
let package = Package(
    name: "DesignKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DesignKit", targets: ["DesignKit"]),
    ],
    targets: [
        .target(name: "DesignKit"),
        .testTarget(name: "DesignKitTests", dependencies: ["DesignKit"]),
    ]
)
