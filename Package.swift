// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LidFold",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LidFold", targets: ["LidFold"])],
    targets: [
        .target(name: "LidFoldCore"),
        .target(name: "LidFoldKit", dependencies: ["LidFoldCore"], resources: [.copy("Fold.metal")]),
        .executableTarget(name: "LidFold", dependencies: ["LidFoldKit"]),
        .testTarget(name: "LidFoldTests", dependencies: ["LidFoldCore", "LidFoldKit"])
    ]
)
