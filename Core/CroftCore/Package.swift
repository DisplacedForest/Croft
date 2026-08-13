// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CroftCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Graph", targets: ["Graph"]),
        .library(name: "Knowledge", targets: ["Knowledge"]),
        .library(name: "GardenModel", targets: ["GardenModel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(name: "Domain"),
        .target(
            name: "Persistence",
            dependencies: ["Domain", "Graph", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .target(
            name: "Graph",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .target(name: "Knowledge"),
        .target(name: "GardenModel", dependencies: ["Domain", "Persistence"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Domain"]),
        .testTarget(name: "GraphTests", dependencies: ["Graph", "Persistence"]),
        .testTarget(name: "KnowledgeTests", dependencies: ["Knowledge"]),
        .testTarget(
            name: "GardenModelTests",
            dependencies: ["GardenModel", "Domain", "Persistence"]
        ),
    ]
)
