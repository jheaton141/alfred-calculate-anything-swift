// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CalculateAnything",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "calc", targets: ["calc"])],
    targets: [
        .target(name: "CalcCore"),
        .executableTarget(name: "calc", dependencies: ["CalcCore"]),
        .testTarget(name: "CalcCoreTests", dependencies: ["CalcCore"], resources: [.copy("Fixtures")]),
    ]
)
