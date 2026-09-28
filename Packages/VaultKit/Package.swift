// swift-tools-version: 6.2
import PackageDescription

// VaultKit: models, format, parser, index, watcher, grammar. Foundation only (§8.3).
let package = Package(
    name: "VaultKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "VaultKit", targets: ["VaultKit"]),
        .executable(name: "vaultctl", targets: ["vaultctl"]),
    ],
    targets: [
        .target(name: "VaultKit"),
        .executableTarget(name: "vaultctl", dependencies: ["VaultKit"]),
        .testTarget(name: "VaultKitTests", dependencies: ["VaultKit"]),
    ]
)
