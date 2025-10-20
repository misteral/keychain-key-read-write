// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "kc",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "kc",
            targets: ["kc"]
        )
    ],
    targets: [
        .executableTarget(
            name: "kc",
            path: "Sources"
        )
    ]
)
