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
        .library(name: "Design", targets: ["Design"]),
        .library(name: "PlantCatalog", targets: ["PlantCatalog"]),
        .library(name: "Today", targets: ["Today"]),
        .library(name: "Capture", targets: ["Capture"]),
        .executable(name: "knowledge-importer", targets: ["knowledge-importer"]),
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
        .target(
            name: "Design",
            resources: [.process("Colors.xcassets")]
        ),
        .target(name: "Today", dependencies: ["Domain"]),
        .target(
            name: "Knowledge",
            dependencies: [
                "Domain", "Graph", "Persistence",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(name: "GardenModel", dependencies: ["Domain", "Persistence"]),
        .target(
            name: "Capture",
            dependencies: ["Domain", "Graph", "Persistence", "PlantCatalog"]
        ),
        .target(
            name: "PlantCatalog",
            dependencies: [
                "Domain", "Persistence", "Graph", .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .executableTarget(name: "knowledge-importer", dependencies: ["Knowledge"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(
            name: "CaptureTests",
            dependencies: ["Capture", "Domain", "Graph", "Persistence", "PlantCatalog"]
        ),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Domain"]),
        .testTarget(name: "GraphTests", dependencies: ["Graph", "Persistence"]),
        .testTarget(
            name: "KnowledgeTests",
            dependencies: [
                "Knowledge", "Domain", "Graph", "Persistence",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(name: "DesignTests", dependencies: ["Design"]),
        .testTarget(
            name: "PlantCatalogTests",
            dependencies: ["PlantCatalog", "Domain", "Persistence", "Graph"]
        ),
        .testTarget(name: "TodayTests", dependencies: ["Today", "Domain"]),
        .testTarget(
            name: "GardenModelTests",
            dependencies: ["GardenModel", "Domain", "Persistence"]
        ),
    ]
)
