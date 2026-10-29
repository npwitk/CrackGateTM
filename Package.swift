// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CrackGate",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "CrackGate", targets: ["CrackGate"]),
    ],
    targets: [
        .target(name: "CrackGate"),
        .testTarget(name: "CrackGateTests", dependencies: ["CrackGate"]),
    ],
    swiftLanguageModes: [.v6]
)
