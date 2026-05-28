// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "AutoPlan",
    platforms: [.macOS("15.0")],
    products: [
        .library(name: "AutoPlanCore", targets: ["AutoPlanCore"]),
    ],
    dependencies: [
        .package(path: "./Packages/swift-argument-parser"),
        .package(path: "./Packages/Yams")
    ],
    targets: [
        .target(
            name: "AutoPlanCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/AutoPlanCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AutoPlanCoreTests",
            dependencies: ["AutoPlanCore"]
        ),
    ]
    
)
